-- BINGO Oman ERP - Step 24 Financial Reports
-- Run once in Supabase SQL Editor after the ERP/Invoice/Payment setup.
-- All reports are sourced from the double-entry journal tables.

create or replace function public.erp_trial_balance(p_from date,p_to date)
returns jsonb language plpgsql security definer set search_path=public as $$
declare r jsonb;
begin
 if not public.is_admin() then raise exception 'Admin access required'; end if;
 select coalesce(jsonb_agg(to_jsonb(x) order by x.code),'[]'::jsonb) into r
 from (
   select a.code,a.name,a.account_type,
          round(coalesce(sum(case when e.id is not null then l.debit else 0 end),0),3) debit,
          round(coalesce(sum(case when e.id is not null then l.credit else 0 end),0),3) credit,
          round(coalesce(sum(case when e.id is not null then l.debit-l.credit else 0 end),0),3) balance
   from public.erp_accounts a
   left join public.erp_journal_lines l on l.account_id=a.id
   left join public.erp_journal_entries e on e.id=l.entry_id and e.entry_date between p_from and p_to
   where a.is_active
   group by a.id,a.code,a.name,a.account_type
 ) x;
 return r;
end $$;

create or replace function public.erp_general_ledger(p_from date,p_to date,p_account_id uuid)
returns jsonb language plpgsql security definer set search_path=public as $$
declare
  r jsonb;
  opening numeric := 0;
  closing numeric := 0;
  normal_credit boolean := false;
begin
 if not public.is_admin() then raise exception 'Admin access required'; end if;
 if p_account_id is null then raise exception 'Account is required'; end if;
 select account_type in ('liability','equity','revenue') into normal_credit from public.erp_accounts where id=p_account_id;
 if normal_credit is null then raise exception 'Account not found'; end if;
 select coalesce(sum(l.debit-l.credit),0) into opening
 from public.erp_journal_lines l join public.erp_journal_entries e on e.id=l.entry_id
 where l.account_id=p_account_id and e.entry_date < p_from;
 if normal_credit then opening := -opening; end if;
 select coalesce(sum(l.debit-l.credit),0) into closing
 from public.erp_journal_lines l join public.erp_journal_entries e on e.id=l.entry_id
 where l.account_id=p_account_id and e.entry_date <= p_to;
 if normal_credit then closing := -closing; end if;
 select jsonb_build_object(
   'account',to_jsonb(a),
   'opening_balance',round(opening,3),
   'closing_balance',round(closing,3),
   'rows',coalesce((select jsonb_agg(to_jsonb(z) order by z.entry_date,z.entry_number,z.line_id) from (
     select e.entry_date,e.entry_number,e.description,e.source_type,e.source_id,l.id line_id,
            a.code account_code,a.name account_name,
            l.debit,l.credit,
            round(
              opening + sum(case when normal_credit then l.credit-l.debit else l.debit-l.credit end)
                over(order by e.entry_date,e.entry_number,l.id rows between unbounded preceding and current row),3
            ) balance
     from public.erp_journal_lines l
     join public.erp_journal_entries e on e.id=l.entry_id
     join public.erp_accounts a on a.id=l.account_id
     where l.account_id=p_account_id and e.entry_date between p_from and p_to
   ) z),'[]'::jsonb)
 ) into r
 from public.erp_accounts a where a.id=p_account_id;
 return coalesce(r,'{}'::jsonb);
end $$;

create or replace function public.erp_profit_loss_accounting(p_from date,p_to date)
returns jsonb language plpgsql security definer set search_path=public as $$
declare r jsonb; revenue numeric; cogs numeric; opex numeric; net numeric;
begin
 if not public.is_admin() then raise exception 'Admin access required'; end if;
 select coalesce(sum(case when a.account_type='revenue' then l.credit-l.debit else 0 end),0),
        coalesce(sum(case when a.code='5100' or lower(a.name) like '%cost of goods%' then l.debit-l.credit else 0 end),0),
        coalesce(sum(case when a.account_type='expense' and not (a.code='5100' or lower(a.name) like '%cost of goods%') then l.debit-l.credit else 0 end),0)
 into revenue,cogs,opex
 from public.erp_journal_lines l join public.erp_journal_entries e on e.id=l.entry_id join public.erp_accounts a on a.id=l.account_id
 where e.entry_date between p_from and p_to;
 net:=revenue-cogs-opex;
 return jsonb_build_object('from_date',p_from,'to_date',p_to,'revenue',round(revenue,3),'cost_of_goods_sold',round(cogs,3),'gross_profit',round(revenue-cogs,3),'operating_expenses',round(opex,3),'net_profit',round(net,3));
end $$;

create or replace function public.erp_balance_sheet(p_to date)
returns jsonb language plpgsql security definer set search_path=public as $$
declare assets numeric; liabilities numeric; equity numeric; retained numeric; tle numeric;
begin
 if not public.is_admin() then raise exception 'Admin access required'; end if;
 select coalesce(sum(case when a.account_type='asset' then l.debit-l.credit else 0 end),0),
        coalesce(sum(case when a.account_type='liability' then l.credit-l.debit else 0 end),0),
        coalesce(sum(case when a.account_type='equity' then l.credit-l.debit else 0 end),0)
 into assets,liabilities,equity
 from public.erp_journal_lines l join public.erp_journal_entries e on e.id=l.entry_id join public.erp_accounts a on a.id=l.account_id
 where e.entry_date<=p_to;
 select coalesce(sum(case when a.account_type='revenue' then l.credit-l.debit when a.account_type='expense' then l.debit-l.credit else 0 end),0)
 into retained
 from public.erp_journal_lines l join public.erp_journal_entries e on e.id=l.entry_id join public.erp_accounts a on a.id=l.account_id
 where e.entry_date<=p_to;
 tle:=liabilities+equity+retained;
 return jsonb_build_object('as_of_date',p_to,'assets',round(assets,3),'liabilities',round(liabilities,3),'equity',round(equity,3),'retained_earnings',round(retained,3),'total_liabilities_equity',round(tle,3),'balanced',abs(assets-tle)<0.001,'difference',round(assets-tle,3));
end $$;

create or replace function public.erp_cash_flow(p_from date,p_to date)
returns jsonb language plpgsql security definer set search_path=public as $$
declare ci numeric;co numeric;bi numeric;bo numeric;
begin
 if not public.is_admin() then raise exception 'Admin access required'; end if;
 select coalesce(sum(case when a.code='1000' then l.debit else 0 end),0),coalesce(sum(case when a.code='1000' then l.credit else 0 end),0),coalesce(sum(case when a.code='1100' then l.debit else 0 end),0),coalesce(sum(case when a.code='1100' then l.credit else 0 end),0)
 into ci,co,bi,bo
 from public.erp_journal_lines l join public.erp_journal_entries e on e.id=l.entry_id join public.erp_accounts a on a.id=l.account_id
 where e.entry_date between p_from and p_to;
 return jsonb_build_object('from_date',p_from,'to_date',p_to,'cash_in',round(ci,3),'cash_out',round(co,3),'cash_net',round(ci-co,3),'bank_in',round(bi,3),'bank_out',round(bo,3),'bank_net',round(bi-bo,3),'total_net',round(ci-co+bi-bo,3));
end $$;

create or replace function public.erp_financial_vat_summary(p_from date,p_to date)
returns jsonb language plpgsql security definer set search_path=public as $$
declare ov numeric;iv numeric;sn numeric;pn numeric;
begin
 if not public.is_admin() then raise exception 'Admin access required'; end if;
 select coalesce(sum(case when a.code='2100' then l.credit-l.debit else 0 end),0) into ov from public.erp_journal_lines l join public.erp_journal_entries e on e.id=l.entry_id join public.erp_accounts a on a.id=l.account_id where e.entry_date between p_from and p_to;
 select coalesce(sum(case when a.code='2100' then l.debit-l.credit else 0 end),0) into iv from public.erp_journal_lines l join public.erp_journal_entries e on e.id=l.entry_id join public.erp_accounts a on a.id=l.account_id where e.entry_date between p_from and p_to;
 select coalesce(sum(taxable_amount),0) into sn from public.erp_invoices where issue_date between p_from and p_to and status<>'cancelled';
 select coalesce(sum(amount),0) into pn from public.erp_expenses where expense_date between p_from and p_to;
 return jsonb_build_object('from_date',p_from,'to_date',p_to,'sales_net',round(sn,3),'purchase_net',round(pn,3),'output_vat',round(ov,3),'input_vat',round(iv,3),'net_vat',round(ov-iv,3));
end $$;

create or replace function public.erp_accounting_control_check(p_from date,p_to date)
returns jsonb language plpgsql security definer set search_path=public as $$
declare entries_count bigint; lines_count bigint; td numeric; tc numeric; diff numeric; unbalanced bigint;
begin
 if not public.is_admin() then raise exception 'Admin access required'; end if;
 select count(*) into entries_count from public.erp_journal_entries where entry_date between p_from and p_to;
 select count(*) into lines_count from public.erp_journal_lines l join public.erp_journal_entries e on e.id=l.entry_id where e.entry_date between p_from and p_to;
 select coalesce(sum(l.debit),0),coalesce(sum(l.credit),0) into td,tc from public.erp_journal_lines l join public.erp_journal_entries e on e.id=l.entry_id where e.entry_date between p_from and p_to;
 select count(*) into unbalanced from (select e.id from public.erp_journal_entries e join public.erp_journal_lines l on l.entry_id=e.id where e.entry_date between p_from and p_to group by e.id having abs(sum(l.debit)-sum(l.credit))>=0.001) q;
 diff:=td-tc;
 return jsonb_build_object('from_date',p_from,'to_date',p_to,'journal_entries',entries_count,'journal_lines',lines_count,'total_debit',round(td,3),'total_credit',round(tc,3),'difference',round(diff,3),'unbalanced_entries',unbalanced,'ok',abs(diff)<0.001 and unbalanced=0);
end $$;


-- Post operating expenses automatically into the double-entry journal.
create or replace function public.erp_post_expense_journal()
returns trigger language plpgsql security definer set search_path=public as $$
declare entry_id uuid; expense_account uuid; vat_account uuid; cash_account uuid;
begin
 select id into expense_account from public.erp_accounts where code='5000';
 select id into vat_account from public.erp_accounts where code='2100';
 if new.payment_method in ('bank','card') then select id into cash_account from public.erp_accounts where code='1100';
 else select id into cash_account from public.erp_accounts where code='1000'; end if;
 if expense_account is null or cash_account is null then return new; end if;
 if exists(select 1 from public.erp_journal_entries where source_type='expense' and source_id=new.id) then return new; end if;
 insert into public.erp_journal_entries(entry_number,entry_date,description,source_type,source_id,created_by)
 values('JE-EXP-'||substr(replace(gen_random_uuid()::text,'-',''),1,12),new.expense_date,'Expense '||new.expense_number,'expense',new.id,new.created_by)
 returning id into entry_id;
 insert into public.erp_journal_lines(entry_id,account_id,debit,credit,description) values(entry_id,expense_account,new.amount,0,'Operating expense');
 if coalesce(new.vat_amount,0)>0 and vat_account is not null then
   insert into public.erp_journal_lines(entry_id,account_id,debit,credit,description) values(entry_id,vat_account,new.vat_amount,0,'Input VAT');
 end if;
 insert into public.erp_journal_lines(entry_id,account_id,debit,credit,description) values(entry_id,cash_account,0,new.total,'Expense payment');
 return new;
end $$;

drop trigger if exists trg_erp_expense_journal on public.erp_expenses;
create trigger trg_erp_expense_journal after insert on public.erp_expenses for each row execute function public.erp_post_expense_journal();

-- Backfill journal entries for expenses created before Step 24.
do $$
declare e record; expense_account uuid; vat_account uuid; cash_account uuid; entry_id uuid;
begin
 select id into expense_account from public.erp_accounts where code='5000';
 select id into vat_account from public.erp_accounts where code='2100';
 for e in select * from public.erp_expenses where not exists(select 1 from public.erp_journal_entries j where j.source_type='expense' and j.source_id=erp_expenses.id) loop
   if e.payment_method in ('bank','card') then select id into cash_account from public.erp_accounts where code='1100'; else select id into cash_account from public.erp_accounts where code='1000'; end if;
   insert into public.erp_journal_entries(entry_number,entry_date,description,source_type,source_id,created_by) values('JE-EXP-'||substr(replace(gen_random_uuid()::text,'-',''),1,12),e.expense_date,'Expense '||e.expense_number,'expense',e.id,e.created_by) returning id into entry_id;
   insert into public.erp_journal_lines(entry_id,account_id,debit,credit,description) values(entry_id,expense_account,e.amount,0,'Operating expense');
   if coalesce(e.vat_amount,0)>0 and vat_account is not null then insert into public.erp_journal_lines(entry_id,account_id,debit,credit,description) values(entry_id,vat_account,e.vat_amount,0,'Input VAT'); end if;
   insert into public.erp_journal_lines(entry_id,account_id,debit,credit,description) values(entry_id,cash_account,0,e.total,'Expense payment');
 end loop;
end $$;

-- Rebuild permissions for the reporting functions.
revoke all on function public.erp_trial_balance(date,date) from public;
grant execute on function public.erp_trial_balance(date,date) to authenticated;
revoke all on function public.erp_general_ledger(date,date,uuid) from public;
grant execute on function public.erp_general_ledger(date,date,uuid) to authenticated;
revoke all on function public.erp_profit_loss_accounting(date,date) from public;
grant execute on function public.erp_profit_loss_accounting(date,date) to authenticated;
revoke all on function public.erp_balance_sheet(date) from public;
grant execute on function public.erp_balance_sheet(date) to authenticated;
revoke all on function public.erp_cash_flow(date,date) from public;
grant execute on function public.erp_cash_flow(date,date) to authenticated;
revoke all on function public.erp_financial_vat_summary(date,date) from public;
grant execute on function public.erp_financial_vat_summary(date,date) to authenticated;
revoke all on function public.erp_accounting_control_check(date,date) from public;
grant execute on function public.erp_accounting_control_check(date,date) to authenticated;
