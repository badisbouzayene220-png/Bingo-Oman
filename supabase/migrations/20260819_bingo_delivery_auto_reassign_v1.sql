-- BINGO Delivery Auto Reassign V1
-- Reassigns stale/offline offered assignments using Smart Score.

alter table public.delivery_dispatch_log
  drop constraint if exists delivery_dispatch_action_check;
alter table public.delivery_dispatch_log
  add constraint delivery_dispatch_action_check
  check (action in ('auto_assign','manual_reassign','auto_reassign'));

create table if not exists public.delivery_dispatch_settings (
  id boolean primary key default true check (id=true),
  offer_timeout_seconds integer not null default 45 check (offer_timeout_seconds between 20 and 180),
  updated_at timestamptz not null default now(),
  updated_by uuid references auth.users(id) on delete set null
);
insert into public.delivery_dispatch_settings(id,offer_timeout_seconds)
values(true,45) on conflict(id) do nothing;
alter table public.delivery_dispatch_settings enable row level security;

create or replace function public.admin_delivery_set_offer_timeout(p_seconds integer)
returns jsonb
language plpgsql security definer set search_path=public
as $$
begin
  if not public.delivery_is_admin() then raise exception 'Admin permission required'; end if;
  if p_seconds not between 20 and 180 then raise exception 'Timeout must be between 20 and 180 seconds'; end if;
  update public.delivery_dispatch_settings
  set offer_timeout_seconds=p_seconds,updated_at=now(),updated_by=auth.uid()
  where id=true;
  return jsonb_build_object('ok',true,'offer_timeout_seconds',p_seconds);
end;
$$;
revoke all on function public.admin_delivery_set_offer_timeout(integer) from public;
grant execute on function public.admin_delivery_set_offer_timeout(integer) to authenticated;

create or replace function public.admin_delivery_auto_reassign_board()
returns table(
  assignment_id uuid, order_number text, driver_name text, driver_online boolean,
  offered_at timestamptz, timeout_seconds integer, seconds_left integer, auto_reason text
)
language plpgsql security definer set search_path=public stable
as $$
begin
  if not public.delivery_is_admin() then raise exception 'Admin permission required'; end if;
  return query
  select a.id,o.order_number,coalesce(d.display_name,d.phone,'BINGO Driver'),d.is_online,a.offered_at,
         s.offer_timeout_seconds,
         greatest(0,s.offer_timeout_seconds-floor(extract(epoch from(now()-a.offered_at)))::integer),
         case when not d.is_online then 'المندوب Offline'
              when now()>=a.offered_at+make_interval(secs=>s.offer_timeout_seconds) then 'انتهت مهلة القبول'
              else 'بانتظار قبول المندوب' end
  from public.delivery_assignments a
  join public.delivery_orders o on o.id=a.order_id
  join public.delivery_drivers d on d.id=a.driver_id
  cross join public.delivery_dispatch_settings s
  where a.status='offered'
  order by a.offered_at asc;
end;
$$;
revoke all on function public.admin_delivery_auto_reassign_board() from public;
grant execute on function public.admin_delivery_auto_reassign_board() to authenticated;

create or replace function public.delivery_process_auto_reassign()
returns jsonb
language plpgsql security definer set search_path=public
as $$
declare
  v_timeout integer;
  rec record;
  v_new_driver uuid;
  v_active integer; v_max integer; v_distance numeric(10,2); v_priority integer;
  v_rating numeric; v_acceptance numeric; v_avg_accept numeric; v_completed integer; v_score numeric(8,2);
  v_new_assignment uuid; v_store_lat numeric; v_store_lng numeric; v_reason text; v_breakdown jsonb;
  v_old_max integer; v_old_load integer; v_count integer:=0;
begin
  if auth.uid() is null then raise exception 'Authentication required'; end if;
  perform pg_advisory_xact_lock(hashtextextended('bingo_delivery_auto_reassign',0));
  select offer_timeout_seconds into v_timeout from public.delivery_dispatch_settings where id=true;

  for rec in
    select a.id assignment_id,a.order_id,a.driver_id,a.offered_at,d.is_online
    from public.delivery_assignments a join public.delivery_drivers d on d.id=a.driver_id
    where a.status='offered'
      and (d.is_online=false or now()>=a.offered_at+make_interval(secs=>v_timeout))
    order by a.offered_at asc
    for update of a skip locked
  loop
    -- Cancel the stale offer and free the old driver's capacity.
    update public.delivery_assignments set status='cancelled' where id=rec.assignment_id and status='offered';
    if not found then continue; end if;

    select coalesce(max_concurrent_orders,1) into v_old_max from public.delivery_drivers where id=rec.driver_id;
    select public.delivery_driver_active_load(rec.driver_id) into v_old_load;
    update public.delivery_drivers
      set is_available=is_online and (v_old_load<v_old_max),updated_at=now()
      where id=rec.driver_id;
    update public.delivery_orders set status='ready',updated_at=now() where id=rec.order_id;

    select s.latitude,s.longitude into v_store_lat,v_store_lng
    from public.delivery_orders o join public.delivery_stores s on s.id=o.store_id where o.id=rec.order_id;

    v_new_driver:=null;
    with candidates as (
      select d.id,
        coalesce(loads.active_load,0) active_load,coalesce(d.max_concurrent_orders,1) max_orders,
        coalesce(d.dispatch_priority,0) priority,coalesce(d.rating,0)::numeric rating,coalesce(d.total_deliveries,0) completed,
        case when coalesce(st.accepted_count,0)+coalesce(st.rejected_count,0)=0 then 1::numeric
             else st.accepted_count::numeric/(st.accepted_count+st.rejected_count) end acceptance_rate,
        coalesce(st.avg_accept_seconds,60)::numeric avg_accept_seconds,
        case when v_store_lat is not null and v_store_lng is not null and l.latitude is not null and l.longitude is not null and l.updated_at>=now()-interval '20 minutes'
          then (sqrt(power((l.latitude-v_store_lat)::numeric,2)+power((l.longitude-v_store_lng)::numeric,2))*111)::numeric(10,2) else null end distance_km
      from public.delivery_drivers d
      left join public.delivery_driver_locations l on l.driver_id=d.id
      left join lateral (select count(*)::integer active_load from public.delivery_assignments a where a.driver_id=d.id and a.status in ('offered','accepted','picked_up','on_delivery')) loads on true
      left join lateral (
        select count(*) filter(where a.status in ('accepted','picked_up','on_delivery','delivered'))::integer accepted_count,
               count(*) filter(where a.status='rejected')::integer rejected_count,
               avg(extract(epoch from(a.accepted_at-a.offered_at))) filter(where a.accepted_at is not null and a.offered_at is not null) avg_accept_seconds
        from public.delivery_assignments a where a.driver_id=d.id
      ) st on true
      where d.id<>rec.driver_id and d.is_online=true and d.is_available=true
        and coalesce(loads.active_load,0)<coalesce(d.max_concurrent_orders,1)
    ), scored as (
      select c.*,round((100+c.priority*25+least(greatest(c.rating,0),5)/5*20+c.acceptance_rate*15
        +greatest(0,10-least(c.avg_accept_seconds,300)/30)+least(c.completed,100)::numeric/100*5
        -(c.active_load::numeric/greatest(c.max_orders,1))*20-case when c.distance_km is null then 8 else least(c.distance_km,30) end)::numeric,2) smart_score
      from candidates c
    )
    select id,active_load,max_orders,distance_km,priority,rating,acceptance_rate,avg_accept_seconds,completed,smart_score
    into v_new_driver,v_active,v_max,v_distance,v_priority,v_rating,v_acceptance,v_avg_accept,v_completed,v_score
    from scored order by smart_score desc,distance_km asc nulls last,active_load asc limit 1;

    if v_new_driver is null then
      insert into public.delivery_dispatch_log(assignment_id,order_id,driver_id,action,reason,active_load,max_concurrent,created_by)
      values(rec.assignment_id,rec.order_id,rec.driver_id,'auto_reassign',
        case when rec.is_online=false then 'Auto Reassign: المندوب أصبح Offline ولا يوجد بديل متاح الآن'
             else 'Auto Reassign: انتهت مهلة القبول ولا يوجد بديل متاح الآن' end,
        v_old_load,v_old_max,auth.uid());
      continue;
    end if;

    insert into public.delivery_assignments(order_id,driver_id,status,offered_at)
    values(rec.order_id,v_new_driver,'offered',now()) returning id into v_new_assignment;
    update public.delivery_orders set status='assigned',updated_at=now() where id=rec.order_id;
    update public.delivery_drivers set is_available=is_online and (v_active+1<v_max),updated_at=now() where id=v_new_driver;

    v_breakdown=jsonb_build_object('priority',v_priority,'distance_km',v_distance,'active_load',v_active,'max_concurrent',v_max,
      'rating',v_rating,'acceptance_rate',round(v_acceptance*100,1),'avg_accept_seconds',round(v_avg_accept,1),'completed_deliveries',v_completed,
      'previous_driver_id',rec.driver_id,'previous_assignment_id',rec.assignment_id);
    v_reason := case when rec.is_online=false then 'Auto Reassign: المندوب السابق Offline' else 'Auto Reassign: انتهت مهلة '||v_timeout||' ثانية' end
      ||' • Smart Score '||to_char(v_score,'FM999990.00');
    insert into public.delivery_dispatch_log(assignment_id,order_id,driver_id,action,reason,distance_km,active_load,max_concurrent,created_by,smart_score,score_breakdown)
    values(v_new_assignment,rec.order_id,v_new_driver,'auto_reassign',v_reason,v_distance,v_active,v_max,auth.uid(),v_score,v_breakdown);
    v_count:=v_count+1;
  end loop;
  return jsonb_build_object('ok',true,'reassigned',v_count,'timeout_seconds',v_timeout);
end;
$$;
revoke all on function public.delivery_process_auto_reassign() from public;
grant execute on function public.delivery_process_auto_reassign() to authenticated;
