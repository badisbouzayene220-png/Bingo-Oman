-- BINGO Oman: reliable public banner access
-- Run once in Supabase SQL Editor.

alter table if exists public.site_banners enable row level security;

drop policy if exists "Public can read published banners" on public.site_banners;
create policy "Public can read published banners"
on public.site_banners for select to anon, authenticated
using (
  status = 'published'
  and (starts_at is null or starts_at <= now())
  and (ends_at is null or ends_at >= now())
);

insert into storage.buckets (id,name,public)
values ('bingo-banners','bingo-banners',true)
on conflict (id) do update set public=true;

drop policy if exists "Public can view bingo banners" on storage.objects;
create policy "Public can view bingo banners"
on storage.objects for select to public
using (bucket_id='bingo-banners');

drop policy if exists "Authenticated can upload bingo banners" on storage.objects;
create policy "Authenticated can upload bingo banners"
on storage.objects for insert to authenticated
with check (bucket_id='bingo-banners');

drop policy if exists "Authenticated can update bingo banners" on storage.objects;
create policy "Authenticated can update bingo banners"
on storage.objects for update to authenticated
using (bucket_id='bingo-banners')
with check (bucket_id='bingo-banners');

-- Public read function. It returns only banner fields needed by the website.
drop function if exists public.get_public_site_banners();
create or replace function public.get_public_site_banners()
returns setof jsonb
language sql
security definer
stable
set search_path = public
as $$
  select jsonb_build_object(
    'id', id,
    'title', title,
    'media_type', media_type,
    'media_url', media_url,
    'link_url', link_url,
    'sort_order', sort_order,
    'created_at', created_at,
    'starts_at', starts_at,
    'ends_at', ends_at,
    'status', status
  )
  from public.site_banners
  where status='published'
    and (starts_at is null or starts_at <= now())
    and (ends_at is null or ends_at >= now())
  order by sort_order asc, created_at desc;
$$;

grant execute on function public.get_public_site_banners() to anon, authenticated;
