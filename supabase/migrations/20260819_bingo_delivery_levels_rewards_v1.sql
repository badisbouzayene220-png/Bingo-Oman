-- BINGO Delivery Driver Levels & Rewards V1
-- Additive migration. Rewards are claims that require admin approval before payment.

create table if not exists public.delivery_driver_rewards (
  id uuid primary key default gen_random_uuid(),
  driver_id uuid not null references public.delivery_drivers(id) on delete cascade,
  reward_key text not null,
  reward_label text not null,
  period_start date not null,
  amount numeric(12,3) not null default 0,
  points integer not null default 0,
  status text not null default 'pending',
  created_at timestamptz not null default now(),
  approved_at timestamptz,
  paid_at timestamptz,
  constraint delivery_driver_reward_amount_nonnegative check (amount >= 0),
  constraint delivery_driver_reward_points_nonnegative check (points >= 0),
  constraint delivery_driver_reward_status check (status in ('pending','approved','paid','rejected')),
  unique(driver_id,reward_key,period_start)
);

alter table public.delivery_driver_rewards enable row level security;

drop policy if exists delivery_driver_rewards_self_read on public.delivery_driver_rewards;
create policy delivery_driver_rewards_self_read on public.delivery_driver_rewards
for select to authenticated using (driver_id = auth.uid());

create or replace function public.delivery_driver_level_name(p_total integer, p_rating numeric)
returns text language sql immutable as $$
  select case
    when coalesce(p_total,0) >= 150 and coalesce(p_rating,0) >= 4.85 then 'BINGO Elite'
    when coalesce(p_total,0) >= 75 and coalesce(p_rating,0) >= 4.70 then 'Gold'
    when coalesce(p_total,0) >= 25 and coalesce(p_rating,0) >= 4.50 then 'Silver'
    else 'Bronze'
  end;
$$;

create or replace function public.delivery_driver_sync_rewards()
returns jsonb
language plpgsql
security definer
set search_path=public
as $$
declare
  v_uid uuid:=auth.uid();
  v_today date:=current_date;
  v_week date:=(current_date - ((extract(isodow from current_date)::int)-1));
  v_day_count integer:=0;
  v_week_count integer:=0;
  v_inserted integer:=0;
begin
  if v_uid is null then raise exception 'Authentication required'; end if;
  if not exists(select 1 from public.delivery_drivers where id=v_uid) then raise exception 'Driver profile not found'; end if;

  select count(*)::integer into v_day_count
  from public.delivery_assignments
  where driver_id=v_uid and status='delivered' and delivered_at>=v_today::timestamptz and delivered_at<(v_today+1)::timestamptz;

  select count(*)::integer into v_week_count
  from public.delivery_assignments
  where driver_id=v_uid and status='delivered' and delivered_at>=v_week::timestamptz and delivered_at<(v_week+7)::timestamptz;

  if v_day_count>=8 then
    insert into public.delivery_driver_rewards(driver_id,reward_key,reward_label,period_start,amount,points)
    values(v_uid,'daily8','هدف اليوم: 8 توصيلات',v_today,1.500,80)
    on conflict(driver_id,reward_key,period_start) do nothing;
    if found then v_inserted:=v_inserted+1; end if;
  end if;

  if v_week_count>=40 then
    insert into public.delivery_driver_rewards(driver_id,reward_key,reward_label,period_start,amount,points)
    values(v_uid,'weekly40','هدف الأسبوع: 40 توصيل',v_week,5.000,300)
    on conflict(driver_id,reward_key,period_start) do nothing;
    if found then v_inserted:=v_inserted+1; end if;
  end if;

  return jsonb_build_object('ok',true,'daily_deliveries',v_day_count,'weekly_deliveries',v_week_count,'new_rewards',v_inserted);
end;
$$;

revoke all on function public.delivery_driver_sync_rewards() from public;
grant execute on function public.delivery_driver_sync_rewards() to authenticated;

create or replace function public.delivery_driver_rewards_stats()
returns jsonb
language plpgsql
security definer
set search_path=public
stable
as $$
declare
  v_uid uuid:=auth.uid();
  v_total integer:=0;
  v_rating numeric(3,2):=5.00;
  v_day integer:=0;
  v_week integer:=0;
  v_five integer:=0;
  v_streak integer:=0;
  v_level text;
  v_points integer:=0;
  v_pending numeric(12,3):=0;
  v_approved numeric(12,3):=0;
  v_rewards jsonb:='[]'::jsonb;
  r record;
begin
  if v_uid is null then raise exception 'Authentication required'; end if;
  select coalesce(total_deliveries,0),coalesce(rating,5.00) into v_total,v_rating from public.delivery_drivers where id=v_uid;
  if not found then raise exception 'Driver profile not found'; end if;

  select count(*)::integer into v_day from public.delivery_assignments where driver_id=v_uid and status='delivered' and delivered_at>=current_date::timestamptz;
  select count(*)::integer into v_week from public.delivery_assignments where driver_id=v_uid and status='delivered' and delivered_at>=(current_date-((extract(isodow from current_date)::int)-1))::timestamptz;
  select count(*) filter(where rating=5)::integer into v_five from public.delivery_ratings where driver_id=v_uid;

  for r in select rating from public.delivery_ratings where driver_id=v_uid order by created_at desc loop
    if r.rating=5 then v_streak:=v_streak+1; else exit; end if;
  end loop;

  v_level:=public.delivery_driver_level_name(v_total,v_rating);
  v_points:=v_total*10 + coalesce(v_five,0)*5 + v_streak*10;

  select coalesce(sum(amount) filter(where status='pending'),0),coalesce(sum(amount) filter(where status in('approved','paid')),0)
  into v_pending,v_approved from public.delivery_driver_rewards where driver_id=v_uid;

  select coalesce(jsonb_agg(jsonb_build_object('label',reward_label,'amount',amount,'points',points,'status',status,'period_start',period_start) order by created_at desc),'[]'::jsonb)
  into v_rewards from (select * from public.delivery_driver_rewards where driver_id=v_uid order by created_at desc limit 8) x;

  return jsonb_build_object(
    'level',v_level,'rating',v_rating,'total_deliveries',v_total,'points',v_points,
    'daily_deliveries',v_day,'daily_target',8,'weekly_deliveries',v_week,'weekly_target',40,
    'pending_bonus',v_pending,'approved_bonus',v_approved,'rewards',v_rewards
  );
end;
$$;

revoke all on function public.delivery_driver_rewards_stats() from public;
grant execute on function public.delivery_driver_rewards_stats() to authenticated;

create or replace function public.admin_delivery_rewards_leaderboard()
returns jsonb
language plpgsql
security definer
set search_path=public
stable
as $$
declare v_uid uuid:=auth.uid(); v_result jsonb;
begin
  if v_uid is null or not exists(select 1 from public.profiles where id=v_uid and role='admin' and is_active=true) then raise exception 'Admin access required'; end if;
  select coalesce(jsonb_agg(to_jsonb(q) order by q.rank_no),'[]'::jsonb) into v_result
  from (
    select row_number() over(order by d.total_deliveries desc,d.rating desc,d.created_at asc) as rank_no,
      d.id,d.display_name,d.rating,d.total_deliveries,
      public.delivery_driver_level_name(d.total_deliveries,d.rating) as level,
      (select count(*) from public.delivery_ratings r where r.driver_id=d.id and r.rating=5) as five_star_count,
      (select coalesce(sum(rr.amount),0) from public.delivery_driver_rewards rr where rr.driver_id=d.id and rr.status='pending') as pending_bonus
    from public.delivery_drivers d
  ) q;
  return v_result;
end;
$$;

revoke all on function public.admin_delivery_rewards_leaderboard() from public;
grant execute on function public.admin_delivery_rewards_leaderboard() to authenticated;

create or replace function public.admin_delivery_reward_set_status(p_reward_id uuid,p_status text)
returns jsonb
language plpgsql
security definer
set search_path=public
as $$
declare v_uid uuid:=auth.uid(); v_row public.delivery_driver_rewards;
begin
  if v_uid is null or not exists(select 1 from public.profiles where id=v_uid and role='admin' and is_active=true) then raise exception 'Admin access required'; end if;
  if p_status not in ('approved','paid','rejected') then raise exception 'Invalid reward status'; end if;
  update public.delivery_driver_rewards set status=p_status,
    approved_at=case when p_status in('approved','paid') then coalesce(approved_at,now()) else approved_at end,
    paid_at=case when p_status='paid' then now() else paid_at end
  where id=p_reward_id returning * into v_row;
  if v_row.id is null then raise exception 'Reward not found'; end if;
  return to_jsonb(v_row);
end;
$$;

revoke all on function public.admin_delivery_reward_set_status(uuid,text) from public;
grant execute on function public.admin_delivery_reward_set_status(uuid,text) to authenticated;
