# BINGO Driver Experience

This branch adds the Omani BINGO driver experience without changing the existing delivery data model flow unnecessarily.

## Included
- Omani BINGO human driver character asset.
- Delivery Ring and BINGO assistant.
- Smart Arrival using live browser GPS and customer order coordinates.
- Secure 4-digit BINGO Code generated per delivery order.
- Customer-only code display.
- Driver-only code verification RPC.
- Successful delivery animation and driver earnings completion.

## Required database step
Run `supabase/migrations/20260818_bingo_delivery_bingo_code_v1.sql` in Supabase before testing the new BINGO Code flow.

The migration intentionally blocks direct `delivered` status changes through `delivery_set_assignment_status`. Successful delivery must use `delivery_confirm_with_code`.

## Test flow
1. Customer creates a delivery order.
2. Admin assigns it to the driver.
3. Driver accepts and picks up the order.
4. Driver starts delivery.
5. Customer sees the 4-digit BINGO Code.
6. Smart Arrival shows live distance as the driver approaches.
7. Driver enters the customer's BINGO Code.
8. Supabase verifies the code, marks the assignment/order delivered, makes the driver available, and creates the earnings row.
9. Driver sees the BINGO success animation.
