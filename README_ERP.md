# BINGO Oman ERP / Business Management

This module adds a company-management layer to BINGO Oman without replacing the marketplace database.

## Included
- Company profile and configurable Oman VAT rate (default 5%).
- Customer/CRM database with customer code, company details, tax number, contact details and balances.
- Tax invoices with automatic subtotal, discount, taxable amount, VAT and grand total.
- Invoice numbering (`INV-000001`, configurable prefix).
- Customer payments and invoice balances.
- Operating expenses with VAT and categories.
- VAT summary: output VAT, input VAT and net VAT.
- Profit & loss summary for a selected period.
- Excel exports for customers, invoices and expenses.
- Printable tax invoice.
- Audit log for ERP changes.
- Admin-only RLS and SECURITY DEFINER RPCs.

## Setup
1. Open Supabase SQL Editor.
2. Run `setup_erp.sql` once after the existing BINGO database setup.
3. Open `admin.html` and click `🧾 ERP / Finance`.

The ERP uses the existing `public.is_admin()` helper and therefore only BINGO administrators can access it.

## Important accounting note
This release provides the operational accounting foundation (sales, VAT, receivables, payments and expenses). A full statutory accounting suite can be added next: automated double-entry posting for every transaction, bank reconciliation, inventory valuation, payroll, fixed assets, credit notes, supplier bills, VAT return workpapers and period closing.
