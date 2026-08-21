-- BINGO Driver Journey — Store Arrival V1
-- Adds a persistent "arrived at store" milestone without changing existing delivery statuses.

alter table public.delivery_assignments
  add column if not exists store_arrived_at timestamptz;

create or replace function public.delivery_driver_arrive_store(p_assignment_id uuid)
returns jsonb
language plpgsql
security definer
set search_path=public
as $$
declare
  v_uid uuid := auth.uid();
  v public.delivery_assignments%rowtype;
begin
  if v_uid is null then raise exception 'Authentication required'; end if;

  update public.delivery_assignments
     set store_arrived_at = coalesce(store_arrived_at, now())
   where id = p_assignment_id
     and driver_id = v_uid
     and status = 'accepted'
  returning * into v;

  if v.id is null then
    raise exception 'Active accepted assignment not found';
  end if;

  return jsonb_build_object(
    'ok', true,
    'assignment_id', v.id,
    'order_id', v.order_id,
    'store_arrived_at', v.store_arrived_at
  );
end;
$$;

revoke all on function public.delivery_driver_arrive_store(uuid) from public;
grant execute on function public.delivery_driver_arrive_store(uuid) to authenticated;

create or replace function public.delivery_driver_journey_context()
returns jsonb
language plpgsql
security definer
set search_path=public
stable
as $$
declare
  v_uid uuid := auth.uid();
  a public.delivery_assignments%rowtype;
  o public.delivery_orders%rowtype;
  s public.delivery_stores%rowtype;
begin
  if v_uid is null then raise exception 'Authentication required'; end if;

  select * into a
  from public.delivery_assignments
  where driver_id=v_uid
    and status in ('accepted','picked_up','on_delivery')
  order by coalesce(accepted_at, offered_at) desc nulls last
  limit 1;

  if a.id is null then return null; end if;

  select * into o from public.delivery_orders where id=a.order_id;
  if o.store_id is not null then
    select * into s from public.delivery_stores where id=o.store_id;
  end if;

  return jsonb_build_object(
    'assignment', to_jsonb(a),
    'order', to_jsonb(o),
    'store', case when s.id is null then null else to_jsonb(s) end
  );
end;
$$;

revoke all on function public.delivery_driver_journey_context() from public;
grant execute on function public.delivery_driver_journey_context() to authenticated;

notify pgrst, 'reload schema';
