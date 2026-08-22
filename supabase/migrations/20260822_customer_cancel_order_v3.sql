-- BINGO customer cancellation V3
-- Allow cancellation until the driver has actually picked up the order.
-- If a driver has only been offered/assigned/accepted, cancel the assignment too.

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

  -- Store order may be pending/confirmed/preparing/ready. Once completed/cancelled it cannot be cancelled.
  if so.status not in ('pending','confirmed','preparing','ready') then
    raise exception 'This order can no longer be cancelled';
  end if;

  select * into d
  from public.delivery_orders
  where customer_id=uid
    and notes like ('%BINGO Store Order '||so.order_number||'%')
  order by created_at desc
  limit 1
  for update;

  -- Delivery is considered actually started only after pickup / on-delivery.
  if d.id is not null and d.status in ('picked_up','on_delivery','delivered') then
    raise exception 'This order can no longer be cancelled because the driver has already picked it up';
  end if;

  -- Restore stock exactly once before changing store status.
  for it in
    select product_id, quantity
    from public.store_order_items
    where order_id=so.id and product_id is not null
  loop
    update public.store_products
       set stock=stock+it.quantity, updated_at=now()
     where id=it.product_id;
  end loop;

  update public.store_orders
     set status='cancelled',
         notes=concat_ws(' • ',nullif(notes,''),'CANCEL_REASON:'||reason_text),
         updated_at=now()
   where id=so.id;

  if d.id is not null then
    -- Cancel every not-yet-completed assignment so it disappears from driver active/offers.
    update public.delivery_assignments
       set status='cancelled'
     where order_id=d.id
       and status not in ('delivered','cancelled');

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
notify pgrst,'reload schema';