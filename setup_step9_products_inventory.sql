-- BINGO Oman ERP — Step 9: Products & Inventory
-- Run this file alone in Supabase SQL Editor after Step 8 CRM.

create table if not exists public.erp_products (
  id uuid primary key default gen_random_uuid(),
  sku varchar(80) unique,
  name varchar(200) not null,
  category varchar(120),
  unit varchar(30) not null default 'pcs',
  description text,
  cost_price numeric(14,3) not null default 0 check (cost_price >= 0),
  sale_price numeric(14,3) not null default 0 check (sale_price >= 0),
  vat_rate numeric(5,2) not null default 5 check (vat_rate >= 0),
  min_stock numeric(14,3) not null default 0 check (min_stock >= 0),
  stock_qty numeric(14,3) not null default 0,
  is_active boolean not null default true,
  created_by uuid references public.profiles(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.erp_stock_movements (
  id uuid primary key default gen_random_uuid(),
  product_id uuid not null references public.erp_products(id) on delete cascade,
  movement_type varchar(20) not null check (movement_type in ('in','out','adjustment')),
  quantity numeric(14,3) not null check (quantity > 0),
  quantity_before numeric(14,3) not null default 0,
  quantity_after numeric(14,3) not null default 0,
  reference_type varchar(40),
  reference_id uuid,
  reference_text varchar(200),
  movement_date date not null default current_date,
  notes text,
  created_by uuid references public.profiles(id) on delete set null,
  created_at timestamptz not null default now()
);

create index if not exists idx_erp_products_name on public.erp_products(name);
create index if not exists idx_erp_stock_product on public.erp_stock_movements(product_id, movement_date desc);

alter table public.erp_products enable row level security;
alter table public.erp_stock_movements enable row level security;

drop policy if exists erp_admin_all_products on public.erp_products;
create policy erp_admin_all_products on public.erp_products for all to authenticated using (public.is_admin()) with check (public.is_admin());
drop policy if exists erp_admin_all_stock on public.erp_stock_movements;
create policy erp_admin_all_stock on public.erp_stock_movements for all to authenticated using (public.is_admin()) with check (public.is_admin());

create or replace function public.erp_list_products(p_search text default null, p_stock_filter text default null)
returns jsonb language plpgsql security definer set search_path=public as $$
begin
 if not public.is_admin() then raise exception 'Admin access required'; end if;
 return coalesce((select jsonb_agg(to_jsonb(x) order by x.created_at desc) from (
   select p.* from public.erp_products p
   where p.is_active=true
     and (p_search is null or p_search='' or lower(concat_ws(' ',p.sku,p.name,p.category,p.description)) like '%'||lower(p_search)||'%') )
     and (p_stock_filter is null or p_stock_filter='' or (p_stock_filter='low' and p.stock_qty<=p.min_stock) or (p_stock_filter='out' and p.stock_qty<=0))
   limit 1000
 ) x),'[]'::jsonb);
end $$;
revoke all on function public.erp_list_products(text,text) from public;
grant execute on function public.erp_list_products(text,text) to authenticated;

create or replace function public.erp_upsert_product(p_product jsonb)
returns jsonb language plpgsql security definer set search_path=public as $$
declare r public.erp_products;
begin
 if not public.is_admin() then raise exception 'Admin access required'; end if;
 if nullif(trim(p_product->>'name'),'') is null then raise exception 'Product name is required'; end if;
 if nullif(p_product->>'id','') is null then
   insert into public.erp_products(sku,name,category,unit,description,cost_price,sale_price,vat_rate,min_stock,created_by)
   values(nullif(trim(p_product->>'sku'),''),trim(p_product->>'name'),nullif(trim(p_product->>'category'),''),coalesce(nullif(trim(p_product->>'unit'),''),'pcs'),nullif(trim(p_product->>'description'),''),coalesce((p_product->>'cost_price')::numeric,0),coalesce((p_product->>'sale_price')::numeric,0),coalesce((p_product->>'vat_rate')::numeric,5),coalesce((p_product->>'min_stock')::numeric,0),auth.uid()) returning * into r;
 else
   update public.erp_products set sku=nullif(trim(p_product->>'sku'),''),name=trim(p_product->>'name'),category=nullif(trim(p_product->>'category'),''),unit=coalesce(nullif(trim(p_product->>'unit'),''),'pcs'),description=nullif(trim(p_product->>'description'),''),cost_price=coalesce((p_product->>'cost_price')::numeric,0),sale_price=coalesce((p_product->>'sale_price')::numeric,0),vat_rate=coalesce((p_product->>'vat_rate')::numeric,5),min_stock=coalesce((p_product->>'min_stock')::numeric,0),updated_at=now() where id=(p_product->>'id')::uuid returning * into r;
 end if;
 if r.id is null then raise exception 'Product not found'; end if;
 insert into public.erp_audit_log(user_id,action,entity_type,entity_id,details) values(auth.uid(),'product_saved','product',r.id,to_jsonb(r));
 return to_jsonb(r);
end $$;
revoke all on function public.erp_upsert_product(jsonb) from public;
grant execute on function public.erp_upsert_product(jsonb) to authenticated;

create or replace function public.erp_adjust_stock(p_product_id uuid,p_movement_type text,p_quantity numeric,p_reference text default null,p_movement_date date default current_date,p_notes text default null)
returns jsonb language plpgsql security definer set search_path=public as $$
declare p public.erp_products; before_qty numeric; after_qty numeric;
begin
 if not public.is_admin() then raise exception 'Admin access required'; end if;
 if p_quantity is null or p_quantity<=0 then raise exception 'Quantity must be greater than zero'; end if;
 if p_movement_type not in ('in','out','adjustment') then raise exception 'Invalid movement type'; end if;
 select * into p from public.erp_products where id=p_product_id for update;
 if p.id is null then raise exception 'Product not found'; end if;
 before_qty=p.stock_qty;
 if p_movement_type='in' then after_qty=before_qty+p_quantity;
 elsif p_movement_type='out' then after_qty=before_qty-p_quantity;
 else after_qty=p_quantity;
 end if;
 if after_qty<0 then raise exception 'Insufficient stock. Current stock: %',before_qty; end if;
 update public.erp_products set stock_qty=after_qty,updated_at=now() where id=p.id;
 insert into public.erp_stock_movements(product_id,movement_type,quantity,quantity_before,quantity_after,reference_text,movement_date,notes,created_by)
 values(p.id,p_movement_type,p_quantity,before_qty,after_qty,nullif(trim(p_reference),''),coalesce(p_movement_date,current_date),nullif(trim(p_notes),''),auth.uid());
 insert into public.erp_audit_log(user_id,action,entity_type,entity_id,details) values(auth.uid(),'stock_adjusted','product',p.id,jsonb_build_object('movement_type',p_movement_type,'quantity',p_quantity,'before',before_qty,'after',after_qty,'reference',p_reference));
 return jsonb_build_object('product_id',p.id,'stock_before',before_qty,'stock_after',after_qty);
end $$;
revoke all on function public.erp_adjust_stock(uuid,text,numeric,text,date,text) from public;
grant execute on function public.erp_adjust_stock(uuid,text,numeric,text,date,text) to authenticated;
