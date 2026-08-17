-- Bingo Delivery E2E validation (read-only assertions)
-- Run AFTER the delivery migrations in Supabase.
-- This script does not create users or mutate operational data.

select 'TABLES' as test_group,
       count(*) filter (where table_name in ('delivery_orders','delivery_order_items','delivery_drivers','delivery_driver_locations','delivery_assignments','delivery_stores','delivery_zones','delivery_pricing_rules','delivery_earnings','delivery_ratings','delivery_complaints')) as found,
       11 as expected
from information_schema.tables
where table_schema='public';

select 'RLS' as test_group,
       count(*) as protected_tables
from pg_tables
where schemaname='public'
  and tablename in ('delivery_orders','delivery_order_items','delivery_drivers','delivery_driver_locations','delivery_assignments','delivery_stores','delivery_zones','delivery_pricing_rules','delivery_earnings','delivery_ratings','delivery_complaints')
  and rowsecurity=true;

select 'PRICING' as test_group,
       count(*) as active_rules,
       coalesce(sum(customer_fee),0)::numeric(12,3) as customer_fee_total,
       coalesce(sum(driver_share),0)::numeric(12,3) as driver_share_total,
       coalesce(sum(bingo_share),0)::numeric(12,3) as bingo_share_total
from public.delivery_pricing_rules
where is_active=true;

select 'ORDERS' as test_group,
       count(*) as total_orders,
       count(*) filter(where status='delivered') as delivered,
       count(*) filter(where status not in ('delivered','cancelled')) as active
from public.delivery_orders;

select 'DRIVERS' as test_group,
       count(*) as drivers,
       count(*) filter(where is_online) as online,
       count(*) filter(where is_online and is_available) as available
from public.delivery_drivers;

select 'ASSIGNMENTS' as test_group,
       count(*) as assignments,
       count(*) filter(where status='delivered') as delivered_assignments,
       count(*) filter(where status in ('offered','accepted','picked_up','on_delivery')) as active_assignments
from public.delivery_assignments;

select 'EARNINGS' as test_group,
       count(*) as earnings_rows,
       coalesce(sum(amount),0)::numeric(12,3) as earnings_total,
       count(*) filter(where status='paid') as paid_rows
from public.delivery_earnings;

select 'LIVE_LOCATION' as test_group,
       count(*) as tracked_drivers,
       count(*) filter(where updated_at > now()-interval '5 minutes') as fresh_locations
from public.delivery_driver_locations;
