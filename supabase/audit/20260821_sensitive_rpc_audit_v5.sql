-- BINGO Oman - Sensitive RPC audit v5
-- READ ONLY. Run in Supabase SQL Editor and send the result back.
-- Focus: HR, users/roles, products/store, banners and remaining admin/security-definer functions.

with funcs as (
  select
    n.nspname as schema_name,
    p.oid,
    p.proname as function_name,
    pg_get_function_identity_arguments(p.oid) as function_args,
    p.prosecdef as security_definer,
    has_function_privilege('anon', p.oid, 'EXECUTE') as execute_anon,
    has_function_privilege('authenticated', p.oid, 'EXECUTE') as execute_authenticated,
    case
      when p.proname ilike 'hr_%' or p.proname ilike '%employee%' or p.proname ilike '%attendance%' or p.proname ilike '%leave%' then 'HR'
      when p.proname ilike '%user%' or p.proname ilike '%role%' or p.proname ilike '%profile%' then 'USERS_ROLES'
      when p.proname ilike '%product%' or p.proname ilike '%store%' then 'PRODUCTS_STORE'
      when p.proname ilike '%banner%' then 'BANNERS'
      when p.proname ilike 'admin_%' then 'ADMIN_OTHER'
      else 'SECURITY_DEFINER_OTHER'
    end as area
  from pg_proc p
  join pg_namespace n on n.oid = p.pronamespace
  where n.nspname = 'public'
    and (
      p.prosecdef
      or p.proname ilike 'admin_%'
      or p.proname ilike 'hr_%'
      or p.proname ilike '%employee%'
      or p.proname ilike '%attendance%'
      or p.proname ilike '%leave%'
      or p.proname ilike '%user%'
      or p.proname ilike '%role%'
      or p.proname ilike '%product%'
      or p.proname ilike '%store%'
      or p.proname ilike '%banner%'
    )
)
select
  area,
  function_name,
  function_args,
  security_definer,
  execute_anon,
  execute_authenticated,
  case
    when security_definer and execute_anon then 'HIGH: SECURITY DEFINER executable by anon'
    when function_name ilike 'admin_%' and execute_anon then 'HIGH: admin RPC executable by anon'
    when security_definer then 'REVIEW: SECURITY DEFINER'
    else 'INFO'
  end as finding
from funcs
order by
  case when security_definer and execute_anon then 0 when function_name ilike 'admin_%' and execute_anon then 1 else 2 end,
  area,
  function_name,
  function_args;
