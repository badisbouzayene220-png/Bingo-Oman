-- BINGO Oman - focused order security precheck for Security Hardening v4
-- READ ONLY: this file changes nothing.
-- Returns one result set combining table RLS policies and relevant RPC execution grants.

with table_policies as (
  select
    'policy'::text as row_type,
    p.tablename as object_name,
    p.policyname as detail_name,
    p.cmd::text as command,
    array_to_string(p.roles, ',') as roles,
    p.qual as using_expression,
    p.with_check as check_expression,
    null::boolean as security_definer,
    null::boolean as execute_anon,
    null::boolean as execute_authenticated,
    null::text as function_args
  from pg_policies p
  where p.schemaname='public'
    and p.tablename in (
      'store_orders','store_order_items',
      'delivery_orders','delivery_order_items','delivery_order_codes'
    )
), function_security as (
  select
    'function'::text as row_type,
    p.proname::text as object_name,
    'EXECUTE'::text as detail_name,
    null::text as command,
    null::text as roles,
    null::text as using_expression,
    null::text as check_expression,
    p.prosecdef as security_definer,
    has_function_privilege('anon', p.oid, 'EXECUTE') as execute_anon,
    has_function_privilege('authenticated', p.oid, 'EXECUTE') as execute_authenticated,
    pg_get_function_identity_arguments(p.oid) as function_args
  from pg_proc p
  join pg_namespace n on n.oid=p.pronamespace
  where n.nspname='public'
    and (
      p.proname in (
        'place_store_order','place_store_order_with_delivery','place_multi_store_order_with_delivery',
        'my_store_orders','my_store_order_items',
        'admin_list_store_orders','admin_store_order_items','admin_update_store_order_status',
        'admin_bingo_store_orders','admin_bingo_store_set_order_status','admin_bingo_store_request_driver',
        'delivery_create_order','delivery_store_request_driver','delivery_store_set_order_status',
        'delivery_customer_tracking_context','delivery_customer_bingo_code'
      )
      or p.proname like 'admin%store%order%'
      or p.proname like 'delivery%order%'
    )
)
select * from table_policies
union all
select * from function_security
order by row_type, object_name, detail_name;
