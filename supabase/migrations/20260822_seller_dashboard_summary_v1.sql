-- BINGO Seller Dashboard V1
-- Secure seller-only summary, products and customer reviews.

create or replace function public.delivery_seller_dashboard_summary()
returns jsonb
language plpgsql
security definer
set search_path=public
stable
as $$
declare
  v_uid uuid := auth.uid();
  v_store_ids uuid[];
  v_result jsonb;
begin
  if v_uid is null then raise exception 'Authentication required'; end if;
  select coalesce(array_agg(s.id),'{}'::uuid[]) into v_store_ids
  from public.delivery_stores s where s.owner_id=v_uid and s.is_active=true;

  select jsonb_build_object(
    'orders_total',(select count(*) from public.delivery_orders o where o.store_id=any(v_store_ids)),
    'orders_pending',(select count(*) from public.delivery_orders o where o.store_id=any(v_store_ids) and o.status='pending'),
    'orders_preparing',(select count(*) from public.delivery_orders o where o.store_id=any(v_store_ids) and o.status='preparing'),
    'orders_delivery',(select count(*) from public.delivery_orders o where o.store_id=any(v_store_ids) and o.status in ('assigned','picked_up','on_delivery')),
    'orders_delivered',(select count(*) from public.delivery_orders o where o.store_id=any(v_store_ids) and o.status='delivered'),
    'sales_delivered',coalesce((select round(sum(o.subtotal)::numeric,3) from public.delivery_orders o where o.store_id=any(v_store_ids) and o.status='delivered'),0),
    'products_total',(select count(*) from public.store_products p where p.store_id=any(v_store_ids)),
    'products_active',(select count(*) from public.store_products p where p.store_id=any(v_store_ids) and p.is_active=true),
    'low_stock',(select count(*) from public.store_products p where p.store_id=any(v_store_ids) and p.is_active=true and p.stock<=5),
    'rating',coalesce((select round(avg(r.rating)::numeric,2) from public.delivery_store_ratings r where r.store_id=any(v_store_ids)),0),
    'rating_count',(select count(*) from public.delivery_store_ratings r where r.store_id=any(v_store_ids))
  ) into v_result;
  return v_result;
end;$$;
revoke all on function public.delivery_seller_dashboard_summary() from public;
grant execute on function public.delivery_seller_dashboard_summary() to authenticated;

create or replace function public.delivery_seller_reviews(p_limit integer default 10)
returns table(order_number text,rating integer,comment text,created_at timestamptz)
language sql security definer set search_path=public stable as $$
 select o.order_number,r.rating,r.comment,r.created_at
 from public.delivery_store_ratings r
 join public.delivery_orders o on o.id=r.order_id
 join public.delivery_stores s on s.id=r.store_id
 where s.owner_id=auth.uid()
 order by r.created_at desc
 limit greatest(1,least(coalesce(p_limit,10),50));
$$;
revoke all on function public.delivery_seller_reviews(integer) from public;
grant execute on function public.delivery_seller_reviews(integer) to authenticated;

create or replace function public.delivery_seller_products(p_limit integer default 100)
returns table(id uuid,title text,price numeric,stock integer,is_active boolean,store_id uuid)
language sql security definer set search_path=public stable as $$
 select p.id,p.title,p.price,p.stock,p.is_active,p.store_id
 from public.store_products p
 join public.delivery_stores s on s.id=p.store_id
 where s.owner_id=auth.uid()
 order by p.is_active desc,p.title
 limit greatest(1,least(coalesce(p_limit,100),300));
$$;
revoke all on function public.delivery_seller_products(integer) from public;
grant execute on function public.delivery_seller_products(integer) to authenticated;

notify pgrst,'reload schema';
