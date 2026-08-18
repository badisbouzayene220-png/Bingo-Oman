-- BINGO Delivery Admin: Driver dashboard enhancement (additive)
-- Adds last-online tracking and an admin RPC with driver operational stats.
-- Does NOT replace the existing driver RPCs or button-management RPC.

alter table public.delivery_drivers
  add column if not exists last_online_at timestamptz;

create index if not exists delivery_drivers_last_online_idx
  on public.delivery_drivers(last_online_at desc);

-- Keep the existing function signature. When a driver goes online, record the time.
create or replace function public.delivery_set_driver_status(p_online boolean)
returns public.delivery_drivers
language plpgsql security invoker set search_path = public
as $$
declare v_driver public.delivery_drivers;
begin
  if auth.uid() is null then raise exception 'Authentication required'; end if;

  insert into public.delivery_drivers(id, is_online, is_available, updated_at, last_online_at)
  values(auth.uid(), p_online, p_online, now(), case when p_online then now() else null end)
  on conflict (id) do update set
    is_online = p_online,
    is_available = p_online,
    updated_at = now(),
    last_online_at = case when p_online then now() else public.delivery_drivers.last_online_at end
  returning * into v_driver;

  return v_driver;
end;
$$;

revoke all on function public.delivery_set_driver_status(boolean) from public;
grant execute on function public.delivery_set_driver_status(boolean) to authenticated;

-- Admin-only driver dashboard data. Existing admin_delivery_drivers_all() remains unchanged.
create or replace function public.admin_delivery_drivers_dashboard()
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare v_result jsonb;
begin
  if auth.uid() is null then raise exception 'Authentication required'; end if;

  if not exists (
    select 1 from public.profiles p
    where p.id = auth.uid()
      and p.role = 'admin'
      and p.is_active = true
  ) then
    raise exception 'Admin access required';
  end if;

  select coalesce(jsonb_agg(to_jsonb(x) order by x.is_online desc, x.is_available desc, x.display_name nulls last), '[]'::jsonb)
    into v_result
  from (
    select
      d.id,
      d.display_name,
      d.phone,
      d.vehicle_type,
      d.is_online,
      d.is_available,
      d.rating,
      d.total_deliveries,
      d.created_at,
      d.updated_at,
      d.last_online_at,
      loc.latitude,
      loc.longitude,
      loc.accuracy_m,
      loc.heading,
      loc.speed_kmh,
      loc.updated_at as location_updated_at,
      coalesce(stats.completed_deliveries,0) as completed_deliveries,
      coalesce(stats.cancelled_deliveries,0) as cancelled_deliveries,
      coalesce(stats.total_assignments,0) as total_assignments,
      cur.order_number as current_order_number,
      cur.order_status as current_order_status,
      cur.delivery_address as current_delivery_address,
      cur.order_total as current_order_total,
      cur.order_id as current_order_id
    from public.delivery_drivers d
    left join public.delivery_driver_locations loc on loc.driver_id = d.id
    left join lateral (
      select
        count(*) filter (where a.status='delivered')::int as completed_deliveries,
        count(*) filter (where a.status='cancelled')::int as cancelled_deliveries,
        count(*)::int as total_assignments
      from public.delivery_assignments a
      where a.driver_id = d.id
    ) stats on true
    left join lateral (
      select
        o.id as order_id,
        o.order_number,
        o.status as order_status,
        o.delivery_address,
        o.total as order_total
      from public.delivery_assignments a
      join public.delivery_orders o on o.id = a.order_id
      where a.driver_id = d.id
        and a.status in ('offered','accepted','picked_up','on_delivery')
      order by a.offered_at desc
      limit 1
    ) cur on true
  ) x;

  return v_result;
end;
$$;

revoke all on function public.admin_delivery_drivers_dashboard() from public;
grant execute on function public.admin_delivery_drivers_dashboard() to authenticated;
