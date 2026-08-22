-- BINGO customer cancellation V2
-- Adds cancellation reason and a driver-safe recent cancelled assignment feed.

create or replace function public.customer_cancel_store_order_v2(
  p_store_order_id uuid,
  p_reason text default 'Customer cancelled'
) returns jsonb
language plpgsql
security definer
set search_path=public
as $$
declare
  uid uuid := auth.uid();
  so public.store_orders;
  d public.delivery_orders;
  it record;
  reason_text text := left(trim(coalesce(p_reason,'Customer cancelled')),300);
begin
  if uid is null then raise exception 'Authentication required'; end if;
  if reason_text='' then reason_text := 'Customer cancelled'; end if;

  select * into so
  from public.store_orders
  where id=p_store_order_id and user_id=uid
  for update;

  if not found then raise exception 'Order not found'; end if;
  if so.status='cancelled' then
    return jsonb_build_object('ok',true,'already_cancelled',true,'order_number',so.order_number);
  end if;
  if so.status not in ('pending','confirmed') then
    raise exception 'This order can no longer be cancelled because preparation has already started';
  end if;

  select * into d
  from public.delivery_orders
  where customer_id=uid
    and notes like ('%BINGO Store Order '||so.order_number||'%')
  order by created_at desc
  limit 1
  for update;

  if d.id is not null and d.status not in ('pending','confirmed','cancelled') then
    raise exception 'This order can no longer be cancelled because delivery processing has already started';
  end if;

  for it in
    select product_id, quantity
    from public.store_order_items
    where order_id=so.id and product_id is not null
  loop
    update public.store_products
      set stock=stock+it.quantity,updated_at=now()
    where id=it.product_id;
  end loop;

  update public.store_orders
    set status='cancelled',
        notes=concat_ws(' • ',nullif(notes,''),'CANCEL_REASON:'||reason_text),
        updated_at=now()
  where id=so.id;

  if d.id is not null then
    update public.delivery_assignments
      set status='cancelled'
    where order_id=d.id and status='offered';

    update public.delivery_orders
      set status='cancelled',
          notes=concat_ws(' • ',nullif(notes,''),'CANCEL_REASON:'||reason_text),
          updated_at=now()
    where id=d.id;
  end if;

  return jsonb_build_object(
    'ok',true,
    'store_order_id',so.id,
    'store_order_number',so.order_number,
    'delivery_order_id',d.id,
    'delivery_order_number',d.order_number,
    'status','cancelled',
    'reason',reason_text
  );
end;
$$;

revoke all on function public.customer_cancel_store_order_v2(uuid,text) from public;
grant execute on function public.customer_cancel_store_order_v2(uuid,text) to authenticated;

create or replace function public.delivery_driver_cancelled_recent()
returns table(
  assignment_id uuid,
  order_id uuid,
  order_number text,
  cancellation_reason text,
  updated_at timestamptz
)
language sql
security definer
set search_path=public
as $$
  select a.id,
         o.id,
         o.order_number,
         coalesce(nullif(substring(o.notes from 'CANCEL_REASON:([^•]+)'),''),'Customer cancelled') as cancellation_reason,
         o.updated_at
  from public.delivery_assignments a
  join public.delivery_orders o on o.id=a.order_id
  where a.driver_id=auth.uid()
    and a.status='cancelled'
    and o.status='cancelled'
  order by o.updated_at desc
  limit 20;
$$;

revoke all on function public.delivery_driver_cancelled_recent() from public;
grant execute on function public.delivery_driver_cancelled_recent() to authenticated;

notify pgrst,'reload schema';