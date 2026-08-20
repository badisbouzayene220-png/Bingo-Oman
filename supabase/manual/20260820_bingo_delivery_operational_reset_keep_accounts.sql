-- =========================================================
-- BINGO Oman — SAFE OPERATIONAL RESET (KEEP ACCOUNTS)
-- Date: 2026-08-20
--
-- USE THIS FOR TEST RESET ONLY.
-- Preserves:
--   * auth.users / profiles
--   * delivery_drivers accounts
--   * delivery_stores / Sellers / BINGO Store
--   * products / seller ownership links
--   * seller commission percentages
--   * driver priority/capacity configuration
--   * pricing rules / zones / RPCs / schema
--
-- Resets:
--   * Store orders created during tests
--   * Delivery orders/items/assignments/codes
--   * ratings/complaints
--   * driver earnings
--   * seller settlements
--   * delivery-generated points/rewards/notifications
--   * live driver locations and runtime state
--   * driver test counters/rating back to clean defaults
--
-- IMPORTANT: This restores product stock using current store_order_items
-- before deleting the Store orders. Run only when the existing orders are
-- test orders that you want to fully undo.
-- =========================================================

begin;

-- ---------------------------------------------------------
-- 1) Restore Store product stock consumed by test orders.
-- ---------------------------------------------------------
do $$
begin
  if to_regclass('public.store_order_items') is not null
     and to_regclass('public.store_products') is not null then
    execute $q$
      update public.store_products p
      set stock = coalesce(p.stock,0) + x.qty,
          updated_at = now()
      from (
        select product_id, coalesce(sum(quantity),0)::integer as qty
        from public.store_order_items
        where product_id is not null
        group by product_id
      ) x
      where p.id=x.product_id
    $q$;
  end if;
end $$;

-- ---------------------------------------------------------
-- 2) Reset finance and order-dependent Delivery data.
-- ---------------------------------------------------------
do $$
begin
  if to_regclass('public.delivery_seller_settlements') is not null then
    execute 'truncate table public.delivery_seller_settlements restart identity cascade';
  end if;
  if to_regclass('public.delivery_order_codes') is not null then
    execute 'truncate table public.delivery_order_codes restart identity cascade';
  end if;
  if to_regclass('public.delivery_ratings') is not null then
    execute 'truncate table public.delivery_ratings restart identity cascade';
  end if;
  if to_regclass('public.delivery_complaints') is not null then
    execute 'truncate table public.delivery_complaints restart identity cascade';
  end if;
  if to_regclass('public.delivery_earnings') is not null then
    execute 'truncate table public.delivery_earnings restart identity cascade';
  end if;
  if to_regclass('public.delivery_assignments') is not null then
    execute 'truncate table public.delivery_assignments restart identity cascade';
  end if;
  if to_regclass('public.delivery_order_items') is not null then
    execute 'truncate table public.delivery_order_items restart identity cascade';
  end if;
  if to_regclass('public.delivery_orders') is not null then
    execute 'truncate table public.delivery_orders restart identity cascade';
  end if;
end $$;

-- ---------------------------------------------------------
-- 3) Reset Store checkout history AFTER Delivery data.
-- ---------------------------------------------------------
do $$
begin
  if to_regclass('public.store_order_items') is not null then
    execute 'truncate table public.store_order_items restart identity cascade';
  end if;
  if to_regclass('public.store_orders') is not null then
    execute 'truncate table public.store_orders restart identity cascade';
  end if;
end $$;

-- ---------------------------------------------------------
-- 4) Reset delivery-generated points/rewards/notifications.
--    Keep general BINGO points unrelated to delivery where possible.
-- ---------------------------------------------------------
do $$
begin
  if to_regclass('public.bingo_points_ledger') is not null then
    begin
      execute 'delete from public.bingo_points_ledger where order_id is not null or role = ''driver''';
    exception when undefined_column then
      -- Schema variant: if role/order_id differs, do not delete unrelated points.
      null;
    end;
  end if;

  if to_regclass('public.delivery_driver_notifications') is not null then
    execute 'truncate table public.delivery_driver_notifications restart identity cascade';
  end if;
  if to_regclass('public.delivery_driver_rewards') is not null then
    execute 'truncate table public.delivery_driver_rewards restart identity cascade';
  end if;
end $$;

-- ---------------------------------------------------------
-- 5) Clear live GPS/runtime state, but KEEP driver accounts.
-- ---------------------------------------------------------
do $$
begin
  if to_regclass('public.delivery_driver_locations') is not null then
    execute 'truncate table public.delivery_driver_locations restart identity cascade';
  end if;

  if to_regclass('public.delivery_drivers') is not null then
    update public.delivery_drivers
    set is_online=false,
        is_available=false,
        rating=5.00,
        total_deliveries=0,
        updated_at=now();
  end if;
end $$;

-- ---------------------------------------------------------
-- 6) Keep store/Seller records and configuration untouched.
--    Keep driver capacity/priority configuration untouched.
-- ---------------------------------------------------------

commit;

-- Refresh PostgREST cache after the reset transaction.
NOTIFY pgrst, 'reload schema';

-- =========================================================
-- VERIFICATION
-- Expected operational counts: 0.
-- Expected drivers/stores: preserved (>0 if configured).
-- =========================================================
select 'delivery_orders' as item,
       case when to_regclass('public.delivery_orders') is null then null
            else (select count(*) from public.delivery_orders) end::bigint as remaining
union all
select 'delivery_assignments',
       case when to_regclass('public.delivery_assignments') is null then null
            else (select count(*) from public.delivery_assignments) end::bigint
union all
select 'delivery_earnings',
       case when to_regclass('public.delivery_earnings') is null then null
            else (select count(*) from public.delivery_earnings) end::bigint
union all
select 'delivery_ratings',
       case when to_regclass('public.delivery_ratings') is null then null
            else (select count(*) from public.delivery_ratings) end::bigint
union all
select 'seller_settlements',
       case when to_regclass('public.delivery_seller_settlements') is null then null
            else (select count(*) from public.delivery_seller_settlements) end::bigint
union all
select 'store_orders',
       case when to_regclass('public.store_orders') is null then null
            else (select count(*) from public.store_orders) end::bigint
union all
select 'drivers_preserved',
       case when to_regclass('public.delivery_drivers') is null then null
            else (select count(*) from public.delivery_drivers) end::bigint
union all
select 'stores_preserved',
       case when to_regclass('public.delivery_stores') is null then null
            else (select count(*) from public.delivery_stores) end::bigint
order by item;
