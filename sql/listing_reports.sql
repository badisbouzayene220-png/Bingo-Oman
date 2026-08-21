create table if not exists public.listing_reports (
  id uuid primary key default gen_random_uuid(),
  listing_id uuid not null references public.listings(id) on delete cascade,
  reporter_id uuid not null references auth.users(id) on delete cascade,
  reason text not null check (reason in ('spam','fraud','wrong_category','prohibited','misleading','other')),
  details text,
  status text not null default 'open' check (status in ('open','reviewing','resolved','dismissed')),
  created_at timestamptz not null default now(),
  unique(listing_id, reporter_id)
);

alter table public.listing_reports enable row level security;

drop policy if exists "Users can create own listing reports" on public.listing_reports;
create policy "Users can create own listing reports"
on public.listing_reports for insert
to authenticated
with check (auth.uid() = reporter_id);

drop policy if exists "Users can view own listing reports" on public.listing_reports;
create policy "Users can view own listing reports"
on public.listing_reports for select
to authenticated
using (auth.uid() = reporter_id);

create index if not exists listing_reports_listing_id_idx on public.listing_reports(listing_id);
create index if not exists listing_reports_status_idx on public.listing_reports(status);
