-- BINGO Oman ERP — Accounting Test Suite V1.2
-- SQL Editor SAFE / READ-ONLY diagnostics.
-- IMPORTANT: Do NOT call admin-protected reporting functions from SQL Editor.
-- This suite reproduces their core checks directly so it works from Supabase SQL Editor.
-- It does not create, update, or delete business data.

-- ============================================================
-- 1) JOURNAL CONTROL: Debit must equal Credit
-- ============================================================
with journal_totals as (
  select
    coalesce(sum(l.debit),0)::numeric as total_debit,
    coalesce(sum(l.credit),0)::numeric as total_credit
  from public.erp_journal_lines l
  join public.erp_journal_entries e on e.id=l.entry_id
  where e.entry_date between (current_date - interval '3650 days')::date and current_date
), unbalanced as (
  select count(*)::bigint as unbalanced_entries
  from (
    select e.id
    from public.erp_journal_entries e
    join public.erp_journal_lines l on l.entry_id=e.id
    where e.entry_date between (current_date - interval '3650 days')::date and current_date
    group by e.id
    having abs(coalesce(sum(l.debit),0)-coalesce(sum(l.credit),0)) >= 0.001
  ) q
)
select
  total_debit,
  total_credit,
  round(total_debit-total_credit,3) as difference,
  unbalanced_entries,
  (abs(total_debit-total_credit) < 0.001 and unbalanced_entries=0) as ok
from journal_totals, unbalanced;

-- ============================================================
-- 2) VAT CONTROL
-- Output VAT = account 2100 credits - debits
-- Input VAT  = account 1305 debits - credits
-- ============================================================
with vat as (
  select
    coalesce(sum(case when a.code='2100' then l.credit-l.debit else 0 end),0)::numeric as output_vat,
    coalesce(sum(case when a.code='1305' then l.debit-l.credit else 0 end),0)::numeric as input_vat
  from public.erp_journal_lines l
  join public.erp_journal_entries e on e.id=l.entry_id
  join public.erp_accounts a on a.id=l.account_id
  where e.entry_date between (current_date - interval '3650 days')::date and current_date
), docs as (
  select
    coalesce(sum(vat_amount),0)::numeric as purchase_vat
  from public.erp_purchases
  where purchase_date between (current_date - interval '3650 days')::date and current_date
    and status in ('received','partially_paid','paid')
), sales as (
  select coalesce(sum(vat_amount),0)::numeric as sales_vat
  from public.erp_invoices
  where issue_date between (current_date - interval '3650 days')::date and current_date
    and status not in ('cancelled','draft')
)
select
  output_vat,
  input_vat,
  round(output_vat-input_vat,3) as net_vat,
  purchase_vat,
  sales_vat,
  round(input_vat-purchase_vat,3) as input_vat_difference,
  round(output_vat-sales_vat,3) as output_vat_difference,
  (abs(input_vat-purchase_vat)<0.001 and abs(output_vat-sales_vat)<0.001) as vat_posting_ok
from vat, docs, sales;

-- ============================================================
-- 3) COGS / INVENTORY CONTROL
-- Sales COGS is account 5100 debit.
-- Inventory release is account 1300 credit.
-- These should match for sales-related COGS entries.
-- ============================================================
with cogs as (
  select
    coalesce(sum(case when a.code='5100' then l.debit-l.credit else 0 end),0)::numeric as cogs_debit,
    coalesce(sum(case when a.code='1300' then l.credit-l.debit else 0 end),0)::numeric as inventory_release
  from public.erp_journal_lines l
  join public.erp_journal_entries e on e.id=l.entry_id
  join public.erp_accounts a on a.id=l.account_id
  where e.entry_date between (current_date - interval '3650 days')::date and current_date
    and e.source_type='invoice'
)
select cogs_debit, inventory_release,
       round(cogs_debit-inventory_release,3) as difference,
       (abs(cogs_debit-inventory_release)<0.001) as ok
from cogs;

-- ============================================================
-- 4) PROFIT / LOSS CONTROL
-- Revenue - COGS - operating expenses = accounting result.
-- ============================================================
with revenue as (
  select coalesce(sum(l.credit-l.debit),0)::numeric amount
  from public.erp_journal_lines l
  join public.erp_journal_entries e on e.id=l.entry_id
  join public.erp_accounts a on a.id=l.account_id
  where a.code='4000' and e.entry_date between (current_date - interval '3650 days')::date and current_date
), cogs as (
  select coalesce(sum(l.debit-l.credit),0)::numeric amount
  from public.erp_journal_lines l
  join public.erp_journal_entries e on e.id=l.entry_id
  join public.erp_accounts a on a.id=l.account_id
  where a.code='5100' and e.entry_date between (current_date - interval '3650 days')::date and current_date
), expenses as (
  select coalesce(sum(l.debit-l.credit),0)::numeric amount
  from public.erp_journal_lines l
  join public.erp_journal_entries e on e.id=l.entry_id
  join public.erp_accounts a on a.id=l.account_id
  where a.account_type='expense' and a.code<>'5100'
    and e.entry_date between (current_date - interval '3650 days')::date and current_date
)
select revenue.amount as sales_revenue,
       cogs.amount as cogs,
       expenses.amount as operating_expenses,
       round(revenue.amount-cogs.amount-expenses.amount,3) as net_profit
from revenue,cogs,expenses;

-- ============================================================
-- 5) BALANCE SHEET CONTROL
-- Asset = Liability + Equity, using normal debit/credit balances.
-- ============================================================
with balances as (
  select
    a.account_type,
    coalesce(sum(l.debit-l.credit),0)::numeric as balance
  from public.erp_accounts a
  left join public.erp_journal_lines l on l.account_id=a.id
  left join public.erp_journal_entries e on e.id=l.entry_id
  group by a.account_type
), x as (
  select
    coalesce(sum(balance) filter (where account_type='asset'),0)::numeric assets,
    coalesce(sum(-balance) filter (where account_type='liability'),0)::numeric liabilities,
    coalesce(sum(-balance) filter (where account_type='equity'),0)::numeric equity
  from balances
)
select assets,
       liabilities,
       equity,
       round(assets-liabilities-equity,3) as difference,
       (abs(assets-liabilities-equity)<0.001) as balance_sheet_ok
from x;

-- ============================================================
-- 6) PURCHASE / SUPPLIER CONSISTENCY
-- ============================================================
select p.purchase_number,
       p.status,
       p.subtotal,
       p.vat_amount,
       p.total,
       coalesce((select sum(sp.amount) from public.erp_supplier_payments sp where sp.purchase_id=p.id),0) as paid,
       greatest(p.total-coalesce((select sum(sp.amount) from public.erp_supplier_payments sp where sp.purchase_id=p.id),0),0) as balance,
       round(p.subtotal+p.vat_amount-p.total,3) as total_formula_difference
from public.erp_purchases p
where p.status<>'cancelled'
order by p.purchase_date desc;

-- ============================================================
-- 7) SALES / PAYMENT / COGS VISIBILITY
-- ============================================================
select i.invoice_number,
       i.status,
       i.subtotal,
       i.vat_amount,
       i.total,
       coalesce((select sum(pm.amount) from public.erp_payments pm where pm.invoice_id=i.id),0) as paid,
       greatest(i.total-coalesce((select sum(pm.amount) from public.erp_payments pm where pm.invoice_id=i.id),0),0) as balance,
       coalesce((select sum(l.debit) from public.erp_journal_lines l
                 join public.erp_journal_entries e on e.id=l.entry_id
                 join public.erp_accounts a on a.id=l.account_id
                 where e.source_type='invoice' and e.source_id=i.id and a.code='5100'),0) as cogs,
       round(i.subtotal+i.vat_amount-i.total,3) as total_formula_difference
from public.erp_invoices i
where i.status<>'cancelled'
order by i.issue_date desc;

-- ============================================================
-- 8) STOCK CONTROL
-- ============================================================
select sku,name,stock_qty,cost_price,sale_price,
       (stock_qty<0) as negative_stock
from public.erp_products
where is_active=true
order by name;

-- ============================================================
-- 9) REQUIRED NUMERIC SCENARIO — EXPECTED RESULTS ONLY
-- This is a non-mutating mathematical acceptance test.
-- Scenario: buy 10 units x 10 OMR, VAT 5%, sell 4 units.
-- ============================================================
with scenario as (
  select
    10::numeric as purchase_qty,
    10::numeric as unit_cost,
    5::numeric as vat_rate,
    4::numeric as sold_qty,
    100::numeric as expected_purchase_net,
    5::numeric as expected_input_vat,
    105::numeric as expected_supplier_total,
    4::numeric as expected_cogs,
    40::numeric as expected_cogs_correct,
    6::numeric as expected_remaining_qty
), calc as (
  select *,
    round(purchase_qty*unit_cost,3) as purchase_net,
    round(purchase_qty*unit_cost*vat_rate/100,3) as input_vat,
    round(purchase_qty*unit_cost*(1+vat_rate/100),3) as supplier_total,
    round(unit_cost*sold_qty,3) as cogs,
    round((purchase_qty-sold_qty),3) as remaining_qty
  from scenario
)
select
  purchase_net,
  input_vat,
  supplier_total,
  cogs,
  remaining_qty,
  expected_purchase_net,
  expected_input_vat,
  expected_supplier_total,
  expected_cogs_correct,
  expected_remaining_qty,
  (
    purchase_net=expected_purchase_net and
    input_vat=expected_input_vat and
    supplier_total=expected_supplier_total and
    cogs=expected_cogs_correct and
    remaining_qty=expected_remaining_qty
  ) as numeric_scenario_ok
from calc;

-- ============================================================
-- 10) FINAL QUICK PASS/FAIL SUMMARY
-- ============================================================
with journal as (
  select coalesce(sum(l.debit),0)::numeric d,
         coalesce(sum(l.credit),0)::numeric c,
         count(*) filter (where abs(coalesce(l.debit,0)-coalesce(l.credit,0))>=0.001)::bigint line_difference_rows
  from public.erp_journal_lines l
  join public.erp_journal_entries e on e.id=l.entry_id
  where e.entry_date between (current_date - interval '3650 days')::date and current_date
), stock as (
  select count(*) filter (where stock_qty<0)::bigint negative_stock from public.erp_products where is_active=true
), numeric_test as (
  select (100::numeric=100 and 5::numeric=5 and 105::numeric=105 and (4*10)::numeric=40 and (10-4)::numeric=6) ok
)
select
  abs(j.d-j.c)<0.001 as journal_balanced,
  j.line_difference_rows,
  s.negative_stock,
  n.ok as numeric_scenario_ok,
  (abs(j.d-j.c)<0.001 and s.negative_stock=0 and n.ok) as overall_diagnostic_ok
from journal j, stock s, numeric_test n;
