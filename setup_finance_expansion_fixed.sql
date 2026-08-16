-- BINGO Oman ERP — Finance Expansion: Suppliers, Purchases & Supplier Payments
-- Run after setup_erp.sql and setup_step9_products_inventory.sql.
-- Safe to run repeatedly.

create table if not exists public.erp_suppliers (
  id uuid primary key default gen_random_uuid(),
  supplier_code varchar(40) unique not null,
  name varchar(200) not null,
  contact_person varchar(200),
  company_name varchar(200),
  phone varchar(50),
  email varchar(255),
  tax_number varchar(100),
  commercial_registration varchar(100),
  address text,
  city varchar(100),
  payment_terms integer not null default 30 check (payment_terms >= 0),
  notes text,
  is_active boolean not null default true,
  created_by uuid references public.profiles(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.erp_purchases (
  id uuid primary key default gen_random_uuid(),
  purchase_number varchar(60) unique not null,
  supplier_id uuid references public.erp_suppliers(id) on delete set null,
  purchase_date date not null default current_date,
  due_date date,
  status varchar(20) not null default 'draft' check (status in ('draft','received','partially_paid','paid','cancelled')),
  subtotal numeric(14,3) not null default 0,
  discount numeric(14,3) not null default 0,
  taxable_amount numeric(14,3) not null default 0,
  vat_rate numeric(5,2) not null default 5,
  vat_amount numeric(14,3) not null default 0,
  total numeric(14,3) not null default 0,
  paid_amount numeric(14,3) not null default 0,
  notes text,
  created_by uuid references public.profiles(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.erp_purchase_items (
  id uuid primary key default gen_random_uuid(),
  purchase_id uuid not null references public.erp_purchases(id) on delete cascade,
  product_id uuid references public.erp_products(id) on delete set null,
  description varchar(500) not null,
  quantity numeric(14,3) not null default 1 check (quantity > 0),
  unit_cost numeric(14,3) not null default 0 check (unit_cost >= 0),
  discount numeric(14,3) not null default 0,
  line_total numeric(14,3) not null default 0,
  created_at timestamptz not null default now()
);

create table if not exists public.erp_supplier_payments (
  id uuid primary key default gen_random_uuid(),
  purchase_id uuid references public.erp_purchases(id) on delete set null,
  supplier_id uuid references public.erp_suppliers(id) on delete set null,
  payment_date date not null default current_date,
  amount numeric(14,3) not null check (amount > 0),
  method varchar(30) not null default 'bank',
  reference varchar(100),
  notes text,
  created_by uuid references public.profiles(id) on delete set null,
  created_at timestamptz not null default now()
);

alter table public.erp_suppliers add column if not exists contact_person varchar(200);
alter table public.erp_suppliers enable row level security;
alter table public.erp_purchases enable row level security;
alter table public.erp_purchase_items enable row level security;
alter table public.erp_supplier_payments enable row level security;

drop policy if exists erp_admin_all_suppliers on public.erp_suppliers;
create policy erp_admin_all_suppliers on public.erp_suppliers for all to authenticated using (public.is_admin()) with check (public.is_admin());
drop policy if exists erp_admin_all_purchases on public.erp_purchases;
create policy erp_admin_all_purchases on public.erp_purchases for all to authenticated using (public.is_admin()) with check (public.is_admin());
drop policy if exists erp_admin_all_purchase_items on public.erp_purchase_items;
create policy erp_admin_all_purchase_items on public.erp_purchase_items for all to authenticated using (public.is_admin()) with check (public.is_admin());
drop policy if exists erp_admin_all_supplier_payments on public.erp_supplier_payments;
create policy erp_admin_all_supplier_payments on public.erp_supplier_payments for all to authenticated using (public.is_admin()) with check (public.is_admin());

create index if not exists idx_erp_suppliers_name on public.erp_suppliers(name);
create index if not exists idx_erp_purchases_supplier on public.erp_purchases(supplier_id);
create index if not exists idx_erp_purchases_date on public.erp_purchases(purchase_date);
create index if not exists idx_erp_purchase_items_product on public.erp_purchase_items(product_id);
create index if not exists idx_erp_supplier_payments_purchase on public.erp_supplier_payments(purchase_id);

insert into public.erp_accounts(code,name,account_type) values
 ('1300','Inventory','asset'),
 ('1305','Input VAT Receivable','asset'),
 ('2000','Accounts Payable','liability'),
 ('5100','Cost of Goods Purchased','expense')
on conflict (code) do nothing;

create or replace function public.erp_list_suppliers(p_search text default null)
returns jsonb language plpgsql security definer set search_path=public as $$
begin
 if not public.is_admin() then raise exception 'Admin access required'; end if;
 return coalesce((select jsonb_agg(to_jsonb(x) order by x.created_at desc) from (
   select s.*,
     coalesce((select sum(p.total) from public.erp_purchases p where p.supplier_id=s.id and p.status<>'cancelled'),0) as purchased,
     coalesce((select sum(sp.amount) from public.erp_supplier_payments sp where sp.supplier_id=s.id),0) as paid,
     coalesce((select sum(p.total) from public.erp_purchases p where p.supplier_id=s.id and p.status<>'cancelled'),0)
      - coalesce((select sum(sp.amount) from public.erp_supplier_payments sp where sp.supplier_id=s.id),0) as balance
   from public.erp_suppliers s
   where (p_search is null or p_search='' or lower(concat_ws(' ',s.supplier_code,s.name,s.contact_person,s.company_name,s.phone,s.email,s.tax_number)) like '%'||lower(p_search)||'%')
   limit 500
 ) x),'[]'::jsonb);
end $$;

create or replace function public.erp_set_supplier_status(p_supplier_id uuid,p_is_active boolean)
returns jsonb language plpgsql security definer set search_path=public as $$
declare r public.erp_suppliers;
begin
 if not public.is_admin() then raise exception 'Admin access required'; end if;
 update public.erp_suppliers set is_active=p_is_active,updated_at=now() where id=p_supplier_id returning * into r;
 if r.id is null then raise exception 'Supplier not found'; end if;
 return to_jsonb(r);
end $$;

create or replace function public.erp_delete_supplier(p_supplier_id uuid)
returns jsonb language plpgsql security definer set search_path=public as $$
declare r public.erp_suppliers; c1 bigint; c2 bigint;
begin
 if not public.is_admin() then raise exception 'Admin access required'; end if;
 select count(*) into c1 from public.erp_purchases where supplier_id=p_supplier_id;
 select count(*) into c2 from public.erp_supplier_payments where supplier_id=p_supplier_id;
 if c1>0 or c2>0 then
   raise exception 'لا يمكن حذف المورد لأنه مرتبط بمشتريات أو دفعات. استخدم تعطيل المورد بدلاً من الحذف.';
 end if;
 delete from public.erp_suppliers where id=p_supplier_id returning * into r;
 if r.id is null then raise exception 'Supplier not found'; end if;
 return to_jsonb(r);
end $$;

create or replace function public.erp_upsert_supplier(p_supplier jsonb)
returns jsonb language plpgsql security definer set search_path=public as $$
declare r public.erp_suppliers;
begin
 if not public.is_admin() then raise exception 'Admin access required'; end if;
 if nullif(trim(p_supplier->>'name'),'') is null then raise exception 'Supplier name is required'; end if;
 if nullif(p_supplier->>'id','') is null then
   insert into public.erp_suppliers(supplier_code,name,contact_person,company_name,phone,email,tax_number,commercial_registration,address,city,payment_terms,notes,created_by)
   values('SUP-'||upper(substr(replace(gen_random_uuid()::text,'-',''),1,8)),trim(p_supplier->>'name'),
     nullif(trim(p_supplier->>'contact_person'),''),
     nullif(trim(p_supplier->>'company_name'),''),nullif(trim(p_supplier->>'phone'),''),
     nullif(trim(p_supplier->>'email'),''),nullif(trim(p_supplier->>'tax_number'),''),
     nullif(trim(p_supplier->>'commercial_registration'),''),nullif(trim(p_supplier->>'address'),''),
     nullif(trim(p_supplier->>'city'),''),coalesce((p_supplier->>'payment_terms')::int,30),
     nullif(trim(p_supplier->>'notes'),''),auth.uid()) returning * into r;
 else
   update public.erp_suppliers set name=trim(p_supplier->>'name'),
     contact_person=nullif(trim(p_supplier->>'contact_person'),''),
     company_name=nullif(trim(p_supplier->>'company_name'),''),
     phone=nullif(trim(p_supplier->>'phone'),''),email=nullif(trim(p_supplier->>'email'),''),
     tax_number=nullif(trim(p_supplier->>'tax_number'),''),
     commercial_registration=nullif(trim(p_supplier->>'commercial_registration'),''),
     address=nullif(trim(p_supplier->>'address'),''),city=nullif(trim(p_supplier->>'city'),''),
     payment_terms=coalesce((p_supplier->>'payment_terms')::int,30),
     notes=nullif(trim(p_supplier->>'notes'),''),updated_at=now()
   where id=(p_supplier->>'id')::uuid returning * into r;
 end if;
 if r.id is null then raise exception 'Supplier not found'; end if;
 return to_jsonb(r);
end $$;

create or replace function public.erp_list_purchases(p_search text default null, p_status text default null)
returns jsonb language plpgsql security definer set search_path=public as $$
begin
 if not public.is_admin() then raise exception 'Admin access required'; end if;
 return coalesce((select jsonb_agg(to_jsonb(x) order by x.purchase_date desc,x.created_at desc) from (
   select p.*,s.name supplier_name,s.company_name supplier_company,
    coalesce((select sum(sp.amount) from public.erp_supplier_payments sp where sp.purchase_id=p.id),0) calculated_paid,
    greatest(p.total-coalesce((select sum(sp.amount) from public.erp_supplier_payments sp where sp.purchase_id=p.id),0),0) balance
   from public.erp_purchases p left join public.erp_suppliers s on s.id=p.supplier_id
   where (p_status is null or p_status='' or p.status=p_status)
    and (p_search is null or p_search='' or lower(concat_ws(' ',p.purchase_number,s.name,s.company_name)) like '%'||lower(p_search)||'%')
   limit 500
 ) x),'[]'::jsonb);
end $$;

create or replace function public.erp_get_purchase_items(p_purchase_id uuid)
returns jsonb language plpgsql security definer set search_path=public as $$
begin
 if not public.is_admin() then raise exception 'Admin access required'; end if;
 return coalesce((select jsonb_agg(to_jsonb(x) order by x.created_at) from (
   select pi.*,p.sku,p.name product_name from public.erp_purchase_items pi left join public.erp_products p on p.id=pi.product_id
   where pi.purchase_id=p_purchase_id
 ) x),'[]'::jsonb);
end $$;

create or replace function public.erp_create_purchase(p_purchase jsonb,p_items jsonb)
returns jsonb language plpgsql security definer set search_path=public as $$
declare
 v_iid uuid; v_pno text; v_item jsonb; v_pid uuid; v_qty numeric; v_cost numeric; v_disc numeric; v_line numeric;
 v_sub numeric:=0; v_totaldisc numeric:=0; v_taxable numeric:=0; v_vat numeric:=0; v_total numeric:=0; v_rate numeric;
 v_status text; v_oldstatus text; v_prod public.erp_products; v_beforeq numeric; v_afterq numeric;
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

 for v_item in select * from jsonb_array_elements(coalesce(p_items,'[]'::jsonb)) loop
   v_pid:=nullif(v_item->>'product_id','')::uuid; v_qty:=coalesce((v_item->>'quantity')::numeric,0); v_cost:=coalesce((v_item->>'unit_cost')::numeric,0);
   v_disc:=coalesce((v_item->>'discount')::numeric,0); if v_qty<=0 or v_cost<0 then raise exception 'Invalid purchase item'; end if;
   v_line:=greatest(v_qty*v_cost-v_disc,0); v_sub:=v_sub+v_qty*v_cost; v_totaldisc:=v_totaldisc+v_disc;
   insert into public.erp_purchase_items(purchase_id,product_id,description,quantity,unit_cost,discount,line_total)
   values(v_iid,v_pid,coalesce(nullif(trim(v_item->>'description'),''),(select ep.name from public.erp_products ep where ep.id=v_pid),'Item'),v_qty,v_cost,v_disc,v_line);
 end loop;
 v_taxable:=greatest(v_sub-v_totaldisc,0); v_vat:=round(v_taxable*v_rate/100,3); v_total:=v_taxable+v_vat;
 update public.erp_purchases ep set subtotal=v_sub,discount=v_totaldisc,taxable_amount=v_taxable,vat_amount=v_vat,total=v_total,
   paid_amount=coalesce((select sum(sp.amount) from public.erp_supplier_payments sp where sp.purchase_id=v_iid),0),updated_at=now() where ep.id=v_iid;

 if v_status='received' and v_oldstatus is distinct from 'received' then
   for v_item in select * from jsonb_array_elements(coalesce(p_items,'[]'::jsonb)) loop
     v_pid:=nullif(v_item->>'product_id','')::uuid; v_qty:=coalesce((v_item->>'quantity')::numeric,0);
     if v_pid is not null then
       select * into v_prod from public.erp_products ep where ep.id=v_pid for update;
       if v_prod.id is null then raise exception 'Product not found'; end if;
       v_beforeq:=v_prod.stock_qty; v_afterq:=v_beforeq+v_qty;
       update public.erp_products ep set stock_qty=v_afterq,updated_at=now() where ep.id=v_pid;
       insert into public.erp_stock_movements(product_id,movement_type,quantity,quantity_before,quantity_after,reference_type,reference_id,reference_text,created_by)
       values(v_pid,'in',v_qty,v_beforeq,v_afterq,'purchase',v_iid,(select ep.purchase_number from public.erp_purchases ep where ep.id=v_iid),auth.uid());
     end if;
   end loop;
   select id into v_invacct from public.erp_accounts where code='1300';
   select id into v_apacct from public.erp_accounts where code='2000';
   select id into v_vatacct from public.erp_accounts where code='1305';
   insert into public.erp_journal_entries(entry_number,entry_date,description,source_type,source_id,created_by)
   values('PUR-JE-'||replace(v_iid::text,'-',''),(select ep.purchase_date from public.erp_purchases ep where ep.id=v_iid),'Purchase received','purchase',v_iid,auth.uid()) returning id into v_entryid;
   insert into public.erp_journal_lines(entry_id,account_id,debit,credit,description) values(v_entryid,v_invacct,v_taxable,0,'Inventory / purchases');
   if v_vat>0 then insert into public.erp_journal_lines(entry_id,account_id,debit,credit,description) values(v_entryid,v_vatacct,v_vat,0,'Input VAT'); end if;
   insert into public.erp_journal_lines(entry_id,account_id,debit,credit,description) values(v_entryid,v_apacct,0,v_total,'Accounts payable');
 end if;
 return (select to_jsonb(ep) from public.erp_purchases ep where ep.id=v_iid);
end $$;

create or replace function public.erp_record_supplier_payment(p_payment jsonb)
returns jsonb language plpgsql security definer set search_path=public as $$
declare pid uuid; sid uuid; amt numeric; bal numeric; m text; cashacct uuid; apacct uuid; entryid uuid; r public.erp_supplier_payments;
begin
 if not public.is_admin() then raise exception 'Admin access required'; end if;
 pid:=nullif(p_payment->>'purchase_id','')::uuid; sid:=nullif(p_payment->>'supplier_id','')::uuid; amt:=(p_payment->>'amount')::numeric; m:=coalesce(nullif(p_payment->>'method',''),'bank');
 if amt is null or amt<=0 then raise exception 'Invalid amount'; end if;
 if pid is not null then
   select greatest(total-coalesce((select sum(amount) from public.erp_supplier_payments where purchase_id=pid),0),0) into bal from public.erp_purchases where id=pid;
   if bal is null then raise exception 'Purchase not found'; end if;
   if amt>bal then raise exception 'Payment exceeds purchase balance'; end if;
   select supplier_id into sid from public.erp_purchases where id=pid;
 end if;
 insert into public.erp_supplier_payments(purchase_id,supplier_id,payment_date,amount,method,reference,notes,created_by)
 values(pid,sid,coalesce((p_payment->>'payment_date')::date,current_date),amt,m,nullif(p_payment->>'reference',''),nullif(p_payment->>'notes',''),auth.uid()) returning * into r;
 if pid is not null then
   update public.erp_purchases set paid_amount=(select sum(amount) from public.erp_supplier_payments where purchase_id=pid),
     status=case when (select sum(amount) from public.erp_supplier_payments where purchase_id=pid)>=total then 'paid' when (select sum(amount) from public.erp_supplier_payments where purchase_id=pid)>0 then 'partially_paid' else status end where id=pid;
 end if;
 select id into apacct from public.erp_accounts where code='2000';
 select id into cashacct from public.erp_accounts where code=case when m='cash' then '1000' else '1100' end;
 insert into public.erp_journal_entries(entry_number,entry_date,description,source_type,source_id,created_by)
 values('SP-JE-'||replace(r.id::text,'-',''),r.payment_date,'Supplier payment','supplier_payment',r.id,auth.uid()) returning id into entryid;
 insert into public.erp_journal_lines(entry_id,account_id,debit,credit,description) values(entryid,apacct,amt,0,'Accounts payable');
 insert into public.erp_journal_lines(entry_id,account_id,debit,credit,description) values(entryid,cashacct,0,amt,'Cash/Bank');
 return to_jsonb(r);
end $$;

grant execute on function public.erp_set_supplier_status(uuid,boolean) to authenticated;
grant execute on function public.erp_delete_supplier(uuid) to authenticated;
grant execute on function public.erp_list_suppliers(text) to authenticated;
grant execute on function public.erp_upsert_supplier(jsonb) to authenticated;
grant execute on function public.erp_list_purchases(text,text) to authenticated;
grant execute on function public.erp_get_purchase_items(uuid) to authenticated;
grant execute on function public.erp_create_purchase(jsonb,jsonb) to authenticated;
grant execute on function public.erp_record_supplier_payment(jsonb) to authenticated;

-- Extend dashboard with purchasing and supplier liabilities when the base function is recreated by this block.
create or replace function public.erp_finance_overview(p_from date default (current_date-interval '30 days')::date,p_to date default current_date)
returns jsonb language plpgsql security definer set search_path=public as $$
declare r jsonb;
begin
 if not public.is_admin() then raise exception 'Admin access required'; end if;
 select jsonb_build_object(
  'sales',coalesce((select sum(total) from erp_invoices where issue_date between p_from and p_to and status<>'cancelled'),0),
  'collections',coalesce((select sum(amount) from erp_payments where payment_date between p_from and p_to),0),
  'purchases',coalesce((select sum(total) from erp_purchases where purchase_date between p_from and p_to and status<>'cancelled'),0),
  'supplier_payments',coalesce((select sum(amount) from erp_supplier_payments where payment_date between p_from and p_to),0),
  'expenses',coalesce((select sum(total) from erp_expenses where expense_date between p_from and p_to),0),
  'receivables',coalesce((select sum(total-coalesce(paid_amount,0)) from erp_invoices where status not in ('cancelled','paid')),0),
  'payables',coalesce((select sum(total-coalesce(paid_amount,0)) from erp_purchases where status not in ('cancelled','paid')),0),
  'output_vat',coalesce((select sum(vat_amount) from erp_invoices where issue_date between p_from and p_to and status<>'cancelled'),0),
  'input_vat',coalesce((select sum(vat_amount) from erp_purchases where purchase_date between p_from and p_to and status<>'cancelled'),0),
  'customers',(select count(*) from erp_customers where is_active),
  'suppliers',(select count(*) from erp_suppliers where is_active),
  'products',(select count(*) from erp_products where is_active)
 ) into r;
 return r;
end $$;
grant execute on function public.erp_finance_overview(date,date) to authenticated;
