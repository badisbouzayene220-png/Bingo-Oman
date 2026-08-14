# BINGO Oman — Step 24 Financial Reports FIX

## What was fixed

- Financial Reports now use the accounting journal (`erp_journal_entries` + `erp_journal_lines`).
- Profit & Loss: `erp_profit_loss_accounting(date,date)`.
- Balance Sheet: `erp_balance_sheet(date)`.
- Cash Flow: `erp_cash_flow(date,date)`.
- VAT Summary: `erp_financial_vat_summary(date,date)`.
- Trial Balance: `erp_trial_balance(date,date)`.
- General Ledger: `erp_general_ledger(date,date,uuid)` using an account selector instead of an account-code text field.
- Accounting Control: `erp_accounting_control_check(date,date)`.
- Expenses are posted automatically to the accounting journal, and existing expenses are backfilled once.
- Existing ERP screens and invoice/payment workflows are preserved.

## Supabase step

Run **`setup_step24_financial_reports.sql`** in the Supabase SQL Editor while signed in as an admin.

Then refresh `erp.html`.

## Important

The General Ledger function expects the account UUID (`p_account_id`). The ERP page now loads the active accounts and sends the UUID correctly.
