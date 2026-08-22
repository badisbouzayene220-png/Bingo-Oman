-- BINGO Oman: secure admin controls for listing promotions
begin;

create or replace function public.admin_set_listing_promotion(
  p_listing_id uuid,
  p_promotion_type text,
  p_duration_days integer default 7
)
returns boolean
language plpgsql
security definer
set search_path=public
as $$
declare
  v_role text;
begin
  select role::text into v_role from public.profiles where id=auth.uid();
  if coalesce(v_role,'') <> 'admin' then raise exception 'Admin access required'; end if;
  if p_promotion_type not in ('highlight','featured','top') then raise exception 'Invalid promotion type'; end if;
  if p_duration_days not in (1,3,7,14,30) then raise exception 'Invalid promotion duration'; end if;

  update public.listings
     set promotion_type=p_promotion_type,
         promoted_at=now(),
         promotion_expires_at=now()+make_interval(days=>p_duration_days)
   where id=p_listing_id and status='published';
  if not found then raise exception 'Published listing not found'; end if;
  return true;
end;
$$;

create or replace function public.admin_clear_listing_promotion(p_listing_id uuid)
returns boolean
language plpgsql
security definer
set search_path=public
as $$
declare v_role text;
begin
  select role::text into v_role from public.profiles where id=auth.uid();
  if coalesce(v_role,'') <> 'admin' then raise exception 'Admin access required'; end if;
  update public.listings set promotion_type=null,promoted_at=null,promotion_expires_at=null where id=p_listing_id;
  return found;
end;
$$;

revoke all on function public.admin_set_listing_promotion(uuid,text,integer) from public;
revoke all on function public.admin_clear_listing_promotion(uuid) from public;
grant execute on function public.admin_set_listing_promotion(uuid,text,integer) to authenticated;
grant execute on function public.admin_clear_listing_promotion(uuid) to authenticated;

commit;
