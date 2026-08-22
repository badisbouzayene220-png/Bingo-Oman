-- BINGO Oman — 3 free active listings per account.
-- Active means draft, pending or published. Archived/rejected/sold do not use a slot.
-- Additional active listings require one unused paid credit.

begin;

create table if not exists public.listing_payment_credits (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  status text not null default 'paid' check (status in ('paid','used','cancelled','refunded')),
  listing_id uuid null references public.listings(id) on delete set null,
  amount numeric(12,3) null,
  currency text not null default 'OMR',
  payment_reference text null,
  created_at timestamptz not null default now(),
  used_at timestamptz null
);

create index if not exists idx_listing_payment_credits_user_status
  on public.listing_payment_credits(user_id,status);

alter table public.listing_payment_credits enable row level security;

drop policy if exists listing_payment_credits_select_own on public.listing_payment_credits;
create policy listing_payment_credits_select_own
on public.listing_payment_credits
for select
to authenticated
using (user_id = auth.uid());

-- No client INSERT/UPDATE/DELETE policies intentionally.
-- Credits are created only by a trusted payment/admin process.

create or replace function public.get_my_listing_quota()
returns table (
  free_limit integer,
  active_count bigint,
  free_remaining bigint,
  paid_credits bigint,
  requires_payment boolean
)
language sql
security definer
set search_path = public
stable
as $$
  with s as (
    select count(*)::bigint as active_count
    from public.listings
    where user_id = auth.uid()
      and status::text in ('draft','pending','published')
  ), c as (
    select count(*)::bigint as paid_credits
    from public.listing_payment_credits
    where user_id = auth.uid()
      and status = 'paid'
      and listing_id is null
  )
  select
    3::integer,
    s.active_count,
    greatest(3 - s.active_count, 0)::bigint,
    c.paid_credits,
    (s.active_count >= 3 and c.paid_credits = 0)
  from s,c;
$$;

revoke all on function public.get_my_listing_quota() from public, anon;
grant execute on function public.get_my_listing_quota() to authenticated;

create or replace function public.enforce_listing_free_quota()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_active bigint;
  v_credit uuid;
begin
  if new.user_id is null then
    raise exception 'Listing owner is required';
  end if;

  if auth.uid() is not null and new.user_id <> auth.uid() then
    raise exception 'You can only create listings for your own account';
  end if;

  -- Serialize listing creation for this account to prevent two simultaneous
  -- requests from both claiming the final free slot.
  perform pg_advisory_xact_lock(hashtext(new.user_id::text));

  if new.status::text not in ('draft','pending','published') then
    return new;
  end if;

  select count(*)
    into v_active
  from public.listings
  where user_id = new.user_id
    and status::text in ('draft','pending','published');

  if v_active < 3 then
    return new;
  end if;

  select id
    into v_credit
  from public.listing_payment_credits
  where user_id = new.user_id
    and status = 'paid'
    and listing_id is null
  order by created_at
  limit 1
  for update skip locked;

  if v_credit is null then
    raise exception using
      errcode = 'P0001',
      message = 'PAID_LISTING_REQUIRED';
  end if;

  update public.listing_payment_credits
  set status = 'used',
      listing_id = new.id,
      used_at = now()
  where id = v_credit;

  return new;
end;
$$;

drop trigger if exists trg_enforce_listing_free_quota on public.listings;
create trigger trg_enforce_listing_free_quota
before insert on public.listings
for each row
execute function public.enforce_listing_free_quota();

commit;
