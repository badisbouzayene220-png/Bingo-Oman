-- BINGO Driver Smart Arrival V3 — customer coordinate validation + saved-address fallback
-- Fixes impossible distances caused by 0,0 or invalid order coordinates.

create or replace function public.delivery_driver_smart_arrival_context()
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_assignment public.delivery_assignments%rowtype;
  v_order public.delivery_orders%rowtype;
  v_driver_lat numeric;
  v_driver_lng numeric;
  v_updated timestamptz;
  v_customer_lat numeric;
  v_customer_lng numeric;
  v_distance_m numeric;
  v_within boolean := false;
  v_source text := 'order';
  v_coords_valid boolean := false;
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

  select * into v_order
  from public.delivery_orders
  where id=v_assignment.order_id;

  v_customer_lat := v_order.latitude;
  v_customer_lng := v_order.longitude;

  -- BINGO Oman: reject null/zero coordinates and obviously non-Oman points.
  v_coords_valid := v_customer_lat is not null and v_customer_lng is not null
                    and abs(v_customer_lat) > 0.0001 and abs(v_customer_lng) > 0.0001
                    and v_customer_lat between 16 and 27
                    and v_customer_lng between 52 and 60;

  -- Fallback to the customer's saved address when the order has no usable GPS point.
  if not v_coords_valid and to_regclass('public.customer_saved_addresses') is not null then
    select a.latitude,a.longitude
      into v_customer_lat,v_customer_lng
    from public.customer_saved_addresses a
    where a.user_id=v_order.customer_id
      and a.latitude is not null and a.longitude is not null
      and abs(a.latitude)>0.0001 and abs(a.longitude)>0.0001
      and a.latitude between 16 and 27
      and a.longitude between 52 and 60
    order by
      case when lower(trim(a.address_line)) = lower(trim(coalesce(v_order.delivery_address,''))) then 0 else 1 end,
      a.is_default desc,
      a.updated_at desc
    limit 1;

    if v_customer_lat is not null and v_customer_lng is not null then
      v_coords_valid := true;
      v_source := 'saved_address';
      -- Repair the active order once so all tracking components use the same point.
      update public.delivery_orders
         set latitude=v_customer_lat,
             longitude=v_customer_lng,
             updated_at=now()
       where id=v_order.id;
    end if;
  end if;

  select l.latitude,l.longitude,l.updated_at
    into v_driver_lat,v_driver_lng,v_updated
  from public.delivery_driver_locations l
  where l.driver_id=v_uid
  order by l.updated_at desc
  limit 1;

  if v_coords_valid and v_driver_lat is not null and v_driver_lng is not null then
    v_distance_m := 6371000 * 2 * asin(sqrt(
      power(sin(radians((v_driver_lat-v_customer_lat)::double precision)/2),2) +
      cos(radians(v_customer_lat::double precision)) * cos(radians(v_driver_lat::double precision)) *
      power(sin(radians((v_driver_lng-v_customer_lng)::double precision)/2),2)
    ));
    v_within := v_distance_m <= 500;
  end if;

  return jsonb_build_object(
    'active',true,
    'assignment_id',v_assignment.id,
    'order_id',v_order.id,
    'order_number',v_order.order_number,
    'driver_latitude',v_driver_lat,
    'driver_longitude',v_driver_lng,
    'gps_updated_at',v_updated,
    'customer_latitude',case when v_coords_valid then v_customer_lat else null end,
    'customer_longitude',case when v_coords_valid then v_customer_lng else null end,
    'customer_coordinates_valid',v_coords_valid,
    'coordinate_source',case when v_coords_valid then v_source else 'missing' end,
    'distance_m',case when v_distance_m is null then null else round(v_distance_m,0) end,
    'within_500m',v_within,
    'code_ready',v_within
  );
end;
$$;

revoke all on function public.delivery_driver_smart_arrival_context() from public;
grant execute on function public.delivery_driver_smart_arrival_context() to authenticated;

notify pgrst, 'reload schema';
