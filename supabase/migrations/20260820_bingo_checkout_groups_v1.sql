-- BINGO Oman — Checkout Groups V1
-- Groups all store + delivery orders created by one multi-seller checkout.

alter table public.store_orders
  add column if not exists checkout_group_id uuid;

alter table public.delivery_orders
  add column if not exists checkout_group_id uuid;

create index if not exists idx_store_orders_checkout_group
  on public.store_orders(checkout_group_id);
create index if not exists idx_delivery_orders_checkout_group
  on public.delivery_orders(checkout_group_id);

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
  v_checkout_group_id uuid := gen_random_uuid();
  v_store_order_id uuid;
  v_delivery_order_id uuid;
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

    v_store_order_id := nullif(v_result#>>'{store_order,id}','')::uuid;
    v_delivery_order_id := nullif(v_result->>'delivery_order_id','')::uuid;

    if v_store_order_id is not null then
      update public.store_orders
      set checkout_group_id=v_checkout_group_id
      where id=v_store_order_id and user_id=auth.uid();
    end if;

    if v_delivery_order_id is not null then
      update public.delivery_orders
      set checkout_group_id=v_checkout_group_id
      where id=v_delivery_order_id and customer_id=auth.uid();
    end if;

    v_results := v_results || jsonb_build_array(
      v_result || jsonb_build_object(
        'effective_store_id',v_group.effective_store_id,
        'checkout_group_id',v_checkout_group_id
      )
    );
    v_shipments := v_shipments + 1;
    v_total_delivery := v_total_delivery + p_delivery_fee;
  end loop;

  if v_shipments=0 then raise exception 'No valid cart groups found'; end if;

  return jsonb_build_object(
    'ok',true,
    'multi_store',v_shipments>1,
    'checkout_group_id',v_checkout_group_id,
    'shipments',v_shipments,
    'delivery_total',round(v_total_delivery,3),
    'quote',v_quote,
    'orders',v_results
  );
end;
$$;

revoke all on function public.place_multi_store_order_with_delivery(jsonb,text,text,text,text,text,text,numeric,numeric,numeric,numeric) from public;
grant execute on function public.place_multi_store_order_with_delivery(jsonb,text,text,text,text,text,text,numeric,numeric,numeric,numeric) to authenticated;

create or replace function public.my_bingo_checkout_groups()
returns jsonb
language plpgsql
security definer
set search_path=public
stable
as $$
declare
  v_uid uuid := auth.uid();
  v_result jsonb;
begin
  if v_uid is null then raise exception 'Authentication required'; end if;

  with rows as (
    select
      so.checkout_group_id,
      so.id as store_order_id,
      so.order_number as store_order_number,
      so.created_at,
      so.total as store_total,
      so.subtotal,
      so.delivery_fee,
      coalesce(ds.store_name_ar,ds.store_name_en,ds.store_name,'BINGO Store') as store_name,
      d.id as delivery_order_id,
      d.order_number as delivery_order_number,
      d.status as delivery_status
    from public.store_orders so
    left join public.delivery_orders d
      on d.checkout_group_id=so.checkout_group_id
     and d.customer_id=v_uid
     and d.notes like '%'||so.order_number||'%'
    left join public.delivery_stores ds on ds.id=d.store_id
    where so.user_id=v_uid
      and so.checkout_group_id is not null
  ), groups as (
    select
      checkout_group_id,
      min(created_at) created_at,
      count(*) shipment_count,
      sum(store_total) total,
      jsonb_agg(jsonb_build_object(
        'store_order_id',store_order_id,
        'store_order_number',store_order_number,
        'store_name',store_name,
        'store_total',store_total,
        'delivery_fee',delivery_fee,
        'delivery_order_id',delivery_order_id,
        'delivery_order_number',delivery_order_number,
        'delivery_status',coalesce(delivery_status,'pending')
      ) order by store_name,store_order_number) shipments
    from rows
    group by checkout_group_id
  )
  select coalesce(jsonb_agg(jsonb_build_object(
    'checkout_group_id',checkout_group_id,
    'created_at',created_at,
    'shipment_count',shipment_count,
    'total',total,
    'shipments',shipments
  ) order by created_at desc),'[]'::jsonb)
  into v_result
  from groups;

  return v_result;
end;
$$;

revoke all on function public.my_bingo_checkout_groups() from public;
grant execute on function public.my_bingo_checkout_groups() to authenticated;

NOTIFY pgrst, 'reload schema';
