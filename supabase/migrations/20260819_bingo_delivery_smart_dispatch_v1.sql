-- BINGO Delivery Smart Dispatch V1
-- Prevents one driver from receiving multiple simultaneous offers and balances work across available drivers.

-- Recreate the seller request RPC with deterministic, serialized smart dispatch.
drop function if exists public.delivery_store_request_driver(uuid);

create function public.delivery_store_request_driver(p_order_id uuid)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_assignment_id uuid;
  v_driver_id uuid;
  v_order_status text;
  v_store_id uuid;
  v_store_lat numeric;
  v_store_lng numeric;
begin
  if auth.uid() is null then
    raise exception 'Authentication required';
  end if;

  -- Serialize dispatch requests so two orders requested at the same moment cannot choose the same driver.
  perform pg_advisory_xact_lock(hashtextextended('bingo_delivery_smart_dispatch', 0));

  -- The caller must own the store for this order. Lock the order while dispatching it.
  select o.status, o.store_id, s.latitude, s.longitude
    into v_order_status, v_store_id, v_store_lat, v_store_lng
  from public.delivery_orders o
  join public.delivery_stores s on s.id = o.store_id
  where o.id = p_order_id
    and s.owner_id = auth.uid()
    and s.is_active = true
  for update of o;

  if not found then
    raise exception 'Order not found for this seller';
  end if;

  -- Idempotent double-click protection: return the existing active offer/assignment.
  select a.id into v_assignment_id
  from public.delivery_assignments a
  where a.order_id = p_order_id
    and a.status in ('offered','accepted','picked_up','on_delivery')
  order by a.offered_at desc
  limit 1;

  if v_assignment_id is not null then
    return v_assignment_id;
  end if;

  if v_order_status <> 'ready' then
    raise exception 'Order must be ready before requesting a driver';
  end if;

  -- Smart selection rules:
  -- 1) online + available only
  -- 2) exclude any driver who already has an offered/accepted/active delivery
  -- 3) prefer a recent GPS position closer to the store
  -- 4) then balance by fewer completed deliveries and longest waiting availability
  select d.id
    into v_driver_id
  from public.delivery_drivers d
  left join public.delivery_driver_locations l on l.driver_id = d.id
  where d.is_online = true
    and d.is_available = true
    and not exists (
      select 1
      from public.delivery_assignments busy
      where busy.driver_id = d.id
        and busy.status in ('offered','accepted','picked_up','on_delivery')
    )
  order by
    case
      when v_store_lat is not null
       and v_store_lng is not null
       and l.latitude is not null
       and l.longitude is not null
       and l.updated_at >= now() - interval '20 minutes'
      then power((l.latitude - v_store_lat)::numeric, 2)
         + power((l.longitude - v_store_lng)::numeric, 2)
      else 1000000000::numeric
    end asc,
    d.total_deliveries asc,
    d.updated_at asc,
    d.created_at asc
  limit 1
  for update of d skip locked;

  if v_driver_id is null then
    raise exception 'No available BINGO driver right now';
  end if;

  insert into public.delivery_assignments(order_id, driver_id, status, offered_at)
  values(p_order_id, v_driver_id, 'offered', now())
  returning id into v_assignment_id;

  update public.delivery_orders
  set status = 'assigned', updated_at = now()
  where id = p_order_id;

  return v_assignment_id;
end;
$$;

revoke all on function public.delivery_store_request_driver(uuid) from public;
grant execute on function public.delivery_store_request_driver(uuid) to authenticated;

-- If a driver rejects an offer, release the order back to READY so the seller can request another driver.
create or replace function public.delivery_driver_decide(p_assignment_id uuid, p_accept boolean)
returns public.delivery_assignments
language plpgsql
security invoker
set search_path = public
as $$
declare
  v_assignment public.delivery_assignments;
begin
  if auth.uid() is null then raise exception 'Authentication required'; end if;

  update public.delivery_assignments
  set status = case when p_accept then 'accepted' else 'rejected' end,
      accepted_at = case when p_accept then now() else accepted_at end,
      rejected_at = case when not p_accept then now() else rejected_at end
  where id = p_assignment_id
    and driver_id = auth.uid()
    and status = 'offered'
  returning * into v_assignment;

  if v_assignment.id is null then
    raise exception 'Assignment not available';
  end if;

  if p_accept then
    update public.delivery_drivers
    set is_available = false, updated_at = now()
    where id = auth.uid();

    update public.delivery_orders
    set status = 'assigned', updated_at = now()
    where id = v_assignment.order_id;
  else
    update public.delivery_orders
    set status = 'ready', updated_at = now()
    where id = v_assignment.order_id
      and not exists (
        select 1 from public.delivery_assignments a
        where a.order_id = v_assignment.order_id
          and a.status in ('offered','accepted','picked_up','on_delivery')
      );
  end if;

  return v_assignment;
end;
$$;

revoke all on function public.delivery_driver_decide(uuid,boolean) from public;
grant execute on function public.delivery_driver_decide(uuid,boolean) to authenticated;
