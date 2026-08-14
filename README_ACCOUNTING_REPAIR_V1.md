# BINGO Oman — Accounting Repair V1

## What this repair fixes

1. **COGS on sales**
   - Every newly issued product sale posts Cost of Goods Sold to account `5100`.
   - Inventory is credited by the same COGS amount.

2. **Weighted-average inventory cost**
   - Receiving a purchase updates `erp_products.cost_price` using the existing stock quantity/cost plus the received quantity/net line cost.
   - This cost is then used for future COGS.

3. **Purchase validation**
   - Received purchase items must be linked to an active product.
   - Line discount cannot exceed the line value.
   - A draft with supplier payments cannot be edited.

4. **Supplier payments**
   - Payments must be linked to a received purchase.
   - Overpayments are blocked.
   - Payment status updates to `partially_paid` / `paid`.

5. **VAT**
   - Output VAT reads account `2100`.
   - Input VAT reads account `1305`.
   - Purchase VAT is no longer incorrectly read from the output VAT account.

6. **Dashboard / Finance overview**
   - Draft invoices/purchases are excluded from actual sales, purchases, receivables and payables.

7. **Accounting control**
   - Double-entry debit/credit balance is checked.
   - Negative stock is reported.

## Important

Run this file **after** the existing ERP setup files, especially:

- `setup_erp.sql`
- `setup_step9_products_inventory.sql`
- `setup_step10_invoices_sales.sql`
- `setup_finance_expansion_fixed.sql`

It is designed as a final repair layer and can be run repeatedly.

## Historical data

Old sales that were posted before this repair may not contain a COGS journal line because the previous sales function did not create one. The repair makes **new sales correct**. Historical COGS requires a separate controlled backfill based on stock/cost history.

## Test scenario

Use `setup_accounting_test_suite_v1.sql` after applying this repair and after logging in as an ERP admin.
