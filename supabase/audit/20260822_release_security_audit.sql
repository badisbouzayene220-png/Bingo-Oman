-- BINGO Oman — final release security audit (READ ONLY)
-- This file changes nothing. Run it in Supabase SQL Editor and inspect results.

-- 1) Sensitive RPC ownership / security-definer / execute grants
select
  n.nspname as schema_name,
  p.proname as function_name,
  pg_get_function_identity_arguments(p.oid) as arguments,
  p.prosecdef as security_definer,
  pg_get_userbyid(p.proowner) as owner,
  has_function_privilege('anon',p.oid,'EXECUTE') as anon_can_execute,
  has_function_privilege('authenticated',p.oid,'EXECUTE') as authenticated_can_execute
from pg_proc p
join pg_namespace n on n.oid=p.pronamespace
where n.nspname='public'
  and p.proname in (
    'admin_set_listing_promotion',
    'admin_clear_listing_promotion',
    'admin_listing_performance',
    'admin_manual_purchase_orders',
    'admin_decide_manual_purchase_order',
    'create_manual_purchase_order',
    'my_manual_purchase_orders',
    'my_listing_analytics',
    'user_republish_listing',
    'user_republish_listing_status',
    'user_republish_plan_status',
    'user_delete_listing'
  )
order by p.proname;

-- 2) RLS status on tables introduced/used by the recent marketplace workflow
select
  n.nspname as schema_name,
  c.relname as relation_name,
  c.relrowsecurity as rls_enabled,
  c.relforcerowsecurity as force_rls
from pg_class c
join pg_namespace n on n.oid=c.relnamespace
where n.nspname='public'
  and c.relkind='r'
  and c.relname in (
    'listings',
    'listing_view_events',
    'user_favorites',
    'bingo_package_catalog',
    'bingo_purchase_orders',
    'listing_republish_subscriptions',
    'conversations',
    'messages',
    'user_notifications'
  )
order by c.relname;

-- 3) Policies on those tables
select
  schemaname,
  tablename,
  policyname,
  roles,
  cmd,
  qual,
  with_check
from pg_policies
where schemaname='public'
  and tablename in (
    'listings',
    'listing_view_events',
    'user_favorites',
    'bingo_package_catalog',
    'bingo_purchase_orders',
    'listing_republish_subscriptions',
    'conversations',
    'messages',
    'user_notifications'
  )
order by tablename,policyname;

-- 4) Flag dangerous anon EXECUTE access on sensitive functions
select
  p.proname as dangerous_anon_function,
  pg_get_function_identity_arguments(p.oid) as arguments
from pg_proc p
join pg_namespace n on n.oid=p.pronamespace
where n.nspname='public'
  and has_function_privilege('anon',p.oid,'EXECUTE')
  and (
    p.proname like 'admin_%'
    or p.proname in (
      'create_manual_purchase_order',
      'my_manual_purchase_orders',
      'my_listing_analytics',
      'user_republish_listing',
      'user_delete_listing'
    )
  )
order by p.proname;
