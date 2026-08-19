-- BINGO Delivery Admin Rewards + Driver Management V1
-- Additive migration. Admin actions are protected by profiles.role='admin'.

create table if not exists public.delivery_driver_notifications (
  id uuid primary key default gen_random_uuid(),
  driver_id uuid not null references public.delivery_drivers(id) on delete cascade,
  kind text not null default 'info',
  title text not null,
  message text,
  is_read boolean not null default false,
  created_at timestamptz not null default now(),
  constraint delivery_driver_notification_kind check (kind in ('info','reward','achievement','system'))
);

create index if not exists delivery_driver_notifications_driver_idx
  on public.delivery_driver_notifications(driver_id, created_at desc);

alter table public.delivery_driver_notifications enable row level security;

drop policy if exists delivery_driver_notifications_self_read on public.delivery_driver_notifications;
create policy delivery_driver_notifications_self_read
on public.delivery_driver_notifications for select to authenticated
using (driver_id = auth.uid());

drop policy if exists delivery_driver_notifications_self_update on public.delivery_driver_notifications;
create policy delivery_driver_notifications_self_update
on public.delivery_driver_notifications for update to authenticated
using (driver_id = auth.uid()) with check (driver_id = auth.uid());

create or replace function public.delivery_is_admin()
returns boolean
language sql
security definer
set search_path=public
stable
as $$
  select exists(
    select 1 from public.profiles p
    where p.id=auth.uid() and p.role='admin' and p.is_active=true
  );
$$;

revoke all on function public.delivery_is_admin() from public;
grant execute on function public.delivery_is_admin() to authenticated;

create or replace function public.admin_delivery_add_driver(
  p_email text,
  p_display_name text default null,
  p_phone text default null,
  p_vehicle_type text default null
)
returns jsonb
language plpgsql
security definer
set search_path=public,auth
as $$
declare
  v_user_id uuid;
  v_email text:=lower(trim(coalesce(p_email,'')));
begin
  if not public.delivery_is_admin() then raise exception 'Admin permission required'; end if;
  if v_email='' then raise exception 'Email is required'; end if;

  select u.id into v_user_id
  from auth.users u
  where lower(u.email)=v_email
  order by u.created_at desc
  limit 1;

  if v_user_id is null then
    raise exception 'User account not found. Create the Auth account first.';
  end if;

  insert into public.delivery_drivers(id,display_name,phone,vehicle_type,is_online,is_available,rating,total_deliveries,updated_at)
  values(v_user_id,nullif(trim(coalesce(p_display_name,'')),''),nullif(trim(coalesce(p_phone,'')),''),nullif(trim(coalesce(p_vehicle_type,'')),''),false,false,5.00,0,now())
  on conflict(id) do update set
    display_name=coalesce(excluded.display_name,public.delivery_drivers.display_name),
    phone=coalesce(excluded.phone,public.delivery_drivers.phone),
    vehicle_type=coalesce(excluded.vehicle_type,public.delivery_drivers.vehicle_type),
    updated_at=now();

  return jsonb_build_object('ok',true,'driver_id',v_user_id,'email',v_email);
end;
$$;

revoke all on function public.admin_delivery_add_driver(text,text,text,text) from public;
grant execute on function public.admin_delivery_add_driver(text,text,text,text) to authenticated;

create or replace function public.admin_delivery_rewards_list()
returns table(
  reward_id uuid,
  driver_id uuid,
  driver_name text,
  reward_key text,
  reward_label text,
  period_start date,
  amount numeric,
  points integer,
  status text,
  created_at timestamptz,
  approved_at timestamptz,
  paid_at timestamptz
)
language plpgsql
security definer
set search_path=public
stable
as $$
begin
  if not public.delivery_is_admin() then raise exception 'Admin permission required'; end if;
  return query
  select r.id,r.driver_id,coalesce(d.display_name,'BINGO Driver'),r.reward_key,r.reward_label,r.period_start,
         r.amount,r.points,r.status,r.created_at,r.approved_at,r.paid_at
  from public.delivery_driver_rewards r
  join public.delivery_drivers d on d.id=r.driver_id
  order by case r.status when 'pending' then 0 when 'approved' then 1 when 'paid' then 2 else 3 end,
           r.created_at desc
  limit 250;
end;
$$;

revoke all on function public.admin_delivery_rewards_list() from public;
grant execute on function public.admin_delivery_rewards_list() to authenticated;

create or replace function public.admin_delivery_reward_set_status(
  p_reward_id uuid,
  p_status text
)
returns jsonb
language plpgsql
security definer
set search_path=public
as $$
declare
  v_driver uuid;
  v_label text;
  v_amount numeric(12,3);
  v_old text;
  v_title text;
  v_message text;
begin
  if not public.delivery_is_admin() then raise exception 'Admin permission required'; end if;
  if p_status not in ('pending','approved','paid','rejected') then raise exception 'Invalid reward status'; end if;

  select r.driver_id,r.reward_label,r.amount,r.status into v_driver,v_label,v_amount,v_old
  from public.delivery_driver_rewards r where r.id=p_reward_id for update;
  if v_driver is null then raise exception 'Reward not found'; end if;

  update public.delivery_driver_rewards set
    status=p_status,
    approved_at=case when p_status in ('approved','paid') then coalesce(approved_at,now()) else approved_at end,
    paid_at=case when p_status='paid' then coalesce(paid_at,now()) else paid_at end
  where id=p_reward_id;

  if p_status is distinct from v_old and p_status in ('approved','paid','rejected') then
    if p_status='approved' then
      v_title:='🎁 تم اعتماد BINGO Bonus';
      v_message:=v_label||' • '||to_char(v_amount,'FM999999990.000')||' OMR';
    elsif p_status='paid' then
      v_title:='✅ تم دفع BINGO Bonus';
      v_message:=v_label||' • '||to_char(v_amount,'FM999999990.000')||' OMR';
    else
      v_title:='تحديث BINGO Bonus';
      v_message:='لم يتم اعتماد '||v_label||' هذه المرة.';
    end if;
    insert into public.delivery_driver_notifications(driver_id,kind,title,message)
    values(v_driver,'reward',v_title,v_message);
  end if;

  return jsonb_build_object('ok',true,'reward_id',p_reward_id,'status',p_status);
end;
$$;

revoke all on function public.admin_delivery_reward_set_status(uuid,text) from public;
grant execute on function public.admin_delivery_reward_set_status(uuid,text) to authenticated;

create or replace function public.delivery_driver_notifications_list()
returns table(id uuid,kind text,title text,message text,is_read boolean,created_at timestamptz)
language sql
security definer
set search_path=public
stable
as $$
  select n.id,n.kind,n.title,n.message,n.is_read,n.created_at
  from public.delivery_driver_notifications n
  where n.driver_id=auth.uid()
  order by n.created_at desc
  limit 30;
$$;

revoke all on function public.delivery_driver_notifications_list() from public;
grant execute on function public.delivery_driver_notifications_list() to authenticated;

create or replace function public.delivery_driver_notification_read(p_id uuid)
returns boolean
language plpgsql
security definer
set search_path=public
as $$
begin
  update public.delivery_driver_notifications set is_read=true
  where id=p_id and driver_id=auth.uid();
  return found;
end;
$$;

revoke all on function public.delivery_driver_notification_read(uuid) from public;
grant execute on function public.delivery_driver_notification_read(uuid) to authenticated;
