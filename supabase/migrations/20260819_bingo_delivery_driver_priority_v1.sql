-- BINGO Driver Priority V1
-- Admin-controlled High / Normal / Low priority for Smart Dispatch.

alter table public.delivery_drivers
  add column if not exists dispatch_priority integer not null default 0;

alter table public.delivery_drivers
  drop constraint if exists delivery_driver_dispatch_priority_check;
alter table public.delivery_drivers
  add constraint delivery_driver_dispatch_priority_check
  check (dispatch_priority in (-1,0,1));

create or replace function public.admin_delivery_set_driver_priority(p_driver_id uuid,p_priority integer)
returns jsonb
language plpgsql
security definer
set search_path=public
as $$
begin
  if not public.delivery_is_admin() then raise exception 'Admin permission required'; end if;
  if p_priority not in (-1,0,1) then raise exception 'Priority must be -1, 0 or 1'; end if;
  update public.delivery_drivers
  set dispatch_priority=p_priority,updated_at=now()
  where id=p_driver_id;
  if not found then raise exception 'Driver not found'; end if;
  return jsonb_build_object('ok',true,'driver_id',p_driver_id,'dispatch_priority',p_priority);
end;
$$;
revoke all on function public.admin_delivery_set_driver_priority(uuid,integer) from public;
grant execute on function public.admin_delivery_set_driver_priority(uuid,integer) to authenticated;

create or replace function public.admin_delivery_driver_priorities()
returns table(driver_id uuid,driver_name text,dispatch_priority integer)
language plpgsql security definer set search_path=public stable
as $$
begin
  if not public.delivery_is_admin() then raise exception 'Admin permission required'; end if;
  return query select d.id,coalesce(d.display_name,d.phone,'BINGO Driver'),d.dispatch_priority
  from public.delivery_drivers d order by coalesce(d.display_name,d.phone,'BINGO Driver');
end;
$$;
revoke all on function public.admin_delivery_driver_priorities() from public;
grant execute on function public.admin_delivery_driver_priorities() to authenticated;

-- Priority-aware Smart Dispatch. Priority is considered first, then distance/load/fairness.
create or replace function public.delivery_store_request_driver(p_order_id uuid)
returns uuid
language plpgsql security definer set search_path=public
as $$
declare
  v_assignment_id uuid; v_driver_id uuid; v_order_status text;
  v_store_lat numeric; v_store_lng numeric; v_active integer; v_max integer;
  v_distance numeric(10,2); v_reason text; v_priority integer;
begin
  if auth.uid() is null then raise exception 'Authentication required'; end if;
  perform pg_advisory_xact_lock(hashtextextended('bingo_delivery_smart_dispatch',0));

  select o.status,s.latitude,s.longitude into v_order_status,v_store_lat,v_store_lng
  from public.delivery_orders o join public.delivery_stores s on s.id=o.store_id
  where o.id=p_order_id and s.owner_id=auth.uid() and s.is_active=true for update of o;
  if not found then raise exception 'Order not found for this seller'; end if;

  select a.id into v_assignment_id from public.delivery_assignments a
  where a.order_id=p_order_id and a.status in ('offered','accepted','picked_up','on_delivery')
  order by a.offered_at desc limit 1;
  if v_assignment_id is not null then return v_assignment_id; end if;
  if v_order_status<>'ready' then raise exception 'Order must be ready before requesting a driver'; end if;

  select d.id,coalesce(loads.active_load,0),d.max_concurrent_orders,d.dispatch_priority,
    case when v_store_lat is not null and v_store_lng is not null and l.latitude is not null and l.longitude is not null and l.updated_at>=now()-interval '20 minutes'
      then (sqrt(power((l.latitude-v_store_lat)::numeric,2)+power((l.longitude-v_store_lng)::numeric,2))*111)::numeric(10,2) else null end
  into v_driver_id,v_active,v_max,v_priority,v_distance
  from public.delivery_drivers d
  left join public.delivery_driver_locations l on l.driver_id=d.id
  left join lateral (select count(*)::integer active_load from public.delivery_assignments a where a.driver_id=d.id and a.status in ('offered','accepted','picked_up','on_delivery')) loads on true
  where d.is_online=true and d.is_available=true and coalesce(loads.active_load,0)<d.max_concurrent_orders
  order by d.dispatch_priority desc,
    case when v_store_lat is not null and v_store_lng is not null and l.latitude is not null and l.longitude is not null and l.updated_at>=now()-interval '20 minutes'
      then power((l.latitude-v_store_lat)::numeric,2)+power((l.longitude-v_store_lng)::numeric,2) else 1000000000::numeric end asc,
    coalesce(loads.active_load,0) asc,d.total_deliveries asc,d.rating desc,d.updated_at asc
  limit 1 for update of d skip locked;

  if v_driver_id is null then raise exception 'No available BINGO driver right now'; end if;
  insert into public.delivery_assignments(order_id,driver_id,status,offered_at) values(p_order_id,v_driver_id,'offered',now()) returning id into v_assignment_id;
  update public.delivery_orders set status='assigned',updated_at=now() where id=p_order_id;
  update public.delivery_drivers set is_available=is_online and (v_active+1<v_max),updated_at=now() where id=v_driver_id;

  v_reason := 'BINGO Priority '||case v_priority when 1 then 'HIGH' when -1 then 'LOW' else 'NORMAL' end||' • '
    ||case when v_distance is not null then 'المسافة '||to_char(v_distance,'FM999990.00')||' كم • ' else '' end
    ||'الحمل '||v_active||'/'||v_max;
  insert into public.delivery_dispatch_log(assignment_id,order_id,driver_id,action,reason,distance_km,active_load,max_concurrent,created_by)
  values(v_assignment_id,p_order_id,v_driver_id,'auto_assign',v_reason,v_distance,v_active,v_max,auth.uid());
  return v_assignment_id;
end;
$$;
revoke all on function public.delivery_store_request_driver(uuid) from public;
grant execute on function public.delivery_store_request_driver(uuid) to authenticated;
