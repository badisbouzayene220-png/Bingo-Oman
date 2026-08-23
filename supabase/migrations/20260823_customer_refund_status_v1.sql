-- BINGO customer refund status V1
-- Lets an authenticated customer read refund status only for their own cancelled delivery orders.

create or replace function public.customer_delivery_refunds()
returns table(
  delivery_order_id uuid,
  delivery_order_number text,
  store_order_number text,
  payment_status text,
  requires_refund boolean,
  refund_status text,
  refund_amount numeric,
  refund_note text,
  refunded_at timestamptz,
  cancelled_at timestamptz
)
language sql
security definer
set search_path=public
as $$
  select
    o.id,
    o.order_number,
    nullif(substring(o.notes from 'BINGO Store Order ([^ •]+)'), '')::text,
    coalesce(o.payment_status::text,'unknown')::text,
    (lower(coalesce(o.payment_status::text,'')) in ('paid','completed','success','succeeded','captured')) as requires_refund,
    coalesce(
      r.status,
      case when lower(coalesce(o.payment_status::text,'')) in ('paid','completed','success','succeeded','captured') then 'pending' else 'not_required' end
    )::text,
    coalesce(
      r.amount,
      case when lower(coalesce(o.payment_status::text,'')) in ('paid','completed','success','succeeded','captured') then coalesce(o.total,0) else 0 end
    )::numeric,
    r.admin_note,
    r.processed_at,
    o.updated_at
  from public.delivery_orders o
  left join public.delivery_refunds r on r.delivery_order_id=o.id
  where o.customer_id=auth.uid()
    and o.status='cancelled'
  order by o.updated_at desc;
$$;

revoke all on function public.customer_delivery_refunds() from public;
grant execute on function public.customer_delivery_refunds() to authenticated;
notify pgrst,'reload schema';