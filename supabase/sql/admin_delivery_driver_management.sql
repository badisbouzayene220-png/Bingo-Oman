-- BINGO Delivery Admin — Driver Management
-- Run this file in Supabase SQL Editor before using the Driver controls in Admin.

create or replace function public.admin_update_delivery_driver(
    p_driver_id uuid,
    p_display_name text default null,
    p_phone text default null,
    p_vehicle_type text default null,
    p_is_online boolean default null,
    p_is_available boolean default null
)
returns public.delivery_drivers
language plpgsql
security definer
set search_path = public
as $$
declare
    v_driver public.delivery_drivers;
    v_online boolean;
    v_available boolean;
begin
    if auth.uid() is null then
        raise exception 'Authentication required';
    end if;

    if not exists (
        select 1 from public.profiles p
        where p.id = auth.uid()
          and p.role = 'admin'
          and p.is_active = true
    ) then
        raise exception 'Admin access required';
    end if;

    select is_online, is_available
      into v_online, v_available
    from public.delivery_drivers
    where id = p_driver_id
    for update;

    if not found then
        raise exception 'Driver not found';
    end if;

    v_online := coalesce(p_is_online, v_online);
    v_available := coalesce(p_is_available, v_available);

    if not v_online then
        v_available := false;
    end if;

    update public.delivery_drivers
    set
        display_name = coalesce(nullif(trim(p_display_name), ''), display_name),
        phone = coalesce(nullif(trim(p_phone), ''), phone),
        vehicle_type = coalesce(nullif(trim(p_vehicle_type), ''), vehicle_type),
        is_online = v_online,
        is_available = v_available,
        updated_at = now()
    where id = p_driver_id
    returning * into v_driver;

    return v_driver;
end;
$$;

revoke all on function public.admin_update_delivery_driver(uuid,text,text,text,boolean,boolean)
from public;

grant execute on function public.admin_update_delivery_driver(uuid,text,text,text,boolean,boolean)
to authenticated;
