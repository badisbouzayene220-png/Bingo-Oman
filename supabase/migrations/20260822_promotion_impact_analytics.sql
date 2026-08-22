-- BINGO Oman: promotion impact analytics
-- Adds before/after Promote view counts to owner analytics.
-- Republish event history is not stored in a dedicated table yet, so republish_count is safely returned as 0.
begin;

drop function if exists public.my_listing_analytics();

create function public.my_listing_analytics()
returns table(
  listing_id uuid,
  views_count bigint,
  contacts_count bigint,
  favorites_count bigint,
  promotion_type text,
  promoted_at timestamptz,
  promotion_expires_at timestamptz,
  views_before_promotion bigint,
  views_after_promotion bigint,
  republish_count bigint
)
language sql
security definer
set search_path=public
as $$
  select
    l.id,
    l.views_count,
    l.contacts_count,
    l.favorites_count,
    l.promotion_type,
    l.promoted_at,
    l.promotion_expires_at,
    case when l.promoted_at is null then 0::bigint else (
      select count(*)::bigint
      from public.listing_view_events e
      where e.listing_id=l.id and e.created_at < l.promoted_at
    ) end as views_before_promotion,
    case when l.promoted_at is null then 0::bigint else (
      select count(*)::bigint
      from public.listing_view_events e
      where e.listing_id=l.id and e.created_at >= l.promoted_at
    ) end as views_after_promotion,
    0::bigint as republish_count
  from public.listings l
  where l.user_id=auth.uid();
$$;

revoke all on function public.my_listing_analytics() from public;
grant execute on function public.my_listing_analytics() to authenticated;

commit;
