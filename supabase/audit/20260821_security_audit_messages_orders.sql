-- BINGO Oman read-only security audit
-- This script DOES NOT modify data, policies, roles, or functions.
-- Run in Supabase SQL Editor and share the result table.

with target_tables as (
  select unnest(array[
    'conversations','messages','listings','listing_images','orders','order_items',
    'delivery_orders','delivery_assignments','delivery_drivers','site_banners',
    'listing_reports','user_favorites'
  ]) as table_name
), table_state as (
  select
    t.table_name,
    coalesce(c.relrowsecurity,false) as rls_enabled,
    coalesce(c.relforcerowsecurity,false) as force_rls
  from target_tables t
  left join pg_class c on c.relname=t.table_name
  left join pg_namespace n on n.oid=c.relnamespace and n.nspname='public'
), policies as (
  select
    tablename as table_name,
    jsonb_agg(jsonb_build_object(
      'policy', policyname,
      'cmd', cmd,
      'roles', roles,
      'using', qual,
      'check', with_check
    ) order by policyname) as policy_list
  from pg_policies
  where schemaname='public'
    and tablename in (select table_name from target_tables)
  group by tablename
), funcs as (
  select jsonb_agg(jsonb_build_object(
      'name', p.proname,
      'security_definer', p.prosecdef,
      'owner', pg_get_userbyid(p.proowner),
      'args', pg_get_function_identity_arguments(p.oid),
      'execute_public', has_function_privilege('public',p.oid,'EXECUTE'),
      'execute_anon', case when exists(select 1 from pg_roles where rolname='anon') then has_function_privilege('anon',p.oid,'EXECUTE') else null end,
      'execute_authenticated', case when exists(select 1 from pg_roles where rolname='authenticated') then has_function_privilege('authenticated',p.oid,'EXECUTE') else null end
    ) order by p.proname) as functions
  from pg_proc p
  join pg_namespace n on n.oid=p.pronamespace
  where n.nspname='public'
    and (
      p.proname like 'admin_%'
      or p.proname like '%conversation%'
      or p.proname like '%message%'
      or p.proname like '%order%'
      or p.proname like '%delivery%'
    )
)
select
  s.table_name,
  s.rls_enabled,
  s.force_rls,
  coalesce(p.policy_list,'[]'::jsonb) as policies,
  case when row_number() over(order by s.table_name)=1 then f.functions else null end as relevant_functions
from table_state s
left join policies p using(table_name)
cross join funcs f
order by s.table_name;
