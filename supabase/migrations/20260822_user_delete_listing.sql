-- BINGO Oman - user-owned listing deletion
-- Allows only the authenticated owner to delete their own listing,
-- regardless of listing status (pending/published/rejected/etc.).

begin;

create or replace function public.user_delete_listing(p_listing_id uuid)
returns boolean
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user uuid := auth.uid();
  v_owner uuid;
  v_deleted integer := 0;
begin
  if v_user is null then
    raise exception 'Authentication required';
  end if;

  select user_id
    into v_owner
  from public.listings
  where id = p_listing_id;

  if v_owner is null then
    return false;
  end if;

  if v_owner <> v_user then
    raise exception 'You can only delete your own listing';
  end if;

  -- Remove messages tied to conversations for this listing first, if these tables exist.
  if to_regclass('public.messages') is not null
     and to_regclass('public.conversations') is not null then
    execute 'delete from public.messages where conversation_id in (select id from public.conversations where listing_id = $1)'
      using p_listing_id;
  end if;

  if to_regclass('public.conversations') is not null then
    execute 'delete from public.conversations where listing_id = $1'
      using p_listing_id;
  end if;

  if to_regclass('public.user_favorites') is not null then
    execute 'delete from public.user_favorites where listing_id = $1'
      using p_listing_id;
  end if;

  if to_regclass('public.listing_images') is not null then
    execute 'delete from public.listing_images where listing_id = $1'
      using p_listing_id;
  end if;

  -- Optional engagement tables: clean only when present.
  if to_regclass('public.listing_views') is not null then
    execute 'delete from public.listing_views where listing_id = $1'
      using p_listing_id;
  end if;

  if to_regclass('public.listing_likes') is not null then
    execute 'delete from public.listing_likes where listing_id = $1'
      using p_listing_id;
  end if;

  delete from public.listings
  where id = p_listing_id
    and user_id = v_user;

  get diagnostics v_deleted = row_count;
  return v_deleted = 1;
end;
$$;

revoke all on function public.user_delete_listing(uuid) from public, anon;
grant execute on function public.user_delete_listing(uuid) to authenticated;

commit;
