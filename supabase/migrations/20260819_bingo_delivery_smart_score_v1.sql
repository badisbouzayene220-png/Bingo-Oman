-- BINGO Delivery Smart Score V1
-- Automatic driver scoring using distance, capacity/load, rating, acceptance behavior,
-- acceptance speed and delivery history. Manual High/Normal/Low remains an override factor.

alter table public.delivery_dispatch_log
  add column if not exists smart_score numeric(8,2),
  add column if not exists score_breakdown jsonb;

create or replace function public.admin_delivery_driver_smart_scores()
returns table(
  driver_id uuid,
  driver_name text,
  is_online boolean,
  is_available boolean,
  dispatch_priority integer,
  active_load integer,
  max_concurrent integer,
  rating numeric,
  accepted_count integer,
  rejected_count integer,
  acceptance_rate numeric,
  avg_accept_seconds numeric,
  completed_deliveries integer,
  base_smart_score numeric
)
language plpgsql
security definer
set search_path=public
stable
as $$
begin
  if not public.delivery_is_admin() then raise exception 'Admin permission required'; end if;

  return query
  with stats as (
    select d.id,
           count(a.id) filter (where a.status in ('accepted','picked_up','on_delivery','delivered'))::integer accepted_count,
           count(a.id) filter (where a.status='rejected')::integer rejected_count,
           avg(extract(epoch from (a.accepted_at-a.offered_at))) filter (where a.accepted_at is not null and a.offered_at is not null) avg_accept_seconds
    from public.delivery_drivers d
    left join public.delivery_assignments a on a.driver_id=d.id
    group by d.id
  ), loads as (
    select d.id,
           count(a.id) filter (where a.status in ('offered','accepted','picked_up','on_delivery'))::integer active_load
    from public.delivery_drivers d
    left join public.delivery_assignments a on a.driver_id=d.id
    group by d.id
  )
  select d.id,
         coalesce(d.display_name,d.phone,'BINGO Driver'),
         d.is_online,d.is_available,coalesce(d.dispatch_priority,0),
         coalesce(l.active_load,0),coalesce(d.max_concurrent_orders,1),
         coalesce(d.rating,0)::numeric,
         coalesce(s.accepted_count,0),coalesce(s.rejected_count,0),
         case when coalesce(s.accepted_count,0)+coalesce(s.rejected_count,0)=0 then 1::numeric
              else s.accepted_count::numeric/(s.accepted_count+s.rejected_count) end,
         coalesce(s.avg_accept_seconds,60)::numeric,
         coalesce(d.total_deliveries,0),
         round((
           100
           + coalesce(d.dispatch_priority,0)*25
           + least(greatest(coalesce(d.rating,0),0),5)/5*20
           + (case when coalesce(s.accepted_count,0)+coalesce(s.rejected_count,0)=0 then 1::numeric else s.accepted_count::numeric/(s.accepted_count+s.rejected_count) end)*15
           + greatest(0,10-least(coalesce(s.avg_accept_seconds,60),300)/30)
           + least(coalesce(d.total_deliveries,0),100)::numeric/100*5
           - (coalesce(l.active_load,0)::numeric/greatest(coalesce(d.max_concurrent_orders,1),1))*20
         )::numeric,2)
  from public.delivery_drivers d
  left join stats s on s.id=d.id
  left join loads l on l.id=d.id
  order by 14 desc,2;
end;
$$;

revoke all on function public.admin_delivery_driver_smart_scores() from public;
grant execute on function public.admin_delivery_driver_smart_scores() to authenticated;

create or replace function public.delivery_store_request_driver(p_order_id uuid)
returns uuid
language plpgsql
security definer
set search_path=public
as $$
declare
  v_assignment_id uuid;
  v_driver_id uuid;
  v_order_status text;
  v_store_lat numeric;
  v_store_lng numeric;
  v_active integer;
  v_max integer;
  v_distance numeric(10,2);
  v_priority integer;
  v_rating numeric;
  v_acceptance numeric;
  v_avg_accept numeric;
  v_completed integer;
  v_score numeric(8,2);
  v_reason text;
  v_breakdown jsonb;
begin
  if auth.uid() is null then raise exception 'Authentication required'; end if;
  perform pg_advisory_xact_lock(hashtextextended('bingo_delivery_smart_dispatch',0));

  select o.status,s.latitude,s.longitude
    into v_order_status,v_store_lat,v_store_lng
  from public.delivery_orders o
  join public.delivery_stores s on s.id=o.store_id
  where o.id=p_order_id and s.owner_id=auth.uid() and s.is_active=true
  for update of o;

  if not found then raise exception 'Order not found for this seller'; end if;

  select a.id into v_assignment_id
  from public.delivery_assignments a
  where a.order_id=p_order_id and a.status in ('offered','accepted','picked_up','on_delivery')
  order by a.offered_at desc limit 1;
  if v_assignment_id is not null then return v_assignment_id; end if;
  if v_order_status<>'ready' then raise exception 'Order must be ready before requesting a driver'; end if;

  with candidates as (
    select d.id,
           coalesce(loads.active_load,0) active_load,
           coalesce(d.max_concurrent_orders,1) max_orders,
           coalesce(d.dispatch_priority,0) priority,
           coalesce(d.rating,0)::numeric rating,
           coalesce(d.total_deliveries,0) completed,
           case when coalesce(st.accepted_count,0)+coalesce(st.rejected_count,0)=0 then 1::numeric
                else st.accepted_count::numeric/(st.accepted_count+st.rejected_count) end acceptance_rate,
           coalesce(st.avg_accept_seconds,60)::numeric avg_accept_seconds,
           case when v_store_lat is not null and v_store_lng is not null and l.latitude is not null and l.longitude is not null and l.updated_at>=now()-interval '20 minutes'
                then (sqrt(power((l.latitude-v_store_lat)::numeric,2)+power((l.longitude-v_store_lng)::numeric,2))*111)::numeric(10,2)
                else null end distance_km
    from public.delivery_drivers d
    left join public.delivery_driver_locations l on l.driver_id=d.id
    left join lateral (
      select count(*)::integer active_load
      from public.delivery_assignments a
      where a.driver_id=d.id and a.status in ('offered','accepted','picked_up','on_delivery')
    ) loads on true
    left join lateral (
      select count(*) filter (where a.status in ('accepted','picked_up','on_delivery','delivered'))::integer accepted_count,
             count(*) filter (where a.status='rejected')::integer rejected_count,
             avg(extract(epoch from (a.accepted_at-a.offered_at))) filter (where a.accepted_at is not null and a.offered_at is not null) avg_accept_seconds
      from public.delivery_assignments a where a.driver_id=d.id
    ) st on true
    where d.is_online=true and d.is_available=true
      and coalesce(loads.active_load,0)<coalesce(d.max_concurrent_orders,1)
  ), scored as (
    select c.*,
      round((
        100
        + c.priority*25
        + least(greatest(c.rating,0),5)/5*20
        + c.acceptance_rate*15
        + greatest(0,10-least(c.avg_accept_seconds,300)/30)
        + least(c.completed,100)::numeric/100*5
        - (c.active_load::numeric/greatest(c.max_orders,1))*20
        - case when c.distance_km is null then 8 else least(c.distance_km,30) end
      )::numeric,2) smart_score
    from candidates c
  )
  select id,active_load,max_orders,distance_km,priority,rating,acceptance_rate,avg_accept_seconds,completed,smart_score
  into v_driver_id,v_active,v_max,v_distance,v_priority,v_rating,v_acceptance,v_avg_accept,v_completed,v_score
  from scored
  order by smart_score desc,
           distance_km asc nulls last,
           active_load asc,
           completed asc
  limit 1;

  if v_driver_id is null then raise exception 'No available BINGO driver right now'; end if;

  insert into public.delivery_assignments(order_id,driver_id,status,offered_at)
  values(p_order_id,v_driver_id,'offered',now()) returning id into v_assignment_id;

  update public.delivery_orders set status='assigned',updated_at=now() where id=p_order_id;
  update public.delivery_drivers
  set is_available=is_online and (v_active+1<v_max),updated_at=now()
  where id=v_driver_id;

  v_breakdown=jsonb_build_object(
    'priority',v_priority,
    'distance_km',v_distance,
    'active_load',v_active,
    'max_concurrent',v_max,
    'rating',v_rating,
    'acceptance_rate',round(v_acceptance*100,1),
    'avg_accept_seconds',round(v_avg_accept,1),
    'completed_deliveries',v_completed
  );

  v_reason := 'BINGO Smart Score '||to_char(v_score,'FM999990.00')||' • '
    ||case v_priority when 1 then 'High' when -1 then 'Low' else 'Normal' end
    ||case when v_distance is not null then ' • '||to_char(v_distance,'FM999990.00')||' كم' else '' end
    ||' • الحمل '||v_active||'/'||v_max
    ||' • التقييم '||to_char(v_rating,'FM9.00')
    ||' • قبول '||to_char(v_acceptance*100,'FM990')||'%';

  insert into public.delivery_dispatch_log(
    assignment_id,order_id,driver_id,action,reason,distance_km,active_load,max_concurrent,created_by,smart_score,score_breakdown
  ) values(
    v_assignment_id,p_order_id,v_driver_id,'auto_assign',v_reason,v_distance,v_active,v_max,auth.uid(),v_score,v_breakdown
  );

  return v_assignment_id;
end;
$$;

revoke all on function public.delivery_store_request_driver(uuid) from public;
grant execute on function public.delivery_store_request_driver(uuid) to authenticated;

create or replace function public.admin_delivery_dispatch_smart_board()
returns table(
  assignment_id uuid,
  order_number text,
  driver_name text,
  assignment_status text,
  smart_score numeric,
  dispatch_reason text,
  score_breakdown jsonb,
  offered_at timestamptz
)
language plpgsql
security definer
set search_path=public
stable
as $$
begin
  if not public.delivery_is_admin() then raise exception 'Admin permission required'; end if;
  return query
  select a.id,o.order_number,coalesce(d.display_name,d.phone,'BINGO Driver'),a.status,
         l.smart_score,l.reason,l.score_breakdown,a.offered_at
  from public.delivery_assignments a
  join public.delivery_orders o on o.id=a.order_id
  join public.delivery_drivers d on d.id=a.driver_id
  left join lateral (
    select x.smart_score,x.reason,x.score_breakdown
    from public.delivery_dispatch_log x where x.assignment_id=a.id
    order by x.created_at desc limit 1
  ) l on true
  where a.status in ('offered','accepted','picked_up','on_delivery')
  order by a.offered_at desc limit 100;
end;
$$;

revoke all on function public.admin_delivery_dispatch_smart_board() from public;
grant execute on function public.admin_delivery_dispatch_smart_board() to authenticated;
