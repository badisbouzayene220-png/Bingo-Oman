-- BINGO Points V1
-- Loyalty points for customers + performance points for drivers.

create table if not exists public.bingo_points_ledger (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  role text not null check (role in ('customer','driver')),
  order_id uuid references public.delivery_orders(id) on delete set null,
  points integer not null,
  reason text not null,
  created_at timestamptz not null default now()
);

create unique index if not exists bingo_points_once_per_order_reason
on public.bingo_points_ledger(user_id, order_id, reason)
where order_id is not null;

create index if not exists bingo_points_user_idx
on public.bingo_points_ledger(user_id, created_at desc);

alter table public.bingo_points_ledger enable row level security;

drop policy if exists bingo_points_self_read on public.bingo_points_ledger;
create policy bingo_points_self_read on public.bingo_points_ledger
for select to authenticated using (user_id = auth.uid());

create or replace function public.bingo_award_delivery_points()
returns trigger
language plpgsql
security definer
set search_path=public
as $$
declare
  v_customer_points integer;
  v_driver uuid;
begin
  if new.status='delivered' and old.status is distinct from 'delivered' then
    v_customer_points := 10 + least(50, greatest(0, floor(coalesce(new.subtotal,0))::integer));

    insert into public.bingo_points_ledger(user_id,role,order_id,points,reason)
    values(new.customer_id,'customer',new.id,v_customer_points,'delivery_completed')
    on conflict do nothing;

    select a.driver_id into v_driver
    from public.delivery_assignments a
    where a.order_id=new.id and a.status='delivered'
    order by a.delivered_at desc nulls last
    limit 1;

    if v_driver is not null then
      insert into public.bingo_points_ledger(user_id,role,order_id,points,reason)
      values(v_driver,'driver',new.id,5,'delivery_completed')
      on conflict do nothing;
    end if;
  end if;
  return new;
end;
$$;

drop trigger if exists trg_bingo_award_delivery_points on public.delivery_orders;
create trigger trg_bingo_award_delivery_points
after update of status on public.delivery_orders
for each row execute function public.bingo_award_delivery_points();

create or replace function public.bingo_award_rating_bonus()
returns trigger
language plpgsql
security definer
set search_path=public
as $$
declare v_bonus integer:=0;
begin
  v_bonus := case when new.rating=5 then 5 when new.rating=4 then 3 when new.rating=3 then 1 else 0 end;
  if v_bonus>0 then
    insert into public.bingo_points_ledger(user_id,role,order_id,points,reason)
    values(new.driver_id,'driver',new.order_id,v_bonus,'rating_bonus')
    on conflict do nothing;
  end if;
  return new;
end;
$$;

drop trigger if exists trg_bingo_award_rating_bonus on public.delivery_ratings;
create trigger trg_bingo_award_rating_bonus
after insert on public.delivery_ratings
for each row execute function public.bingo_award_rating_bonus();

create or replace function public.bingo_my_points_summary()
returns jsonb
language sql
security definer
set search_path=public
stable
as $$
select jsonb_build_object(
  'balance', coalesce(sum(points),0),
  'earned', coalesce(sum(points) filter(where points>0),0),
  'used', abs(coalesce(sum(points) filter(where points<0),0)),
  'recent', coalesce((select jsonb_agg(x) from (
    select points,reason,order_id,created_at
    from public.bingo_points_ledger
    where user_id=auth.uid()
    order by created_at desc limit 8
  ) x),'[]'::jsonb)
)
from public.bingo_points_ledger
where user_id=auth.uid();
$$;

revoke all on function public.bingo_my_points_summary() from public;
grant execute on function public.bingo_my_points_summary() to authenticated;

create or replace function public.bingo_order_points(p_order_id uuid)
returns jsonb
language plpgsql
security definer
set search_path=public
stable
as $$
declare v_uid uuid:=auth.uid(); v_points integer:=0; v_status text;
begin
  select status into v_status from public.delivery_orders where id=p_order_id and customer_id=v_uid;
  if v_status is null then raise exception 'Order not found'; end if;
  select coalesce(sum(points),0)::integer into v_points
  from public.bingo_points_ledger
  where user_id=v_uid and order_id=p_order_id and role='customer';
  return jsonb_build_object('order_id',p_order_id,'status',v_status,'points',v_points);
end;
$$;

revoke all on function public.bingo_order_points(uuid) from public;
grant execute on function public.bingo_order_points(uuid) to authenticated;
