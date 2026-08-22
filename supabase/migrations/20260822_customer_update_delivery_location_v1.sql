-- BINGO Customer: update delivery location for an active order
create or replace function public.delivery_customer_update_location(
  p_order_id uuid,
  p_latitude numeric,
  p_longitude numeric
) returns boolean
language plpgsql
security definer
set search_path=public
as $$
declare
  v_uid uuid := auth.uid();
  v_count integer;
begin
  if v_uid is null then
    raise exception 'Authentication required';
  end if;
  if p_latitude is null or p_longitude is null
     or p_latitude < -90 or p_latitude > 90
     or p_longitude < -180 or p_longitude > 180 then
    raise exception 'Invalid location';
  end if;

  update public.delivery_orders
     set latitude = p_latitude,
         longitude = p_longitude,
         updated_at = now()
   where id = p_order_id
     and customer_id = v_uid
     and status not in ('delivered','cancelled');

  get diagnostics v_count = row_count;
  if v_count = 0 then
    raise exception 'Order not found, not owned by customer, or already closed';
  end if;

  return true;
end
$$;

revoke all on function public.delivery_customer_update_location(uuid,numeric,numeric) from public;
grant execute on function public.delivery_customer_update_location(uuid,numeric,numeric) to authenticated;
notify pgrst,'reload schema';