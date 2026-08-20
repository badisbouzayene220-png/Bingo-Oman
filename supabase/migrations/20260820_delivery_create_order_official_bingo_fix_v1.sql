-- BINGO Delivery — Official BINGO product routing fix V1
-- Official products keep store_products.store_id = NULL.
-- They are accepted only when the Delivery Order targets the internal active BINGO Store.

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
language plpgsql
security definer
set search_path=public
as $$
declare
  v_order_id uuid;
  v_subtotal numeric(12,3);
  v_total numeric(12,3);
  v_item jsonb;
  v_product_id uuid;
  v_quantity numeric;
  v_price numeric;
  v_store_id uuid;
  v_stock numeric;
  v_is_bingo_store boolean := false;
begin
  if auth.uid() is null then
    raise exception 'Authentication required';
  end if;

  if p_items is null or jsonb_typeof(p_items) <> 'array' or jsonb_array_length(p_items)=0 then
    raise exception 'Order must contain items';
  end if;

  if coalesce(p_delivery_fee,0)<0
     or coalesce(p_driver_share,0)<0
     or coalesce(p_bingo_share,0)<0
     or coalesce(p_store_commission,0)<0 then
    raise exception 'Invalid delivery amounts';
  end if;

  select s.id,
         (s.owner_id is null and lower(coalesce(s.store_name_en,s.store_name,''))='bingo store')
    into v_store_id,v_is_bingo_store
  from public.delivery_stores s
  where s.id=p_store_id and s.is_active=true;

  if v_store_id is null then
    raise exception 'Store not found or inactive';
  end if;

  v_subtotal := 0;

  for v_item in select * from jsonb_array_elements(p_items)
  loop
    v_product_id := nullif(v_item->>'product_id','')::uuid;
    v_quantity := coalesce(nullif(v_item->>'quantity','')::numeric,0);

    if v_product_id is null then raise exception 'Product ID is required'; end if;
    if v_quantity<=0 then raise exception 'Invalid product quantity'; end if;

    select sp.price,sp.stock
      into v_price,v_stock
    from public.store_products sp
    where sp.id=v_product_id
      and sp.is_active=true
      and (
        sp.store_id=p_store_id
        or (sp.store_id is null and v_is_bingo_store)
      )
    for update;

    if not found then
      raise exception 'Product % not found in selected store',v_product_id;
    end if;

    if v_stock<v_quantity then
      raise exception 'Insufficient stock for product %',v_product_id;
    end if;

    v_subtotal := v_subtotal + (v_price*v_quantity);
  end loop;

  v_subtotal := v_subtotal::numeric(12,3);
  v_total := (v_subtotal+coalesce(p_delivery_fee,0))::numeric(12,3);

  insert into public.delivery_orders(
    customer_id,store_id,status,payment_status,delivery_address,
    latitude,longitude,distance_km,subtotal,delivery_fee,
    driver_share,bingo_share,store_commission,total,notes
  ) values(
    auth.uid(),p_store_id,'pending',p_payment_status,p_address,
    p_latitude,p_longitude,p_distance_km,v_subtotal,p_delivery_fee,
    p_driver_share,p_bingo_share,p_store_commission,v_total,p_notes
  ) returning id into v_order_id;

  for v_item in select * from jsonb_array_elements(p_items)
  loop
    v_product_id := nullif(v_item->>'product_id','')::uuid;
    v_quantity := coalesce(nullif(v_item->>'quantity','')::numeric,0);

    select sp.price into v_price
    from public.store_products sp
    where sp.id=v_product_id
      and sp.is_active=true
      and (
        sp.store_id=p_store_id
        or (sp.store_id is null and v_is_bingo_store)
      );

    if v_price is null then
      raise exception 'Product % not found in selected store',v_product_id;
    end if;

    insert into public.delivery_order_items(
      order_id,product_id,description,quantity,unit_price
    ) values(
      v_order_id,v_product_id,coalesce(v_item->>'description','Item'),v_quantity,v_price
    );
  end loop;

  return v_order_id;
end;
$$;

revoke all on function public.delivery_create_order(uuid,text,numeric,numeric,numeric,jsonb,numeric,numeric,numeric,numeric,text,text) from public;
grant execute on function public.delivery_create_order(uuid,text,numeric,numeric,numeric,jsonb,numeric,numeric,numeric,numeric,text,text) to authenticated;

NOTIFY pgrst, 'reload schema';
