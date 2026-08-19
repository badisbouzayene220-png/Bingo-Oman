-- BINGO Code Proximity V2
-- Requires the assigned driver to be within 500m of the delivery point
-- before the customer can see the code or the driver can confirm delivery.

create or replace function public.delivery_distance_m(
  p_lat1 numeric, p_lon1 numeric, p_lat2 numeric, p_lon2 numeric
)
returns numeric
language sql
immutable
set search_path = public
as $$
  select case
    when p_lat1 is null or p_lon1 is null or p_lat2 is null or p_lon2 is null then null
    else 6371000 * 2 * atan2(
      sqrt(
        power(sin(radians((p_lat2-p_lat1)::double precision)/2),2) +
        cos(radians(p_lat1::double precision))*cos(radians(p_lat2::double precision))*
        power(sin(radians((p_lon2-p_lon1)::double precision)/2),2)
      ),
      sqrt(1-(
        power(sin(radians((p_lat2-p_lat1)::double precision)/2),2) +
        cos(radians(p_lat1::double precision))*cos(radians(p_lat2::double precision))*
        power(sin(radians((p_lon2-p_lon1)::double precision)/2),2)
      ))
    )
  end;
$$;

create or replace function public.delivery_customer_bingo_code(p_order_id uuid)
returns text
language plpgsql
security definer
set search_path = public
as $$
declare
  v_code text;
  v_driver uuid;
  v_order_lat numeric;
  v_order_lon numeric;
  v_driver_lat numeric;
  v_driver_lon numeric;
  v_distance numeric;
begin
  if auth.uid() is null then raise exception 'Authentication required'; end if;

  select a.driver_id,o.latitude,o.longitude
    into v_driver,v_order_lat,v_order_lon
  from public.delivery_orders o
  join public.delivery_assignments a on a.order_id=o.id and a.status='on_delivery'
  where o.id=p_order_id
    and o.customer_id=auth.uid()
    and o.status='on_delivery'
  order by a.offered_at desc
  limit 1;

  if v_driver is null then raise exception 'BINGO Code not available'; end if;

  select l.latitude,l.longitude into v_driver_lat,v_driver_lon
  from public.delivery_driver_locations l where l.driver_id=v_driver;

  v_distance := public.delivery_distance_m(v_driver_lat,v_driver_lon,v_order_lat,v_order_lon);
  if v_distance is null or v_distance > 500 then
    raise exception 'BINGO Code available only within 500m of the customer';
  end if;

  select c.code into v_code
  from public.delivery_order_codes c
  where c.order_id=p_order_id and c.verified_at is null;

  if v_code is null then raise exception 'BINGO Code not available'; end if;
  return v_code;
end;
$$;

create or replace function public.delivery_confirm_with_code(p_assignment_id uuid,p_code text)
returns public.delivery_assignments
language plpgsql
security definer
set search_path = public
as $$
declare
  v_assignment public.delivery_assignments;
  v_expected text;
  v_order public.delivery_orders;
  v_location public.delivery_driver_locations;
  v_distance numeric;
begin
  if auth.uid() is null then raise exception 'Authentication required'; end if;
  if p_code is null or p_code !~ '^[0-9]{4}$' then raise exception 'Invalid BINGO Code'; end if;

  select a.* into v_assignment
  from public.delivery_assignments a
  where a.id=p_assignment_id and a.driver_id=auth.uid() and a.status='on_delivery'
  for update;
  if v_assignment.id is null then raise exception 'Assignment not available for delivery confirmation'; end if;

  select * into v_order from public.delivery_orders where id=v_assignment.order_id for update;
  select * into v_location from public.delivery_driver_locations where driver_id=auth.uid();
  v_distance := public.delivery_distance_m(v_location.latitude,v_location.longitude,v_order.latitude,v_order.longitude);
  if v_distance is null then raise exception 'GPS location required before delivery confirmation'; end if;
  if v_distance > 500 then raise exception 'Move within 500m of the customer before using BINGO Code'; end if;

  select c.code into v_expected from public.delivery_order_codes c
  where c.order_id=v_assignment.order_id and c.verified_at is null
  for update;
  if v_expected is null or v_expected <> p_code then raise exception 'Incorrect BINGO Code'; end if;

  update public.delivery_assignments set status='delivered',delivered_at=coalesce(delivered_at,now())
  where id=v_assignment.id returning * into v_assignment;
  update public.delivery_orders set status='delivered',updated_at=now() where id=v_assignment.order_id;
  update public.delivery_order_codes set verified_at=coalesce(verified_at,now()) where order_id=v_assignment.order_id;
  update public.delivery_drivers set is_available=true,total_deliveries=total_deliveries+1,updated_at=now() where id=auth.uid();
  insert into public.delivery_earnings(driver_id,order_id,amount,status)
  select auth.uid(),o.id,o.driver_share,'pending' from public.delivery_orders o where o.id=v_assignment.order_id
  on conflict(driver_id,order_id) do nothing;
  return v_assignment;
end;
$$;

-- Rebuild tracking context so bingo_code is returned only inside Smart Arrival range.
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
  v_distance numeric;
begin
  if auth.uid() is null then raise exception 'Authentication required'; end if;
  select * into v_order from public.delivery_orders where id=p_order_id and customer_id=auth.uid();
  if v_order.id is null then raise exception 'Order not found'; end if;
  select * into v_store from public.delivery_stores where id=v_order.store_id;
  select * into v_assignment from public.delivery_assignments
  where order_id=v_order.id and status in ('offered','accepted','picked_up','on_delivery','delivered')
  order by offered_at desc limit 1;
  if v_assignment.id is not null then
    select * into v_driver from public.delivery_drivers where id=v_assignment.driver_id;
    select * into v_location from public.delivery_driver_locations where driver_id=v_assignment.driver_id;
  end if;
  v_distance := public.delivery_distance_m(v_location.latitude,v_location.longitude,v_order.latitude,v_order.longitude);
  if v_order.status='on_delivery' and v_distance is not null and v_distance <= 500 then
    select code into v_code from public.delivery_order_codes where order_id=v_order.id and verified_at is null;
  end if;
  return jsonb_build_object(
    'order',jsonb_build_object('id',v_order.id,'order_number',v_order.order_number,'status',v_order.status,'total',v_order.total,'delivery_fee',v_order.delivery_fee,'delivery_address',v_order.delivery_address,'latitude',v_order.latitude,'longitude',v_order.longitude,'created_at',v_order.created_at,'updated_at',v_order.updated_at),
    'store',case when v_store.id is null then null else jsonb_build_object('id',v_store.id,'name',coalesce(v_store.store_name_ar,v_store.store_name_en,v_store.store_name),'phone',v_store.phone,'latitude',v_store.latitude,'longitude',v_store.longitude) end,
    'assignment',case when v_assignment.id is null then null else jsonb_build_object('id',v_assignment.id,'status',v_assignment.status,'offered_at',v_assignment.offered_at,'accepted_at',v_assignment.accepted_at,'picked_up_at',v_assignment.picked_up_at,'delivered_at',v_assignment.delivered_at) end,
    'driver',case when v_driver.id is null then null else jsonb_build_object('id',v_driver.id,'name',coalesce(v_driver.display_name,'BINGO Driver'),'phone',v_driver.phone,'vehicle',v_driver.vehicle_type,'rating',v_driver.rating,'avatar_url',v_driver.avatar_url) end,
    'driver_location',case when v_location.driver_id is null then null else jsonb_build_object('latitude',v_location.latitude,'longitude',v_location.longitude,'accuracy_m',v_location.accuracy_m,'heading',v_location.heading,'speed_kmh',v_location.speed_kmh,'updated_at',v_location.updated_at) end,
    'distance_m',v_distance,
    'bingo_code',v_code
  );
end;
$$;

revoke all on function public.delivery_customer_bingo_code(uuid) from public;
revoke all on function public.delivery_confirm_with_code(uuid,text) from public;
grant execute on function public.delivery_customer_bingo_code(uuid) to authenticated;
grant execute on function public.delivery_confirm_with_code(uuid,text) to authenticated;
grant execute on function public.delivery_customer_tracking_context(uuid) to authenticated;
