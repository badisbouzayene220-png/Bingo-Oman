-- BINGO Delivery - Driver picked-up compatibility RPC
-- Restores the RPC expected by the current Driver Journey UI.

create or replace function public.delivery_driver_mark_picked_up(p_assignment_id uuid)
returns public.delivery_assignments
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_assignment public.delivery_assignments;
begin
  if v_uid is null then
    raise exception 'Authentication required';
  end if;

  update public.delivery_assignments a
     set status = 'picked_up'
   where a.id = p_assignment_id
     and a.driver_id = v_uid
     and a.status = 'accepted'
  returning a.* into v_assignment;

  if v_assignment.id is null then
    raise exception 'Assignment not available for pickup';
  end if;

  -- Keep the delivery order synchronized with the driver journey.
  update public.delivery_orders o
     set status = 'picked_up',
         updated_at = now()
   where o.id = v_assignment.order_id;

  return v_assignment;
end;
$$;

revoke all on function public.delivery_driver_mark_picked_up(uuid) from public;
grant execute on function public.delivery_driver_mark_picked_up(uuid) to authenticated;

notify pgrst, 'reload schema';
