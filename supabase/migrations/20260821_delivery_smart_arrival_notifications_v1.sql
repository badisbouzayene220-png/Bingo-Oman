-- BINGO Delivery — Smart Arrival Notifications V1
-- Notifies customer and assigned driver once when the driver enters the 500m Smart Arrival zone.
-- Requires: delivery_notifications_v1 + bingo_code_proximity_v2 (delivery_distance_m).

create or replace function public.delivery_check_smart_arrival(p_driver_id uuid)
returns void
language plpgsql
security definer
set search_path=public
as $$
declare
  v_location public.delivery_driver_locations%rowtype;
  r record;
  v_distance numeric;
  v_customer_body text;
  v_driver_body text;
begin
  if p_driver_id is null then return; end if;

  select * into v_location
  from public.delivery_driver_locations
  where driver_id=p_driver_id;

  if v_location.driver_id is null
     or v_location.latitude is null
     or v_location.longitude is null then
    return;
  end if;

  for r in
    select
      a.id as assignment_id,
      a.driver_id,
      o.id as order_id,
      o.order_number,
      o.customer_id,
      o.latitude as customer_latitude,
      o.longitude as customer_longitude
    from public.delivery_assignments a
    join public.delivery_orders o on o.id=a.order_id
    where a.driver_id=p_driver_id
      and a.status='on_delivery'
      and o.status='on_delivery'
      and o.latitude is not null
      and o.longitude is not null
  loop
    v_distance := public.delivery_distance_m(
      v_location.latitude,
      v_location.longitude,
      r.customer_latitude,
      r.customer_longitude
    );

    if v_distance is not null and v_distance <= 500 then
      v_customer_body := 'مندوب BINGO أصبح قريبًا منك (ضمن 500 متر). جهّز BINGO Code لتأكيد استلام طلب '||coalesce(r.order_number,'')||'.';
      v_driver_body := 'أنت الآن ضمن نطاق Smart Arrival للطلب '||coalesce(r.order_number,'')||'. اطلب BINGO Code من العميل لإتمام التسليم.';

      perform public.delivery_notify_user(
        r.customer_id,
        'smart_arrival',
        'مندوب BINGO قريب منك 📍',
        v_customer_body,
        'order-tracking.html?delivery='||coalesce(r.order_number,''),
        r.order_id,
        'smart_arrival:'||r.order_id||':customer'
      );

      perform public.delivery_notify_user(
        r.driver_id,
        'smart_arrival_driver',
        'وصلت إلى نطاق العميل 📍',
        v_driver_body,
        'bingo-delivery-driver.html',
        r.order_id,
        'smart_arrival:'||r.order_id||':driver'
      );
    end if;
  end loop;
end;
$$;

revoke all on function public.delivery_check_smart_arrival(uuid) from public;

-- Check every time the driver's live position is inserted/updated.
create or replace function public.delivery_driver_location_smart_arrival_trigger()
returns trigger
language plpgsql
security definer
set search_path=public
as $$
begin
  perform public.delivery_check_smart_arrival(new.driver_id);
  return new;
end;
$$;

drop trigger if exists trg_delivery_driver_location_smart_arrival on public.delivery_driver_locations;
create trigger trg_delivery_driver_location_smart_arrival
after insert or update of latitude,longitude on public.delivery_driver_locations
for each row execute function public.delivery_driver_location_smart_arrival_trigger();

-- Also check immediately when an assignment becomes on_delivery, in case the latest
-- GPS position is already inside 500m before the next location update arrives.
create or replace function public.delivery_assignment_smart_arrival_trigger()
returns trigger
language plpgsql
security definer
set search_path=public
as $$
begin
  if new.status='on_delivery'
     and (tg_op='INSERT' or old.status is distinct from new.status) then
    perform public.delivery_check_smart_arrival(new.driver_id);
  end if;
  return new;
end;
$$;

drop trigger if exists trg_delivery_assignment_smart_arrival on public.delivery_assignments;
create trigger trg_delivery_assignment_smart_arrival
after insert or update of status on public.delivery_assignments
for each row execute function public.delivery_assignment_smart_arrival_trigger();

-- Optional backfill/check for currently active deliveries using their current GPS.
do $$
declare r record;
begin
  for r in
    select distinct a.driver_id
    from public.delivery_assignments a
    join public.delivery_orders o on o.id=a.order_id
    where a.status='on_delivery' and o.status='on_delivery'
  loop
    perform public.delivery_check_smart_arrival(r.driver_id);
  end loop;
end $$;

NOTIFY pgrst, 'reload schema';
