-- BINGO Oman - robust owner listing deletion
-- Owner-only. Attempts a real DELETE first.
-- If a foreign-key relationship prevents hard deletion, the listing is safely archived instead.
-- Marketplace already shows only published listings, so archived listings disappear publicly.

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

  -- Prefer a true delete. If all related FKs are ON DELETE CASCADE (or no children exist),
  -- this removes the listing completely.
  begin
    delete from public.listings
    where id = p_listing_id
      and user_id = v_user;

    get diagnostics v_deleted = row_count;
    if v_deleted = 1 then
      return true;
    end if;
  exception
    when foreign_key_violation then
      -- Some existing BINGO tables intentionally retain history. In that case,
      -- archive the listing so it disappears from public results and the user's active ads.
      null;
  end;

  update public.listings
     set status = 'archived',
         updated_at = now()
   where id = p_listing_id
     and user_id = v_user;

  get diagnostics v_deleted = row_count;
  return v_deleted = 1;
end;
$$;

revoke all on function public.user_delete_listing(uuid) from public, anon;
grant execute on function public.user_delete_listing(uuid) to authenticated;

commit;
