-- BINGO Oman Cart -> BINGO Delivery Bridge V1
-- Creates the existing Store Order and matching Delivery Order in one PostgreSQL transaction.

create or replace function public.place_store_order_with_delivery(
  p_items jsonb,
  p_customer_name text,
  p_phone text,
  p_email text,
  p_address text,
  p_notes text,
  p_payment_method text,
  p_delivery_fee numeric default 1.500,
  p_latitude numeric default 0,
  p_longitude numeric default 0,
  p_distance_km numeric default 0
) returns jsonb
language plpgsql
security invoker
set search_path=public
as $$
declare
  v_store_id uuid;
  v_store_count integer;
  v_missing integer;
  v_delivery_items jsonb;
  v_store_order jsonb;
  v_delivery_order_id uuid;
  v_delivery_order_number text;
  v_store_order_number text;
  v_driver_share numeric(12,3);
  v_bingo_share numeric(12,3);
  v_delivery_store_count integer;
begin
  if auth.uid() is null then raise exception 'Authentication required'; end if;
  if p_items is null or jsonb_typeof(p_items)<>'array' or jsonb_array_length(p_items)=0 then
    raise exception 'Cart is empty';
  end if;
  if coalesce(p_address,'')='' then raise exception 'Delivery address is required'; end if;
  if coalesce(p_phone,'')='' then raise exception 'Phone number is required'; end if;
  if p_delivery_fee not in (1.500,2.000) then raise exception 'Invalid delivery option'; end if;

  -- Validate every cart product and quantity against the authoritative Store catalog.
  with requested as (
    select nullif(x->>'product_id','')::uuid product_id,
           greatest(coalesce((x->>'quantity')::integer,0),0) quantity
    from jsonb_array_elements(p_items) x
  )
  select count(*) filter (
           where sp.id is null or r.quantity<=0 or sp.is_active is not true or r.quantity>coalesce(sp.stock,0)
         )::integer
    into v_missing
  from requested r
  left join public.store_products sp on sp.id=r.product_id;
  if v_missing>0 then raise exception 'One or more cart products are unavailable or have invalid quantity'; end if;

  -- A Delivery Order belongs to one store. Derive it from store_products.store_id.
  with requested as (
    select nullif(x->>'product_id','')::uuid product_id
    from jsonb_array_elements(p_items) x
  )
  select count(distinct sp.store_id) filter(where sp.store_id is not null)::integer,
         min(sp.store_id::text)::uuid
    into v_store_count,v_store_id
  from requested r
  join public.store_products sp on sp.id=r.product_id;

  if v_store_count>1 then
    raise exception 'Your cart contains products from more than one delivery store. Please checkout one store at a time.';
  end if;

  -- Compatibility fallback for older official BINGO products without store_id:
  -- use the only active delivery store when exactly one exists.
  if v_store_id is null then
    select count(*)::integer,min(id::text)::uuid
      into v_delivery_store_count,v_store_id
    from public.delivery_stores
    where is_active=true;
    if v_delivery_store_count<>1 then
      raise exception 'Cart products are not linked to a BINGO Delivery store. Set store_id on store_products.';
    end if;
  end if;

  if not exists(select 1 from public.delivery_stores where id=v_store_id and is_active=true) then
    raise exception 'The selected store is not active in BINGO Delivery';
  end if;

  -- Build delivery line items from current DB prices/titles, never trusting browser prices.
  with requested as (
    select nullif(x->>'product_id','')::uuid product_id,(x->>'quantity')::integer quantity
    from jsonb_array_elements(p_items) x
  )
  select jsonb_agg(jsonb_build_object(
           'product_id',sp.id,
           'description',sp.title,
           'quantity',r.quantity,
           'unit_price',sp.price
         ) order by sp.title)
    into v_delivery_items
  from requested r
  join public.store_products sp on sp.id=r.product_id;

  -- Standard 1.500 => Driver 1.100 / BINGO 0.400. Express preserves the same ratio.
  v_driver_share := round((p_delivery_fee*(1.100/1.500))::numeric,3);
  v_bingo_share := round((p_delivery_fee-v_driver_share)::numeric,3);

  -- Call the existing Store checkout RPC. Dynamic SELECT keeps compatibility with its return type.
  execute $q$
    select to_jsonb(public.place_store_order(
      p_items=>$1::jsonb,
      p_customer_name=>$2::text,
      p_phone=>$3::text,
      p_email=>$4::text,
      p_address=>$5::text,
      p_notes=>$6::text,
      p_payment_method=>$7::text,
      p_delivery_fee=>$8::numeric
    ))
  $q$
  into v_store_order
  using p_items,p_customer_name,p_phone,p_email,p_address,p_notes,p_payment_method,p_delivery_fee;

  v_store_order_number := coalesce(v_store_order->>'order_number',v_store_order#>>'{data,order_number}');

  -- Create the Delivery Order in the same transaction. Any failure rolls back Store Order too.
  v_delivery_order_id := public.delivery_create_order(
    v_store_id,
    p_address,
    coalesce(p_latitude,0),
    coalesce(p_longitude,0),
    coalesce(p_distance_km,0),
    v_delivery_items,
    p_delivery_fee,
    v_driver_share,
    v_bingo_share,
    0,
    'pending',
    concat_ws(' • ',nullif(p_notes,''),case when v_store_order_number is not null then 'BINGO Store Order '||v_store_order_number end)
  );

  select order_number into v_delivery_order_number
  from public.delivery_orders where id=v_delivery_order_id;

  return jsonb_build_object(
    'ok',true,
    'store_order',v_store_order,
    'store_order_number',v_store_order_number,
    'delivery_order_id',v_delivery_order_id,
    'delivery_order_number',v_delivery_order_number,
    'store_id',v_store_id,
    'delivery_fee',p_delivery_fee,
    'driver_share',v_driver_share,
    'bingo_share',v_bingo_share
  );
end;
$$;

revoke all on function public.place_store_order_with_delivery(jsonb,text,text,text,text,text,text,numeric,numeric,numeric,numeric) from public;
grant execute on function public.place_store_order_with_delivery(jsonb,text,text,text,text,text,text,numeric,numeric,numeric,numeric) to authenticated;
