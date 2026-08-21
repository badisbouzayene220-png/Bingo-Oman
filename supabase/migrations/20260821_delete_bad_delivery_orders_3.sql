-- Remove only these faulty delivery test orders:
-- BGO-19C5D85B
-- BGO-C1340137
-- BGO-5C7C45D0
--
-- This script preserves users, drivers, sellers, stores, and all other orders.

DO $$
DECLARE
  v_ids uuid[];
  v_driver record;
BEGIN
  SELECT array_agg(id)
    INTO v_ids
  FROM public.delivery_orders
  WHERE order_number IN ('BGO-19C5D85B','BGO-C1340137','BGO-5C7C45D0');

  IF v_ids IS NULL OR array_length(v_ids,1) IS NULL THEN
    RAISE NOTICE 'None of the target delivery orders were found.';
    RETURN;
  END IF;

  -- Roll back delivery counters only for target assignments that had actually
  -- reached delivered state. We do this before deleting assignments/orders.
  FOR v_driver IN
    SELECT a.driver_id, count(*)::int AS delivered_count
    FROM public.delivery_assignments a
    WHERE a.order_id = ANY(v_ids)
      AND a.status = 'delivered'
    GROUP BY a.driver_id
  LOOP
    UPDATE public.delivery_drivers
       SET total_deliveries = greatest(coalesce(total_deliveries,0) - v_driver.delivered_count, 0),
           updated_at = now()
     WHERE id = v_driver.driver_id;
  END LOOP;

  -- delivery_earnings uses ON DELETE RESTRICT, so remove it first.
  DELETE FROM public.delivery_earnings
   WHERE order_id = ANY(v_ids);

  -- Ratings and BINGO codes are normally cascade children, but deleting them
  -- explicitly keeps the reset clear and safe across schema versions.
  IF to_regclass('public.delivery_ratings') IS NOT NULL THEN
    DELETE FROM public.delivery_ratings WHERE order_id = ANY(v_ids);
  END IF;

  IF to_regclass('public.delivery_order_codes') IS NOT NULL THEN
    DELETE FROM public.delivery_order_codes WHERE order_id = ANY(v_ids);
  END IF;

  -- Complaints should not be deleted wholesale; detach them from bad test orders.
  IF to_regclass('public.delivery_complaints') IS NOT NULL THEN
    UPDATE public.delivery_complaints
       SET order_id = NULL
     WHERE order_id = ANY(v_ids);
  END IF;

  -- These are cascade children in the base schema; explicit deletes make the
  -- operation deterministic before the order rows are removed.
  DELETE FROM public.delivery_assignments
   WHERE order_id = ANY(v_ids);

  DELETE FROM public.delivery_order_items
   WHERE order_id = ANY(v_ids);

  DELETE FROM public.delivery_orders
   WHERE id = ANY(v_ids);

  -- Release any affected drivers that no longer have an active delivery.
  UPDATE public.delivery_drivers d
     SET is_available = true,
         updated_at = now()
   WHERE NOT EXISTS (
     SELECT 1
     FROM public.delivery_assignments a
     WHERE a.driver_id = d.id
       AND a.status IN ('offered','accepted','picked_up','on_delivery')
   );

  RAISE NOTICE 'Deleted faulty delivery orders: BGO-19C5D85B, BGO-C1340137, BGO-5C7C45D0';
END $$;

-- Verification: this should return zero rows.
SELECT id, order_number, status
FROM public.delivery_orders
WHERE order_number IN ('BGO-19C5D85B','BGO-C1340137','BGO-5C7C45D0');
