-- BINGO Delivery: live driver location prerequisites
-- Run after admin_delivery_drivers_dashboard.sql.
-- The delivery_update_location(...) RPC already exists in the delivery RPC migration.
-- This script safely re-creates it so the driver page can publish GPS location.

create or replace function public.delivery_update_location(
  p_latitude numeric,
  p_longitude numeric,
  p_accuracy_m numeric default null,
  p_heading numeric default null,
  p_speed_kmh numeric default null
) returns void
language plpgsql security invoker set search_path = public
as $$
begin
  if auth.uid() is null then raise exception 'Authentication required'; end if;

  insert into public.delivery_drivers(id,is_online,is_available,updated_at,last_online_at)
  values(auth.uid(),true,true,now(),now())
  on conflict(id) do update set
    is_online=true,
    updated_at=now(),
    last_online_at=now();

  insert into public.delivery_driver_locations(
    driver_id,latitude,longitude,accuracy_m,heading,speed_kmh,updated_at
  ) values(
    auth.uid(),p_latitude,p_longitude,p_accuracy_m,p_heading,p_speed_kmh,now()
  )
  on conflict(driver_id) do update set
    latitude=excluded.latitude,
    longitude=excluded.longitude,
    accuracy_m=excluded.accuracy_m,
    heading=excluded.heading,
    speed_kmh=excluded.speed_kmh,
    updated_at=now();
end;
$$;

revoke all on function public.delivery_update_location(numeric,numeric,numeric,numeric,numeric) from public;
grant execute on function public.delivery_update_location(numeric,numeric,numeric,numeric,numeric) to authenticated;
