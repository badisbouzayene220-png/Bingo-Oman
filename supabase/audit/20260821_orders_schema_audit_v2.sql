-- BINGO Oman orders/order_items schema audit v2
-- READ ONLY: this file changes nothing.

-- 1) Columns
select
  c.table_name,
  c.ordinal_position,
  c.column_name,
  c.data_type,
  c.is_nullable,
  c.column_default
from information_schema.columns c
where c.table_schema='public'
  and c.table_name in ('orders','order_items')
order by c.table_name, c.ordinal_position;

-- 2) Foreign keys
select
  tc.table_name,
  kcu.column_name,
  ccu.table_name as foreign_table_name,
  ccu.column_name as foreign_column_name,
  tc.constraint_name
from information_schema.table_constraints tc
join information_schema.key_column_usage kcu
  on tc.constraint_name=kcu.constraint_name
 and tc.table_schema=kcu.table_schema
join information_schema.constraint_column_usage ccu
  on ccu.constraint_name=tc.constraint_name
 and ccu.table_schema=tc.table_schema
where tc.table_schema='public'
  and tc.constraint_type='FOREIGN KEY'
  and tc.table_name in ('orders','order_items')
order by tc.table_name, kcu.column_name;

-- 3) Grants
select table_name,grantee,privilege_type
from information_schema.role_table_grants
where table_schema='public'
  and table_name in ('orders','order_items')
order by table_name,grantee,privilege_type;

-- 4) RLS + policies
select
  c.relname as table_name,
  c.relrowsecurity as rls_enabled,
  c.relforcerowsecurity as force_rls,
  coalesce(jsonb_agg(
    jsonb_build_object(
      'policy',p.policyname,
      'cmd',p.cmd,
      'roles',p.roles,
      'using',p.qual,
      'check',p.with_check
    ) order by p.policyname
  ) filter (where p.policyname is not null),'[]'::jsonb) as policies
from pg_class c
join pg_namespace n on n.oid=c.relnamespace
left join pg_policies p on p.schemaname=n.nspname and p.tablename=c.relname
where n.nspname='public'
  and c.relname in ('orders','order_items')
group by c.relname,c.relrowsecurity,c.relforcerowsecurity
order by c.relname;

-- 5) Functions touching store orders
select
  p.proname as function_name,
  pg_get_function_identity_arguments(p.oid) as args,
  p.prosecdef as security_definer,
  has_function_privilege('anon',p.oid,'EXECUTE') as execute_anon,
  has_function_privilege('authenticated',p.oid,'EXECUTE') as execute_authenticated,
  pg_get_functiondef(p.oid) as definition
from pg_proc p
join pg_namespace n on n.oid=p.pronamespace
where n.nspname='public'
  and (
    p.proname like '%store_order%'
    or p.proname in ('place_store_order','my_store_orders','my_store_order_items')
  )
order by p.proname,pg_get_function_identity_arguments(p.oid);
