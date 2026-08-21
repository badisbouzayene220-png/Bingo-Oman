-- BINGO Delivery - Driver customer reviews feed

create or replace function public.delivery_driver_reviews_feed(p_limit integer default 20)
returns jsonb
language plpgsql
security definer
set search_path=public
stable
as $$
declare
  v_uid uuid := auth.uid();
  v_avg numeric(4,2);
  v_count integer;
  v_five integer;
  v_reviews jsonb;
begin
  if v_uid is null then raise exception 'Authentication required'; end if;
  if not exists(select 1 from public.delivery_drivers where id=v_uid) then
    raise exception 'Driver profile not found';
  end if;

  select round(avg(r.rating)::numeric,2),count(*)::integer,
         count(*) filter(where r.rating=5)::integer
    into v_avg,v_count,v_five
  from public.delivery_ratings r
  where r.driver_id=v_uid;

  select coalesce(jsonb_agg(x order by x.created_at desc),'[]'::jsonb)
    into v_reviews
  from (
    select r.id,r.order_id,o.order_number,r.rating,r.comment,r.created_at
    from public.delivery_ratings r
    join public.delivery_orders o on o.id=r.order_id
    where r.driver_id=v_uid
    order by r.created_at desc
    limit greatest(1,least(coalesce(p_limit,20),50))
  ) x;

  return jsonb_build_object(
    'rating',coalesce(v_avg,5.00),
    'rating_count',coalesce(v_count,0),
    'five_star_count',coalesce(v_five,0),
    'reviews',coalesce(v_reviews,'[]'::jsonb)
  );
end;
$$;

revoke all on function public.delivery_driver_reviews_feed(integer) from public;
grant execute on function public.delivery_driver_reviews_feed(integer) to authenticated;
notify pgrst,'reload schema';
