-- BINGO Oman Store - complete trial commerce setup
-- Run once in Supabase SQL Editor.

create table if not exists public.store_products (
  id uuid primary key default gen_random_uuid(),
  title text not null,
  description text,
  price numeric(12,3) not null default 0 check (price >= 0),
  image_url text,
  category text,
  stock integer not null default 0 check (stock >= 0),
  is_active boolean not null default true,
  sort_order integer not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.store_orders (
  id uuid primary key default gen_random_uuid(),
  order_number text not null unique,
  user_id uuid not null references auth.users(id) on delete cascade,
  customer_name text not null,
  phone text not null,
  email text,
  address text not null,
  notes text,
  payment_method text not null default 'cash_on_delivery' check (payment_method in ('cash_on_delivery','bank_transfer','contact_before_payment')),
  status text not null default 'pending' check (status in ('pending','confirmed','processing','shipped','delivered','cancelled')),
  subtotal numeric(12,3) not null default 0,
  delivery_fee numeric(12,3) not null default 0,
  total numeric(12,3) not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.store_order_items (
  id uuid primary key default gen_random_uuid(),
  order_id uuid not null references public.store_orders(id) on delete cascade,
  product_id uuid references public.store_products(id) on delete set null,
  product_title text not null,
  unit_price numeric(12,3) not null,
  quantity integer not null check (quantity > 0),
  line_total numeric(12,3) not null
);

alter table public.store_products enable row level security;
alter table public.store_orders enable row level security;
alter table public.store_order_items enable row level security;

drop policy if exists "store_products_public_read" on public.store_products;
create policy "store_products_public_read" on public.store_products
for select to anon, authenticated using (is_active = true);

drop policy if exists "store_orders_own_read" on public.store_orders;
create policy "store_orders_own_read" on public.store_orders
for select to authenticated using (user_id = auth.uid() or public.is_admin());

drop policy if exists "store_order_items_own_read" on public.store_order_items;
create policy "store_order_items_own_read" on public.store_order_items
for select to authenticated using (
  exists (select 1 from public.store_orders o where o.id = order_id and (o.user_id = auth.uid() or public.is_admin()))
);

create or replace function public.admin_list_store_products()
returns setof public.store_products language sql security definer set search_path=public as $$
  select * from public.store_products where public.is_admin() order by sort_order asc, created_at desc;
$$;

create or replace function public.admin_upsert_store_product(p_product jsonb)
returns public.store_products language plpgsql security definer set search_path=public as $$
declare r public.store_products;
begin
  if not public.is_admin() then raise exception 'Admin access required'; end if;
  if trim(coalesce(p_product->>'title','')) = '' then raise exception 'Product title is required'; end if;
  insert into public.store_products
    (id,title,description,price,image_url,category,stock,is_active,sort_order,updated_at)
  values
    (coalesce(nullif(p_product->>'id','')::uuid,gen_random_uuid()),
     trim(p_product->>'title'), nullif(trim(coalesce(p_product->>'description','')),''),
     coalesce((p_product->>'price')::numeric,0), nullif(trim(coalesce(p_product->>'image_url','')),''),
     nullif(trim(coalesce(p_product->>'category','')),''), coalesce((p_product->>'stock')::integer,0),
     coalesce((p_product->>'is_active')::boolean,true), coalesce((p_product->>'sort_order')::integer,0), now())
  on conflict (id) do update set title=excluded.title,description=excluded.description,price=excluded.price,
    image_url=excluded.image_url,category=excluded.category,stock=excluded.stock,is_active=excluded.is_active,
    sort_order=excluded.sort_order,updated_at=now()
  returning * into r;
  return r;
end $$;

create or replace function public.admin_delete_store_product(p_id uuid)
returns void language plpgsql security definer set search_path=public as $$
begin
  if not public.is_admin() then raise exception 'Admin access required'; end if;
  delete from public.store_products where id=p_id;
end $$;

grant execute on function public.admin_list_store_products() to authenticated;
grant execute on function public.admin_upsert_store_product(jsonb) to authenticated;
grant execute on function public.admin_delete_store_product(uuid) to authenticated;

create or replace function public.place_store_order(
  p_items jsonb,
  p_customer_name text,
  p_phone text,
  p_email text,
  p_address text,
  p_notes text,
  p_payment_method text,
  p_delivery_fee numeric default 0
) returns public.store_orders
language plpgsql security definer set search_path=public
as $$
declare
  uid uuid := auth.uid();
  r public.store_orders;
  item jsonb;
  p public.store_products;
  qty integer;
  sub numeric(12,3) := 0;
  fee numeric(12,3) := greatest(coalesce(p_delivery_fee,0),0);
  order_id uuid := gen_random_uuid();
  order_no text := 'BO-' || to_char(now(),'YYYYMMDD') || '-' || upper(substr(replace(gen_random_uuid()::text,'-',''),1,6));
begin
  if uid is null then raise exception 'Login required'; end if;
  if trim(coalesce(p_customer_name,''))='' then raise exception 'Customer name is required'; end if;
  if trim(coalesce(p_phone,''))='' then raise exception 'Phone is required'; end if;
  if trim(coalesce(p_address,''))='' then raise exception 'Delivery address is required'; end if;
  if jsonb_typeof(p_items) <> 'array' or jsonb_array_length(p_items)=0 then raise exception 'Cart is empty'; end if;
  if p_payment_method not in ('cash_on_delivery','bank_transfer','contact_before_payment') then raise exception 'Invalid payment method'; end if;

  insert into public.store_orders(id,order_number,user_id,customer_name,phone,email,address,notes,payment_method,subtotal,delivery_fee,total)
  values(order_id,order_no,uid,trim(p_customer_name),trim(p_phone),nullif(trim(coalesce(p_email,'')),''),trim(p_address),nullif(trim(coalesce(p_notes,'')),''),p_payment_method,0,fee,0);

  for item in select * from jsonb_array_elements(p_items) loop
    qty := greatest(coalesce((item->>'quantity')::integer,0),0);
    if qty <= 0 then raise exception 'Invalid quantity'; end if;
    select * into p from public.store_products where id=(item->>'product_id')::uuid and is_active=true for update;
    if not found then raise exception 'A product is no longer available'; end if;
    if p.stock < qty then raise exception 'Not enough stock for: %', p.title; end if;
    insert into public.store_order_items(order_id,product_id,product_title,unit_price,quantity,line_total)
    values(order_id,p.id,p.title,p.price,qty,p.price*qty);
    sub := sub + p.price*qty;
    update public.store_products set stock=stock-qty,updated_at=now() where id=p.id;
  end loop;

  if sub <= 0 then raise exception 'Order total must be greater than zero'; end if;
  update public.store_orders set subtotal=sub,total=sub+fee,updated_at=now() where id=order_id returning * into r;
  return r;
exception when others then
  raise;
end $$;

grant execute on function public.place_store_order(jsonb,text,text,text,text,text,text,numeric) to authenticated;

create or replace function public.my_store_orders()
returns table(id uuid,order_number text,customer_name text,phone text,email text,address text,notes text,payment_method text,status text,subtotal numeric,delivery_fee numeric,total numeric,created_at timestamptz,updated_at timestamptz)
language sql security definer set search_path=public as $$
  select o.id,o.order_number,o.customer_name,o.phone,o.email,o.address,o.notes,o.payment_method,o.status,o.subtotal,o.delivery_fee,o.total,o.created_at,o.updated_at
  from public.store_orders o where o.user_id=auth.uid() order by o.created_at desc;
$$;
grant execute on function public.my_store_orders() to authenticated;

create or replace function public.my_store_order_items(p_order_id uuid)
returns setof public.store_order_items language sql security definer set search_path=public as $$
  select i.* from public.store_order_items i join public.store_orders o on o.id=i.order_id
  where i.order_id=p_order_id and (o.user_id=auth.uid() or public.is_admin()) order by i.id;
$$;
grant execute on function public.my_store_order_items(uuid) to authenticated;

create or replace function public.admin_list_store_orders()
returns table(id uuid,order_number text,user_id uuid,customer_name text,phone text,email text,address text,notes text,payment_method text,status text,subtotal numeric,delivery_fee numeric,total numeric,created_at timestamptz,updated_at timestamptz)
language sql security definer set search_path=public as $$
  select o.id,o.order_number,o.user_id,o.customer_name,o.phone,o.email,o.address,o.notes,o.payment_method,o.status,o.subtotal,o.delivery_fee,o.total,o.created_at,o.updated_at
  from public.store_orders o where public.is_admin() order by o.created_at desc;
$$;
grant execute on function public.admin_list_store_orders() to authenticated;

create or replace function public.admin_update_store_order_status(p_order_id uuid,p_status text)
returns public.store_orders language plpgsql security definer set search_path=public as $$
declare r public.store_orders;
begin
  if not public.is_admin() then raise exception 'Admin access required'; end if;
  if p_status not in ('pending','confirmed','processing','shipped','delivered','cancelled') then raise exception 'Invalid order status'; end if;
  update public.store_orders set status=p_status,updated_at=now() where id=p_order_id returning * into r;
  if not found then raise exception 'Order not found'; end if;
  return r;
end $$;
grant execute on function public.admin_update_store_order_status(uuid,text) to authenticated;

create or replace function public.admin_store_order_items(p_order_id uuid)
returns setof public.store_order_items language sql security definer set search_path=public as $$
  select i.* from public.store_order_items i where public.is_admin() and i.order_id=p_order_id order by i.id;
$$;
grant execute on function public.admin_store_order_items(uuid) to authenticated;
