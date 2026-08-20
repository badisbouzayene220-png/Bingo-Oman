-- BINGO Oman Product -> Seller/Delivery Store link V1
-- Existing products remain official BINGO products (store_id NULL).

alter table public.store_products
  add column if not exists store_id uuid references public.delivery_stores(id) on delete set null;

create index if not exists store_products_delivery_store_idx
  on public.store_products(store_id);

-- Ensure one internal delivery store exists for official BINGO Store products.
insert into public.delivery_stores(owner_id,store_name,store_name_ar,store_name_en,address,is_active)
select null,'BINGO Store','متجر BINGO','BINGO Store','BINGO Oman',true
where not exists (
  select 1 from public.delivery_stores
  where owner_id is null and lower(coalesce(store_name_en,store_name,''))='bingo store'
);

create or replace function public.admin_store_product_owner_options()
returns table(
  store_id uuid,
  store_name text,
  seller_email text,
  is_active boolean
)
language plpgsql
security definer
set search_path=public,auth
as $$
begin
  if not public.is_admin() then raise exception 'Admin access required'; end if;
  return query
  select s.id,
         coalesce(s.store_name_ar,s.store_name_en,s.store_name) as store_name,
         u.email::text,
         s.is_active
  from public.delivery_stores s
  join auth.users u on u.id=s.owner_id
  where s.owner_id is not null
  order by s.is_active desc,coalesce(s.store_name_ar,s.store_name_en,s.store_name);
end;
$$;

revoke all on function public.admin_store_product_owner_options() from public;
grant execute on function public.admin_store_product_owner_options() to authenticated;

create or replace function public.admin_store_product_owners_all()
returns table(
  product_id uuid,
  store_id uuid,
  store_name text,
  seller_email text
)
language plpgsql
security definer
set search_path=public,auth
as $$
begin
  if not public.is_admin() then raise exception 'Admin access required'; end if;
  return query
  select p.id,
         p.store_id,
         coalesce(s.store_name_ar,s.store_name_en,s.store_name),
         u.email::text
  from public.store_products p
  left join public.delivery_stores s on s.id=p.store_id
  left join auth.users u on u.id=s.owner_id
  order by p.created_at desc;
end;
$$;

revoke all on function public.admin_store_product_owners_all() from public;
grant execute on function public.admin_store_product_owners_all() to authenticated;

create or replace function public.admin_upsert_store_product_with_owner(
  p_product jsonb,
  p_store_id uuid default null
) returns jsonb
language plpgsql
security definer
set search_path=public
as $$
declare
  v_result jsonb;
  v_product_id uuid;
begin
  if not public.is_admin() then raise exception 'Admin access required'; end if;

  if p_store_id is not null and not exists(
    select 1 from public.delivery_stores
    where id=p_store_id and owner_id is not null and is_active=true
  ) then
    raise exception 'Selected Seller store is not active';
  end if;

  execute 'select to_jsonb(public.admin_upsert_store_product($1::jsonb))'
    into v_result using p_product;

  begin
    v_product_id := nullif(v_result->>'id','')::uuid;
  exception when others then
    v_product_id := null;
  end;

  if v_product_id is null and nullif(p_product->>'id','') is not null then
    v_product_id := (p_product->>'id')::uuid;
  end if;

  if v_product_id is null then
    select id into v_product_id
    from public.store_products
    where title=trim(p_product->>'title')
    order by created_at desc
    limit 1;
  end if;

  if v_product_id is null then raise exception 'Could not resolve saved product'; end if;

  update public.store_products
  set store_id=p_store_id
  where id=v_product_id;

  return jsonb_build_object(
    'ok',true,
    'id',v_product_id,
    'store_id',p_store_id,
    'owner_type',case when p_store_id is null then 'bingo' else 'seller' end
  );
end;
$$;

revoke all on function public.admin_upsert_store_product_with_owner(jsonb,uuid) from public;
grant execute on function public.admin_upsert_store_product_with_owner(jsonb,uuid) to authenticated;

-- Replace cart bridge so official BINGO products (store_id NULL) always route to the
-- internal BINGO Store, while Seller products route to their selected Delivery Store.
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
  v_null_count integer;
  v_missing integer;
  v_delivery_items jsonb;
  v_store_order jsonb;
  v_delivery_order_id uuid;
  v_delivery_order_number text;
  v_store_order_number text;
  v_driver_share numeric(12,3);
  v_bingo_share numeric(12,3);
begin
  if auth.uid() is null then raise exception 'Authentication required'; end if;
  if p_items is null or jsonb_typeof(p_items)<>'array' or jsonb_array_length(p_items)=0 then raise exception 'Cart is empty'; end if;
  if coalesce(p_address,'')='' then raise exception 'Delivery address is required'; end if;
  if coalesce(p_phone,'')='' then raise exception 'Phone number is required'; end if;
  if p_delivery_fee not in (1.500,2.000) then raise exception 'Invalid delivery option'; end if;

  with requested as (
    select nullif(x->>'product_id','')::uuid product_id,
           greatest(coalesce((x->>'quantity')::integer,0),0) quantity
    from jsonb_array_elements(p_items) x
  )
  select count(*) filter(where sp.id is null or r.quantity<=0 or sp.is_active is not true or r.quantity>coalesce(sp.stock,0))::integer
  into v_missing
  from requested r left join public.store_products sp on sp.id=r.product_id;
  if v_missing>0 then raise exception 'One or more cart products are unavailable or have invalid quantity'; end if;

  with requested as (
    select nullif(x->>'product_id','')::uuid product_id from jsonb_array_elements(p_items) x
  )
  select count(distinct sp.store_id) filter(where sp.store_id is not null)::integer,
         count(*) filter(where sp.store_id is null)::integer,
         min(sp.store_id::text)::uuid
    into v_store_count,v_null_count,v_store_id
  from requested r join public.store_products sp on sp.id=r.product_id;

  if v_store_count>1 or (v_store_count=1 and v_null_count>0) then
    raise exception 'Your cart contains products from more than one seller. Please checkout one store at a time.';
  end if;

  if v_store_id is null then
    select id into v_store_id
    from public.delivery_stores
    where owner_id is null and lower(coalesce(store_name_en,store_name,''))='bingo store' and is_active=true
    order by created_at
    limit 1;
    if v_store_id is null then raise exception 'BINGO Store delivery profile is missing'; end if;
  end if;

  if not exists(select 1 from public.delivery_stores where id=v_store_id and is_active=true) then
    raise exception 'The selected store is not active in BINGO Delivery';
  end if;

  with requested as (
    select nullif(x->>'product_id','')::uuid product_id,(x->>'quantity')::integer quantity
    from jsonb_array_elements(p_items) x
  )
  select jsonb_agg(jsonb_build_object('product_id',sp.id,'description',sp.title,'quantity',r.quantity,'unit_price',sp.price) order by sp.title)
  into v_delivery_items
  from requested r join public.store_products sp on sp.id=r.product_id;

  v_driver_share := round((p_delivery_fee*(1.100/1.500))::numeric,3);
  v_bingo_share := round((p_delivery_fee-v_driver_share)::numeric,3);

  execute $q$
    select to_jsonb(public.place_store_order(
      p_items=>$1::jsonb,p_customer_name=>$2::text,p_phone=>$3::text,p_email=>$4::text,
      p_address=>$5::text,p_notes=>$6::text,p_payment_method=>$7::text,p_delivery_fee=>$8::numeric
    ))
  $q$ into v_store_order
  using p_items,p_customer_name,p_phone,p_email,p_address,p_notes,p_payment_method,p_delivery_fee;

  v_store_order_number := coalesce(v_store_order->>'order_number',v_store_order#>>'{data,order_number}');
  v_delivery_order_id := public.delivery_create_order(
    v_store_id,p_address,coalesce(p_latitude,0),coalesce(p_longitude,0),coalesce(p_distance_km,0),
    v_delivery_items,p_delivery_fee,v_driver_share,v_bingo_share,0,'pending',
    concat_ws(' • ',nullif(p_notes,''),case when v_store_order_number is not null then 'BINGO Store Order '||v_store_order_number end)
  );
  select order_number into v_delivery_order_number from public.delivery_orders where id=v_delivery_order_id;

  return jsonb_build_object('ok',true,'store_order',v_store_order,'store_order_number',v_store_order_number,
    'delivery_order_id',v_delivery_order_id,'delivery_order_number',v_delivery_order_number,'store_id',v_store_id,
    'delivery_fee',p_delivery_fee,'driver_share',v_driver_share,'bingo_share',v_bingo_share);
end;
$$;

revoke all on function public.place_store_order_with_delivery(jsonb,text,text,text,text,text,text,numeric,numeric,numeric,numeric) from public;
grant execute on function public.place_store_order_with_delivery(jsonb,text,text,text,text,text,text,numeric,numeric,numeric,numeric) to authenticated;
