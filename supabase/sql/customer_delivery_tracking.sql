-- BINGO Delivery: secure customer tracking RPC
-- Returns only delivery/driver data for orders owned by auth.uid().
-- For orders with more than one assignment, prefer the active/accepted assignment
-- so the customer sees the driver immediately after acceptance.

create or replace function public.customer_delivery_tracking()
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_result jsonb;
begin
  if auth.uid() is null then
    raise exception 'Authentication required';
  end if;

  select coalesce(jsonb_agg(to_jsonb(x) order by x.created_at desc), '[]'::jsonb)
  into v_result
  from (
    select
      o.id as order_id,
      o.order_number,
      o.status as order_status,
      o.total,
      o.delivery_fee,
      o.delivery_address,
      o.latitude as customer_latitude,
      o.longitude as customer_longitude,
      o.updated_at as order_updated_at,
      o.created_at,
      a.id as assignment_id,
      a.status as assignment_status,
      a.driver_id,
      d.display_name as driver_name,
      d.phone as driver_phone,
      d.vehicle_type,
      d.is_online as driver_online,
      d.rating as driver_rating,
      d.last_online_at,
      loc.latitude as driver_latitude,
      loc.longitude as driver_longitude,
      loc.accuracy_m as driver_accuracy_m,
      loc.heading as driver_heading,
      loc.speed_kmh as driver_speed_kmh,
      loc.updated_at as driver_location_updated_at
    from public.delivery_orders o
    left join lateral (
      select da.*
      from public.delivery_assignments da
      where da.order_id = o.id
      order by
        case da.status
          when 'on_delivery' then 1
          when 'picked_up' then 2
          when 'accepted' then 3
          when 'delivered' then 4
          else 9
        end,
        da.offered_at desc
      limit 1
    ) a on true
    left join public.delivery_drivers d on d.id = a.driver_id
    left join public.delivery_driver_locations loc on loc.driver_id = a.driver_id
    where o.customer_id = auth.uid()
  ) x;

  return v_result;
end;
$$;

revoke all on function public.customer_delivery_tracking() from public;
grant execute on function public.customer_delivery_tracking() to authenticated;
