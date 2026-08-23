-- BINGO Admin Refund Management V1
-- Tracks manual refunds for cancelled delivery orders.

create table if not exists public.delivery_refunds (
  id uuid primary key default gen_random_uuid(),
  delivery_order_id uuid not null unique references public.delivery_orders(id) on delete cascade,
  amount numeric(18,3) not null check (amount >= 0),
  status text not null default 'pending' check (status in ('pending','refunded','failed')),
  admin_note text,
  processed_by uuid references auth.users(id),
  processed_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.delivery_refunds enable row level security;

-- No direct browser table access; admin works through SECURITY DEFINER RPCs.
revoke all on public.delivery_refunds from anon, authenticated;

create or replace function public.admin_delivery_refunds()
returns table(
  delivery_order_id uuid,
  order_number text,
  customer_name text,
  store_name text,
  total numeric,
  payment_status text,
  requires_refund boolean,
  refund_status text,
  refund_amount numeric,
  refund_note text,
  refunded_at timestamptz,
  cancellation_reason text,
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
    coalesce(cp.full_name,'العميل')::text,
    coalesce(s.store_name_ar,s.store_name_en,s.store_name,'المتجر')::text,
    coalesce(o.total,0)::numeric,
    coalesce(o.payment_status::text,'unknown')::text,
    (lower(coalesce(o.payment_status::text,'')) in ('paid','completed','success','succeeded','captured')) as requires_refund,
    coalesce(r.status,
      case when lower(coalesce(o.payment_status::text,'')) in ('paid','completed','success','succeeded','captured') then 'pending' else 'not_required' end
    )::text,
    coalesce(r.amount,case when lower(coalesce(o.payment_status::text,'')) in ('paid','completed','success','succeeded','captured') then coalesce(o.total,0) else 0 end)::numeric,
    r.admin_note,
    r.processed_at,
    coalesce(nullif(trim(substring(o.notes from 'CANCEL_REASON:([^•]+)')),''),'غير محدد')::text,
    o.updated_at
  from public.delivery_orders o
  left join public.profiles cp on cp.id=o.customer_id
  left join public.delivery_stores s on s.id=o.store_id
  left join public.delivery_refunds r on r.delivery_order_id=o.id
  where o.status='cancelled'
  order by o.updated_at desc
  limit 500;
end;
$$;

create or replace function public.admin_set_delivery_refund(
  p_delivery_order_id uuid,
  p_status text,
  p_amount numeric default null,
  p_note text default null
) returns jsonb
language plpgsql
security definer
set search_path=public
as $$
declare
  o public.delivery_orders;
  v_status text := lower(trim(coalesce(p_status,'')));
  v_amount numeric(18,3);
begin
  if not exists(
    select 1 from public.profiles p
    where p.id=auth.uid() and p.role='admin' and p.is_active=true
  ) then
    raise exception 'Admin access required';
  end if;

  if v_status not in ('pending','refunded','failed') then
    raise exception 'Invalid refund status';
  end if;

  select * into o from public.delivery_orders where id=p_delivery_order_id for update;
  if not found then raise exception 'Order not found'; end if;
  if o.status <> 'cancelled' then raise exception 'Only cancelled orders can be refunded'; end if;
  if lower(coalesce(o.payment_status::text,'')) not in ('paid','completed','success','succeeded','captured') then
    raise exception 'This order is not marked as paid';
  end if;

  v_amount := round(coalesce(p_amount,o.total,0)::numeric,3);
  if v_amount < 0 or v_amount > coalesce(o.total,0) then
    raise exception 'Invalid refund amount';
  end if;

  insert into public.delivery_refunds(delivery_order_id,amount,status,admin_note,processed_by,processed_at,updated_at)
  values(
    o.id,v_amount,v_status,nullif(trim(coalesce(p_note,'')),''),auth.uid(),
    case when v_status in ('refunded','failed') then now() else null end,
    now()
  )
  on conflict (delivery_order_id) do update set
    amount=excluded.amount,
    status=excluded.status,
    admin_note=excluded.admin_note,
    processed_by=auth.uid(),
    processed_at=case when excluded.status in ('refunded','failed') then now() else null end,
    updated_at=now();

  return jsonb_build_object('ok',true,'delivery_order_id',o.id,'status',v_status,'amount',v_amount);
end;
$$;

revoke all on function public.admin_delivery_refunds() from public;
grant execute on function public.admin_delivery_refunds() to authenticated;
revoke all on function public.admin_set_delivery_refund(uuid,text,numeric,text) from public;
grant execute on function public.admin_set_delivery_refund(uuid,text,numeric,text) to authenticated;

notify pgrst,'reload schema';