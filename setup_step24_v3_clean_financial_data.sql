-- BINGO Oman ERP - Step 24 V3 Clean Financial Data
-- PURPOSE: Remove existing financial transaction data so the ERP starts with blank financial reports.
-- PRESERVES: company settings, customers, products, chart of accounts, expense categories, users and inventory data.
-- DELETES: invoices, invoice items, payments, expenses, journal entries and journal lines (journal lines cascade).
-- ALSO RESETS the next invoice number to 1.
-- RUN THIS ONCE in Supabase SQL Editor. BACK UP YOUR DATABASE FIRST if the old financial data may be needed.

begin;

-- Remove dependent payment records first.
delete from public.erp_payments;

-- Invoice items are deleted automatically with invoices, but this explicit delete is clear and safe.
delete from public.erp_invoice_items;
delete from public.erp_invoices;

-- Remove operating expenses. Their financial journal entries are removed below.
delete from public.erp_expenses;

-- Remove all double-entry accounting transactions. Lines cascade from entries.
delete from public.erp_journal_entries;

-- Start invoice numbering again from 1 for the new accounting period/data set.
update public.erp_company_settings
set invoice_next_number = 1,
    updated_at = now()
where id = 'default';

commit;

-- Verification: all financial transaction tables should return 0.
select
  (select count(*) from public.erp_invoices)       as invoices,
  (select count(*) from public.erp_invoice_items)  as invoice_items,
  (select count(*) from public.erp_payments)       as payments,
  (select count(*) from public.erp_expenses)       as expenses,
  (select count(*) from public.erp_journal_entries) as journal_entries,
  (select count(*) from public.erp_journal_lines)   as journal_lines;

-- Expected result: every value above = 0.
-- Chart of Accounts, customers, products and expense categories are intentionally NOT deleted.
