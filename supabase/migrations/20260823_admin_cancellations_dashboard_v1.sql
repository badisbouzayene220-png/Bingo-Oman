-- BINGO Admin Cancellation Dashboard V1
-- Secure admin-only feed for cancelled delivery orders.

create or replace function public.admin_delivery_cancellations()
returns table(
  delivery_order_id uuid,
  order_number text,
  customer_id uuid,
  customer_name text,
  store_id uuid,
  store_name text,
  driver_id uuid,
  driver_name text,
  total numeric,
  delivery_fee numeric,
  cancellation_reason text,
  created_at timestamptz,
  cancelled_at timestamptz
)
language plpgsql
security definer
set search_path=public
as $$
begin
  if not exists(
    select 1 from public.profiles p
    where p.id=auth.uid() and p.role='admin' and p.is_active=true
  ) then
    raise exception 'Admin access required';
  end if;

  return query
  select
    o.id,
    o.order_number,
    o.customer_id,
    coalesce(cp.full_name,'العميل')::text,
    o.store_id,
    coalesce(s.store_name_ar,s.store_name_en,s.store_name,'المتجر')::text,
    a.driver_id,
    coalesce(dp.full_name,dd.display_name,'—')::text,
    coalesce(o.total,0)::numeric,
    coalesce(o.delivery_fee,0)::numeric,
    coalesce(nullif(trim(substring(o.notes from 'CANCEL_REASON:([^•]+)')),''),'غير محدد')::text,
    o.created_at,
    o.updated_at
  from public.delivery_orders o
  left join public.profiles cp on cp.id=o.customer_id
  left join public.delivery_stores s on s.id=o.store_id
  left join lateral (
    select da.driver_id
    from public.delivery_assignments da
    where da.order_id=o.id
    order by da.created_at desc
    limit 1
  ) a on true
  left join public.profiles dp on dp.id=a.driver_id
  left join public.delivery_drivers dd on dd.id=a.driver_id
  where o.status='cancelled'
  order by o.updated_at desc
  limit 500;
end;
$$;

revoke all on function public.admin_delivery_cancellations() from public;
grant execute on function public.admin_delivery_cancellations() to authenticated;
notify pgrst,'reload schema';