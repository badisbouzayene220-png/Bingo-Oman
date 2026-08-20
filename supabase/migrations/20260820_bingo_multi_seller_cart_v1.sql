-- BINGO Oman — Multi Seller Cart V1
-- Splits one customer checkout into independent Store + Delivery orders per seller/store.
-- Official BINGO products (store_products.store_id IS NULL) are grouped into the internal BINGO Store.

create or replace function public.bingo_cart_delivery_quote(
  p_items jsonb,
  p_delivery_fee numeric default 1.500
) returns jsonb
language plpgsql
security definer
set search_path=public
stable
as $$
declare
  v_shipments integer := 0;
  v_missing integer := 0;
  v_subtotal numeric(12,3) := 0;
  v_bingo_store uuid;
begin
  if p_items is null or jsonb_typeof(p_items)<>'array' or jsonb_array_length(p_items)=0 then
    return jsonb_build_object('shipments',0,'subtotal',0,'delivery_total',0,'grand_total',0);
  end if;
  if p_delivery_fee not in (1.500,2.000) then raise exception 'Invalid delivery option'; end if;

  select id into v_bingo_store
  from public.delivery_stores
  where owner_id is null
    and lower(coalesce(store_name_en,store_name,''))='bingo store'
    and is_active=true
  order by created_at
  limit 1;
  if v_bingo_store is null then raise exception 'BINGO Store delivery profile is missing'; end if;

  with requested as (
    select nullif(x->>'product_id','')::uuid product_id,
           greatest(coalesce((x->>'quantity')::integer,0),0) quantity
    from jsonb_array_elements(p_items) x
  ), checked as (
    select r.product_id,r.quantity,sp.price,sp.stock,sp.is_active,
           coalesce(sp.store_id,v_bingo_store) effective_store_id,
           sp.id found_id
    from requested r
    left join public.store_products sp on sp.id=r.product_id
  )
  select count(*) filter(where found_id is null or quantity<=0 or is_active is not true or quantity>coalesce(stock,0))::integer,
         coalesce(sum(price*quantity),0)::numeric(12,3),
         count(distinct effective_store_id)::integer
  into v_missing,v_subtotal,v_shipments
  from checked;

  if v_missing>0 then raise exception 'One or more cart products are unavailable or have invalid quantity'; end if;

  return jsonb_build_object(
    'shipments',v_shipments,
    'subtotal',v_subtotal,
    'delivery_fee_each',p_delivery_fee,
    'delivery_total',round((v_shipments*p_delivery_fee)::numeric,3),
    'grand_total',round((v_subtotal+v_shipments*p_delivery_fee)::numeric,3)
  );
end;
$$;

revoke all on function public.bingo_cart_delivery_quote(jsonb,numeric) from public;
grant execute on function public.bingo_cart_delivery_quote(jsonb,numeric) to anon, authenticated;

create or replace function public.place_multi_store_order_with_delivery(
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
  v_bingo_store uuid;
  v_group record;
  v_group_items jsonb;
  v_result jsonb;
  v_results jsonb := '[]'::jsonb;
  v_shipments integer := 0;
  v_total_delivery numeric(12,3) := 0;
  v_quote jsonb;
begin
  if auth.uid() is null then raise exception 'Authentication required'; end if;
  if p_items is null or jsonb_typeof(p_items)<>'array' or jsonb_array_length(p_items)=0 then raise exception 'Cart is empty'; end if;
  if coalesce(trim(p_address),'')='' then raise exception 'Delivery address is required'; end if;
  if coalesce(trim(p_phone),'')='' then raise exception 'Phone number is required'; end if;
  if p_delivery_fee not in (1.500,2.000) then raise exception 'Invalid delivery option'; end if;

  v_quote := public.bingo_cart_delivery_quote(p_items,p_delivery_fee);

  select id into v_bingo_store
  from public.delivery_stores
  where owner_id is null
    and lower(coalesce(store_name_en,store_name,''))='bingo store'
    and is_active=true
  order by created_at
  limit 1;
  if v_bingo_store is null then raise exception 'BINGO Store delivery profile is missing'; end if;

  -- One loop per effective store. Every call below is single-store, so it reuses the
  -- already-tested Store Order + Delivery Order bridge. The whole function is atomic.
  for v_group in
    with requested as (
      select nullif(x->>'product_id','')::uuid product_id,
             greatest(coalesce((x->>'quantity')::integer,0),0) quantity
      from jsonb_array_elements(p_items) x
    )
    select coalesce(sp.store_id,v_bingo_store) effective_store_id
    from requested r
    join public.store_products sp on sp.id=r.product_id
    group by coalesce(sp.store_id,v_bingo_store)
    order by coalesce(sp.store_id,v_bingo_store)::text
  loop
    with requested as (
      select nullif(x->>'product_id','')::uuid product_id,
             greatest(coalesce((x->>'quantity')::integer,0),0) quantity
      from jsonb_array_elements(p_items) x
    )
    select jsonb_agg(jsonb_build_object('product_id',r.product_id,'quantity',r.quantity) order by r.product_id::text)
    into v_group_items
    from requested r
    join public.store_products sp on sp.id=r.product_id
    where coalesce(sp.store_id,v_bingo_store)=v_group.effective_store_id;

    v_result := public.place_store_order_with_delivery(
      v_group_items,
      p_customer_name,
      p_phone,
      p_email,
      p_address,
      concat_ws(' • ',nullif(trim(coalesce(p_notes,'')),''),'Multi-store checkout'),
      p_payment_method,
      p_delivery_fee,
      p_latitude,
      p_longitude,
      p_distance_km
    );

    v_results := v_results || jsonb_build_array(
      v_result || jsonb_build_object('effective_store_id',v_group.effective_store_id)
    );
    v_shipments := v_shipments + 1;
    v_total_delivery := v_total_delivery + p_delivery_fee;
  end loop;

  if v_shipments=0 then raise exception 'No valid cart groups found'; end if;

  return jsonb_build_object(
    'ok',true,
    'multi_store',v_shipments>1,
    'shipments',v_shipments,
    'delivery_total',round(v_total_delivery,3),
    'quote',v_quote,
    'orders',v_results
  );
end;
$$;

revoke all on function public.place_multi_store_order_with_delivery(jsonb,text,text,text,text,text,text,numeric,numeric,numeric,numeric) from public;
grant execute on function public.place_multi_store_order_with_delivery(jsonb,text,text,text,text,text,text,numeric,numeric,numeric,numeric) to authenticated;

NOTIFY pgrst, 'reload schema';
