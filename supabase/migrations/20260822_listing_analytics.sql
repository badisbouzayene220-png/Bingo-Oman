-- BINGO Oman listing analytics
begin;

alter table public.listings add column if not exists views_count bigint not null default 0;
alter table public.listings add column if not exists contacts_count bigint not null default 0;
alter table public.listings add column if not exists favorites_count bigint not null default 0;

create table if not exists public.listing_view_events (
  id bigserial primary key,
  listing_id uuid not null references public.listings(id) on delete cascade,
  viewer_id uuid references auth.users(id) on delete set null,
  session_key text,
  created_at timestamptz not null default now()
);
create index if not exists idx_listing_view_events_listing_created on public.listing_view_events(listing_id,created_at desc);

alter table public.listing_view_events enable row level security;

create or replace function public.record_listing_view(p_listing_id uuid, p_session_key text default null)
returns boolean
language plpgsql
security definer
set search_path=public
as $$
declare
  v_owner uuid;
  v_recent boolean;
begin
  select user_id into v_owner from public.listings where id=p_listing_id and status='published';
  if v_owner is null then return false; end if;
  if auth.uid() is not null and auth.uid()=v_owner then return true; end if;

  select exists(
    select 1 from public.listing_view_events e
    where e.listing_id=p_listing_id
      and e.created_at > now()-interval '30 minutes'
      and (
        (auth.uid() is not null and e.viewer_id=auth.uid())
        or (auth.uid() is null and p_session_key is not null and e.session_key=p_session_key)
      )
  ) into v_recent;

  if v_recent then return true; end if;

  insert into public.listing_view_events(listing_id,viewer_id,session_key)
  values(p_listing_id,auth.uid(),left(coalesce(p_session_key,''),120));
  update public.listings set views_count=views_count+1 where id=p_listing_id;
  return true;
end;
$$;

create or replace function public.record_listing_contact(p_listing_id uuid)
returns boolean
language plpgsql
security definer
set search_path=public
as $$
begin
  if auth.uid() is null then return false; end if;
  update public.listings
     set contacts_count=contacts_count+1
   where id=p_listing_id and status='published' and user_id<>auth.uid();
  return found;
end;
$$;

create or replace function public.my_listing_analytics()
returns table(
  listing_id uuid,
  views_count bigint,
  contacts_count bigint,
  favorites_count bigint,
  promotion_type text,
  promoted_at timestamptz,
  promotion_expires_at timestamptz
)
language sql
security definer
set search_path=public
as $$
  select l.id,l.views_count,l.contacts_count,l.favorites_count,l.promotion_type,l.promoted_at,l.promotion_expires_at
  from public.listings l
  where l.user_id=auth.uid();
$$;

revoke all on function public.record_listing_view(uuid,text) from public;
revoke all on function public.record_listing_contact(uuid) from public;
revoke all on function public.my_listing_analytics() from public;
grant execute on function public.record_listing_view(uuid,text) to anon,authenticated;
grant execute on function public.record_listing_contact(uuid) to authenticated;
grant execute on function public.my_listing_analytics() to authenticated;

-- keep favorites_count synchronized when user_favorites exists
create or replace function public.sync_listing_favorites_count()
returns trigger language plpgsql security definer set search_path=public as $$
begin
  if tg_op='INSERT' then
    update public.listings set favorites_count=favorites_count+1 where id=new.listing_id;
    return new;
  elsif tg_op='DELETE' then
    update public.listings set favorites_count=greatest(favorites_count-1,0) where id=old.listing_id;
    return old;
  end if;
  return null;
end;
$$;

do $$ begin
  if to_regclass('public.user_favorites') is not null then
    drop trigger if exists trg_sync_listing_favorites_count on public.user_favorites;
    create trigger trg_sync_listing_favorites_count
    after insert or delete on public.user_favorites
    for each row execute function public.sync_listing_favorites_count();
    update public.listings l
      set favorites_count=(select count(*) from public.user_favorites f where f.listing_id=l.id);
  end if;
end $$;

commit;
