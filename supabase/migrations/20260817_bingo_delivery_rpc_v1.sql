-- Bingo Delivery RPC V1
-- Additive only. Does not modify ERP.

create or replace function public.delivery_create_order(
  p_store_id uuid,
  p_address text,
  p_latitude numeric,
  p_longitude numeric,
  p_distance_km numeric,
  p_items jsonb,
  p_delivery_fee numeric,
  p_driver_share numeric,
  p_bingo_share numeric,
  p_store_commission numeric default 0,
  p_payment_status text default 'pending',
  p_notes text default null
) returns uuid
language plpgsql security invoker set search_path = public
as $$
declare
  v_order_id uuid;
  v_subtotal numeric(12,3);
  v_total numeric(12,3);
  v_item jsonb;
begin
  if auth.uid() is null then raise exception 'Authentication required'; end if;
  if p_items is null or jsonb_typeof(p_items) <> 'array' or jsonb_array_length(p_items) = 0 then raise exception 'Order must contain items'; end if;
  if p_delivery_fee < 0 or p_driver_share < 0 or p_bingo_share < 0 or p_store_commission < 0 then raise exception 'Invalid delivery amounts'; end if;

  select coalesce(sum((x->>'quantity')::numeric * (x->>'unit_price')::numeric),0)::numeric(12,3)
  into v_subtotal
  from jsonb_array_elements(p_items) x;

  v_total := (v_subtotal + p_delivery_fee)::numeric(12,3);

  insert into public.delivery_orders(
    customer_id, store_id, status, payment_status, delivery_address,
    latitude, longitude, distance_km, subtotal, delivery_fee,
    driver_share, bingo_share, store_commission, total, notes
  ) values (
    auth.uid(), p_store_id, 'pending', p_payment_status, p_address,
    p_latitude, p_longitude, p_distance_km, v_subtotal, p_delivery_fee,
    p_driver_share, p_bingo_share, p_store_commission, v_total, p_notes
  ) returning id into v_order_id;

  for v_item in select * from jsonb_array_elements(p_items) loop
    insert into public.delivery_order_items(order_id, product_id, description, quantity, unit_price)
    values (
      v_order_id,
      nullif(v_item->>'product_id','')::uuid,
      coalesce(v_item->>'description','Item'),
      (v_item->>'quantity')::numeric,
      (v_item->>'unit_price')::numeric
    );
  end loop;

  return v_order_id;
end;
$$;

create or replace function public.delivery_set_driver_status(p_online boolean)
returns public.delivery_drivers
language plpgsql security invoker set search_path = public
as $$
declare v_driver public.delivery_drivers;
begin
  if auth.uid() is null then raise exception 'Authentication required'; end if;
  insert into public.delivery_drivers(id, is_online, is_available, updated_at)
  values(auth.uid(), p_online, p_online, now())
  on conflict (id) do update set is_online=p_online, is_available=p_online, updated_at=now()
  returning * into v_driver;
  return v_driver;
end;
$$;

create or replace function public.delivery_update_location(
  p_latitude numeric,
  p_longitude numeric,
  p_accuracy_m numeric default null,
  p_heading numeric default null,
  p_speed_kmh numeric default null
) returns void
language plpgsql security invoker set search_path = public
as $$
begin
  if auth.uid() is null then raise exception 'Authentication required'; end if;
  insert into public.delivery_drivers(id,is_online,is_available)
  values(auth.uid(),true,true)
  on conflict(id) do nothing;
  insert into public.delivery_driver_locations(driver_id,latitude,longitude,accuracy_m,heading,speed_kmh,updated_at)
  values(auth.uid(),p_latitude,p_longitude,p_accuracy_m,p_heading,p_speed_kmh,now())
  on conflict(driver_id) do update set latitude=excluded.latitude, longitude=excluded.longitude, accuracy_m=excluded.accuracy_m, heading=excluded.heading, speed_kmh=excluded.speed_kmh, updated_at=now();
end;
$$;

create or replace function public.delivery_driver_decide(p_assignment_id uuid, p_accept boolean)
returns public.delivery_assignments
language plpgsql security invoker set search_path = public
as $$
declare v_assignment public.delivery_assignments;
begin
  if auth.uid() is null then raise exception 'Authentication required'; end if;
  update public.delivery_assignments
  set status=case when p_accept then 'accepted' else 'rejected' end,
      accepted_at=case when p_accept then now() else accepted_at end,
      rejected_at=case when not p_accept then now() else rejected_at end
  where id=p_assignment_id and driver_id=auth.uid() and status='offered'
  returning * into v_assignment;
  if v_assignment.id is null then raise exception 'Assignment not available'; end if;
  if p_accept then
    update public.delivery_drivers set is_available=false, updated_at=now() where id=auth.uid();
    update public.delivery_orders set status='assigned', updated_at=now() where id=v_assignment.order_id;
  end if;
  return v_assignment;
end;
$$;

create or replace function public.delivery_set_assignment_status(p_assignment_id uuid, p_status text)
returns public.delivery_assignments
language plpgsql security invoker set search_path = public
as $$
declare v_assignment public.delivery_assignments;
begin
  if auth.uid() is null then raise exception 'Authentication required'; end if;
  if p_status not in ('picked_up','on_delivery','delivered','cancelled') then raise exception 'Invalid assignment status'; end if;
  update public.delivery_assignments
  set status=p_status,
      picked_up_at=case when p_status='picked_up' then coalesce(picked_up_at,now()) else picked_up_at end,
      delivered_at=case when p_status='delivered' then coalesce(delivered_at,now()) else delivered_at end
  where id=p_assignment_id and driver_id=auth.uid() and status in ('accepted','picked_up','on_delivery')
  returning * into v_assignment;
  if v_assignment.id is null then raise exception 'Assignment not available'; end if;
  update public.delivery_orders
  set status=case when p_status='picked_up' then 'picked_up' when p_status='on_delivery' then 'on_delivery' when p_status='delivered' then 'delivered' else 'cancelled' end,
      updated_at=now()
  where id=v_assignment.order_id;
  if p_status='delivered' then
    update public.delivery_drivers set is_available=true,total_deliveries=total_deliveries+1,updated_at=now() where id=auth.uid();
    insert into public.delivery_earnings(driver_id,order_id,amount,status)
    select auth.uid(),o.id,o.driver_share,'pending' from public.delivery_orders o where o.id=v_assignment.order_id
    on conflict(driver_id,order_id) do nothing;
  end if;
  return v_assignment;
end;
$$;

create or replace function public.delivery_assign_driver(p_order_id uuid, p_driver_id uuid)
returns uuid
language plpgsql security invoker set search_path = public
as $$
declare v_id uuid;
begin
  if auth.uid() is null then raise exception 'Authentication required'; end if;
  if not exists(select 1 from public.delivery_drivers where id=p_driver_id and is_online and is_available) then raise exception 'Driver is not available'; end if;
  insert into public.delivery_assignments(order_id,driver_id,status) values(p_order_id,p_driver_id,'offered') returning id into v_id;
  return v_id;
end;
$$;

revoke all on function public.delivery_create_order(uuid,text,numeric,numeric,numeric,jsonb,numeric,numeric,numeric,numeric,text,text) from public;
revoke all on function public.delivery_set_driver_status(boolean) from public;
revoke all on function public.delivery_update_location(numeric,numeric,numeric,numeric,numeric) from public;
revoke all on function public.delivery_driver_decide(uuid,boolean) from public;
revoke all on function public.delivery_set_assignment_status(uuid,text) from public;
revoke all on function public.delivery_assign_driver(uuid,uuid) from public;
grant execute on function public.delivery_create_order(uuid,text,numeric,numeric,numeric,jsonb,numeric,numeric,numeric,numeric,text,text) to authenticated;
grant execute on function public.delivery_set_driver_status(boolean) to authenticated;
grant execute on function public.delivery_update_location(numeric,numeric,numeric,numeric,numeric) to authenticated;
grant execute on function public.delivery_driver_decide(uuid,boolean) to authenticated;
grant execute on function public.delivery_set_assignment_status(uuid,text) to authenticated;
grant execute on function public.delivery_assign_driver(uuid,uuid) to authenticated;
