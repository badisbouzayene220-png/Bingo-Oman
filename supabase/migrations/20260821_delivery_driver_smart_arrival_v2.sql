-- BINGO Driver Smart Arrival V2
-- Computes driver-to-customer distance from the driver's latest GPS position.

create or replace function public.delivery_driver_smart_arrival_context()
returns jsonb
language plpgsql
security definer
set search_path = public
stable
as $$
declare
  v_uid uuid := auth.uid();
  v_assignment public.delivery_assignments%rowtype;
  v_order public.delivery_orders%rowtype;
  v_lat numeric;
  v_lng numeric;
  v_updated timestamptz;
  v_distance_m numeric;
  v_within boolean := false;
begin
  if v_uid is null then raise exception 'Authentication required'; end if;

  select * into v_assignment
  from public.delivery_assignments
  where driver_id=v_uid and status='on_delivery'
  order by coalesce(accepted_at,offered_at) desc nulls last
  limit 1;

  if v_assignment.id is null then
    return jsonb_build_object('active',false);
  end if;

  select * into v_order from public.delivery_orders where id=v_assignment.order_id;

  select l.latitude,l.longitude,l.updated_at
    into v_lat,v_lng,v_updated
  from public.delivery_driver_locations l
  where l.driver_id=v_uid
  order by l.updated_at desc
  limit 1;

  if v_order.latitude is not null and v_order.longitude is not null
     and v_lat is not null and v_lng is not null then
    v_distance_m := 6371000 * 2 * asin(sqrt(
      power(sin(radians((v_lat-v_order.latitude)::double precision)/2),2) +
      cos(radians(v_order.latitude::double precision)) * cos(radians(v_lat::double precision)) *
      power(sin(radians((v_lng-v_order.longitude)::double precision)/2),2)
    ));
    v_within := v_distance_m <= 500;
  end if;

  return jsonb_build_object(
    'active',true,
    'assignment_id',v_assignment.id,
    'order_id',v_order.id,
    'order_number',v_order.order_number,
    'driver_latitude',v_lat,
    'driver_longitude',v_lng,
    'gps_updated_at',v_updated,
    'customer_latitude',v_order.latitude,
    'customer_longitude',v_order.longitude,
    'distance_m',case when v_distance_m is null then null else round(v_distance_m,0) end,
    'within_500m',v_within,
    'code_ready',v_within
  );
end;
$$;

revoke all on function public.delivery_driver_smart_arrival_context() from public;
grant execute on function public.delivery_driver_smart_arrival_context() to authenticated;

notify pgrst, 'reload schema';
