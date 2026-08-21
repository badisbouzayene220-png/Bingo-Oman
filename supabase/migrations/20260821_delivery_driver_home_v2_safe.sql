-- BINGO Driver Home V2 Safe
-- Restores the driver dashboard feed: profile, offers, active deliveries and earnings.
-- Uses auth.uid() and SECURITY DEFINER so dashboard reads are not blocked by table RLS.

create or replace function public.delivery_driver_home()
returns jsonb
language plpgsql
security definer
set search_path = public
stable
as $$
declare
  v_uid uuid := auth.uid();
  v_driver jsonb;
  v_offers jsonb := '[]'::jsonb;
  v_active jsonb := '[]'::jsonb;
  v_today numeric := 0;
  v_week numeric := 0;
begin
  if v_uid is null then
    raise exception 'Authentication required';
  end if;

  select to_jsonb(d)
    into v_driver
  from public.delivery_drivers d
  where d.id = v_uid;

  if v_driver is null then
    raise exception 'Driver profile not found';
  end if;

  select coalesce(jsonb_agg(x.row_json order by x.offered_at desc), '[]'::jsonb)
    into v_offers
  from (
    select a.offered_at,
           to_jsonb(a) || jsonb_build_object('order', to_jsonb(o)) as row_json
    from public.delivery_assignments a
    join public.delivery_orders o on o.id = a.order_id
    where a.driver_id = v_uid
      and a.status = 'offered'
  ) x;

  select coalesce(jsonb_agg(x.row_json order by x.sort_at desc), '[]'::jsonb)
    into v_active
  from (
    select coalesce(a.accepted_at,a.offered_at) as sort_at,
           to_jsonb(a) || jsonb_build_object('order', to_jsonb(o)) as row_json
    from public.delivery_assignments a
    join public.delivery_orders o on o.id = a.order_id
    where a.driver_id = v_uid
      and a.status in ('accepted','picked_up','on_delivery')
  ) x;

  if to_regclass('public.delivery_earnings') is not null then
    select coalesce(sum(e.amount) filter (
             where e.created_at >= date_trunc('day', now())
           ),0),
           coalesce(sum(e.amount) filter (
             where e.created_at >= date_trunc('week', now())
           ),0)
      into v_today, v_week
    from public.delivery_earnings e
    where e.driver_id = v_uid;
  end if;

  return jsonb_build_object(
    'driver', v_driver,
    'offers', v_offers,
    'active', v_active,
    'today_earnings', coalesce(v_today,0),
    'week_earnings', coalesce(v_week,0)
  );
end;
$$;

revoke all on function public.delivery_driver_home() from public;
grant execute on function public.delivery_driver_home() to authenticated;

notify pgrst, 'reload schema';
