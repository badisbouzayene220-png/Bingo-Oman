-- BINGO Driver Accept / Reject Compatibility V1
-- Restores the RPC names used by bingo-delivery-driver.html.
-- Delegates to the canonical delivery_driver_decide() logic.

create or replace function public.delivery_driver_accept(p_assignment_id uuid)
returns public.delivery_assignments
language sql
security definer
set search_path = public
as $$
  select public.delivery_driver_decide(p_assignment_id, true);
$$;

create or replace function public.delivery_driver_reject(p_assignment_id uuid)
returns public.delivery_assignments
language sql
security definer
set search_path = public
as $$
  select public.delivery_driver_decide(p_assignment_id, false);
$$;

revoke all on function public.delivery_driver_accept(uuid) from public;
revoke all on function public.delivery_driver_reject(uuid) from public;
grant execute on function public.delivery_driver_accept(uuid) to authenticated;
grant execute on function public.delivery_driver_reject(uuid) to authenticated;

notify pgrst, 'reload schema';
