-- BINGO Customer Tracking Context V2
-- Safe customer-only read model for integrated tracking.

alter table public.delivery_drivers
  add column if not exists avatar_url text;

create or replace function public.delivery_customer_tracking_context(p_order_id uuid)
returns jsonb
language plpgsql
security definer
set search_path=public
as $$
declare
  v_order public.delivery_orders;
  v_assignment public.delivery_assignments;
  v_driver public.delivery_drivers;
  v_location public.delivery_driver_locations;
  v_store public.delivery_stores;
  v_code text;
begin
  if auth.uid() is null then raise exception 'Authentication required'; end if;

  select * into v_order
  from public.delivery_orders
  where id=p_order_id and customer_id=auth.uid();
  if v_order.id is null then raise exception 'Order not found'; end if;

  select * into v_store from public.delivery_stores where id=v_order.store_id;

  select * into v_assignment
  from public.delivery_assignments
  where order_id=v_order.id
    and status in ('offered','accepted','picked_up','on_delivery','delivered')
  order by offered_at desc
  limit 1;

  if v_assignment.id is not null then
    select * into v_driver from public.delivery_drivers where id=v_assignment.driver_id;
    select * into v_location from public.delivery_driver_locations where driver_id=v_assignment.driver_id;
  end if;

  -- Protect the handoff code: reveal only when driver is actively on the way.
  if v_order.status='on_delivery' then
    select code into v_code from public.delivery_order_codes where order_id=v_order.id and verified_at is null;
  end if;

  return jsonb_build_object(
    'order',jsonb_build_object(
      'id',v_order.id,'order_number',v_order.order_number,'status',v_order.status,
      'total',v_order.total,'delivery_fee',v_order.delivery_fee,
      'delivery_address',v_order.delivery_address,'latitude',v_order.latitude,'longitude',v_order.longitude,
      'created_at',v_order.created_at,'updated_at',v_order.updated_at
    ),
    'store',case when v_store.id is null then null else jsonb_build_object(
      'id',v_store.id,'name',coalesce(v_store.store_name_ar,v_store.store_name_en,v_store.store_name),
      'phone',v_store.phone,'latitude',v_store.latitude,'longitude',v_store.longitude
    ) end,
    'assignment',case when v_assignment.id is null then null else jsonb_build_object(
      'id',v_assignment.id,'status',v_assignment.status,'offered_at',v_assignment.offered_at,
      'accepted_at',v_assignment.accepted_at,'picked_up_at',v_assignment.picked_up_at,'delivered_at',v_assignment.delivered_at
    ) end,
    'driver',case when v_driver.id is null then null else jsonb_build_object(
      'id',v_driver.id,'name',coalesce(v_driver.display_name,'BINGO Driver'),'phone',v_driver.phone,
      'vehicle',v_driver.vehicle_type,'rating',v_driver.rating,'avatar_url',v_driver.avatar_url
    ) end,
    'driver_location',case when v_location.driver_id is null then null else jsonb_build_object(
      'latitude',v_location.latitude,'longitude',v_location.longitude,'accuracy_m',v_location.accuracy_m,
      'heading',v_location.heading,'speed_kmh',v_location.speed_kmh,'updated_at',v_location.updated_at
    ) end,
    'bingo_code',v_code
  );
end;
$$;

revoke all on function public.delivery_customer_tracking_context(uuid) from public;
grant execute on function public.delivery_customer_tracking_context(uuid) to authenticated;
