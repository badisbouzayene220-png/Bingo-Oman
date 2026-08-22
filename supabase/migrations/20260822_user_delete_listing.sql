-- BINGO Oman - robust owner listing deletion
-- Owner-only. Attempts a real DELETE first.
-- If a foreign-key relationship prevents hard deletion, the listing is safely archived instead.

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
  v_changed integer := 0;
begin
  if v_user is null then
    raise exception 'Authentication required';
  end if;

  select user_id into v_owner
  from public.listings
  where id = p_listing_id;

  if v_owner is null then
    return false;
  end if;

  if v_owner <> v_user then
    raise exception 'You can only delete your own listing';
  end if;

  -- Try physical deletion first. The nested exception rolls back this delete cleanly
  -- if any related foreign-key row prevents it.
  begin
    delete from public.listings
    where id = p_listing_id and user_id = v_user;
    get diagnostics v_changed = row_count;
    if v_changed = 1 then
      return true;
    end if;
  exception
    when foreign_key_violation then
      null;
  end;

  -- Safe fallback: hide the listing everywhere public while retaining linked history.
  update public.listings
  set status = 'archived'
  where id = p_listing_id and user_id = v_user;

  get diagnostics v_changed = row_count;
  return v_changed = 1;
end;
$$;

revoke all on function public.user_delete_listing(uuid) from public, anon;
grant execute on function public.user_delete_listing(uuid) to authenticated;

commit;
