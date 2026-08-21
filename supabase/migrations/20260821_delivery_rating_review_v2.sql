-- BINGO Rating & Review System V2
-- Extends the existing driver rating flow with an independent store rating.

create table if not exists public.delivery_store_ratings (
  id uuid primary key default gen_random_uuid(),
  order_id uuid not null references public.delivery_orders(id) on delete cascade,
  customer_id uuid not null references auth.users(id) on delete cascade,
  store_id uuid not null references public.delivery_stores(id) on delete cascade,
  rating integer not null check (rating between 1 and 5),
  comment text,
  created_at timestamptz not null default now(),
  unique(order_id)
);

create index if not exists delivery_store_ratings_store_idx
  on public.delivery_store_ratings(store_id,created_at desc);

alter table public.delivery_store_ratings enable row level security;
DO $$ BEGIN
  create policy delivery_store_ratings_customer_read on public.delivery_store_ratings
    for select to authenticated using (customer_id=auth.uid());
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

create or replace function public.customer_delivery_rate_v2(
  p_order_id uuid,
  p_driver_rating integer,
  p_store_rating integer,
  p_driver_comment text default null,
  p_store_comment text default null
)
returns jsonb
language plpgsql
security definer
set search_path=public
as $$
declare
  v_uid uuid := auth.uid();
  v_order public.delivery_orders%rowtype;
  v_driver uuid;
  v_driver_avg numeric(3,2);
  v_driver_count integer;
  v_store_avg numeric(3,2);
  v_store_count integer;
begin
  if v_uid is null then raise exception 'Authentication required'; end if;
  if p_driver_rating not between 1 and 5 then raise exception 'Driver rating must be between 1 and 5'; end if;
  if p_store_rating not between 1 and 5 then raise exception 'Store rating must be between 1 and 5'; end if;

  select * into v_order from public.delivery_orders
  where id=p_order_id and customer_id=v_uid and status='delivered';
  if v_order.id is null then raise exception 'Completed order not found'; end if;

  select a.driver_id into v_driver from public.delivery_assignments a
  where a.order_id=v_order.id and a.status='delivered'
  order by a.delivered_at desc nulls last limit 1;
  if v_driver is null then raise exception 'Completed delivery not found'; end if;

  if exists(select 1 from public.delivery_ratings where order_id=p_order_id)
     or exists(select 1 from public.delivery_store_ratings where order_id=p_order_id) then
    raise exception 'Order already rated';
  end if;

  insert into public.delivery_ratings(order_id,customer_id,driver_id,rating,comment)
  values(p_order_id,v_uid,v_driver,p_driver_rating,nullif(left(trim(coalesce(p_driver_comment,'')),500),''));

  insert into public.delivery_store_ratings(order_id,customer_id,store_id,rating,comment)
  values(p_order_id,v_uid,v_order.store_id,p_store_rating,nullif(left(trim(coalesce(p_store_comment,'')),500),''));

  select round(avg(r.rating)::numeric,2),count(*)::integer into v_driver_avg,v_driver_count
  from public.delivery_ratings r where r.driver_id=v_driver;
  update public.delivery_drivers set rating=coalesce(v_driver_avg,5.00),updated_at=now() where id=v_driver;

  select round(avg(r.rating)::numeric,2),count(*)::integer into v_store_avg,v_store_count
  from public.delivery_store_ratings r where r.store_id=v_order.store_id;

  return jsonb_build_object('ok',true,'order_id',v_order.id,'order_number',v_order.order_number,
    'driver_id',v_driver,'driver_rating',v_driver_avg,'driver_rating_count',v_driver_count,
    'store_id',v_order.store_id,'store_rating',v_store_avg,'store_rating_count',v_store_count);
end;$$;

revoke all on function public.customer_delivery_rate_v2(uuid,integer,integer,text,text) from public;
grant execute on function public.customer_delivery_rate_v2(uuid,integer,integer,text,text) to authenticated;

create or replace function public.customer_delivery_pending_ratings_v2()
returns table(order_id uuid,order_number text,driver_id uuid,driver_name text,store_id uuid,store_name text,delivered_at timestamptz)
language sql security definer set search_path=public stable as $$
 select o.id,o.order_number,a.driver_id,coalesce(d.display_name,'BINGO Driver'),o.store_id,
        coalesce(s.store_name_ar,s.store_name_en,s.store_name,'BINGO Store'),a.delivered_at
 from public.delivery_orders o
 join public.delivery_assignments a on a.order_id=o.id and a.status='delivered'
 join public.delivery_drivers d on d.id=a.driver_id
 join public.delivery_stores s on s.id=o.store_id
 left join public.delivery_ratings dr on dr.order_id=o.id
 left join public.delivery_store_ratings sr on sr.order_id=o.id
 where o.customer_id=auth.uid() and o.status='delivered' and dr.id is null and sr.id is null
 order by a.delivered_at desc nulls last limit 10;
$$;
revoke all on function public.customer_delivery_pending_ratings_v2() from public;
grant execute on function public.customer_delivery_pending_ratings_v2() to authenticated;

-- Notify customer once after delivery to rate both driver and store.
create or replace function public.delivery_rating_prompt_trigger()
returns trigger language plpgsql security definer set search_path=public as $$
begin
 if new.status='delivered' and old.status is distinct from new.status then
   perform public.delivery_notify_user(new.customer_id,'rating_prompt','⭐ قيّم تجربتك','قيّم المندوب والمتجر لطلب '||new.order_number||'.',
     'order-tracking.html?delivery='||new.order_number,new.id,'order:'||new.id||':rating-prompt');
 end if;
 return new;
end;$$;
drop trigger if exists trg_delivery_rating_prompt on public.delivery_orders;
create trigger trg_delivery_rating_prompt after update of status on public.delivery_orders
for each row execute function public.delivery_rating_prompt_trigger();

NOTIFY pgrst, 'reload schema';
