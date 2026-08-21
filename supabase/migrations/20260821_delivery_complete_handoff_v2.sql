-- BINGO Delivery: final handoff v2
-- Makes BINGO Code confirmation idempotent and guarantees the driver is released once.

create or replace function public.delivery_confirm_with_code(p_assignment_id uuid,p_code text)
returns public.delivery_assignments
language plpgsql
security definer
set search_path = public
as $$
declare
  v_assignment public.delivery_assignments;
  v_expected text;
  v_was_delivered boolean := false;
begin
  if auth.uid() is null then raise exception 'Authentication required'; end if;
  if p_code is null or p_code !~ '^[0-9]{4}$' then raise exception 'Invalid BINGO Code'; end if;

  select a.* into v_assignment
  from public.delivery_assignments a
  where a.id=p_assignment_id
    and a.driver_id=auth.uid()
    and a.status in ('on_delivery','delivered')
  for update;

  if v_assignment.id is null then
    raise exception 'Assignment not available for delivery confirmation';
  end if;

  select c.code into v_expected
  from public.delivery_order_codes c
  where c.order_id=v_assignment.order_id
  for update;

  if v_expected is null or v_expected <> p_code then
    raise exception 'Incorrect BINGO Code';
  end if;

  v_was_delivered := (v_assignment.status='delivered');

  if not v_was_delivered then
    update public.delivery_assignments
       set status='delivered',
           delivered_at=coalesce(delivered_at,now())
     where id=v_assignment.id
     returning * into v_assignment;

    update public.delivery_orders
       set status='delivered', updated_at=now()
     where id=v_assignment.order_id;

    update public.delivery_order_codes
       set verified_at=coalesce(verified_at,now())
     where order_id=v_assignment.order_id;

    -- Release driver and count this delivery exactly once.
    update public.delivery_drivers
       set is_available=true,
           total_deliveries=coalesce(total_deliveries,0)+1,
           updated_at=now()
     where id=auth.uid();

    -- Unique(driver_id,order_id) prevents duplicate earnings.
    insert into public.delivery_earnings(driver_id,order_id,amount,status)
    select auth.uid(),o.id,o.driver_share,'pending'
      from public.delivery_orders o
     where o.id=v_assignment.order_id
    on conflict(driver_id,order_id) do nothing;
  end if;

  return v_assignment;
end;
$$;

revoke all on function public.delivery_confirm_with_code(uuid,text) from public;
grant execute on function public.delivery_confirm_with_code(uuid,text) to authenticated;

notify pgrst, 'reload schema';
