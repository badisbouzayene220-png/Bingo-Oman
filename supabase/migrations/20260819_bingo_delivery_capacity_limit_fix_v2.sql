-- BINGO Delivery Capacity Limit Fix V2
-- Makes driver Online/Available state capacity-aware and exposes saved capacity to Admin.

create or replace function public.delivery_set_driver_status(p_online boolean)
returns public.delivery_drivers
language plpgsql
security invoker
set search_path = public
as $$
declare
  v_driver public.delivery_drivers;
  v_load integer := 0;
  v_max integer := 1;
begin
  if auth.uid() is null then raise exception 'Authentication required'; end if;

  select coalesce(d.max_concurrent_orders,1)
    into v_max
  from public.delivery_drivers d
  where d.id=auth.uid();

  select count(*)::integer
    into v_load
  from public.delivery_assignments a
  where a.driver_id=auth.uid()
    and a.status in ('offered','accepted','picked_up','on_delivery');

  insert into public.delivery_drivers(id,is_online,is_available,updated_at)
  values(auth.uid(),p_online,(p_online and v_load < v_max),now())
  on conflict(id) do update
  set is_online=p_online,
      is_available=(p_online and v_load < coalesce(public.delivery_drivers.max_concurrent_orders,1)),
      updated_at=now()
  returning * into v_driver;

  return v_driver;
end;
$$;

revoke all on function public.delivery_set_driver_status(boolean) from public;
grant execute on function public.delivery_set_driver_status(boolean) to authenticated;

create or replace function public.admin_delivery_driver_capacities()
returns table(
  driver_id uuid,
  driver_name text,
  is_online boolean,
  is_available boolean,
  active_load integer,
  max_concurrent_orders integer,
  remaining_capacity integer
)
language plpgsql
security definer
set search_path=public
stable
as $$
begin
  if not public.delivery_is_admin() then raise exception 'Admin permission required'; end if;

  return query
  select d.id,
         coalesce(d.display_name,d.phone,'BINGO Driver'),
         d.is_online,
         d.is_available,
         count(a.id) filter (where a.status in ('offered','accepted','picked_up','on_delivery'))::integer,
         coalesce(d.max_concurrent_orders,1),
         greatest(coalesce(d.max_concurrent_orders,1)-count(a.id) filter (where a.status in ('offered','accepted','picked_up','on_delivery'))::integer,0)
  from public.delivery_drivers d
  left join public.delivery_assignments a on a.driver_id=d.id
  group by d.id,d.display_name,d.phone,d.is_online,d.is_available,d.max_concurrent_orders
  order by coalesce(d.display_name,d.phone,'BINGO Driver');
end;
$$;

revoke all on function public.admin_delivery_driver_capacities() from public;
grant execute on function public.admin_delivery_driver_capacities() to authenticated;

-- Defensive reconciliation: availability must always agree with capacity.
create or replace function public.admin_delivery_reconcile_driver_capacity()
returns integer
language plpgsql
security definer
set search_path=public
as $$
declare v_count integer;
begin
  if not public.delivery_is_admin() then raise exception 'Admin permission required'; end if;

  update public.delivery_drivers d
  set is_available = d.is_online and (
        (select count(*) from public.delivery_assignments a
         where a.driver_id=d.id and a.status in ('offered','accepted','picked_up','on_delivery'))
        < coalesce(d.max_concurrent_orders,1)
      ),
      updated_at=now();
  get diagnostics v_count = row_count;
  return v_count;
end;
$$;

revoke all on function public.admin_delivery_reconcile_driver_capacity() from public;
grant execute on function public.admin_delivery_reconcile_driver_capacity() to authenticated;
