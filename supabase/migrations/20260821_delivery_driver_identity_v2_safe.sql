-- BINGO Driver Identity V2 SAFE
-- Schema-tolerant: returns the whole driver row as JSONB and avoids referencing optional columns.

drop function if exists public.delivery_driver_identity();

create or replace function public.delivery_driver_identity()
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_driver jsonb;
begin
  if v_uid is null then
    raise exception 'Authentication required';
  end if;

  select to_jsonb(d)
    into v_driver
  from public.delivery_drivers d
  where d.id = v_uid
  limit 1;

  if v_driver is null then
    raise exception 'Driver profile not found';
  end if;

  return v_driver;
end;
$$;

revoke all on function public.delivery_driver_identity() from public;
grant execute on function public.delivery_driver_identity() to authenticated;

notify pgrst, 'reload schema';
