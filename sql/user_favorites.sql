-- BINGO Oman — User favorites
-- Run once in Supabase SQL Editor.

create table if not exists public.user_favorites (
  user_id uuid not null references auth.users(id) on delete cascade,
  listing_id uuid not null references public.listings(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (user_id, listing_id)
);

alter table public.user_favorites enable row level security;

create policy "Users can read own favorites"
on public.user_favorites
for select
using (auth.uid() = user_id);

create policy "Users can add own favorites"
on public.user_favorites
for insert
with check (auth.uid() = user_id);

create policy "Users can remove own favorites"
on public.user_favorites
for delete
using (auth.uid() = user_id);

create index if not exists user_favorites_created_at_idx
  on public.user_favorites (user_id, created_at desc);
