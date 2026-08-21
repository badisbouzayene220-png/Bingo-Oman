-- BINGO Oman order relation discovery v3
-- READ ONLY: changes nothing.
-- Uses PostgreSQL catalogs directly and returns every public relation containing "order".

select
  n.nspname as schema_name,
  c.relname as relation_name,
  case c.relkind
    when 'r' then 'table'
    when 'p' then 'partitioned table'
    when 'v' then 'view'
    when 'm' then 'materialized view'
    when 'f' then 'foreign table'
    else c.relkind::text
  end as relation_type,
  c.relrowsecurity as rls_enabled,
  a.attnum as column_position,
  a.attname as column_name,
  pg_catalog.format_type(a.atttypid,a.atttypmod) as data_type,
  not a.attnotnull as is_nullable
from pg_catalog.pg_class c
join pg_catalog.pg_namespace n on n.oid=c.relnamespace
left join pg_catalog.pg_attribute a
  on a.attrelid=c.oid
 and a.attnum>0
 and not a.attisdropped
where n.nspname='public'
  and lower(c.relname) like '%order%'
  and c.relkind in ('r','p','v','m','f')
order by c.relname,a.attnum;