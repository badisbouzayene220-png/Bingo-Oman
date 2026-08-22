-- BINGO fractional checkout fix V3 (generated-column safe)
-- The quantity columns are already NUMERIC(18,3).
-- This migration ONLY patches checkout/delivery RPCs that still cast JSON quantity to INTEGER.

begin;

-- Patch all checkout/delivery bridge functions that can touch cart quantities.
-- The replacement is intentionally generic: it catches x/item/v_item/etc.
do $$
declare
  r record;
  def text;
  patched text;
begin
  for r in
    select p.oid, p.proname, pg_get_function_identity_arguments(p.oid) as args
    from pg_proc p
    join pg_namespace n on n.oid=p.pronamespace
    where n.nspname='public'
      and (
        p.proname in (
          'place_store_order',
          'place_store_order_with_delivery',
          'place_multi_store_order_with_delivery',
          'bingo_cart_delivery_quote',
          'delivery_create_order'
        )
        or p.proname like 'place%store%order%delivery%'
        or p.proname like '%cart%delivery%quote%'
      )
  loop
    def := pg_get_functiondef(r.oid);
    patched := def;

    -- Handles: (x->>'quantity')::integer, (item->>'quantity')::integer, etc.
    patched := replace(patched,
      '->>''quantity'')::integer',
      '->>''quantity'')::numeric(18,3)');
    patched := replace(patched,
      '->> ''quantity'')::integer',
      '->> ''quantity'')::numeric(18,3)');

    -- Handles PostgreSQL spelling INTEGER in uppercase in any older definition.
    patched := replace(patched,
      '->>''quantity'')::INTEGER',
      '->>''quantity'')::numeric(18,3)');
    patched := replace(patched,
      '->> ''quantity'')::INTEGER',
      '->> ''quantity'')::numeric(18,3)');

    -- Known coalesce forms from earlier BINGO migrations.
    patched := replace(patched,
      'coalesce((x->>''quantity'')::integer,0)',
      'coalesce((x->>''quantity'')::numeric(18,3),0)');
    patched := replace(patched,
      'coalesce((item->>''quantity'')::integer,0)',
      'coalesce((item->>''quantity'')::numeric(18,3),0)');
    patched := replace(patched,
      'coalesce((v_item->>''quantity'')::integer,0)',
      'coalesce((v_item->>''quantity'')::numeric(18,3),0)');

    if patched is distinct from def then
      execute patched;
      raise notice 'Patched %.%', r.proname, r.args;
    end if;
  end loop;
end $$;

-- Re-assert delivery_create_order with explicit NUMERIC quantity handling.
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
  if p_items is null or jsonb_typeof(p_items) <> 'array' or jsonb_array_length(p_items)=0 then
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
    customer_id,store_id,status,payment_status,delivery_address,
    latitude,longitude,distance_km,subtotal,delivery_fee,
    driver_share,bingo_share,store_commission,total,notes
  ) values (
    auth.uid(),p_store_id,'pending',p_payment_status,p_address,
    p_latitude,p_longitude,p_distance_km,v_subtotal,p_delivery_fee,
    p_driver_share,p_bingo_share,p_store_commission,v_total,p_notes
  ) returning id into v_order_id;

  for v_item in select * from jsonb_array_elements(p_items) loop
    v_qty := round((v_item->>'quantity')::numeric(18,3),3);
    if v_qty is null or v_qty <= 0 then
      raise exception 'Invalid delivery item quantity';
    end if;

    insert into public.delivery_order_items(order_id,product_id,description,quantity,unit_price)
    values(
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

-- Fail loudly if a checkout/delivery function still contains an INTEGER cast
-- directly on a JSON quantity value. This prevents a false "Success".
do $$
declare
  bad text;
begin
  select string_agg(p.proname || '(' || pg_get_function_identity_arguments(p.oid) || ')', E'\n')
    into bad
  from pg_proc p
  join pg_namespace n on n.oid=p.pronamespace
  where n.nspname='public'
    and (
      p.proname in (
        'place_store_order',
        'place_store_order_with_delivery',
        'place_multi_store_order_with_delivery',
        'bingo_cart_delivery_quote',
        'delivery_create_order'
      )
      or p.proname like 'place%store%order%delivery%'
      or p.proname like '%cart%delivery%quote%'
    )
    and lower(pg_get_functiondef(p.oid)) like '%quantity%' 
    and lower(pg_get_functiondef(p.oid)) like '%::integer%';

  if bad is not null then
    raise exception 'INTEGER quantity cast still exists in:%', E'\n' || bad;
  end if;
end $$;

notify pgrst,'reload schema';
commit;
