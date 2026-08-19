-- BINGO Delivery Capacity Limit Fix V3
-- Safe follow-up for environments that reject UPDATE statements without an explicit WHERE clause.

create or replace function public.admin_delivery_reconcile_driver_capacity()
returns integer
language plpgsql
security definer
set search_path=public
as $$
declare v_count integer;
begin
  if not public.delivery_is_admin() then
    raise exception 'Admin permission required';
  end if;

  update public.delivery_drivers d
  set is_available = d.is_online and (
        (select count(*)
         from public.delivery_assignments a
         where a.driver_id=d.id
           and a.status in ('offered','accepted','picked_up','on_delivery'))
        < coalesce(d.max_concurrent_orders,1)
      ),
      updated_at=now()
  where d.id is not null;

  get diagnostics v_count = row_count;
  return v_count;
end;
$$;

revoke all on function public.admin_delivery_reconcile_driver_capacity() from public;
grant execute on function public.admin_delivery_reconcile_driver_capacity() to authenticated;
