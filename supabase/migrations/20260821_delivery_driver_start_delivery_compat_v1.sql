-- BINGO Delivery - Driver start-delivery compatibility RPC
-- Restores the RPC expected by the current Driver Journey UI.

create or replace function public.delivery_driver_start_delivery(p_assignment_id uuid)
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
     set status = 'on_delivery'
   where a.id = p_assignment_id
     and a.driver_id = v_uid
     and a.status = 'picked_up'
  returning a.* into v_assignment;

  if v_assignment.id is null then
    raise exception 'Assignment not available to start delivery';
  end if;

  update public.delivery_orders o
     set status = 'on_delivery',
         updated_at = now()
   where o.id = v_assignment.order_id;

  return v_assignment;
end;
$$;

revoke all on function public.delivery_driver_start_delivery(uuid) from public;
grant execute on function public.delivery_driver_start_delivery(uuid) to authenticated;

notify pgrst, 'reload schema';
