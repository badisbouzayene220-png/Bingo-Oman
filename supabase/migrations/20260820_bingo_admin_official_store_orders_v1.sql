-- BINGO Oman — Admin controls for Official BINGO Store orders V1
-- Lets Delivery Admin prepare, mark ready, and request a driver for the internal BINGO Store.

create or replace function public.admin_bingo_store_orders()
returns table(
  order_id uuid,
  order_number text,
  status text,
  payment_status text,
  delivery_address text,
  subtotal numeric,
  delivery_fee numeric,
  total numeric,
  created_at timestamptz,
  items jsonb
)
language plpgsql
security definer
set search_path=public
stable
as $$
begin
  if not public.delivery_is_admin() then raise exception 'Admin permission required'; end if;

  return query
  select o.id,
         o.order_number,
         o.status,
         o.payment_status,
         o.delivery_address,
         o.subtotal,
         o.delivery_fee,
         o.total,
         o.created_at,
         coalesce((
           select jsonb_agg(jsonb_build_object(
             'product_id',i.product_id,
             'description',i.description,
             'quantity',i.quantity,
             'unit_price',i.unit_price
           ) order by i.description)
           from public.delivery_order_items i
           where i.order_id=o.id
         ),'[]'::jsonb)
  from public.delivery_orders o
  join public.delivery_stores s on s.id=o.store_id
  where s.owner_id is null
    and lower(coalesce(s.store_name_en,s.store_name,''))='bingo store'
    and s.is_active=true
  order by o.created_at desc
  limit 100;
end;
$$;

revoke all on function public.admin_bingo_store_orders() from public;
grant execute on function public.admin_bingo_store_orders() to authenticated;

create or replace function public.admin_bingo_store_set_order_status(
  p_order_id uuid,
  p_status text
) returns jsonb
language plpgsql
security definer
set search_path=public
as $$
declare
  v_old text;
  v_store uuid;
begin
  if not public.delivery_is_admin() then raise exception 'Admin permission required'; end if;
  if p_status not in ('preparing','ready') then raise exception 'Invalid BINGO Store status'; end if;

  select o.status,o.store_id into v_old,v_store
  from public.delivery_orders o
  join public.delivery_stores s on s.id=o.store_id
  where o.id=p_order_id
    and s.owner_id is null
    and lower(coalesce(s.store_name_en,s.store_name,''))='bingo store'
    and s.is_active=true
  for update of o;

  if not found then raise exception 'Official BINGO Store order not found'; end if;

  if p_status='preparing' and v_old not in ('pending','confirmed') then
    raise exception 'Order cannot start preparation from status %',v_old;
  end if;
  if p_status='ready' and v_old<>'preparing' then
    raise exception 'Order must be preparing before it can be ready';
  end if;

  update public.delivery_orders
  set status=p_status,updated_at=now()
  where id=p_order_id;

  return jsonb_build_object('ok',true,'order_id',p_order_id,'status',p_status);
end;
$$;

revoke all on function public.admin_bingo_store_set_order_status(uuid,text) from public;
grant execute on function public.admin_bingo_store_set_order_status(uuid,text) to authenticated;

create or replace function public.admin_bingo_store_request_driver(p_order_id uuid)
returns uuid
language plpgsql
security definer
set search_path=public
as $$
declare
  v_uid uuid:=auth.uid();
  v_store_id uuid;
  v_assignment uuid;
begin
  if not public.delivery_is_admin() then raise exception 'Admin permission required'; end if;

  select s.id into v_store_id
  from public.delivery_stores s
  join public.delivery_orders o on o.store_id=s.id
  where o.id=p_order_id
    and o.status='ready'
    and s.owner_id is null
    and lower(coalesce(s.store_name_en,s.store_name,''))='bingo store'
    and s.is_active=true
  for update of s;

  if v_store_id is null then raise exception 'Ready Official BINGO Store order not found'; end if;

  -- Reuse the already-tested Smart Score seller dispatcher without changing its logic.
  -- The temporary owner change exists only inside this transaction and is restored before commit.
  update public.delivery_stores set owner_id=v_uid where id=v_store_id;
  begin
    v_assignment:=public.delivery_store_request_driver(p_order_id);
  exception when others then
    update public.delivery_stores set owner_id=null where id=v_store_id;
    raise;
  end;
  update public.delivery_stores set owner_id=null where id=v_store_id;

  return v_assignment;
end;
$$;

revoke all on function public.admin_bingo_store_request_driver(uuid) from public;
grant execute on function public.admin_bingo_store_request_driver(uuid) to authenticated;

NOTIFY pgrst, 'reload schema';
