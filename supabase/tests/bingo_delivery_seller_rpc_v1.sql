-- Run this migration in Supabase SQL Editor.
-- Seller can only change an order belonging to a store they own.
-- No ERP tables are touched.

create or replace function public.delivery_store_set_order_status(
    p_order_id uuid,
    p_status text
)
returns public.delivery_orders
language plpgsql
security invoker
set search_path = public
as $$
declare
    v_order public.delivery_orders;
begin
    if auth.uid() is null then
        raise exception 'Authentication required';
    end if;

    if p_status not in ('preparing','ready','cancelled') then
        raise exception 'Invalid seller status';
    end if;

    update public.delivery_orders o
    set status = p_status,
        updated_at = now()
    where o.id = p_order_id
      and exists (
          select 1
          from public.delivery_stores s
          where s.id = o.store_id
            and s.owner_id = auth.uid()
      )
      and (
          (o.status in ('pending','confirmed') and p_status = 'preparing')
          or (o.status = 'preparing' and p_status = 'ready')
          or (o.status in ('pending','confirmed','preparing') and p_status = 'cancelled')
      )
    returning o.* into v_order;

    if v_order.id is null then
        raise exception 'Order not found, not owned by seller, or invalid status transition';
    end if;

    return v_order;
end;
$$;

revoke all on function public.delivery_store_set_order_status(uuid,text) from public;
grant execute on function public.delivery_store_set_order_status(uuid,text) to authenticated;

select
    'SELLER_STATUS_RPC' as test,
    count(*) as found,
    case when count(*) = 1 then 'PASS' else 'FAIL' end as status
from pg_proc p
join pg_namespace n on n.oid = p.pronamespace
where n.nspname = 'public'
  and p.proname = 'delivery_store_set_order_status';
