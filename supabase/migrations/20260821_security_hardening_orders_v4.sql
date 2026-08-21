-- BINGO Oman - Security Hardening v4 (orders / delivery RPC permissions)
-- 2026-08-21
-- Safe permission hardening based on live audit results.
-- This migration DOES NOT change existing RLS policies or function bodies.
-- It only removes direct EXECUTE access that should not be available to anonymous users.

begin;

-- -----------------------------------------------------------------------------
-- 1) Admin store-order RPCs: authenticated only.
-- Function bodies must still perform their own admin check (existing design).
-- ----------------------------------------------------------------------------
revoke all on function public.admin_bingo_store_orders() from public, anon;
grant execute on function public.admin_bingo_store_orders() to authenticated;

revoke all on function public.admin_bingo_store_request_driver(uuid) from public, anon;
grant execute on function public.admin_bingo_store_request_driver(uuid) to authenticated;

revoke all on function public.admin_bingo_store_set_order_status(uuid,text) from public, anon;
grant execute on function public.admin_bingo_store_set_order_status(uuid,text) to authenticated;

revoke all on function public.admin_list_store_orders() from public, anon;
grant execute on function public.admin_list_store_orders() to authenticated;

revoke all on function public.admin_store_order_items(uuid) from public, anon;
grant execute on function public.admin_store_order_items(uuid) to authenticated;

revoke all on function public.admin_update_store_order_status(uuid,text) from public, anon;
grant execute on function public.admin_update_store_order_status(uuid,text) to authenticated;

-- -----------------------------------------------------------------------------
-- 2) Customer/store-facing order RPCs require a signed-in account.
-- Current site checkout/order history is account-based, so anonymous EXECUTE is unnecessary.
-- ----------------------------------------------------------------------------
revoke all on function public.place_store_order(jsonb,text,text,text,text,text,text,numeric) from public, anon;
grant execute on function public.place_store_order(jsonb,text,text,text,text,text,text,numeric) to authenticated;

revoke all on function public.place_store_order_with_delivery(jsonb,text,text,text,text,text,text,numeric,numeric,numeric,numeric) from public, anon;
grant execute on function public.place_store_order_with_delivery(jsonb,text,text,text,text,text,text,numeric,numeric,numeric,numeric) to authenticated;

revoke all on function public.place_multi_store_order_with_delivery(jsonb,text,text,text,text,text,text,numeric,numeric,numeric,numeric) from public, anon;
grant execute on function public.place_multi_store_order_with_delivery(jsonb,text,text,text,text,text,text,numeric,numeric,numeric,numeric) to authenticated;

revoke all on function public.my_store_orders() from public, anon;
grant execute on function public.my_store_orders() to authenticated;

revoke all on function public.my_store_order_items(uuid) from public, anon;
grant execute on function public.my_store_order_items(uuid) to authenticated;

-- -----------------------------------------------------------------------------
-- 3) Delivery customer/store RPCs require authentication.
-- ----------------------------------------------------------------------------
revoke all on function public.delivery_create_order(uuid,text,numeric,numeric,numeric,jsonb,numeric,numeric,numeric,numeric,text,text) from public, anon;
grant execute on function public.delivery_create_order(uuid,text,numeric,numeric,numeric,jsonb,numeric,numeric,numeric,numeric,text,text) to authenticated;

revoke all on function public.delivery_customer_bingo_code(uuid) from public, anon;
grant execute on function public.delivery_customer_bingo_code(uuid) to authenticated;

revoke all on function public.delivery_customer_tracking_context(uuid) from public, anon;
grant execute on function public.delivery_customer_tracking_context(uuid) to authenticated;

revoke all on function public.delivery_store_request_driver(uuid) from public, anon;
grant execute on function public.delivery_store_request_driver(uuid) to authenticated;

revoke all on function public.delivery_store_set_order_status(uuid,text) from public, anon;
grant execute on function public.delivery_store_set_order_status(uuid,text) to authenticated;

-- -----------------------------------------------------------------------------
-- 4) Trigger-only functions must not be callable from the API.
-- PostgreSQL triggers can execute them without granting EXECUTE to anon/authenticated.
-- ----------------------------------------------------------------------------
revoke all on function public.delivery_order_finance_sync_trigger() from public, anon, authenticated;
revoke all on function public.delivery_order_notification_trigger() from public, anon, authenticated;
revoke all on function public.delivery_sync_order_status_from_assignment() from public, anon, authenticated;

commit;

-- Existing RLS policies are intentionally preserved:
-- store_orders: owner/admin read
-- store_order_items: owner/admin read through parent order
-- delivery_orders: customer/store/assigned-driver scoped reads
-- delivery_order_items: customer/store scoped reads through parent order
