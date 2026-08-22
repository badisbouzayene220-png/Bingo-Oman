-- BINGO customer order cancellation V1
-- Customer can cancel only before store preparation starts.

create or replace function public.customer_cancel_store_order(p_store_order_id uuid)
returns jsonb
language plpgsql
security definer
set search_path=public
as $$
declare
  uid uuid := auth.uid();
  so public.store_orders;
  d public.delivery_orders;
  it record;
begin
  if uid is null then raise exception 'Authentication required'; end if;

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

  -- Restore stock once, before marking the store order cancelled.
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
    set status='cancelled',updated_at=now()
  where id=so.id;

  if d.id is not null then
    update public.delivery_assignments
      set status='cancelled'
    where order_id=d.id and status='offered';

    update public.delivery_orders
      set status='cancelled',updated_at=now()
    where id=d.id;
  end if;

  return jsonb_build_object(
    'ok',true,
    'store_order_id',so.id,
    'store_order_number',so.order_number,
    'delivery_order_id',d.id,
    'delivery_order_number',d.order_number,
    'status','cancelled'
  );
end;
$$;

revoke all on function public.customer_cancel_store_order(uuid) from public;
grant execute on function public.customer_cancel_store_order(uuid) to authenticated;
notify pgrst,'reload schema';