-- BINGO Store Product Unit V1
-- Adds a selling unit while preserving old products as 'piece'.

alter table public.store_products
  add column if not exists unit text not null default 'piece';

update public.store_products set unit='piece' where unit is null or trim(unit)='';

alter table public.store_products drop constraint if exists store_products_unit_check;
alter table public.store_products add constraint store_products_unit_check
  check (unit in ('piece','kg','g','meter','liter','pack'));

-- Replace seller save RPC with unit-aware signature.
drop function if exists public.delivery_seller_product_save(uuid,text,text,numeric,integer,boolean,uuid,text);
create function public.delivery_seller_product_save(
 p_product_id uuid default null,
 p_title text default null,
 p_description text default null,
 p_price numeric default 0,
 p_stock integer default 0,
 p_is_active boolean default true,
 p_store_id uuid default null,
 p_image_url text default null,
 p_unit text default 'piece'
) returns uuid
language plpgsql security definer set search_path=public as $$
declare v_uid uuid:=auth.uid(); v_id uuid; v_store uuid; v_unit text:=coalesce(nullif(trim(p_unit),''),'piece');
begin
 if v_uid is null then raise exception 'Authentication required'; end if;
 if trim(coalesce(p_title,''))='' then raise exception 'Product title is required'; end if;
 if coalesce(p_price,0)<0 then raise exception 'Invalid price'; end if;
 if coalesce(p_stock,0)<0 then raise exception 'Invalid stock'; end if;
 if v_unit not in ('piece','kg','g','meter','liter','pack') then raise exception 'Invalid product unit'; end if;
 if p_product_id is null then
   select s.id into v_store from public.delivery_stores s
   where s.owner_id=v_uid and s.is_active=true and (p_store_id is null or s.id=p_store_id)
   order by s.created_at limit 1;
   if v_store is null then raise exception 'Seller store not found'; end if;
   insert into public.store_products(store_id,title,description,price,stock,is_active,image_url,unit,updated_at)
   values(v_store,trim(p_title),nullif(trim(coalesce(p_description,'')),''),p_price,p_stock,p_is_active,nullif(trim(coalesce(p_image_url,'')),''),v_unit,now())
   returning id into v_id;
 else
   update public.store_products p set
     title=trim(p_title),description=nullif(trim(coalesce(p_description,'')),''),price=p_price,
     stock=p_stock,is_active=p_is_active,image_url=nullif(trim(coalesce(p_image_url,'')),''),unit=v_unit,updated_at=now()
   where p.id=p_product_id and exists(select 1 from public.delivery_stores s where s.id=p.store_id and s.owner_id=v_uid)
   returning p.id into v_id;
   if v_id is null then raise exception 'Product not found or access denied'; end if;
 end if;
 return v_id;
end$$;
revoke all on function public.delivery_seller_product_save(uuid,text,text,numeric,integer,boolean,uuid,text,text) from public;
grant execute on function public.delivery_seller_product_save(uuid,text,text,numeric,integer,boolean,uuid,text,text) to authenticated;

-- Extend seller product feed.
drop function if exists public.delivery_seller_products(integer);
create function public.delivery_seller_products(p_limit integer default 100)
returns table(id uuid,title text,description text,price numeric,stock integer,is_active boolean,store_id uuid,image_url text,unit text)
language sql security definer set search_path=public stable as $$
 select p.id,p.title,p.description,p.price,p.stock,p.is_active,p.store_id,p.image_url,p.unit
 from public.store_products p join public.delivery_stores s on s.id=p.store_id
 where s.owner_id=auth.uid()
 order by p.is_active desc,p.title limit greatest(1,least(coalesce(p_limit,100),300));
$$;
revoke all on function public.delivery_seller_products(integer) from public;
grant execute on function public.delivery_seller_products(integer) to authenticated;

notify pgrst,'reload schema';