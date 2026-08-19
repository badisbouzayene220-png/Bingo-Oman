-- BINGO Delivery Ratings + Driver Badges V1
-- Additive migration. Reuses delivery_ratings and delivery_drivers.

create or replace function public.customer_delivery_rate(
  p_order_id uuid,
  p_rating integer,
  p_comment text default null
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_driver uuid;
  v_order_number text;
  v_avg numeric(3,2);
  v_count integer;
begin
  if v_uid is null then
    raise exception 'Authentication required';
  end if;
  if p_rating < 1 or p_rating > 5 then
    raise exception 'Rating must be between 1 and 5';
  end if;

  select o.order_number, a.driver_id
    into v_order_number, v_driver
  from public.delivery_orders o
  join public.delivery_assignments a on a.order_id = o.id and a.status = 'delivered'
  where o.id = p_order_id
    and o.customer_id = v_uid
    and o.status = 'delivered'
  order by a.delivered_at desc nulls last
  limit 1;

  if v_driver is null then
    raise exception 'Completed delivery not found';
  end if;

  if exists (select 1 from public.delivery_ratings r where r.order_id = p_order_id) then
    raise exception 'Delivery already rated';
  end if;

  insert into public.delivery_ratings(order_id, customer_id, driver_id, rating, comment)
  values (p_order_id, v_uid, v_driver, p_rating, nullif(left(trim(coalesce(p_comment,'')),500),''));

  select round(avg(r.rating)::numeric,2), count(*)::integer
    into v_avg, v_count
  from public.delivery_ratings r
  where r.driver_id = v_driver;

  update public.delivery_drivers
  set rating = coalesce(v_avg,5.00), updated_at = now()
  where id = v_driver;

  return jsonb_build_object(
    'ok', true,
    'order_id', p_order_id,
    'order_number', v_order_number,
    'driver_id', v_driver,
    'rating', p_rating,
    'driver_rating', coalesce(v_avg,5.00),
    'rating_count', v_count
  );
end;
$$;

revoke all on function public.customer_delivery_rate(uuid,integer,text) from public;
grant execute on function public.customer_delivery_rate(uuid,integer,text) to authenticated;

create or replace function public.customer_delivery_pending_ratings()
returns table(
  order_id uuid,
  order_number text,
  driver_id uuid,
  driver_name text,
  delivered_at timestamptz
)
language sql
security definer
set search_path = public
stable
as $$
  select o.id,
         o.order_number,
         a.driver_id,
         coalesce(d.display_name,'BINGO Driver') as driver_name,
         a.delivered_at
  from public.delivery_orders o
  join public.delivery_assignments a on a.order_id=o.id and a.status='delivered'
  join public.delivery_drivers d on d.id=a.driver_id
  left join public.delivery_ratings r on r.order_id=o.id
  where o.customer_id=auth.uid()
    and o.status='delivered'
    and r.id is null
  order by a.delivered_at desc nulls last
  limit 5;
$$;

revoke all on function public.customer_delivery_pending_ratings() from public;
grant execute on function public.customer_delivery_pending_ratings() to authenticated;

create or replace function public.delivery_driver_badge_stats()
returns jsonb
language plpgsql
security definer
set search_path = public
stable
as $$
declare
  v_uid uuid := auth.uid();
  v_rating numeric(3,2);
  v_total integer;
  v_rating_count integer;
  v_five integer;
  v_streak integer := 0;
  v_row record;
  v_badges jsonb := '[]'::jsonb;
begin
  if v_uid is null then raise exception 'Authentication required'; end if;

  select d.rating,d.total_deliveries
    into v_rating,v_total
  from public.delivery_drivers d where d.id=v_uid;
  if not found then raise exception 'Driver profile not found'; end if;

  select count(*)::integer,
         count(*) filter(where r.rating=5)::integer
    into v_rating_count,v_five
  from public.delivery_ratings r where r.driver_id=v_uid;

  for v_row in
    select r.rating from public.delivery_ratings r
    where r.driver_id=v_uid
    order by r.created_at desc
  loop
    if v_row.rating = 5 then v_streak := v_streak + 1;
    else exit;
    end if;
  end loop;

  if v_total >= 10 then v_badges := v_badges || jsonb_build_array(jsonb_build_object('id','starter10','icon','🚀','name','أول 10 توصيلات')); end if;
  if v_total >= 50 then v_badges := v_badges || jsonb_build_array(jsonb_build_object('id','road50','icon','🛵','name','BINGO Road 50')); end if;
  if v_total >= 100 then v_badges := v_badges || jsonb_build_array(jsonb_build_object('id','century','icon','🏆','name','BINGO 100')); end if;
  if v_rating_count >= 5 and v_rating >= 4.80 then v_badges := v_badges || jsonb_build_array(jsonb_build_object('id','toprated','icon','⭐','name','Top Rated')); end if;
  if v_five >= 10 then v_badges := v_badges || jsonb_build_array(jsonb_build_object('id','five10','icon','🌟','name','10 تقييمات كاملة')); end if;
  if v_streak >= 3 then v_badges := v_badges || jsonb_build_array(jsonb_build_object('id','streak3','icon','🔥','name','BINGO Streak')); end if;

  return jsonb_build_object(
    'rating', coalesce(v_rating,5.00),
    'rating_count', coalesce(v_rating_count,0),
    'total_deliveries', coalesce(v_total,0),
    'five_star_count', coalesce(v_five,0),
    'five_star_streak', v_streak,
    'badges', v_badges
  );
end;
$$;

revoke all on function public.delivery_driver_badge_stats() from public;
grant execute on function public.delivery_driver_badge_stats() to authenticated;
