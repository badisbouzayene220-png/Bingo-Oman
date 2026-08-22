-- BINGO Oman — listing republish / bump rules
-- Free account: one free republish per listing lifetime.
-- Active monthly/yearly plan: one republish per listing every 24 hours.

begin;

alter table public.listings
  add column if not exists bumped_at timestamptz,
  add column if not exists free_republish_used boolean not null default false,
  add column if not exists last_republished_at timestamptz,
  add column if not exists republish_count integer not null default 0;

update public.listings
set bumped_at = coalesce(bumped_at, created_at)
where bumped_at is null;

create index if not exists listings_status_bumped_at_idx
  on public.listings(status, bumped_at desc);

create table if not exists public.listing_republish_subscriptions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  plan text not null check (plan in ('monthly','yearly')),
  status text not null default 'active' check (status in ('active','expired','cancelled','pending')),
  starts_at timestamptz not null default now(),
  ends_at timestamptz not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists listing_republish_subscriptions_user_active_idx
  on public.listing_republish_subscriptions(user_id,status,ends_at desc);

alter table public.listing_republish_subscriptions enable row level security;

drop policy if exists "Users can view own republish subscriptions" on public.listing_republish_subscriptions;
create policy "Users can view own republish subscriptions"
on public.listing_republish_subscriptions
for select
to authenticated
using (user_id = auth.uid());

-- No client INSERT/UPDATE/DELETE policy on subscriptions.
-- Paid subscriptions must later be activated only by a trusted payment/admin flow.

create or replace function public.user_republish_plan_status()
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user uuid := auth.uid();
  v_plan text;
  v_ends timestamptz;
begin
  if v_user is null then
    raise exception 'Authentication required';
  end if;

  select s.plan, s.ends_at
    into v_plan, v_ends
  from public.listing_republish_subscriptions s
  where s.user_id = v_user
    and s.status = 'active'
    and s.starts_at <= now()
    and s.ends_at > now()
  order by s.ends_at desc
  limit 1;

  return jsonb_build_object(
    'active', v_plan is not null,
    'plan', v_plan,
    'ends_at', v_ends
  );
end;
$$;

create or replace function public.user_republish_listing_status(p_listing_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user uuid := auth.uid();
  v_listing public.listings%rowtype;
  v_plan text;
  v_plan_ends timestamptz;
  v_next timestamptz;
  v_can boolean := false;
  v_reason text;
begin
  if v_user is null then
    raise exception 'Authentication required';
  end if;

  select * into v_listing
  from public.listings
  where id = p_listing_id and user_id = v_user;

  if not found then
    raise exception 'Listing not found or not owned by you';
  end if;

  if v_listing.status <> 'published' then
    return jsonb_build_object('can_republish',false,'reason','published_only','status',v_listing.status);
  end if;

  select s.plan, s.ends_at into v_plan, v_plan_ends
  from public.listing_republish_subscriptions s
  where s.user_id = v_user
    and s.status='active'
    and s.starts_at <= now()
    and s.ends_at > now()
  order by s.ends_at desc
  limit 1;

  if v_plan is not null then
    if v_listing.last_republished_at is null or v_listing.last_republished_at <= now() - interval '24 hours' then
      v_can := true;
      v_reason := 'subscription_available';
    else
      v_next := v_listing.last_republished_at + interval '24 hours';
      v_reason := 'daily_limit';
    end if;
  elsif not v_listing.free_republish_used then
    v_can := true;
    v_reason := 'free_available';
  else
    v_reason := 'subscription_required';
  end if;

  return jsonb_build_object(
    'can_republish',v_can,
    'reason',v_reason,
    'free_used',v_listing.free_republish_used,
    'last_republished_at',v_listing.last_republished_at,
    'next_available_at',v_next,
    'plan',v_plan,
    'plan_ends_at',v_plan_ends,
    'republish_count',v_listing.republish_count
  );
end;
$$;

create or replace function public.user_republish_listing(p_listing_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user uuid := auth.uid();
  v_listing public.listings%rowtype;
  v_plan text;
  v_next timestamptz;
begin
  if v_user is null then
    raise exception 'Authentication required';
  end if;

  select * into v_listing
  from public.listings
  where id = p_listing_id and user_id = v_user
  for update;

  if not found then
    raise exception 'Listing not found or not owned by you';
  end if;

  if v_listing.status <> 'published' then
    raise exception 'Only published listings can be republished';
  end if;

  select s.plan into v_plan
  from public.listing_republish_subscriptions s
  where s.user_id = v_user
    and s.status='active'
    and s.starts_at <= now()
    and s.ends_at > now()
  order by s.ends_at desc
  limit 1;

  if v_plan is not null then
    if v_listing.last_republished_at is not null
       and v_listing.last_republished_at > now() - interval '24 hours' then
      v_next := v_listing.last_republished_at + interval '24 hours';
      return jsonb_build_object('ok',false,'reason','daily_limit','next_available_at',v_next,'plan',v_plan);
    end if;

    update public.listings
    set bumped_at = now(),
        last_republished_at = now(),
        republish_count = coalesce(republish_count,0) + 1
    where id = p_listing_id;

    return jsonb_build_object('ok',true,'mode','subscription','plan',v_plan,'bumped_at',now());
  end if;

  if v_listing.free_republish_used then
    return jsonb_build_object('ok',false,'reason','subscription_required');
  end if;

  update public.listings
  set bumped_at = now(),
      last_republished_at = now(),
      free_republish_used = true,
      republish_count = coalesce(republish_count,0) + 1
  where id = p_listing_id;

  return jsonb_build_object('ok',true,'mode','free','bumped_at',now());
end;
$$;

revoke all on function public.user_republish_plan_status() from public, anon;
revoke all on function public.user_republish_listing_status(uuid) from public, anon;
revoke all on function public.user_republish_listing(uuid) from public, anon;
grant execute on function public.user_republish_plan_status() to authenticated;
grant execute on function public.user_republish_listing_status(uuid) to authenticated;
grant execute on function public.user_republish_listing(uuid) to authenticated;

commit;
