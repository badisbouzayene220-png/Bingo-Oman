-- BINGO Oman ERP — Accounting Repair V1
-- Run AFTER setup_erp.sql, setup_step9_products_inventory.sql,
-- setup_step10_invoices_sales.sql and setup_finance_expansion_fixed.sql.
-- Purpose: correct COGS, weighted-average inventory cost, VAT reporting,
-- purchase/payment validation and dashboard/financial report consistency.

-- Required accounts.
insert into public.erp_accounts(code,name,account_type) values
 ('1300','Inventory','asset'),
 ('1305','Input VAT Receivable','asset'),
 ('2000','Accounts Payable','liability'),
 ('5100','Cost of Goods Sold','expense')
on conflict (code) do update set name=excluded.name, account_type=excluded.account_type;

-- Purchase posting: received purchases increase inventory, update weighted-average
-- product cost, record input VAT and accounts payable.
create or replace function public.erp_create_purchase(p_purchase jsonb,p_items jsonb)
returns jsonb language plpgsql security definer set search_path=public as $$
declare
 v_iid uuid; v_pno text; v_item jsonb; v_pid uuid; v_qty numeric; v_cost numeric; v_disc numeric; v_line numeric;
 v_sub numeric:=0; v_totaldisc numeric:=0; v_taxable numeric:=0; v_vat numeric:=0; v_total numeric:=0; v_rate numeric;
 v_status text; v_oldstatus text; v_prod public.erp_products; v_beforeq numeric; v_afterq numeric; v_oldcost numeric; v_newcost numeric;
 v_invacct uuid; v_apacct uuid; v_vatacct uuid; v_entryid uuid;
begin
 if not public.is_admin() then raise exception 'Admin access required'; end if;
 v_status:=coalesce(nullif(p_purchase->>'status',''),'draft');
 if v_status not in ('draft','received') then raise exception 'Purchase can only be Draft or Received'; end if;
 v_rate:=coalesce((p_purchase->>'vat_rate')::numeric,5);
 if v_rate<0 or v_rate>100 then raise exception 'Invalid VAT rate'; end if;

 if nullif(p_purchase->>'id','') is not null then
   v_iid:=(p_purchase->>'id')::uuid;
   select ep.status into v_oldstatus from public.erp_purchases ep where ep.id=v_iid for update;
   if v_oldstatus is null then raise exception 'Purchase not found'; end if;
   if v_oldstatus<>'draft' then raise exception 'Received purchases cannot be edited'; end if;
   if exists(select 1 from public.erp_supplier_payments sp where sp.purchase_id=v_iid) then
     raise exception 'A purchase with payments cannot be edited.';
   end if;
   delete from public.erp_purchase_items where purchase_id=v_iid;
   update public.erp_purchases ep set supplier_id=nullif(p_purchase->>'supplier_id','')::uuid,
     purchase_date=coalesce((p_purchase->>'purchase_date')::date,current_date),
     due_date=nullif(p_purchase->>'due_date','')::date,status=v_status,vat_rate=v_rate,
     notes=nullif(trim(p_purchase->>'notes'),'') where ep.id=v_iid;
 else
   v_pno:=coalesce(nullif(trim(p_purchase->>'purchase_number'),''),'PUR-'||to_char(current_date,'YYYYMMDD')||'-'||upper(substr(replace(gen_random_uuid()::text,'-',''),1,6)));
   insert into public.erp_purchases(purchase_number,supplier_id,purchase_date,due_date,status,vat_rate,notes,created_by)
   values(v_pno,nullif(p_purchase->>'supplier_id','')::uuid,coalesce((p_purchase->>'purchase_date')::date,current_date),
     nullif(p_purchase->>'due_date','')::date,v_status,v_rate,nullif(trim(p_purchase->>'notes'),''),auth.uid()) returning id into v_iid;
 end if;

 if jsonb_array_length(coalesce(p_items,'[]'::jsonb))=0 then raise exception 'Add at least one purchase item'; end if;

 for v_item in select * from jsonb_array_elements(coalesce(p_items,'[]'::jsonb)) loop
   v_pid:=nullif(v_item->>'product_id','')::uuid; v_qty:=coalesce((v_item->>'quantity')::numeric,0); v_cost:=coalesce((v_item->>'unit_cost')::numeric,0);
   v_disc:=coalesce((v_item->>'discount')::numeric,0);
   if v_qty<=0 or v_cost<0 or v_disc<0 then raise exception 'Invalid purchase item'; end if;
   if v_disc > v_qty*v_cost then raise exception 'Discount cannot exceed purchase line value'; end if;
   if v_status='received' and v_pid is null then raise exception 'Every received purchase item must be linked to a product'; end if;
   if v_pid is not null and not exists(select 1 from public.erp_products where id=v_pid and is_active=true) then
     raise exception 'Product not found or inactive';
   end if;
   v_line:=round((v_qty*v_cost)-v_disc,3); v_sub:=v_sub+round(v_qty*v_cost,3); v_totaldisc:=v_totaldisc+v_disc;
   insert into public.erp_purchase_items(purchase_id,product_id,description,quantity,unit_cost,discount,line_total)
   values(v_iid,v_pid,coalesce(nullif(trim(v_item->>'description'),''),(select ep.name from public.erp_products ep where ep.id=v_pid),'Item'),v_qty,v_cost,v_disc,v_line);
 end loop;

 v_taxable:=round(greatest(v_sub-v_totaldisc,0),3); v_vat:=round(v_taxable*v_rate/100,3); v_total:=round(v_taxable+v_vat,3);
 update public.erp_purchases ep set subtotal=v_sub,discount=v_totaldisc,taxable_amount=v_taxable,vat_amount=v_vat,total=v_total,
   paid_amount=coalesce((select sum(sp.amount) from public.erp_supplier_payments sp where sp.purchase_id=v_iid),0),updated_at=now() where ep.id=v_iid;

 if v_status='received' and v_oldstatus is distinct from 'received' then
   -- Inventory quantity + weighted-average cost. Discount is applied to the line cost.
   for v_item in select * from jsonb_array_elements(coalesce(p_items,'[]'::jsonb)) loop
     v_pid:=(v_item->>'product_id')::uuid; v_qty:=(v_item->>'quantity')::numeric; v_cost:=(v_item->>'unit_cost')::numeric; v_disc:=coalesce((v_item->>'discount')::numeric,0);
     select * into v_prod from public.erp_products ep where ep.id=v_pid for update;
     if v_prod.id is null then raise exception 'Product not found'; end if;
     v_beforeq:=v_prod.stock_qty; v_afterq:=v_beforeq+v_qty; v_oldcost:=coalesce(v_prod.cost_price,0);
     v_newcost:=case when v_afterq>0 then round(((v_beforeq*v_oldcost)+greatest(v_qty*v_cost-v_disc,0))/v_afterq,3) else v_oldcost end;
     update public.erp_products ep set stock_qty=v_afterq,cost_price=v_newcost,updated_at=now() where ep.id=v_pid;
     insert into public.erp_stock_movements(product_id,movement_type,quantity,quantity_before,quantity_after,reference_type,reference_id,reference_text,created_by)
     values(v_pid,'in',v_qty,v_beforeq,v_afterq,'purchase',v_iid,(select ep.purchase_number from public.erp_purchases ep where ep.id=v_iid),auth.uid());
   end loop;

   select id into v_invacct from public.erp_accounts where code='1300';
   select id into v_apacct from public.erp_accounts where code='2000';
   select id into v_vatacct from public.erp_accounts where code='1305';
   if v_invacct is null or v_apacct is null or (v_vat>0 and v_vatacct is null) then raise exception 'Required purchase accounting accounts are missing'; end if;
   insert into public.erp_journal_entries(entry_number,entry_date,description,source_type,source_id,created_by)
   values('PUR-JE-'||replace(v_iid::text,'-',''),(select ep.purchase_date from public.erp_purchases ep where ep.id=v_iid),'Purchase received','purchase',v_iid,auth.uid()) returning id into v_entryid;
   insert into public.erp_journal_lines(entry_id,account_id,debit,credit,description) values(v_entryid,v_invacct,v_taxable,0,'Inventory received');
   if v_vat>0 then insert into public.erp_journal_lines(entry_id,account_id,debit,credit,description) values(v_entryid,v_vatacct,v_vat,0,'Input VAT'); end if;
   insert into public.erp_journal_lines(entry_id,account_id,debit,credit,description) values(v_entryid,v_apacct,0,v_total,'Accounts payable');
 end if;
 return (select to_jsonb(ep) from public.erp_purchases ep where ep.id=v_iid);
end $$;

grant execute on function public.erp_create_purchase(jsonb,jsonb) to authenticated;

-- Supplier payments must be tied to a received purchase. This prevents a payment
-- from silently reducing supplier balances without a corresponding payable.
create or replace function public.erp_record_supplier_payment(p_payment jsonb)
returns jsonb language plpgsql security definer set search_path=public as $$
declare pid uuid; sid uuid; amt numeric; bal numeric; m text; cashacct uuid; apacct uuid; entryid uuid; r public.erp_supplier_payments; pstatus text; ptotal numeric; psupplier uuid;
begin
 if not public.is_admin() then raise exception 'Admin access required'; end if;
 pid:=nullif(p_payment->>'purchase_id','')::uuid; amt:=(p_payment->>'amount')::numeric; m:=coalesce(nullif(p_payment->>'method',''),'bank');
 if pid is null then raise exception 'Purchase is required for supplier payment'; end if;
 if amt is null or amt<=0 then raise exception 'Invalid amount'; end if;
 if m not in ('cash','bank','card') then raise exception 'Invalid payment method'; end if;
 select total,status,supplier_id into ptotal,pstatus,psupplier from public.erp_purchases where id=pid for update;
 if ptotal is null then raise exception 'Purchase not found'; end if;
 if pstatus not in ('received','partially_paid','paid') then raise exception 'Only received purchases can be paid'; end if;
 if psupplier is null then raise exception 'Purchase must have a supplier before payment'; end if;
 select greatest(ptotal-coalesce((select sum(amount) from public.erp_supplier_payments where purchase_id=pid),0),0) into bal;
 if amt>bal then raise exception 'Payment exceeds purchase balance'; end if;
 sid:=psupplier;
 insert into public.erp_supplier_payments(purchase_id,supplier_id,payment_date,amount,method,reference,notes,created_by)
 values(pid,sid,coalesce((p_payment->>'payment_date')::date,current_date),amt,m,nullif(trim(p_payment->>'reference'),''),nullif(trim(p_payment->>'notes'),''),auth.uid()) returning * into r;
 update public.erp_purchases set paid_amount=(select sum(amount) from public.erp_supplier_payments where purchase_id=pid),
   status=case when (select sum(amount) from public.erp_supplier_payments where purchase_id=pid)>=total then 'paid' when (select sum(amount) from public.erp_supplier_payments where purchase_id=pid)>0 then 'partially_paid' else 'received' end,
   updated_at=now() where id=pid;
 select id into apacct from public.erp_accounts where code='2000';
 select id into cashacct from public.erp_accounts where code=case when m='cash' then '1000' else '1100' end;
 if apacct is null or cashacct is null then raise exception 'Required payment accounts are missing'; end if;
 insert into public.erp_journal_entries(entry_number,entry_date,description,source_type,source_id,created_by)
 values('SP-JE-'||replace(r.id::text,'-',''),r.payment_date,'Supplier payment','supplier_payment',r.id,auth.uid()) returning id into entryid;
 insert into public.erp_journal_lines(entry_id,account_id,debit,credit,description) values(entryid,apacct,amt,0,'Accounts payable settled');
 insert into public.erp_journal_lines(entry_id,account_id,debit,credit,description) values(entryid,cashacct,0,amt,'Cash/Bank paid');
 return to_jsonb(r);
end $$;

grant execute on function public.erp_record_supplier_payment(jsonb) to authenticated;

-- Sales posting: reduce stock and record COGS using the product's weighted-average
-- cost immediately before the sale.
create or replace function public.erp_create_invoice(p_invoice jsonb,p_items jsonb)
returns jsonb language plpgsql security definer set search_path=public as $$
declare
 iid uuid; invno text; vat numeric; sub numeric:=0; disc numeric:=0; taxable numeric:=0; vatamt numeric:=0; total numeric:=0;
 item jsonb; itemdisc numeric; qty numeric; unitprice numeric; linetotal numeric; pid uuid; old_status text:='draft'; new_status text;
 p public.erp_products; before_qty numeric; after_qty numeric; cost numeric; cogs numeric:=0; entry_id uuid; ar_account uuid; revenue_account uuid; vat_account uuid; inventory_account uuid; cogs_account uuid; r jsonb;
begin
 if not public.is_admin() then raise exception 'Admin access required'; end if;
 new_status:=coalesce(nullif(p_invoice->>'status',''),'draft');
 if new_status not in ('draft','issued') then raise exception 'New invoices can only be Draft or Issued'; end if;
 vat:=coalesce((p_invoice->>'vat_rate')::numeric,(select vat_rate from public.erp_company_settings where id='default'),5);
 if vat<0 or vat>100 then raise exception 'Invalid VAT rate'; end if;
 if nullif(p_invoice->>'id','') is not null then
   iid:=(p_invoice->>'id')::uuid; select status into old_status from public.erp_invoices where id=iid for update;
   if old_status is null then raise exception 'Invoice not found'; end if;
   if old_status in ('issued','partially_paid','paid','overdue','cancelled') then raise exception 'Issued or completed invoices cannot be edited. Create a new invoice or cancel it first.'; end if;
   delete from public.erp_invoice_items where invoice_id=iid;
   update public.erp_invoices set customer_id=nullif(p_invoice->>'customer_id','')::uuid,issue_date=coalesce((p_invoice->>'issue_date')::date,current_date),due_date=nullif(p_invoice->>'due_date','')::date,status=new_status,vat_rate=vat,notes=nullif(trim(p_invoice->>'notes'),'') ,updated_at=now() where id=iid;
 else
   invno:=coalesce(nullif(trim(p_invoice->>'invoice_number'),''),public.erp_next_number('invoice'));
   insert into public.erp_invoices(invoice_number,customer_id,issue_date,due_date,status,vat_rate,notes,created_by)
   values(invno,nullif(p_invoice->>'customer_id','')::uuid,coalesce((p_invoice->>'issue_date')::date,current_date),nullif((p_invoice->>'due_date'),'')::date,new_status,vat,nullif(trim(p_invoice->>'notes'),''),auth.uid()) returning id into iid;
 end if;
 if jsonb_array_length(coalesce(p_items,'[]'::jsonb))=0 then raise exception 'Add at least one invoice item'; end if;
 for item in select * from jsonb_array_elements(coalesce(p_items,'[]'::jsonb)) loop
   qty:=coalesce((item->>'quantity')::numeric,0); unitprice:=coalesce((item->>'unit_price')::numeric,0); itemdisc:=coalesce((item->>'discount')::numeric,0); pid:=nullif(item->>'product_id','')::uuid;
   if qty<=0 then raise exception 'Quantity must be greater than zero'; end if; if unitprice<0 then raise exception 'Unit price cannot be negative'; end if; if itemdisc<0 or itemdisc>qty*unitprice then raise exception 'Invalid line discount'; end if;
   if nullif(trim(item->>'description'),'') is null then raise exception 'Each invoice item needs a description'; end if;
   linetotal:=round((qty*unitprice)-itemdisc,3); sub:=sub+round(qty*unitprice,3); disc:=disc+itemdisc;
   if pid is not null and not exists(select 1 from public.erp_products where id=pid and is_active=true) then raise exception 'Product not found or inactive'; end if;
   if new_status='issued' and pid is null then raise exception 'Every stock sale item must be linked to a product'; end if;
   insert into public.erp_invoice_items(invoice_id,product_id,description,quantity,unit_price,discount,line_total) values(iid,pid,trim(item->>'description'),qty,unitprice,itemdisc,linetotal);
 end loop;
 taxable:=round(greatest(sub-disc,0),3); vatamt:=round(taxable*vat/100,3); total:=round(taxable+vatamt,3);
 update public.erp_invoices set subtotal=sub,discount=disc,taxable_amount=taxable,vat_amount=vatamt,total=total,updated_at=now() where id=iid;

 if new_status='issued' then
   -- Calculate COGS from cost_price before changing stock.
   for item in select * from jsonb_array_elements(coalesce(p_items,'[]'::jsonb)) loop
     pid:=(item->>'product_id')::uuid; qty:=(item->>'quantity')::numeric;
     select * into p from public.erp_products where id=pid for update;
     if p.id is null then raise exception 'Product not found'; end if;
     before_qty:=p.stock_qty; after_qty:=before_qty-qty;
     if after_qty<0 then raise exception 'Insufficient stock for %. Current stock: %, requested: %',p.name,before_qty,qty; end if;
     cost:=round(qty*coalesce(p.cost_price,0),3); cogs:=cogs+cost;
     update public.erp_products set stock_qty=after_qty,updated_at=now() where id=p.id;
     insert into public.erp_stock_movements(product_id,movement_type,quantity,quantity_before,quantity_after,reference_type,reference_id,reference_text,movement_date,notes,created_by)
     values(p.id,'out',qty,before_qty,after_qty,'invoice',iid,(select invoice_number from public.erp_invoices where id=iid),coalesce((p_invoice->>'issue_date')::date,current_date),'Stock issued for sales invoice',auth.uid());
   end loop;
   select id into ar_account from public.erp_accounts where code='1200'; select id into revenue_account from public.erp_accounts where code='4000'; select id into vat_account from public.erp_accounts where code='2100';
   select id into inventory_account from public.erp_accounts where code='1300'; select id into cogs_account from public.erp_accounts where code='5100';
   if ar_account is null or revenue_account is null or (vatamt>0 and vat_account is null) or (cogs>0 and (inventory_account is null or cogs_account is null)) then raise exception 'Required accounting accounts are missing'; end if;
   insert into public.erp_journal_entries(entry_number,entry_date,description,source_type,source_id,created_by)
   values('JE-INV-'||substr(replace(gen_random_uuid()::text,'-',''),1,12),coalesce((p_invoice->>'issue_date')::date,current_date),'Sales invoice '||(select invoice_number from public.erp_invoices where id=iid),'invoice',iid,auth.uid()) returning id into entry_id;
   insert into public.erp_journal_lines(entry_id,account_id,debit,credit,description) values(entry_id,ar_account,total,0,'Accounts receivable');
   if taxable>0 then insert into public.erp_journal_lines(entry_id,account_id,debit,credit,description) values(entry_id,revenue_account,0,taxable,'Sales revenue'); end if;
   if vatamt>0 then insert into public.erp_journal_lines(entry_id,account_id,debit,credit,description) values(entry_id,vat_account,0,vatamt,'Output VAT'); end if;
   if cogs>0 then
     insert into public.erp_journal_lines(entry_id,account_id,debit,credit,description) values(entry_id,cogs_account,cogs,0,'Cost of goods sold');
     insert into public.erp_journal_lines(entry_id,account_id,debit,credit,description) values(entry_id,inventory_account,0,cogs,'Inventory cost released');
   end if;
 end if;
 select to_jsonb(i) into r from public.erp_invoices i where i.id=iid;
 insert into public.erp_audit_log(user_id,action,entity_type,entity_id,details) values(auth.uid(),case when new_status='issued' then 'invoice_issued' else 'invoice_saved' end,'invoice',iid,r);
 return r;
end $$;

grant execute on function public.erp_create_invoice(jsonb,jsonb) to authenticated;

-- Correct VAT summary: output VAT is account 2100, input VAT is account 1305.
-- Purchase net is taxable purchases; expense net is kept separately.
create or replace function public.erp_financial_vat_summary(p_from date,p_to date)
returns jsonb language plpgsql security definer set search_path=public as $$
declare ov numeric; iv numeric; sn numeric; pn numeric; en numeric; ev numeric;
begin
 if not public.is_admin() then raise exception 'Admin access required'; end if;
 select coalesce(sum(case when a.code='2100' then l.credit-l.debit else 0 end),0) into ov from public.erp_journal_lines l join public.erp_journal_entries e on e.id=l.entry_id join public.erp_accounts a on a.id=l.account_id where e.entry_date between p_from and p_to;
 select coalesce(sum(case when a.code='1305' then l.debit-l.credit else 0 end),0) into iv from public.erp_journal_lines l join public.erp_journal_entries e on e.id=l.entry_id join public.erp_accounts a on a.id=l.account_id where e.entry_date between p_from and p_to;
 select coalesce(sum(taxable_amount),0),coalesce(sum(vat_amount),0) into sn,pn from public.erp_purchases where purchase_date between p_from and p_to and status in ('received','partially_paid','paid');
 select coalesce(sum(amount),0),coalesce(sum(vat_amount),0) into en,ev from public.erp_expenses where expense_date between p_from and p_to;
 return jsonb_build_object('from_date',p_from,'to_date',p_to,'sales_net',round(coalesce((select sum(taxable_amount) from public.erp_invoices where issue_date between p_from and p_to and status<>'cancelled'),0),3),'purchase_net',round(sn,3),'expense_net',round(en,3),'output_vat',round(ov,3),'input_vat',round(iv,3),'purchase_vat',round(pn,3),'expense_vat',round(ev,3),'net_vat',round(ov-iv,3));
end $$;
grant execute on function public.erp_financial_vat_summary(date,date) to authenticated;

-- Dashboard/overview: drafts do not count as sales/purchases or liabilities.
create or replace function public.erp_dashboard(p_from date default (current_date - interval '30 days')::date,p_to date default current_date)
returns jsonb language plpgsql security definer set search_path=public as $$
declare result jsonb;
begin
 if not public.is_admin() then raise exception 'Admin access required'; end if;
 select jsonb_build_object(
  'from',p_from,'to',p_to,
  'sales',coalesce((select sum(total) from public.erp_invoices where issue_date between p_from and p_to and status<>'cancelled' and status<>'draft'),0),
  'paid',coalesce((select sum(amount) from public.erp_payments where payment_date between p_from and p_to),0),
  'expenses',coalesce((select sum(total) from public.erp_expenses where expense_date between p_from and p_to),0),
  'purchases',coalesce((select sum(total) from public.erp_purchases where purchase_date between p_from and p_to and status in ('received','partially_paid','paid')),0),
  'supplier_payments',coalesce((select sum(amount) from public.erp_supplier_payments where payment_date between p_from and p_to),0),
  'receivable',coalesce((select sum(total-paid_amount) from public.erp_invoices where status not in ('cancelled','paid','draft')),0),
  'payable',coalesce((select sum(total-paid_amount) from public.erp_purchases where status in ('received','partially_paid')),0),
  'vat_sales',coalesce((select sum(vat_amount) from public.erp_invoices where issue_date between p_from and p_to and status<>'cancelled' and status<>'draft'),0),
  'vat_expenses',coalesce((select sum(vat_amount) from public.erp_expenses where expense_date between p_from and p_to),0),
  'customers',(select count(*) from public.erp_customers where is_active),
  'invoices',(select count(*) from public.erp_invoices where issue_date between p_from and p_to and status<>'cancelled' and status<>'draft')
 ) into result;
 return result;
end $$;
grant execute on function public.erp_dashboard(date,date) to authenticated;

create or replace function public.erp_finance_overview(p_from date default (current_date-interval '30 days')::date,p_to date default current_date)
returns jsonb language plpgsql security definer set search_path=public as $$
declare r jsonb;
begin
 if not public.is_admin() then raise exception 'Admin access required'; end if;
 select jsonb_build_object(
  'sales',coalesce((select sum(total) from erp_invoices where issue_date between p_from and p_to and status not in ('cancelled','draft')),0),
  'collections',coalesce((select sum(amount) from erp_payments where payment_date between p_from and p_to),0),
  'purchases',coalesce((select sum(total) from erp_purchases where purchase_date between p_from and p_to and status in ('received','partially_paid','paid')),0),
  'supplier_payments',coalesce((select sum(amount) from erp_supplier_payments where payment_date between p_from and p_to),0),
  'expenses',coalesce((select sum(total) from erp_expenses where expense_date between p_from and p_to),0),
  'receivables',coalesce((select sum(total-coalesce(paid_amount,0)) from erp_invoices where status not in ('cancelled','paid','draft')),0),
  'payables',coalesce((select sum(total-coalesce(paid_amount,0)) from erp_purchases where status in ('received','partially_paid')),0),
  'output_vat',coalesce((select sum(vat_amount) from erp_invoices where issue_date between p_from and p_to and status not in ('cancelled','draft')),0),
  'input_vat',coalesce((select sum(vat_amount) from erp_purchases where purchase_date between p_from and p_to and status in ('received','partially_paid','paid')),0),
  'customers',(select count(*) from erp_customers where is_active),
  'suppliers',(select count(*) from erp_suppliers where is_active),
  'products',(select count(*) from erp_products where is_active)
 ) into r;
 return r;
end $$;
grant execute on function public.erp_finance_overview(date,date) to authenticated;

-- Control check with explicit account-balance sanity check.
create or replace function public.erp_accounting_control_check(p_from date,p_to date)
returns jsonb language plpgsql security definer set search_path=public as $$
declare entries_count bigint; lines_count bigint; td numeric; tc numeric; diff numeric; unbalanced bigint; negative_stock bigint; purchase_mismatch bigint; invoice_mismatch bigint;
begin
 if not public.is_admin() then raise exception 'Admin access required'; end if;
 select count(*) into entries_count from public.erp_journal_entries where entry_date between p_from and p_to;
 select count(*) into lines_count from public.erp_journal_lines l join public.erp_journal_entries e on e.id=l.entry_id where e.entry_date between p_from and p_to;
 select coalesce(sum(l.debit),0),coalesce(sum(l.credit),0) into td,tc from public.erp_journal_lines l join public.erp_journal_entries e on e.id=l.entry_id where e.entry_date between p_from and p_to;
 select count(*) into unbalanced from (select e.id from public.erp_journal_entries e join public.erp_journal_lines l on l.entry_id=e.id where e.entry_date between p_from and p_to group by e.id having abs(sum(l.debit)-sum(l.credit))>=0.001) q;
 select count(*) into negative_stock from public.erp_products where stock_qty<0;
 select count(*) into purchase_mismatch from public.erp_purchases p where p.status in ('received','partially_paid','paid') and (
   (p.status='paid' and coalesce((select sum(sp.amount) from public.erp_supplier_payments sp where sp.purchase_id=p.id),0)+0.001 < p.total) or
   (p.status='partially_paid' and (coalesce((select sum(sp.amount) from public.erp_supplier_payments sp where sp.purchase_id=p.id),0)<=0 or coalesce((select sum(sp.amount) from public.erp_supplier_payments sp where sp.purchase_id=p.id),0)+0.001 >= p.total))
 );
 select count(*) into invoice_mismatch from public.erp_invoices i where i.status not in ('cancelled','draft') and (
   (i.status='paid' and coalesce((select sum(pm.amount) from public.erp_payments pm where pm.invoice_id=i.id),0)+0.001 < i.total) or
   (i.status='partially_paid' and (coalesce((select sum(pm.amount) from public.erp_payments pm where pm.invoice_id=i.id),0)<=0 or coalesce((select sum(pm.amount) from public.erp_payments pm where pm.invoice_id=i.id),0)+0.001 >= i.total))
 );
 diff:=td-tc;
 return jsonb_build_object('from_date',p_from,'to_date',p_to,'journal_entries',entries_count,'journal_lines',lines_count,'total_debit',round(td,3),'total_credit',round(tc,3),'difference',round(diff,3),'unbalanced_entries',unbalanced,'negative_stock_products',negative_stock,'purchase_status_mismatches',purchase_mismatch,'invoice_status_mismatches',invoice_mismatch,'ok',abs(diff)<0.001 and unbalanced=0 and negative_stock=0 and purchase_mismatch=0 and invoice_mismatch=0);
end $$;
grant execute on function public.erp_accounting_control_check(date,date) to authenticated;

-- Repair note: existing sales that were posted before this repair do not have historical COGS
-- because the old journal did not store it. New issued sales will be correct. Existing stock
-- cost_price is used as the opening average cost for future sales.
