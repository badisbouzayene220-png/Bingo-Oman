-- BINGO Oman security hardening v2
-- Corrected for listings.user_id ownership column.
-- Safe to run even if v1 partially executed.

-- 1) Banner storage: public read, ADMIN-ONLY writes.
insert into storage.buckets (id,name,public)
values ('bingo-banners','bingo-banners',true)
on conflict (id) do update set public=true;

drop policy if exists "Authenticated can upload bingo banners" on storage.objects;
drop policy if exists "Authenticated can update bingo banners" on storage.objects;
drop policy if exists "Admin can upload bingo banners" on storage.objects;
drop policy if exists "Admin can update bingo banners" on storage.objects;
drop policy if exists "Admin can delete bingo banners" on storage.objects;

create policy "Admin can upload bingo banners"
on storage.objects for insert to authenticated
with check (
  bucket_id='bingo-banners'
  and exists (
    select 1 from public.profiles p
    where p.id = auth.uid() and p.role='admin' and p.is_active=true
  )
);

create policy "Admin can update bingo banners"
on storage.objects for update to authenticated
using (
  bucket_id='bingo-banners'
  and exists (
    select 1 from public.profiles p
    where p.id = auth.uid() and p.role='admin' and p.is_active=true
  )
)
with check (
  bucket_id='bingo-banners'
  and exists (
    select 1 from public.profiles p
    where p.id = auth.uid() and p.role='admin' and p.is_active=true
  )
);

create policy "Admin can delete bingo banners"
on storage.objects for delete to authenticated
using (
  bucket_id='bingo-banners'
  and exists (
    select 1 from public.profiles p
    where p.id = auth.uid() and p.role='admin' and p.is_active=true
  )
);

-- 2) Listing reports: reporter may create/read own report, cannot report own listing.
alter table if exists public.listing_reports enable row level security;

drop policy if exists "Users can create own listing reports" on public.listing_reports;
create policy "Users can create own listing reports"
on public.listing_reports for insert to authenticated
with check (
  auth.uid() = reporter_id
  and exists (
    select 1 from public.listings l
    where l.id = listing_id
      and l.user_id <> auth.uid()
  )
);

drop policy if exists "Users can view own listing reports" on public.listing_reports;
create policy "Users can view own listing reports"
on public.listing_reports for select to authenticated
using (auth.uid() = reporter_id);

-- Active admins can review and update moderation status.
drop policy if exists "Admins can view listing reports" on public.listing_reports;
create policy "Admins can view listing reports"
on public.listing_reports for select to authenticated
using (
  exists (
    select 1 from public.profiles p
    where p.id = auth.uid() and p.role='admin' and p.is_active=true
  )
);

drop policy if exists "Admins can update listing reports" on public.listing_reports;
create policy "Admins can update listing reports"
on public.listing_reports for update to authenticated
using (
  exists (
    select 1 from public.profiles p
    where p.id = auth.uid() and p.role='admin' and p.is_active=true
  )
)
with check (
  exists (
    select 1 from public.profiles p
    where p.id = auth.uid() and p.role='admin' and p.is_active=true
  )
);

-- 3) Public banner RPC: explicit execution grants only.
do $$
begin
  if to_regprocedure('public.get_public_site_banners()') is not null then
    execute 'revoke all on function public.get_public_site_banners() from public';
    execute 'grant execute on function public.get_public_site_banners() to anon, authenticated';
  end if;
end $$;
