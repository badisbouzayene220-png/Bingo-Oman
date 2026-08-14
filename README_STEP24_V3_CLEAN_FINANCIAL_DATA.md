# BINGO Oman ERP — Step 24 V3 Clean Financial Data

## What this version does

V3 starts the financial module from a blank state while preserving the ERP master data.

### Cleared
- Invoices
- Invoice items
- Payments
- Operating expenses
- Journal entries
- Journal lines
- Invoice numbering reset to `1`

### Preserved
- Customers
- Products
- Chart of Accounts
- Expense Categories
- Company settings (except the invoice counter reset)
- Users / profiles
- Inventory and stock movements
- Other ERP modules

## How to use

1. Open the Supabase SQL Editor.
2. Run `setup_step24_v3_clean_financial_data.sql` once.
3. Confirm the final verification query shows `0` for every financial transaction count.
4. Open `erp.html` and refresh the page.
5. Financial Reports should now show no transactions / zero balances.
6. Enter new invoices, payments and expenses from scratch.

## Important

This is a destructive cleanup of financial transaction data. Make a database backup before running it if the previous numbers might be needed later.
