-- BINGO fractional checkout fix V3
-- Robustly patches any remaining INTEGER casts applied to JSON quantity values
-- in checkout/delivery functions. Does not alter table columns.

begin;

do $$
declare
  r record;
  def text;
  patched text;
begin
  for r in
    select p.oid, p.oid::regprocedure::text as signature
    from pg_proc p
    join pg_namespace n on n.oid=p.pronamespace
    where n.nspname='public'
      and p.proname in (
        'place_store_order_with_delivery',
        'place_multi_store_order_with_delivery',
        'bingo_cart_delivery_quote'
      )
  loop
    def := pg_get_functiondef(r.oid);
    patched := def;

    -- Matches e.g. (x->>'quantity')::integer, (item ->> 'quantity') :: integer, etc.
    patched := regexp_replace(
      patched,
      E'\\(\\s*([a-zA-Z_][a-zA-Z0-9_]*)\\s*->>\\s*''quantity''\\s*\\)\\s*::\\s*integer',
      E'(\\1->>''quantity'')::numeric(18,3)',
      'gi'
    );

    -- Matches direct form without parentheses: x->>'quantity'::integer
    patched := regexp_replace(
      patched,
      E'([a-zA-Z_][a-zA-Z0-9_]*)\\s*->>\\s*''quantity''\\s*::\\s*integer',
      E'\\1->>''quantity''::numeric(18,3)',
      'gi'
    );

    -- Matches CAST((x->>'quantity') AS integer)
    patched := regexp_replace(
      patched,
      E'cast\\s*\\(\\s*\\(\\s*([a-zA-Z_][a-zA-Z0-9_]*)\\s*->>\\s*''quantity''\\s*\\)\\s+as\\s+integer\\s*\\)',
      E'(\\1->>''quantity'')::numeric(18,3)',
      'gi'
    );

    if patched is distinct from def then
      execute patched;
    end if;
  end loop;
end $$;

-- Re-assert delivery_create_order with decimal quantity handling.
create or replace function public.delivery_create_order(
  p_store_id uuid,
  p_address text,
  p_latitude numeric,
  p_longitude numeric,
  p_distance_km numeric,
  p_items jsonb,
  p_delivery_fee numeric,
  p_driver_share numeric,
  p_bingo_share numeric,
  p_store_commission numeric default 0,
  p_payment_status text default 'pending',
  p_notes text default null
) returns uuid
language plpgsql security invoker set search_path = public
as $$
declare
  v_order_id uuid;
  v_subtotal numeric(18,3);
  v_total numeric(18,3);
  v_item jsonb;
  v_qty numeric(18,3);
begin
  if auth.uid() is null then raise exception 'Authentication required'; end if;
  if p_items is null or jsonb_typeof(p_items) <> 'array' or jsonb_array_length(p_items) = 0 then
    raise exception 'Order must contain items';
  end if;
  if p_delivery_fee < 0 or p_driver_share < 0 or p_bingo_share < 0 or p_store_commission < 0 then
    raise exception 'Invalid delivery amounts';
  end if;

  select coalesce(sum((x->>'quantity')::numeric(18,3) * (x->>'unit_price')::numeric),0)::numeric(18,3)
    into v_subtotal
  from jsonb_array_elements(p_items) x;

  v_total := (v_subtotal + p_delivery_fee)::numeric(18,3);

  insert into public.delivery_orders(
    customer_id, store_id, status, payment_status, delivery_address,
    latitude, longitude, distance_km, subtotal, delivery_fee,
    driver_share, bingo_share, store_commission, total, notes
  ) values (
    auth.uid(), p_store_id, 'pending', p_payment_status, p_address,
    p_latitude, p_longitude, p_distance_km, v_subtotal, p_delivery_fee,
    p_driver_share, p_bingo_share, p_store_commission, v_total, p_notes
  ) returning id into v_order_id;

  for v_item in select * from jsonb_array_elements(p_items) loop
    v_qty := round((v_item->>'quantity')::numeric,3);
    if v_qty <= 0 then raise exception 'Invalid delivery item quantity'; end if;

    insert into public.delivery_order_items(order_id, product_id, description, quantity, unit_price)
    values (
      v_order_id,
      nullif(v_item->>'product_id','')::uuid,
      coalesce(v_item->>'description','Item'),
      v_qty,
      (v_item->>'unit_price')::numeric
    );
  end loop;

  return v_order_id;
end;
$$;

grant execute on function public.delivery_create_order(uuid,text,numeric,numeric,numeric,jsonb,numeric,numeric,numeric,numeric,text,text) to authenticated;

-- Final verification: fail loudly if any checkout/delivery function still casts JSON quantity to integer.
do $$
declare
  bad text;
begin
  select string_agg(p.oid::regprocedure::text, E'\n')
    into bad
  from pg_proc p
  join pg_namespace n on n.oid=p.pronamespace
  where n.nspname='public'
    and p.proname in (
      'place_store_order_with_delivery',
      'place_multi_store_order_with_delivery',
      'bingo_cart_delivery_quote'
    )
    and pg_get_functiondef(p.oid) ~* E'quantity.{0,40}::\\s*integer';

  if bad is not null then
    raise exception 'INTEGER quantity cast still exists in:%', E'\n'||bad;
  end if;
end $$;

notify pgrst,'reload schema';
commit;
