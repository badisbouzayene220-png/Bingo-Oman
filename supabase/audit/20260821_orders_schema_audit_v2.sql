-- BINGO Oman orders/order_items schema audit v2
-- READ ONLY: changes nothing.
-- Returns ONE result table so Supabase SQL Editor shows everything clearly.

with cols as (
  select
    c.table_name,
    c.ordinal_position,
    c.column_name,
    c.data_type,
    c.is_nullable,
    c.column_default,
    exists (
      select 1
      from information_schema.key_column_usage kcu
      join information_schema.table_constraints tc
        on tc.constraint_name = kcu.constraint_name
       and tc.table_schema = kcu.table_schema
      where tc.table_schema='public'
        and tc.table_name=c.table_name
        and tc.constraint_type='PRIMARY KEY'
        and kcu.column_name=c.column_name
    ) as is_primary_key
  from information_schema.columns c
  where c.table_schema='public'
    and c.table_name in ('orders','order_items')
), fks as (
  select
    tc.table_name,
    kcu.column_name,
    ccu.table_name as foreign_table_name,
    ccu.column_name as foreign_column_name
  from information_schema.table_constraints tc
  join information_schema.key_column_usage kcu
    on tc.constraint_name=kcu.constraint_name
   and tc.table_schema=kcu.table_schema
  join information_schema.constraint_column_usage ccu
    on tc.constraint_name=ccu.constraint_name
   and tc.table_schema=ccu.table_schema
  where tc.table_schema='public'
    and tc.table_name in ('orders','order_items')
    and tc.constraint_type='FOREIGN KEY'
), rls as (
  select
    c.relname as table_name,
    c.relrowsecurity as rls_enabled,
    c.relforcerowsecurity as force_rls
  from pg_class c
  join pg_namespace n on n.oid=c.relnamespace
  where n.nspname='public'
    and c.relname in ('orders','order_items')
), pol as (
  select
    tablename as table_name,
    count(*)::int as policy_count,
    string_agg(policyname || ' [' || cmd || ']', '; ' order by policyname) as policies
  from pg_policies
  where schemaname='public'
    and tablename in ('orders','order_items')
  group by tablename
)
select
  c.table_name,
  c.ordinal_position,
  c.column_name,
  c.data_type,
  c.is_nullable,
  c.column_default,
  c.is_primary_key,
  f.foreign_table_name,
  f.foreign_column_name,
  coalesce(r.rls_enabled,false) as rls_enabled,
  coalesce(r.force_rls,false) as force_rls,
  coalesce(p.policy_count,0) as policy_count,
  coalesce(p.policies,'') as policies
from cols c
left join fks f
  on f.table_name=c.table_name
 and f.column_name=c.column_name
left join rls r
  on r.table_name=c.table_name
left join pol p
  on p.table_name=c.table_name
order by c.table_name,c.ordinal_position;
