-- BINGO Oman: admin marketplace performance analytics
begin;

create or replace function public.admin_listing_performance(p_days integer default 30)
returns table(
  listing_id uuid,
  title text,
  status text,
  views_count bigint,
  favorites_count bigint,
  contacts_count bigint,
  republish_count bigint,
  promotion_type text,
  promoted_at timestamptz,
  promotion_expires_at timestamptz,
  recent_views bigint,
  engagement_score numeric
)
language plpgsql
security definer
set search_path=public
as $$
declare v_role text;
begin
  select role::text into v_role from public.profiles where id=auth.uid();
  if coalesce(v_role,'') <> 'admin' then raise exception 'Admin access required'; end if;

  return query
  select
    l.id::uuid as listing_id,
    l.title::text as title,
    l.status::text as status,
    coalesce(l.views_count,0)::bigint as views_count,
    coalesce(l.favorites_count,0)::bigint as favorites_count,
    coalesce(l.contacts_count,0)::bigint as contacts_count,
    coalesce(l.republish_count,0)::bigint as republish_count,
    l.promotion_type::text as promotion_type,
    l.promoted_at::timestamptz as promoted_at,
    l.promotion_expires_at::timestamptz as promotion_expires_at,
    (
      select count(*)::bigint
      from public.listing_view_events e
      where e.listing_id=l.id
        and (p_days<=0 or e.created_at>=now()-make_interval(days=>p_days))
    )::bigint as recent_views,
    (
      coalesce(l.views_count,0)::numeric
      + coalesce(l.favorites_count,0)::numeric * 5
      + coalesce(l.contacts_count,0)::numeric * 10
    )::numeric as engagement_score
  from public.listings l
  order by engagement_score desc, coalesce(l.views_count,0) desc
  limit 100;
end;
$$;

revoke all on function public.admin_listing_performance(integer) from public;
grant execute on function public.admin_listing_performance(integer) to authenticated;

commit;