-- BINGO Oman — final RLS cleanup
-- Conservative cleanup only: remove duplicate listing policies and scope favorites to authenticated users.
begin;

-- LISTINGS: keep one policy per operation.
-- Keep:
--   bingo_listings_select
--   bingo_listings_insert_own
--   bingo_listings_update_own_or_admin
--   bingo_listings_delete_own_or_admin

drop policy if exists "published_listings_read" on public.listings;
drop policy if exists "users_create_listing" on public.listings;
drop policy if exists "users_update_own_listing" on public.listings;
drop policy if exists "users_delete_own_listing" on public.listings;

-- USER FAVORITES: same ownership checks, but authenticated role explicitly.
drop policy if exists "Users can add own favorites" on public.user_favorites;
drop policy if exists "Users can read own favorites" on public.user_favorites;
drop policy if exists "Users can remove own favorites" on public.user_favorites;

create policy "Users can add own favorites"
on public.user_favorites
for insert
to authenticated
with check (auth.uid() = user_id);

create policy "Users can read own favorites"
on public.user_favorites
for select
to authenticated
using (auth.uid() = user_id);

create policy "Users can remove own favorites"
on public.user_favorites
for delete
to authenticated
using (auth.uid() = user_id);

commit;