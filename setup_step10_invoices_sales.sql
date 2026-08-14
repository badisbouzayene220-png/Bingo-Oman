-- BINGO Oman ERP — Step 10: Invoices, Sales, VAT, Payments & Stock Integration
-- Run this file once in Supabase SQL Editor after Step 9.
-- Existing customers/products are preserved.

alter table public.erp_invoice_items
  add column if not exists product_id uuid references public.erp_products(id) on delete set null;

create index if not exists idx_erp_invoice_items_product on public.erp_invoice_items(product_id);

-- Keep invoice/payment tables admin-only.
alter table public.erp_invoice_items enable row level security;
alter table public.erp_invoices enable row level security;
alter table public.erp_payments enable row level security;

drop policy if exists erp_admin_all_invoices on public.erp_invoices;
create policy erp_admin_all_invoices on public.erp_invoices
for all to authenticated using (public.is_admin()) with check (public.is_admin());

drop policy if exists erp_admin_all_invoice_items on public.erp_invoice_items;
create policy erp_admin_all_invoice_items on public.erp_invoice_items
for all to authenticated using (public.is_admin()) with check (public.is_admin());

drop policy if exists erp_admin_all_payments on public.erp_payments;
create policy erp_admin_all_payments on public.erp_payments
for all to authenticated using (public.is_admin()) with check (public.is_admin());

-- Invoice list: includes customer and payment balance.
create or replace function public.erp_list_invoices(p_search text default null, p_status text default null)
returns jsonb
language plpgsql security definer set search_path=public
as $$
begin
  if not public.is_admin() then raise exception 'Admin access required'; end if;
  return coalesce((
    select jsonb_agg(to_jsonb(x) order by x.issue_date desc, x.created_at desc)
    from (
      select i.*, c.name as customer_name, c.company_name as customer_company,
             coalesce((select sum(p.amount) from public.erp_payments p where p.invoice_id=i.id),0) as calculated_paid,
             greatest(i.total - coalesce((select sum(p.amount) from public.erp_payments p where p.invoice_id=i.id),0),0) as balance
      from public.erp_invoices i
      left join public.erp_customers c on c.id=i.customer_id
      where (p_status is null or p_status='' or i.status=p_status)
        and (p_search is null or p_search='' or lower(concat_ws(' ',i.invoice_number,c.name,c.company_name,c.phone)) like '%'||lower(p_search)||'%')
      limit 500
    ) x
  ),'[]'::jsonb);
end $$;

revoke all on function public.erp_list_invoices(text,text) from public;
grant execute on function public.erp_list_invoices(text,text) to authenticated;

-- Create/update an invoice. When status becomes ISSUED, product stock is reduced
-- atomically and an accounting journal entry is created.
create or replace function public.erp_create_invoice(p_invoice jsonb, p_items jsonb)
returns jsonb
language plpgsql security definer set search_path=public
as $$
declare
  iid uuid;
  invno text;
  vat numeric;
  sub numeric := 0;
  disc numeric := 0;
  taxable numeric := 0;
  vatamt numeric := 0;
  total numeric := 0;
  item jsonb;
  itemdisc numeric;
  qty numeric;
  unitprice numeric;
  linetotal numeric;
  pid uuid;
  old_status text := 'draft';
  new_status text;
  p public.erp_products;
  before_qty numeric;
  after_qty numeric;
  entry_id uuid;
  ar_account uuid;
  revenue_account uuid;
  vat_account uuid;
  r jsonb;
begin
  if not public.is_admin() then raise exception 'Admin access required'; end if;

  new_status := coalesce(nullif(p_invoice->>'status',''),'draft');
  if new_status not in ('draft','issued') then
    raise exception 'New invoices can only be Draft or Issued';
  end if;

  vat := coalesce((p_invoice->>'vat_rate')::numeric,
                  (select vat_rate from public.erp_company_settings where id='default'),5);
  if vat < 0 or vat > 100 then raise exception 'Invalid VAT rate'; end if;

  if nullif(p_invoice->>'id','') is not null then
    iid := (p_invoice->>'id')::uuid;
    select status into old_status from public.erp_invoices where id=iid for update;
    if old_status is null then raise exception 'Invoice not found'; end if;
    if old_status in ('issued','partially_paid','paid','overdue','cancelled') then
      raise exception 'Issued or completed invoices cannot be edited. Create a new invoice or cancel it first.';
    end if;
    delete from public.erp_invoice_items where invoice_id=iid;
    update public.erp_invoices
      set customer_id=nullif(p_invoice->>'customer_id','')::uuid,
          issue_date=coalesce((p_invoice->>'issue_date')::date,current_date),
          due_date=nullif(p_invoice->>'due_date','')::date,
          status=new_status,
          vat_rate=vat,
          notes=nullif(trim(p_invoice->>'notes'),''),
          updated_at=now()
      where id=iid;
  else
    invno := coalesce(nullif(trim(p_invoice->>'invoice_number'),''),public.erp_next_number('invoice'));
    insert into public.erp_invoices(invoice_number,customer_id,issue_date,due_date,status,vat_rate,notes,created_by)
    values(invno,nullif(p_invoice->>'customer_id','')::uuid,
           coalesce((p_invoice->>'issue_date')::date,current_date),
           nullif(p_invoice->>'due_date','')::date,
           new_status,vat,nullif(trim(p_invoice->>'notes'),''),auth.uid())
    returning id into iid;
  end if;

  if jsonb_array_length(coalesce(p_items,'[]'::jsonb)) = 0 then
    raise exception 'Add at least one invoice item';
  end if;

  for item in select * from jsonb_array_elements(coalesce(p_items,'[]'::jsonb)) loop
    qty := coalesce((item->>'quantity')::numeric,0);
    unitprice := coalesce((item->>'unit_price')::numeric,0);
    itemdisc := coalesce((item->>'discount')::numeric,0);
    pid := nullif(item->>'product_id','')::uuid;

    if qty <= 0 then raise exception 'Quantity must be greater than zero'; end if;
    if unitprice < 0 then raise exception 'Unit price cannot be negative'; end if;
    if itemdisc < 0 then raise exception 'Discount cannot be negative'; end if;
    if itemdisc > qty*unitprice then raise exception 'Discount cannot exceed line value'; end if;
    if nullif(trim(item->>'description'),'') is null then raise exception 'Each invoice item needs a description'; end if;

    linetotal := round((qty*unitprice)-itemdisc,3);
    sub := sub + (qty*unitprice);
    disc := disc + itemdisc;

    if pid is not null then
      if not exists(select 1 from public.erp_products where id=pid and is_active=true) then
        raise exception 'Product not found or inactive';
      end if;
    end if;

    insert into public.erp_invoice_items(invoice_id,product_id,description,quantity,unit_price,discount,line_total)
    values(iid,pid,trim(item->>'description'),qty,unitprice,itemdisc,linetotal);
  end loop;

  taxable := greatest(sub-disc,0);
  vatamt := round(taxable*vat/100,3);
  total := taxable+vatamt;

  update public.erp_invoices
  set subtotal=sub,discount=disc,taxable_amount=taxable,vat_amount=vatamt,total=total,updated_at=now()
  where id=iid;

  -- Only an issued invoice affects inventory and accounting.
  if new_status='issued' then
    for item in select * from jsonb_array_elements(coalesce(p_items,'[]'::jsonb)) loop
      pid := nullif(item->>'product_id','')::uuid;
      qty := coalesce((item->>'quantity')::numeric,0);
      if pid is not null then
        select * into p from public.erp_products where id=pid for update;
        before_qty := p.stock_qty;
        after_qty := before_qty-qty;
        if after_qty < 0 then
          raise exception 'Insufficient stock for %. Current stock: %, requested: %',p.name,before_qty,qty;
        end if;
        update public.erp_products set stock_qty=after_qty,updated_at=now() where id=p.id;
        insert into public.erp_stock_movements(
          product_id,movement_type,quantity,quantity_before,quantity_after,
          reference_type,reference_id,reference_text,movement_date,notes,created_by
        ) values(
          p.id,'out',qty,before_qty,after_qty,'invoice',iid,
          (select invoice_number from public.erp_invoices where id=iid),
          coalesce((p_invoice->>'issue_date')::date,current_date),
          'Stock issued for sales invoice',auth.uid()
        );
      end if;
    end loop;

    select id into ar_account from public.erp_accounts where code='1200';
    select id into revenue_account from public.erp_accounts where code='4000';
    select id into vat_account from public.erp_accounts where code='2100';
    if ar_account is null or revenue_account is null or vat_account is null then
      raise exception 'Required accounting accounts are missing';
    end if;

    insert into public.erp_journal_entries(entry_number,entry_date,description,source_type,source_id,created_by)
    values('JE-INV-'||substr(replace(gen_random_uuid()::text,'-',''),1,12),
           coalesce((p_invoice->>'issue_date')::date,current_date),
           'Sales invoice '||(select invoice_number from public.erp_invoices where id=iid),
           'invoice',iid,auth.uid()) returning id into entry_id;

    insert into public.erp_journal_lines(entry_id,account_id,debit,credit,description)
    values(entry_id,ar_account,total,0,'Accounts receivable');
    if taxable > 0 then
      insert into public.erp_journal_lines(entry_id,account_id,debit,credit,description)
      values(entry_id,revenue_account,0,taxable,'Sales revenue');
    end if;
    if vatamt > 0 then
      insert into public.erp_journal_lines(entry_id,account_id,debit,credit,description)
      values(entry_id,vat_account,0,vatamt,'Output VAT');
    end if;
  end if;

  select to_jsonb(i) into r from public.erp_invoices i where i.id=iid;
  insert into public.erp_audit_log(user_id,action,entity_type,entity_id,details)
  values(auth.uid(),case when new_status='issued' then 'invoice_issued' else 'invoice_saved' end,'invoice',iid,r);
  return r;
end $$;

revoke all on function public.erp_create_invoice(jsonb,jsonb) from public;
grant execute on function public.erp_create_invoice(jsonb,jsonb) to authenticated;

-- Record a payment, update invoice status, and post the payment to Cash/Bank vs Receivables.
create or replace function public.erp_record_payment(p_payment jsonb)
returns jsonb
language plpgsql security definer set search_path=public
as $$
declare
  pid uuid;
  iid uuid;
  cid uuid;
  amt numeric;
  inv_total numeric;
  current_paid numeric;
  new_paid numeric;
  method text;
  inv_status text;
  cash_account uuid;
  ar_account uuid;
  entry_id uuid;
  r jsonb;
begin
  if not public.is_admin() then raise exception 'Admin access required'; end if;
  iid := nullif(p_payment->>'invoice_id','')::uuid;
  amt := (p_payment->>'amount')::numeric;
  method := coalesce(nullif(p_payment->>'method',''),'cash');
  if amt is null or amt<=0 then raise exception 'Payment amount must be greater than zero'; end if;
  if iid is null then raise exception 'Invoice is required'; end if;

  select total,customer_id,status,paid_amount into inv_total,cid,inv_status,current_paid
  from public.erp_invoices where id=iid for update;
  if inv_total is null then raise exception 'Invoice not found'; end if;
  if inv_status='cancelled' then raise exception 'Cancelled invoice cannot receive payment'; end if;
  current_paid := coalesce((select sum(p.amount) from public.erp_payments p where p.invoice_id=iid),0);
  if current_paid+amt > inv_total then
    raise exception 'Payment exceeds invoice balance. Remaining balance: %',round(inv_total-current_paid,3);
  end if;

  insert into public.erp_payments(invoice_id,customer_id,payment_date,amount,method,reference,notes,created_by)
  values(iid,cid,coalesce((p_payment->>'payment_date')::date,current_date),amt,method,
         nullif(trim(p_payment->>'reference'),''),nullif(trim(p_payment->>'notes'),''),auth.uid())
  returning id into pid;

  new_paid := current_paid+amt;
  update public.erp_invoices
  set paid_amount=new_paid,
      status=case when new_paid>=total then 'paid' when new_paid>0 then 'partially_paid' else status end,
      updated_at=now()
  where id=iid;

  if method in ('bank','card') then
    select id into cash_account from public.erp_accounts where code='1100';
  else
    select id into cash_account from public.erp_accounts where code='1000';
  end if;
  select id into ar_account from public.erp_accounts where code='1200';
  if cash_account is null or ar_account is null then raise exception 'Required payment accounts are missing'; end if;

  insert into public.erp_journal_entries(entry_number,entry_date,description,source_type,source_id,created_by)
  values('JE-PAY-'||substr(replace(gen_random_uuid()::text,'-',''),1,12),
         coalesce((p_payment->>'payment_date')::date,current_date),
         'Payment for invoice '||(select invoice_number from public.erp_invoices where id=iid),
         'payment',pid,auth.uid()) returning id into entry_id;
  insert into public.erp_journal_lines(entry_id,account_id,debit,credit,description)
  values(entry_id,cash_account,amt,0,'Cash/Bank received');
  insert into public.erp_journal_lines(entry_id,account_id,debit,credit,description)
  values(entry_id,ar_account,0,amt,'Accounts receivable settled');

  select to_jsonb(p) into r from public.erp_payments p where p.id=pid;
  insert into public.erp_audit_log(user_id,action,entity_type,entity_id,details)
  values(auth.uid(),'payment_recorded','payment',pid,r);
  return r;
end $$;

revoke all on function public.erp_record_payment(jsonb) from public;
grant execute on function public.erp_record_payment(jsonb) to authenticated;

-- Cancel an issued invoice only when it has no payments; restore its stock and reverse its journal.
create or replace function public.erp_cancel_invoice(p_invoice_id uuid, p_reason text default null)
returns jsonb
language plpgsql security definer set search_path=public
as $$
declare
  inv public.erp_invoices;
  item record;
  p public.erp_products;
  entry record;
  before_qty numeric;
  after_qty numeric;
  r jsonb;
begin
  if not public.is_admin() then raise exception 'Admin access required'; end if;
  select * into inv from public.erp_invoices where id=p_invoice_id for update;
  if inv.id is null then raise exception 'Invoice not found'; end if;
  if inv.status='cancelled' then return to_jsonb(inv); end if;
  if coalesce((select sum(amount) from public.erp_payments where invoice_id=inv.id),0)>0 then
    raise exception 'Paid invoices cannot be cancelled. Reverse/refund the payment first.';
  end if;

  if inv.status in ('issued','partially_paid','paid','overdue') then
    for item in select product_id,quantity from public.erp_invoice_items where invoice_id=inv.id and product_id is not null loop
      select * into p from public.erp_products where id=item.product_id for update;
      if p.id is not null then
        before_qty:=p.stock_qty;
        after_qty:=before_qty+item.quantity;
        update public.erp_products set stock_qty=after_qty,updated_at=now() where id=p.id;
        insert into public.erp_stock_movements(product_id,movement_type,quantity,quantity_before,quantity_after,reference_type,reference_id,reference_text,movement_date,notes,created_by)
        values(p.id,'in',item.quantity,before_qty,after_qty,'invoice_cancel',inv.id,inv.invoice_number,current_date,'Stock restored after invoice cancellation',auth.uid());
      end if;
    end loop;

    for entry in select je.id from public.erp_journal_entries je where je.source_type='invoice' and je.source_id=inv.id loop
      delete from public.erp_journal_lines where entry_id=entry.id;
      delete from public.erp_journal_entries where id=entry.id;
    end loop;
  end if;

  update public.erp_invoices set status='cancelled',updated_at=now(),notes=concat_ws(E'\n',notes,case when nullif(trim(p_reason),'') is not null then 'Cancellation: '||trim(p_reason) end) where id=inv.id returning * into inv;
  select to_jsonb(inv) into r;
  insert into public.erp_audit_log(user_id,action,entity_type,entity_id,details)
  values(auth.uid(),'invoice_cancelled','invoice',inv.id,jsonb_build_object('invoice',r,'reason',p_reason));
  return r;
end $$;

revoke all on function public.erp_cancel_invoice(uuid,text) from public;
grant execute on function public.erp_cancel_invoice(uuid,text) to authenticated;

-- Invoice items for printing now include product information.
create or replace function public.erp_get_invoice_items(p_invoice_id uuid)
returns jsonb language sql security definer set search_path=public
as $$
  select coalesce(jsonb_agg(to_jsonb(x) order by x.created_at),'[]'::jsonb)
  from (
    select i.*, p.sku as product_sku, p.name as product_name
    from public.erp_invoice_items i
    left join public.erp_products p on p.id=i.product_id
    where i.invoice_id=p_invoice_id and public.is_admin()
  ) x;
$$;

revoke all on function public.erp_get_invoice_items(uuid) from public;
grant execute on function public.erp_get_invoice_items(uuid) to authenticated;

-- Done.
-- Flow: product sale -> issued invoice -> stock OUT -> VAT -> journal entry -> payment -> customer balance.
