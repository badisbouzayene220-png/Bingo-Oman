-- BINGO Delivery: secure handoff code + driver active context
-- Additive migration, except delivery_set_assignment_status is tightened so
-- a driver cannot mark an order delivered without delivery_confirm_with_code().

create table if not exists public.delivery_order_codes (
  order_id uuid primary key references public.delivery_orders(id) on delete cascade,
  code text not null,
  created_at timestamptz not null default now(),
  verified_at timestamptz,
  constraint delivery_order_code_four_digits check (code ~ '^[0-9]{4}$')
);

alter table public.delivery_order_codes enable row level security;

create or replace function public.delivery_make_bingo_code()
returns text
language sql
volatile
set search_path = public
as $$
  select lpad((floor(random()*10000))::int::text,4,'0');
$$;

create or replace function public.delivery_seed_bingo_code()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.delivery_order_codes(order_id,code)
  values(new.id, public.delivery_make_bingo_code())
  on conflict(order_id) do nothing;
  return new;
end;
$$;

drop trigger if exists trg_delivery_seed_bingo_code on public.delivery_orders;
create trigger trg_delivery_seed_bingo_code
after insert on public.delivery_orders
for each row execute function public.delivery_seed_bingo_code();

insert into public.delivery_order_codes(order_id,code)
select o.id, public.delivery_make_bingo_code()
from public.delivery_orders o
left join public.delivery_order_codes c on c.order_id=o.id
where c.order_id is null and o.status <> 'delivered';

create or replace function public.delivery_customer_bingo_code(p_order_id uuid)
returns text
language plpgsql
security definer
set search_path = public
as $$
declare v_code text;
begin
  if auth.uid() is null then raise exception 'Authentication required'; end if;
  select c.code into v_code
  from public.delivery_order_codes c
  join public.delivery_orders o on o.id=c.order_id
  where o.id=p_order_id
    and o.customer_id=auth.uid()
    and o.status in ('assigned','picked_up','on_delivery');
  if v_code is null then raise exception 'BINGO Code not available'; end if;
  return v_code;
end;
$$;

create or replace function public.delivery_driver_active_context()
returns table(
  assignment_id uuid,
  order_id uuid,
  order_number text,
  assignment_status text,
  latitude numeric,
  longitude numeric,
  delivery_address text,
  driver_share numeric
)
language sql
security definer
set search_path = public
as $$
  select a.id,a.order_id,o.order_number,a.status,o.latitude,o.longitude,o.delivery_address,o.driver_share
  from public.delivery_assignments a
  join public.delivery_orders o on o.id=a.order_id
  where a.driver_id=auth.uid()
    and a.status in ('accepted','picked_up','on_delivery')
  order by a.offered_at desc
  limit 1;
$$;

create or replace function public.delivery_confirm_with_code(p_assignment_id uuid,p_code text)
returns public.delivery_assignments
language plpgsql
security definer
set search_path = public
as $$
declare
  v_assignment public.delivery_assignments;
  v_expected text;
begin
  if auth.uid() is null then raise exception 'Authentication required'; end if;
  if p_code is null or p_code !~ '^[0-9]{4}$' then raise exception 'Invalid BINGO Code'; end if;

  select a.* into v_assignment
  from public.delivery_assignments a
  where a.id=p_assignment_id
    and a.driver_id=auth.uid()
    and a.status='on_delivery'
  for update;

  if v_assignment.id is null then raise exception 'Assignment not available for delivery confirmation'; end if;

  select c.code into v_expected
  from public.delivery_order_codes c
  where c.order_id=v_assignment.order_id
  for update;

  if v_expected is null or v_expected <> p_code then
    raise exception 'Incorrect BINGO Code';
  end if;

  update public.delivery_assignments
  set status='delivered', delivered_at=coalesce(delivered_at,now())
  where id=v_assignment.id
  returning * into v_assignment;

  update public.delivery_orders
  set status='delivered', updated_at=now()
  where id=v_assignment.order_id;

  update public.delivery_order_codes
  set verified_at=coalesce(verified_at,now())
  where order_id=v_assignment.order_id;

  update public.delivery_drivers
  set is_available=true,total_deliveries=total_deliveries+1,updated_at=now()
  where id=auth.uid();

  insert into public.delivery_earnings(driver_id,order_id,amount,status)
  select auth.uid(),o.id,o.driver_share,'pending'
  from public.delivery_orders o where o.id=v_assignment.order_id
  on conflict(driver_id,order_id) do nothing;

  return v_assignment;
end;
$$;

-- Tighten the old status RPC: delivered must go through BINGO Code verification.
create or replace function public.delivery_set_assignment_status(p_assignment_id uuid, p_status text)
returns public.delivery_assignments
language plpgsql security invoker set search_path = public
as $$
declare v_assignment public.delivery_assignments;
begin
  if auth.uid() is null then raise exception 'Authentication required'; end if;
  if p_status not in ('picked_up','on_delivery','cancelled') then raise exception 'Use BINGO Code to confirm delivery'; end if;
  update public.delivery_assignments
  set status=p_status,
      picked_up_at=case when p_status='picked_up' then coalesce(picked_up_at,now()) else picked_up_at end
  where id=p_assignment_id and driver_id=auth.uid() and status in ('accepted','picked_up','on_delivery')
  returning * into v_assignment;
  if v_assignment.id is null then raise exception 'Assignment not available'; end if;
  update public.delivery_orders
  set status=case when p_status='picked_up' then 'picked_up' when p_status='on_delivery' then 'on_delivery' else 'cancelled' end,
      updated_at=now()
  where id=v_assignment.order_id;
  return v_assignment;
end;
$$;

revoke all on function public.delivery_customer_bingo_code(uuid) from public;
revoke all on function public.delivery_driver_active_context() from public;
revoke all on function public.delivery_confirm_with_code(uuid,text) from public;
grant execute on function public.delivery_customer_bingo_code(uuid) to authenticated;
grant execute on function public.delivery_driver_active_context() to authenticated;
grant execute on function public.delivery_confirm_with_code(uuid,text) to authenticated;
