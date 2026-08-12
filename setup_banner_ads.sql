-- BINGO Oman — Top Banner Ads
-- Run once in Supabase SQL Editor.

create table if not exists public.site_banners (
  id uuid primary key default gen_random_uuid(),
  title text not null,
  subtitle text,
  button_text text default 'Shop Now',
  media_type text not null default 'image' check (media_type in ('image','video')),
  media_url text not null,
  link_url text,
  status text not null default 'draft' check (status in ('draft','published','paused')),
  sort_order integer not null default 0,
  starts_at timestamptz,
  ends_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.site_banners add column if not exists subtitle text;
alter table public.site_banners add column if not exists button_text text default 'Shop Now';
alter table public.site_banners enable row level security;

drop policy if exists "Public can view published banners" on public.site_banners;
create policy "Public can view published banners"
on public.site_banners for select
using (
  status = 'published'
  and (starts_at is null or starts_at <= now())
  and (ends_at is null or ends_at >= now())
);

create or replace function public.is_bingo_admin()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.profiles
    where id = auth.uid() and role = 'admin'
  );
$$;

create or replace function public.admin_list_site_banners()
returns setof public.site_banners
language sql
security definer
set search_path = public
as $$
  select * from public.site_banners
  where public.is_bingo_admin()
  order by sort_order asc, created_at desc;
$$;

create or replace function public.admin_upsert_site_banner(p_banner jsonb)
returns public.site_banners
language plpgsql
security definer
set search_path = public
as $$
declare r public.site_banners;
begin
  if not public.is_bingo_admin() then raise exception 'Admin access required'; end if;
  insert into public.site_banners
    (id,title,subtitle,button_text,media_type,media_url,link_url,status,sort_order,starts_at,ends_at,updated_at)
  values (
    coalesce(nullif(p_banner->>'id','')::uuid,gen_random_uuid()),
    p_banner->>'title',
    nullif(p_banner->>'subtitle',''),
    coalesce(nullif(p_banner->>'button_text',''),'Shop Now'),
    coalesce(p_banner->>'media_type','image'),
    p_banner->>'media_url',
    nullif(p_banner->>'link_url',''),
    coalesce(p_banner->>'status','draft'),
    coalesce((p_banner->>'sort_order')::integer,0),
    nullif(p_banner->>'starts_at','')::timestamptz,
    nullif(p_banner->>'ends_at','')::timestamptz,
    now()
  )
  on conflict (id) do update set
    title=excluded.title, subtitle=excluded.subtitle, button_text=excluded.button_text, media_type=excluded.media_type, media_url=excluded.media_url,
    link_url=excluded.link_url, status=excluded.status, sort_order=excluded.sort_order,
    starts_at=excluded.starts_at, ends_at=excluded.ends_at, updated_at=now()
  returning * into r;
  return r;
end $$;

create or replace function public.admin_delete_site_banner(p_id uuid)
returns boolean
language plpgsql
security definer
set search_path = public
as $$
begin
  if not public.is_bingo_admin() then raise exception 'Admin access required'; end if;
  delete from public.site_banners where id=p_id;
  return true;
end $$;

-- Public media bucket for banner delivery. Upload/delete remains admin-only via storage policies.
insert into storage.buckets (id, name, public)
values ('bingo-banners','bingo-banners',true)
on conflict (id) do update set public=true;

drop policy if exists "Bingo admins upload banners" on storage.objects;
create policy "Bingo admins upload banners"
on storage.objects for insert to authenticated
with check (
  bucket_id='bingo-banners' and public.is_bingo_admin()
);

drop policy if exists "Bingo admins update banners" on storage.objects;
create policy "Bingo admins update banners"
on storage.objects for update to authenticated
using (bucket_id='bingo-banners' and public.is_bingo_admin())
with check (bucket_id='bingo-banners' and public.is_bingo_admin());

drop policy if exists "Bingo admins delete banners" on storage.objects;
create policy "Bingo admins delete banners"
on storage.objects for delete to authenticated
using (bucket_id='bingo-banners' and public.is_bingo_admin());

drop policy if exists "Anyone can view banner media" on storage.objects;
create policy "Anyone can view banner media"
on storage.objects for select to public
using (bucket_id='bingo-banners');
