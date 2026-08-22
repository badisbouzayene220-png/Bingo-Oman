-- BINGO Store fractional quantities V1
-- piece/pack stay whole-number; kg/g/meter/liter can use decimal quantities.
-- Safely preserves RLS policies while changing column types.

begin;

-- PostgreSQL does not allow changing a column type while an RLS policy depends on it.
-- Save ALL policies for the affected tables exactly as they currently exist.
create temporary table _bingo_saved_policies on commit drop as
select schemaname, tablename, policyname, permissive, roles, cmd, qual, with_check
from pg_policies
where schemaname='public'
  and tablename in ('store_products','store_order_items');

-- Drop the saved policies temporarily.
do $$
declare r record;
begin
  for r in select * from _bingo_saved_policies loop
    execute format('drop policy if exists %I on %I.%I',r.policyname,r.schemaname,r.tablename);
  end loop;
end $$;

-- Convert stock/order quantities to decimals.
alter table public.store_products
  alter column stock type numeric(18,3) using stock::numeric;

alter table public.store_order_items
  alter column quantity type numeric(18,3) using quantity::numeric;

-- Restore every RLS policy with its original role, command and conditions.
do $$
declare
  r record;
  v_roles text;
  v_sql text;
begin
  for r in select * from _bingo_saved_policies loop
    select string_agg(case when x='public' then 'public' else quote_ident(x) end, ', ')
      into v_roles
    from unnest(r.roles) x;

    v_sql := format(
      'create policy %I on %I.%I as %s for %s to %s',
      r.policyname,
      r.schemaname,
      r.tablename,
      r.permissive,
      r.cmd,
      coalesce(v_roles,'public')
    );

    if r.qual is not null then
      v_sql := v_sql || ' using (' || r.qual || ')';
    end if;
    if r.with_check is not null then
      v_sql := v_sql || ' with check (' || r.with_check || ')';
    end if;

    execute v_sql;
  end loop;
end $$;

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
language plpgsql
security definer
set search_path to 'public'
as $function$
declare
  uid uuid := auth.uid();
  r public.store_orders;
  item jsonb;
  p public.store_products;
  qty numeric(18,3);
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
    qty := round(greatest(coalesce((item->>'quantity')::numeric,0),0),3);
    if qty <= 0 then raise exception 'Invalid quantity'; end if;

    select * into p from public.store_products
    where id=(item->>'product_id')::uuid and is_active=true
    for update;
    if not found then raise exception 'A product is no longer available'; end if;

    -- Piece and pack products must remain whole-number quantities.
    if coalesce(p.unit,'piece') in ('piece','pack') and qty <> trunc(qty) then
      raise exception 'Whole quantity required for: %', p.title;
    end if;

    if p.stock < qty then raise exception 'Not enough stock for: %', p.title; end if;

    insert into public.store_order_items(order_id,product_id,product_title,unit_price,quantity,line_total)
    values(order_id,p.id,p.title,p.price,qty,round((p.price*qty)::numeric,3));

    sub := sub + (p.price*qty);
    update public.store_products set stock=stock-qty,updated_at=now() where id=p.id;
  end loop;

  sub := round(sub,3);
  if sub <= 0 then raise exception 'Order total must be greater than zero'; end if;
  update public.store_orders set subtotal=sub,total=sub+fee,updated_at=now()
  where id=order_id returning * into r;
  return r;
end
$function$;

notify pgrst,'reload schema';
commit;
