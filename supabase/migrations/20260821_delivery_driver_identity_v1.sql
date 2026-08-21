-- BINGO Driver Identity V1
-- Returns the signed-in driver's own profile safely, without relying on table RLS.

create or replace function public.delivery_driver_identity()
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  uid uuid := auth.uid();
  d public.delivery_drivers%rowtype;
begin
  if uid is null then
    raise exception 'Authentication required';
  end if;

  select * into d
  from public.delivery_drivers
  where id = uid;

  if d.id is null then
    raise exception 'Driver profile not found';
  end if;

  return jsonb_build_object(
    'id', d.id,
    'display_name', d.display_name,
    'phone', d.phone,
    'vehicle_type', d.vehicle_type,
    'vehicle_plate', d.vehicle_plate,
    'rating', d.rating,
    'total_deliveries', d.total_deliveries,
    'is_online', d.is_online,
    'is_available', d.is_available
  );
end;
$$;

revoke all on function public.delivery_driver_identity() from public;
grant execute on function public.delivery_driver_identity() to authenticated;

notify pgrst, 'reload schema';
