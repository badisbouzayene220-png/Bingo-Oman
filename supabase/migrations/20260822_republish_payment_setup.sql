-- BINGO Oman - Republish plan pricing + payment ledger
begin;

create table if not exists public.listing_plan_catalog (
  plan_code text primary key check (plan_code in ('monthly','yearly')),
  name_en text not null,
  name_ar text not null,
  duration_days integer not null check (duration_days > 0),
  amount_baisa integer,
  currency text not null default 'OMR',
  is_active boolean not null default false,
  updated_at timestamptz not null default now()
);

insert into public.listing_plan_catalog(plan_code,name_en,name_ar,duration_days,amount_baisa,currency,is_active)
values
 ('monthly','Monthly Republish','إعادة النشر الشهرية',30,null,'OMR',false),
 ('yearly','Yearly Republish','إعادة النشر السنوية',365,null,'OMR',false)
on conflict (plan_code) do nothing;

alter table public.listing_plan_catalog enable row level security;
drop policy if exists listing_plan_catalog_public_read on public.listing_plan_catalog;
create policy listing_plan_catalog_public_read on public.listing_plan_catalog for select using (true);

create table if not exists public.listing_plan_payments (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  plan_code text not null references public.listing_plan_catalog(plan_code),
  amount_baisa integer not null,
  currency text not null default 'OMR',
  provider text not null default 'thawani',
  provider_session_id text,
  provider_reference text,
  status text not null default 'created' check (status in ('created','pending','paid','failed','cancelled','refunded')),
  created_at timestamptz not null default now(),
  paid_at timestamptz,
  metadata jsonb not null default '{}'::jsonb
);
create index if not exists idx_listing_plan_payments_user on public.listing_plan_payments(user_id,created_at desc);
create unique index if not exists idx_listing_plan_payments_session on public.listing_plan_payments(provider_session_id) where provider_session_id is not null;
alter table public.listing_plan_payments enable row level security;
drop policy if exists listing_plan_payments_owner_read on public.listing_plan_payments;
create policy listing_plan_payments_owner_read on public.listing_plan_payments for select using (auth.uid()=user_id);
-- Writes are service-role / Edge Function only.

-- Ensure subscription table has provider/payment references if it already exists.
do $$ begin
  if to_regclass('public.listing_republish_subscriptions') is not null then
    alter table public.listing_republish_subscriptions add column if not exists payment_id uuid references public.listing_plan_payments(id);
    alter table public.listing_republish_subscriptions add column if not exists provider text;
  end if;
end $$;

commit;
