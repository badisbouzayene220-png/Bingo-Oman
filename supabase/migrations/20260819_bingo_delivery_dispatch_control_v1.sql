-- BINGO Delivery Dispatch Control V1
-- Adds per-driver capacity, dispatch audit reasons, admin manual reassignment,
-- and upgrades Smart Dispatch to respect configurable concurrent-order limits.

alter table public.delivery_drivers
  add column if not exists max_concurrent_orders integer not null default 1;

alter table public.delivery_drivers
  drop constraint if exists delivery_driver_max_concurrent_orders_check;
alter table public.delivery_drivers
  add constraint delivery_driver_max_concurrent_orders_check
  check (max_concurrent_orders between 1 and 5);

create table if not exists public.delivery_dispatch_log (
  id uuid primary key default gen_random_uuid(),
  assignment_id uuid references public.delivery_assignments(id) on delete set null,
  order_id uuid not null references public.delivery_orders(id) on delete cascade,
  driver_id uuid not null references public.delivery_drivers(id) on delete restrict,
  action text not null default 'auto_assign',
  reason text not null,
  distance_km numeric(10,2),
  active_load integer not null default 0,
  max_concurrent integer not null default 1,
  created_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  constraint delivery_dispatch_action_check check (action in ('auto_assign','manual_reassign'))
);

create index if not exists delivery_dispatch_log_order_idx
  on public.delivery_dispatch_log(order_id, created_at desc);
create index if not exists delivery_dispatch_log_driver_idx
  on public.delivery_dispatch_log(driver_id, created_at desc);

alter table public.delivery_dispatch_log enable row level security;

create or replace function public.delivery_driver_active_load(p_driver_id uuid)
returns integer
language sql
security definer
set search_path=public
stable
as $$
  select count(*)::integer
  from public.delivery_assignments a
  where a.driver_id=p_driver_id
    and a.status in ('offered','accepted','picked_up','on_delivery');
$$;

revoke all on function public.delivery_driver_active_load(uuid) from public;
grant execute on function public.delivery_driver_active_load(uuid) to authenticated;

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
  v_reason text;
begin
  if auth.uid() is null then raise exception 'Authentication required'; end if;

  perform pg_advisory_xact_lock(hashtextextended('bingo_delivery_smart_dispatch',0));

  select o.status,s.latitude,s.longitude
    into v_order_status,v_store_lat,v_store_lng
  from public.delivery_orders o
  join public.delivery_stores s on s.id=o.store_id
  where o.id=p_order_id
    and s.owner_id=auth.uid()
    and s.is_active=true
  for update of o;

  if not found then raise exception 'Order not found for this seller'; end if;

  select a.id into v_assignment_id
  from public.delivery_assignments a
  where a.order_id=p_order_id
    and a.status in ('offered','accepted','picked_up','on_delivery')
  order by a.offered_at desc limit 1;
  if v_assignment_id is not null then return v_assignment_id; end if;

  if v_order_status <> 'ready' then raise exception 'Order must be ready before requesting a driver'; end if;

  select d.id,
         coalesce(loads.active_load,0),
         d.max_concurrent_orders,
         case when v_store_lat is not null and v_store_lng is not null
                    and l.latitude is not null and l.longitude is not null
                    and l.updated_at >= now()-interval '20 minutes'
              then (sqrt(power((l.latitude-v_store_lat)::numeric,2)+power((l.longitude-v_store_lng)::numeric,2))*111)::numeric(10,2)
              else null end
    into v_driver_id,v_active,v_max,v_distance
  from public.delivery_drivers d
  left join public.delivery_driver_locations l on l.driver_id=d.id
  left join lateral (
    select count(*)::integer active_load
    from public.delivery_assignments a
    where a.driver_id=d.id
      and a.status in ('offered','accepted','picked_up','on_delivery')
  ) loads on true
  where d.is_online=true
    and d.is_available=true
    and coalesce(loads.active_load,0) < d.max_concurrent_orders
  order by
    case when v_store_lat is not null and v_store_lng is not null
              and l.latitude is not null and l.longitude is not null
              and l.updated_at >= now()-interval '20 minutes'
         then power((l.latitude-v_store_lat)::numeric,2)+power((l.longitude-v_store_lng)::numeric,2)
         else 1000000000::numeric end asc,
    coalesce(loads.active_load,0) asc,
    d.total_deliveries asc,
    d.rating desc,
    d.updated_at asc
  limit 1
  for update of d skip locked;

  if v_driver_id is null then raise exception 'No available BINGO driver right now'; end if;

  insert into public.delivery_assignments(order_id,driver_id,status,offered_at)
  values(p_order_id,v_driver_id,'offered',now())
  returning id into v_assignment_id;

  update public.delivery_orders set status='assigned',updated_at=now() where id=p_order_id;

  update public.delivery_drivers
  set is_available = is_online and (v_active+1 < v_max), updated_at=now()
  where id=v_driver_id;

  v_reason := case
    when v_distance is not null then
      'اختيار ذكي: أقرب مندوب متاح تقريبًا '||to_char(v_distance,'FM999990.00')||' كم، الحمل '||v_active||'/'||v_max
    else
      'اختيار ذكي: مندوب متاح بأقل حمل '||v_active||'/'||v_max||' مع موازنة التوصيلات والتقييم'
  end;

  insert into public.delivery_dispatch_log(assignment_id,order_id,driver_id,action,reason,distance_km,active_load,max_concurrent,created_by)
  values(v_assignment_id,p_order_id,v_driver_id,'auto_assign',v_reason,v_distance,v_active,v_max,auth.uid());

  return v_assignment_id;
end;
$$;

revoke all on function public.delivery_store_request_driver(uuid) from public;
grant execute on function public.delivery_store_request_driver(uuid) to authenticated;

create or replace function public.delivery_driver_decide(p_assignment_id uuid,p_accept boolean)
returns public.delivery_assignments
language plpgsql
security invoker
set search_path=public
as $$
declare
  v_assignment public.delivery_assignments;
  v_max integer;
  v_load integer;
begin
  if auth.uid() is null then raise exception 'Authentication required'; end if;

  update public.delivery_assignments
  set status=case when p_accept then 'accepted' else 'rejected' end,
      accepted_at=case when p_accept then now() else accepted_at end,
      rejected_at=case when not p_accept then now() else rejected_at end
  where id=p_assignment_id and driver_id=auth.uid() and status='offered'
  returning * into v_assignment;

  if v_assignment.id is null then raise exception 'Assignment not available'; end if;

  select max_concurrent_orders into v_max from public.delivery_drivers where id=auth.uid();
  select public.delivery_driver_active_load(auth.uid()) into v_load;

  update public.delivery_drivers
  set is_available=is_online and (v_load < coalesce(v_max,1)),updated_at=now()
  where id=auth.uid();

  if p_accept then
    update public.delivery_orders set status='assigned',updated_at=now() where id=v_assignment.order_id;
  else
    update public.delivery_orders
    set status='ready',updated_at=now()
    where id=v_assignment.order_id
      and not exists(select 1 from public.delivery_assignments a where a.order_id=v_assignment.order_id and a.status in ('offered','accepted','picked_up','on_delivery'));
  end if;

  return v_assignment;
end;
$$;

revoke all on function public.delivery_driver_decide(uuid,boolean) from public;
grant execute on function public.delivery_driver_decide(uuid,boolean) to authenticated;

create or replace function public.admin_delivery_set_driver_capacity(p_driver_id uuid,p_max integer)
returns jsonb
language plpgsql
security definer
set search_path=public
as $$
declare v_load integer;
begin
  if not public.delivery_is_admin() then raise exception 'Admin permission required'; end if;
  if p_max not between 1 and 5 then raise exception 'Max concurrent orders must be between 1 and 5'; end if;
  if not exists(select 1 from public.delivery_drivers where id=p_driver_id) then raise exception 'Driver not found'; end if;

  select public.delivery_driver_active_load(p_driver_id) into v_load;
  update public.delivery_drivers
  set max_concurrent_orders=p_max,
      is_available=is_online and (v_load < p_max),
      updated_at=now()
  where id=p_driver_id;

  return jsonb_build_object('ok',true,'driver_id',p_driver_id,'max_concurrent_orders',p_max,'active_load',v_load);
end;
$$;

revoke all on function public.admin_delivery_set_driver_capacity(uuid,integer) from public;
grant execute on function public.admin_delivery_set_driver_capacity(uuid,integer) to authenticated;

create or replace function public.admin_delivery_dispatch_board()
returns table(
  assignment_id uuid,
  order_id uuid,
  order_number text,
  assignment_status text,
  driver_id uuid,
  driver_name text,
  driver_online boolean,
  active_load integer,
  max_concurrent integer,
  dispatch_reason text,
  distance_km numeric,
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
  select a.id,a.order_id,o.order_number,a.status,a.driver_id,
         coalesce(d.display_name,d.phone,'BINGO Driver'),d.is_online,
         public.delivery_driver_active_load(d.id),d.max_concurrent_orders,
         coalesce(log.reason,'تعيين سابق بدون سجل سبب'),log.distance_km,a.offered_at
  from public.delivery_assignments a
  join public.delivery_orders o on o.id=a.order_id
  join public.delivery_drivers d on d.id=a.driver_id
  left join lateral (
    select l.reason,l.distance_km
    from public.delivery_dispatch_log l
    where l.assignment_id=a.id
    order by l.created_at desc limit 1
  ) log on true
  where a.status in ('offered','accepted','picked_up','on_delivery')
  order by a.offered_at desc
  limit 100;
end;
$$;

revoke all on function public.admin_delivery_dispatch_board() from public;
grant execute on function public.admin_delivery_dispatch_board() to authenticated;

create or replace function public.admin_delivery_reassign_order(p_assignment_id uuid,p_new_driver_id uuid)
returns uuid
language plpgsql
security definer
set search_path=public
as $$
declare
  v_old public.delivery_assignments;
  v_new_id uuid;
  v_new_load integer;
  v_new_max integer;
  v_distance numeric(10,2);
  v_order_lat numeric;
  v_order_lng numeric;
  v_old_max integer;
  v_old_load integer;
begin
  if not public.delivery_is_admin() then raise exception 'Admin permission required'; end if;
  perform pg_advisory_xact_lock(hashtextextended('bingo_delivery_smart_dispatch',0));

  select * into v_old from public.delivery_assignments
  where id=p_assignment_id and status in ('offered','accepted') for update;
  if v_old.id is null then raise exception 'Only offered or accepted orders can be reassigned'; end if;
  if v_old.driver_id=p_new_driver_id then raise exception 'Order is already assigned to this driver'; end if;

  select max_concurrent_orders into v_new_max
  from public.delivery_drivers
  where id=p_new_driver_id and is_online=true
  for update;
  if v_new_max is null then raise exception 'New driver must be online'; end if;

  select public.delivery_driver_active_load(p_new_driver_id) into v_new_load;
  if v_new_load >= v_new_max then raise exception 'New driver has reached maximum concurrent orders'; end if;

  update public.delivery_assignments
  set status='cancelled'
  where id=v_old.id;

  select max_concurrent_orders into v_old_max from public.delivery_drivers where id=v_old.driver_id;
  select public.delivery_driver_active_load(v_old.driver_id) into v_old_load;
  update public.delivery_drivers
  set is_available=is_online and (v_old_load < coalesce(v_old_max,1)),updated_at=now()
  where id=v_old.driver_id;

  insert into public.delivery_assignments(order_id,driver_id,status,offered_at)
  values(v_old.order_id,p_new_driver_id,'offered',now()) returning id into v_new_id;

  select o.latitude,o.longitude into v_order_lat,v_order_lng from public.delivery_orders o where o.id=v_old.order_id;
  select case when v_order_lat is not null and v_order_lng is not null and l.latitude is not null and l.longitude is not null
              then (sqrt(power((l.latitude-v_order_lat)::numeric,2)+power((l.longitude-v_order_lng)::numeric,2))*111)::numeric(10,2)
              else null end
    into v_distance
  from public.delivery_driver_locations l where l.driver_id=p_new_driver_id;

  update public.delivery_drivers
  set is_available=is_online and (v_new_load+1 < v_new_max),updated_at=now()
  where id=p_new_driver_id;

  update public.delivery_orders set status='assigned',updated_at=now() where id=v_old.order_id;

  insert into public.delivery_dispatch_log(assignment_id,order_id,driver_id,action,reason,distance_km,active_load,max_concurrent,created_by)
  values(v_new_id,v_old.order_id,p_new_driver_id,'manual_reassign',
         'إعادة تعيين يدوي بواسطة الإدارة • الحمل '||v_new_load||'/'||v_new_max,
         v_distance,v_new_load,v_new_max,auth.uid());

  return v_new_id;
end;
$$;

revoke all on function public.admin_delivery_reassign_order(uuid,uuid) from public;
grant execute on function public.admin_delivery_reassign_order(uuid,uuid) to authenticated;

-- Keep availability correct after BINGO Code completion when capacity is greater than one.
create or replace function public.delivery_confirm_with_code(p_assignment_id uuid,p_code text)
returns public.delivery_assignments
language plpgsql
security definer
set search_path=public
as $$
declare
  v_assignment public.delivery_assignments;
  v_expected text;
  v_max integer;
  v_load integer;
begin
  if auth.uid() is null then raise exception 'Authentication required'; end if;
  if p_code is null or p_code !~ '^[0-9]{4}$' then raise exception 'Invalid BINGO Code'; end if;

  select a.* into v_assignment from public.delivery_assignments a
  where a.id=p_assignment_id and a.driver_id=auth.uid() and a.status='on_delivery' for update;
  if v_assignment.id is null then raise exception 'Assignment not available for delivery confirmation'; end if;

  select c.code into v_expected from public.delivery_order_codes c where c.order_id=v_assignment.order_id for update;
  if v_expected is null or v_expected<>p_code then raise exception 'Incorrect BINGO Code'; end if;

  update public.delivery_assignments set status='delivered',delivered_at=coalesce(delivered_at,now()) where id=v_assignment.id returning * into v_assignment;
  update public.delivery_orders set status='delivered',updated_at=now() where id=v_assignment.order_id;
  update public.delivery_order_codes set verified_at=coalesce(verified_at,now()) where order_id=v_assignment.order_id;

  select max_concurrent_orders into v_max from public.delivery_drivers where id=auth.uid();
  select public.delivery_driver_active_load(auth.uid()) into v_load;
  update public.delivery_drivers
  set is_available=is_online and (v_load < coalesce(v_max,1)),total_deliveries=total_deliveries+1,updated_at=now()
  where id=auth.uid();

  insert into public.delivery_earnings(driver_id,order_id,amount,status)
  select auth.uid(),o.id,o.driver_share,'pending' from public.delivery_orders o where o.id=v_assignment.order_id
  on conflict(driver_id,order_id) do nothing;

  return v_assignment;
end;
$$;

revoke all on function public.delivery_confirm_with_code(uuid,text) from public;
grant execute on function public.delivery_confirm_with_code(uuid,text) to authenticated;
