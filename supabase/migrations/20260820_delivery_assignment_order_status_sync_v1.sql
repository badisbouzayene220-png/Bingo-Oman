-- BINGO Delivery — Assignment/Order status sync V1
-- Ensures the customer tracking status always follows the active driver assignment.

create or replace function public.delivery_sync_order_status_from_assignment()
returns trigger
language plpgsql
security definer
set search_path=public
as $$
begin
  if new.status in ('accepted','picked_up','on_delivery','delivered','cancelled') then
    update public.delivery_orders
    set status = case
      when new.status='accepted' then 'assigned'
      when new.status='picked_up' then 'picked_up'
      when new.status='on_delivery' then 'on_delivery'
      when new.status='delivered' then 'delivered'
      when new.status='cancelled' then 'cancelled'
      else status
    end,
    updated_at=now()
    where id=new.order_id
      and status is distinct from case
        when new.status='accepted' then 'assigned'
        when new.status='picked_up' then 'picked_up'
        when new.status='on_delivery' then 'on_delivery'
        when new.status='delivered' then 'delivered'
        when new.status='cancelled' then 'cancelled'
        else status
      end;
  end if;
  return new;
end;
$$;

drop trigger if exists trg_delivery_assignment_order_status_sync on public.delivery_assignments;
create trigger trg_delivery_assignment_order_status_sync
after insert or update of status on public.delivery_assignments
for each row
execute function public.delivery_sync_order_status_from_assignment();

-- Repair existing active mismatches immediately.
with latest_assignment as (
  select distinct on (x.order_id)
    x.order_id,
    x.status
  from public.delivery_assignments x
  where x.status in ('accepted','picked_up','on_delivery','delivered','cancelled')
  order by x.order_id,
           coalesce(x.delivered_at,x.picked_up_at,x.accepted_at,x.offered_at) desc nulls last,
           x.id desc
), mapped as (
  select
    la.order_id,
    case
      when la.status='accepted' then 'assigned'
      when la.status='picked_up' then 'picked_up'
      when la.status='on_delivery' then 'on_delivery'
      when la.status='delivered' then 'delivered'
      when la.status='cancelled' then 'cancelled'
    end as order_status
  from latest_assignment la
)
update public.delivery_orders o
set status=m.order_status,
    updated_at=now()
from mapped m
where o.id=m.order_id
  and o.status is distinct from m.order_status;
