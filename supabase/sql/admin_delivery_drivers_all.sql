-- BINGO Delivery Admin: return ALL drivers, not only online drivers.
-- Safe additive RPC. Does not modify orders, earnings, or ERP.

create or replace function public.admin_delivery_drivers_all()
returns setof public.delivery_drivers
language plpgsql
security definer
set search_path = public
as $$
begin
  if auth.uid() is null then
    raise exception 'Authentication required';
  end if;

  if not exists (
    select 1
    from public.profiles p
    where p.id = auth.uid()
      and p.role = 'admin'
      and p.is_active = true
  ) then
    raise exception 'Admin access required';
  end if;

  return query
  select d.*
  from public.delivery_drivers d
  order by d.is_online desc, d.is_available desc, d.display_name nulls last, d.created_at desc;
end;
$$;

revoke all on function public.admin_delivery_drivers_all() from public;
grant execute on function public.admin_delivery_drivers_all() to authenticated;
