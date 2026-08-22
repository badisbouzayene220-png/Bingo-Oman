-- BINGO Oman - Featured / Top / Highlight listing infrastructure
begin;

alter table public.listings add column if not exists promotion_type text;
alter table public.listings add column if not exists promoted_at timestamptz;
alter table public.listings add column if not exists promotion_expires_at timestamptz;

create table if not exists public.listing_promotion_catalog (
  code text primary key check (code in ('featured','top','highlight')),
  name_en text not null,
  name_ar text not null,
  duration_days integer not null check (duration_days > 0),
  amount_baisa integer,
  currency text not null default 'OMR',
  is_active boolean not null default false,
  sort_order integer not null default 0,
  updated_at timestamptz not null default now()
);

insert into public.listing_promotion_catalog(code,name_en,name_ar,duration_days,amount_baisa,currency,is_active,sort_order)
values
 ('highlight','Highlight','تمييز الإعلان',7,null,'OMR',false,10),
 ('featured','Featured Ad','إعلان مميز',7,null,'OMR',false,20),
 ('top','Top Ad','إعلان في الأعلى',7,null,'OMR',false,30)
on conflict (code) do nothing;

alter table public.listing_promotion_catalog enable row level security;
drop policy if exists listing_promotion_catalog_public_read on public.listing_promotion_catalog;
create policy listing_promotion_catalog_public_read on public.listing_promotion_catalog for select using (true);

create table if not exists public.listing_promotion_orders (
 id uuid primary key default gen_random_uuid(),
 user_id uuid not null references auth.users(id) on delete cascade,
 listing_id uuid not null references public.listings(id) on delete cascade,
 promotion_code text not null references public.listing_promotion_catalog(code),
 amount_baisa integer,
 currency text not null default 'OMR',
 status text not null default 'draft' check (status in ('draft','pending','paid','activated','cancelled','expired')),
 starts_at timestamptz,
 ends_at timestamptz,
 payment_id uuid,
 created_at timestamptz not null default now()
);
create index if not exists idx_listing_promotion_orders_owner on public.listing_promotion_orders(user_id,created_at desc);
create index if not exists idx_listings_promotion_active on public.listings(promotion_expires_at desc) where promotion_type is not null;
alter table public.listing_promotion_orders enable row level security;
drop policy if exists listing_promotion_orders_owner_read on public.listing_promotion_orders;
create policy listing_promotion_orders_owner_read on public.listing_promotion_orders for select using (auth.uid()=user_id);

-- Preview/status helper. Promotion writes remain server/admin only until payments are enabled.
create or replace function public.my_listing_promotion_status(p_listing_id uuid)
returns table(promotion_type text, promoted_at timestamptz, promotion_expires_at timestamptz, is_active boolean)
language sql security definer set search_path=public as $$
 select l.promotion_type,l.promoted_at,l.promotion_expires_at,
        (l.promotion_type is not null and l.promotion_expires_at > now())
 from public.listings l
 where l.id=p_listing_id and l.user_id=auth.uid();
$$;
revoke all on function public.my_listing_promotion_status(uuid) from public;
grant execute on function public.my_listing_promotion_status(uuid) to authenticated;

commit;
