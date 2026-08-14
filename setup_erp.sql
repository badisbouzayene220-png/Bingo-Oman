-- BINGO Oman ERP / Business Management Module
-- Run once in Supabase SQL Editor after the existing BINGO database setup.
-- Default Oman VAT rate is configurable and starts at 5%.

create extension if not exists pgcrypto;

create table if not exists public.erp_company_settings (
  id text primary key default 'default',
  company_name varchar(200) not null default 'BINGO Oman',
  legal_name varchar(250),
  tax_number varchar(100),
  commercial_registration varchar(100),
  address text,
  phone varchar(50),
  email varchar(255),
  currency varchar(10) not null default 'OMR',
  vat_rate numeric(5,2) not null default 5.00 check (vat_rate >= 0 and vat_rate <= 100),
  invoice_prefix varchar(20) not null default 'INV-',
  invoice_next_number bigint not null default 1,
  updated_at timestamptz not null default now()
);
insert into public.erp_company_settings(id) values ('default') on conflict (id) do nothing;

create table if not exists public.erp_customers (
  id uuid primary key default gen_random_uuid(),
  profile_id uuid unique references public.profiles(id) on delete set null,
  customer_code varchar(40) unique,
  customer_type varchar(20) not null default 'individual' check (customer_type in ('individual','company')),
  name varchar(200) not null,
  company_name varchar(200),
  phone varchar(50),
  email varchar(255),
  tax_number varchar(100),
  commercial_registration varchar(100),
  address text,
  city varchar(100),
  notes text,
  is_active boolean not null default true,
  created_by uuid references public.profiles(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.erp_invoices (
  id uuid primary key default gen_random_uuid(),
  invoice_number varchar(60) unique not null,
  customer_id uuid references public.erp_customers(id) on delete set null,
  issue_date date not null default current_date,
  due_date date,
  status varchar(20) not null default 'draft' check (status in ('draft','issued','partially_paid','paid','overdue','cancelled')),
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

create table if not exists public.erp_invoice_items (
  id uuid primary key default gen_random_uuid(),
  invoice_id uuid not null references public.erp_invoices(id) on delete cascade,
  description varchar(500) not null,
  quantity numeric(14,3) not null default 1 check (quantity > 0),
  unit_price numeric(14,3) not null default 0 check (unit_price >= 0),
  discount numeric(14,3) not null default 0,
  line_total numeric(14,3) not null default 0,
  created_at timestamptz not null default now()
);

create table if not exists public.erp_payments (
  id uuid primary key default gen_random_uuid(),
  invoice_id uuid references public.erp_invoices(id) on delete set null,
  customer_id uuid references public.erp_customers(id) on delete set null,
  payment_date date not null default current_date,
  amount numeric(14,3) not null check (amount > 0),
  method varchar(30) not null default 'cash',
  reference varchar(100),
  notes text,
  created_by uuid references public.profiles(id) on delete set null,
  created_at timestamptz not null default now()
);

create table if not exists public.erp_expense_categories (
  id uuid primary key default gen_random_uuid(),
  name varchar(120) unique not null,
  is_active boolean not null default true,
  created_at timestamptz not null default now()
);
insert into public.erp_expense_categories(name) values
 ('Rent'),('Utilities'),('Salaries'),('Marketing'),('Transport'),('Office'),('Software'),('Other')
on conflict (name) do nothing;

create table if not exists public.erp_expenses (
  id uuid primary key default gen_random_uuid(),
  expense_number varchar(60) unique not null,
  category_id uuid references public.erp_expense_categories(id) on delete set null,
  vendor_name varchar(200),
  expense_date date not null default current_date,
  amount numeric(14,3) not null default 0 check (amount >= 0),
  vat_rate numeric(5,2) not null default 5,
  vat_amount numeric(14,3) not null default 0,
  total numeric(14,3) not null default 0,
  payment_method varchar(30) not null default 'cash',
  reference varchar(100),
  notes text,
  created_by uuid references public.profiles(id) on delete set null,
  created_at timestamptz not null default now()
);

create table if not exists public.erp_accounts (
  id uuid primary key default gen_random_uuid(),
  code varchar(20) unique not null,
  name varchar(150) not null,
  account_type varchar(30) not null check (account_type in ('asset','liability','equity','revenue','expense')),
  is_active boolean not null default true
);
insert into public.erp_accounts(code,name,account_type) values
 ('1000','Cash','asset'),('1100','Bank','asset'),('1200','Accounts Receivable','asset'),
 ('2100','VAT Payable','liability'),('3000','Owner Equity','equity'),
 ('4000','Sales Revenue','revenue'),('5000','Operating Expenses','expense')
on conflict (code) do nothing;

create table if not exists public.erp_journal_entries (
  id uuid primary key default gen_random_uuid(),
  entry_number varchar(60) unique not null,
  entry_date date not null default current_date,
  description text,
  source_type varchar(30),
  source_id uuid,
  created_by uuid references public.profiles(id) on delete set null,
  created_at timestamptz not null default now()
);
create table if not exists public.erp_journal_lines (
  id uuid primary key default gen_random_uuid(),
  entry_id uuid not null references public.erp_journal_entries(id) on delete cascade,
  account_id uuid not null references public.erp_accounts(id),
  debit numeric(14,3) not null default 0 check (debit >= 0),
  credit numeric(14,3) not null default 0 check (credit >= 0),
  description text,
  check ((debit > 0 and credit = 0) or (credit > 0 and debit = 0))
);

create table if not exists public.erp_audit_log (
  id bigint generated always as identity primary key,
  user_id uuid references public.profiles(id) on delete set null,
  action varchar(100) not null,
  entity_type varchar(50),
  entity_id uuid,
  details jsonb,
  created_at timestamptz not null default now()
);

create index if not exists idx_erp_customers_profile on public.erp_customers(profile_id);
create index if not exists idx_erp_invoices_customer on public.erp_invoices(customer_id);
create index if not exists idx_erp_invoices_date on public.erp_invoices(issue_date);
create index if not exists idx_erp_payments_invoice on public.erp_payments(invoice_id);
create index if not exists idx_erp_expenses_date on public.erp_expenses(expense_date);
create index if not exists idx_erp_journal_lines_account on public.erp_journal_lines(account_id);

alter table public.erp_company_settings enable row level security;
alter table public.erp_customers enable row level security;
alter table public.erp_invoices enable row level security;
alter table public.erp_invoice_items enable row level security;
alter table public.erp_payments enable row level security;
alter table public.erp_expense_categories enable row level security;
alter table public.erp_expenses enable row level security;
alter table public.erp_accounts enable row level security;
alter table public.erp_journal_entries enable row level security;
alter table public.erp_journal_lines enable row level security;
alter table public.erp_audit_log enable row level security;

-- Admin-only ERP access. This intentionally uses the existing BINGO admin helper.
drop policy if exists erp_admin_all_settings on public.erp_company_settings;
create policy erp_admin_all_settings on public.erp_company_settings for all to authenticated using (public.is_admin()) with check (public.is_admin());
drop policy if exists erp_admin_all_customers on public.erp_customers;
create policy erp_admin_all_customers on public.erp_customers for all to authenticated using (public.is_admin()) with check (public.is_admin());
drop policy if exists erp_admin_all_invoices on public.erp_invoices;
create policy erp_admin_all_invoices on public.erp_invoices for all to authenticated using (public.is_admin()) with check (public.is_admin());
drop policy if exists erp_admin_all_invoice_items on public.erp_invoice_items;
create policy erp_admin_all_invoice_items on public.erp_invoice_items for all to authenticated using (public.is_admin()) with check (public.is_admin());
drop policy if exists erp_admin_all_payments on public.erp_payments;
create policy erp_admin_all_payments on public.erp_payments for all to authenticated using (public.is_admin()) with check (public.is_admin());
drop policy if exists erp_admin_all_expense_categories on public.erp_expense_categories;
create policy erp_admin_all_expense_categories on public.erp_expense_categories for all to authenticated using (public.is_admin()) with check (public.is_admin());
drop policy if exists erp_admin_all_expenses on public.erp_expenses;
create policy erp_admin_all_expenses on public.erp_expenses for all to authenticated using (public.is_admin()) with check (public.is_admin());
drop policy if exists erp_admin_all_accounts on public.erp_accounts;
create policy erp_admin_all_accounts on public.erp_accounts for all to authenticated using (public.is_admin()) with check (public.is_admin());
drop policy if exists erp_admin_all_journal_entries on public.erp_journal_entries;
create policy erp_admin_all_journal_entries on public.erp_journal_entries for all to authenticated using (public.is_admin()) with check (public.is_admin());
drop policy if exists erp_admin_all_journal_lines on public.erp_journal_lines;
create policy erp_admin_all_journal_lines on public.erp_journal_lines for all to authenticated using (public.is_admin()) with check (public.is_admin());
drop policy if exists erp_admin_all_audit on public.erp_audit_log;
create policy erp_admin_all_audit on public.erp_audit_log for select to authenticated using (public.is_admin());

create or replace function public.erp_next_number(p_kind text)
returns text language plpgsql security definer set search_path=public as $$
declare s public.erp_company_settings; n bigint; prefix text;
begin
 if not public.is_admin() then raise exception 'Admin access required'; end if;
 select * into s from public.erp_company_settings where id='default' for update;
 if p_kind='invoice' then prefix:=s.invoice_prefix; else prefix:='EXP-'; end if;
 n:=s.invoice_next_number;
 update public.erp_company_settings set invoice_next_number=n+1,updated_at=now() where id='default';
 return prefix || lpad(n::text,6,'0');
end $$;
revoke all on function public.erp_next_number(text) from public;
grant execute on function public.erp_next_number(text) to authenticated;

create or replace function public.erp_dashboard(p_from date default (current_date - interval '30 days')::date, p_to date default current_date)
returns jsonb language plpgsql security definer set search_path=public as $$
declare result jsonb;
begin
 if not public.is_admin() then raise exception 'Admin access required'; end if;
 select jsonb_build_object(
  'from',p_from,'to',p_to,
  'sales',coalesce((select sum(total) from public.erp_invoices where issue_date between p_from and p_to and status<>'cancelled'),0),
  'paid',coalesce((select sum(amount) from public.erp_payments where payment_date between p_from and p_to),0),
  'expenses',coalesce((select sum(total) from public.erp_expenses where expense_date between p_from and p_to),0),
  'receivable',coalesce((select sum(total-paid_amount) from public.erp_invoices where status not in ('cancelled','paid')),0),
  'vat_sales',coalesce((select sum(vat_amount) from public.erp_invoices where issue_date between p_from and p_to and status<>'cancelled'),0),
  'vat_expenses',coalesce((select sum(vat_amount) from public.erp_expenses where expense_date between p_from and p_to),0),
  'customers',(select count(*) from public.erp_customers where is_active),
  'invoices',(select count(*) from public.erp_invoices where issue_date between p_from and p_to and status<>'cancelled')
 ) into result;
 return result;
end $$;

-- CRM integration: link ERP customers to existing BINGO profiles.
alter table public.erp_customers add column if not exists profile_id uuid references public.profiles(id) on delete set null;
create unique index if not exists uq_erp_customers_profile on public.erp_customers(profile_id) where profile_id is not null;

create or replace function public.erp_list_bingo_users()
returns jsonb language plpgsql security definer set search_path=public,auth as $$
begin
 if not public.is_admin() then raise exception 'Admin access required'; end if;
 return coalesce((select jsonb_agg(to_jsonb(x) order by x.created_at desc) from (
   select u.id,
          coalesce(nullif(p.full_name,''), nullif(p.username,''), split_part(u.email,'@',1)) as display_name,
          p.username,
          u.email,
          u.created_at
   from auth.users u
   left join public.profiles p on p.id=u.id
   where not exists (select 1 from public.erp_customers c where c.profile_id=u.id)
   order by u.created_at desc
   limit 1000
 ) x),'[]'::jsonb);
end $$;

create or replace function public.erp_list_customers(p_search text default null)
returns jsonb language plpgsql security definer set search_path=public as $$
begin
 if not public.is_admin() then raise exception 'Admin access required'; end if;
 return coalesce((select jsonb_agg(to_jsonb(x) order by x.created_at desc) from (
  select c.*, p.username as profile_username, u.email as profile_email, coalesce(nullif(p.full_name,''),nullif(p.username,''),split_part(u.email,'@',1)) as profile_display_name, coalesce((select sum(i.total) from public.erp_invoices i where i.customer_id=c.id and i.status<>'cancelled'),0) as invoiced,
  coalesce((select sum(pmt.amount) from public.erp_payments pmt where pmt.customer_id=c.id),0) as paid
  from public.erp_customers c left join public.profiles p on p.id=c.profile_id left join auth.users u on u.id=c.profile_id
  where p_search is null or p_search='' or lower(concat_ws(' ',c.name,c.company_name,c.phone,c.email,c.customer_code,p.username,u.email)) like '%'||lower(p_search)||'%'
  limit 500) x),'[]'::jsonb);
end $$;

create or replace function public.erp_upsert_customer(p_customer jsonb)
returns jsonb language plpgsql security definer set search_path=public as $$
declare r public.erp_customers;
begin
 if not public.is_admin() then raise exception 'Admin access required'; end if;
 if nullif(trim(p_customer->>'name'),'') is null then raise exception 'Customer name is required'; end if;
 if nullif(p_customer->>'id','') is null then
  insert into public.erp_customers(profile_id,customer_code,customer_type,name,company_name,phone,email,tax_number,commercial_registration,address,city,notes,created_by)
  values(nullif(p_customer->>'profile_id','')::uuid,'CUS-'||upper(substr(replace(gen_random_uuid()::text,'-',''),1,8)),coalesce(nullif(p_customer->>'customer_type',''),'individual'),trim(p_customer->>'name'),nullif(trim(p_customer->>'company_name'),''),nullif(trim(p_customer->>'phone'),''),nullif(trim(p_customer->>'email'),''),nullif(trim(p_customer->>'tax_number'),''),nullif(trim(p_customer->>'commercial_registration'),''),nullif(trim(p_customer->>'address'),''),nullif(trim(p_customer->>'city'),''),nullif(trim(p_customer->>'notes'),''),auth.uid()) returning * into r;
 else
  update public.erp_customers set profile_id=nullif(p_customer->>'profile_id','')::uuid, customer_type=coalesce(nullif(p_customer->>'customer_type',''),customer_type),name=trim(p_customer->>'name'),company_name=nullif(trim(p_customer->>'company_name'),''),phone=nullif(trim(p_customer->>'phone'),''),email=nullif(trim(p_customer->>'email'),''),tax_number=nullif(trim(p_customer->>'tax_number'),''),commercial_registration=nullif(trim(p_customer->>'commercial_registration'),''),address=nullif(trim(p_customer->>'address'),''),city=nullif(trim(p_customer->>'city'),''),notes=nullif(trim(p_customer->>'notes'),''),is_active=coalesce((p_customer->>'is_active')::boolean,is_active),updated_at=now() where id=(p_customer->>'id')::uuid returning * into r;
 end if;
 insert into public.erp_audit_log(user_id,action,entity_type,entity_id,details) values(auth.uid(),'customer_saved','customer',r.id,to_jsonb(r));
 return to_jsonb(r);
end $$;

create or replace function public.erp_list_invoices(p_search text default null, p_status text default null)
returns jsonb language plpgsql security definer set search_path=public as $$
begin
 if not public.is_admin() then raise exception 'Admin access required'; end if;
 return coalesce((select jsonb_agg(to_jsonb(x) order by x.issue_date desc,x.created_at desc) from (
  select i.*, c.name customer_name,c.company_name customer_company
  from public.erp_invoices i left join public.erp_customers c on c.id=i.customer_id
  where (p_status is null or p_status='' or i.status=p_status)
    and (p_search is null or p_search='' or lower(concat_ws(' ',i.invoice_number,c.name,c.company_name,c.phone)) like '%'||lower(p_search)||'%')
  limit 500) x),'[]'::jsonb);
end $$;

create or replace function public.erp_create_invoice(p_invoice jsonb,p_items jsonb)
returns jsonb language plpgsql security definer set search_path=public as $$
declare iid uuid; invno text; vat numeric; sub numeric:=0; disc numeric:=0; taxable numeric:=0; vatamt numeric:=0; total numeric:=0; item jsonb; itemdisc numeric; linetotal numeric; r jsonb;
begin
 if not public.is_admin() then raise exception 'Admin access required'; end if;
 vat:=coalesce((p_invoice->>'vat_rate')::numeric,(select vat_rate from public.erp_company_settings where id='default'));
 invno:=coalesce(nullif(p_invoice->>'invoice_number',''),public.erp_next_number('invoice'));
 if nullif(p_invoice->>'id','') is not null then
  iid:=(p_invoice->>'id')::uuid;
  delete from public.erp_invoice_items where invoice_id=iid;
  update public.erp_invoices set customer_id=nullif(p_invoice->>'customer_id','')::uuid,issue_date=coalesce((p_invoice->>'issue_date')::date,current_date),due_date=nullif(p_invoice->>'due_date','')::date,status=coalesce(nullif(p_invoice->>'status',''),'draft'),vat_rate=vat,notes=nullif(p_invoice->>'notes',''),updated_at=now() where id=iid;
 else
  insert into public.erp_invoices(invoice_number,customer_id,issue_date,due_date,status,vat_rate,notes,created_by) values(invno,nullif(p_invoice->>'customer_id','')::uuid,coalesce((p_invoice->>'issue_date')::date,current_date),nullif(p_invoice->>'due_date','')::date,coalesce(nullif(p_invoice->>'status',''),'draft'),vat,nullif(p_invoice->>'notes',''),auth.uid()) returning id into iid;
 end if;
 for item in select * from jsonb_array_elements(coalesce(p_items,'[]'::jsonb)) loop
  itemdisc:=coalesce((item->>'discount')::numeric,0);
  linetotal:=round(((item->>'quantity')::numeric * (item->>'unit_price')::numeric)-itemdisc,3);
  if linetotal < 0 then raise exception 'Line total cannot be negative'; end if;
  sub:=sub+((item->>'quantity')::numeric*(item->>'unit_price')::numeric); disc:=disc+itemdisc;
  insert into public.erp_invoice_items(invoice_id,description,quantity,unit_price,discount,line_total) values(iid,trim(item->>'description'),(item->>'quantity')::numeric,(item->>'unit_price')::numeric,itemdisc,linetotal);
 end loop;
 taxable:=greatest(sub-disc,0); vatamt:=round(taxable*vat/100,3); total:=taxable+vatamt;
 update public.erp_invoices set subtotal=sub,discount=disc,taxable_amount=taxable,vat_amount=vatamt,total=total,updated_at=now() where id=iid;
 select to_jsonb(i) into r from public.erp_invoices i where i.id=iid;
 insert into public.erp_audit_log(user_id,action,entity_type,entity_id,details) values(auth.uid(),'invoice_saved','invoice',iid,r);
 return r;
end $$;

create or replace function public.erp_record_payment(p_payment jsonb)
returns jsonb language plpgsql security definer set search_path=public as $$
declare pid uuid; iid uuid; cid uuid; amt numeric; r jsonb;
begin
 if not public.is_admin() then raise exception 'Admin access required'; end if;
 iid:=nullif(p_payment->>'invoice_id','')::uuid; cid:=nullif(p_payment->>'customer_id','')::uuid; amt:=(p_payment->>'amount')::numeric;
 if amt is null or amt<=0 then raise exception 'Payment amount must be greater than zero'; end if;
 insert into public.erp_payments(invoice_id,customer_id,payment_date,amount,method,reference,notes,created_by) values(iid,cid,coalesce((p_payment->>'payment_date')::date,current_date),amt,coalesce(nullif(p_payment->>'method',''),'cash'),nullif(p_payment->>'reference',''),nullif(p_payment->>'notes',''),auth.uid()) returning id into pid;
 if iid is not null then
  update public.erp_invoices i set paid_amount=coalesce((select sum(p.amount) from public.erp_payments p where p.invoice_id=i.id),0),status=case when coalesce((select sum(p.amount) from public.erp_payments p where p.invoice_id=i.id),0)>=i.total then 'paid' when coalesce((select sum(p.amount) from public.erp_payments p where p.invoice_id=i.id),0)>0 then 'partially_paid' else i.status end,updated_at=now() where i.id=iid;
 end if;
 select to_jsonb(p) into r from public.erp_payments p where p.id=pid;
 insert into public.erp_audit_log(user_id,action,entity_type,entity_id,details) values(auth.uid(),'payment_recorded','payment',pid,r);
 return r;
end $$;

create or replace function public.erp_list_expenses(p_from date default null,p_to date default null)
returns jsonb language plpgsql security definer set search_path=public as $$
begin
 if not public.is_admin() then raise exception 'Admin access required'; end if;
 return coalesce((select jsonb_agg(to_jsonb(x) order by x.expense_date desc,x.created_at desc) from (
  select e.*,c.name category_name from public.erp_expenses e left join public.erp_expense_categories c on c.id=e.category_id
  where (p_from is null or e.expense_date>=p_from) and (p_to is null or e.expense_date<=p_to) limit 500) x),'[]'::jsonb);
end $$;

create or replace function public.erp_add_expense(p_expense jsonb)
returns jsonb language plpgsql security definer set search_path=public as $$
declare r public.erp_expenses; net numeric; vat numeric; total numeric;
begin
 if not public.is_admin() then raise exception 'Admin access required'; end if;
 net:=coalesce((p_expense->>'amount')::numeric,0); vat:=round(net*coalesce((p_expense->>'vat_rate')::numeric,(select vat_rate from public.erp_company_settings where id='default'))/100,3); total:=net+vat;
 insert into public.erp_expenses(expense_number,category_id,vendor_name,expense_date,amount,vat_rate,vat_amount,total,payment_method,reference,notes,created_by)
 values(public.erp_next_number('expense'),nullif(p_expense->>'category_id','')::uuid,nullif(trim(p_expense->>'vendor_name'),''),coalesce((p_expense->>'expense_date')::date,current_date),net,coalesce((p_expense->>'vat_rate')::numeric,(select vat_rate from public.erp_company_settings where id='default')),vat,total,coalesce(nullif(p_expense->>'payment_method',''),'cash'),nullif(p_expense->>'reference',''),nullif(p_expense->>'notes',''),auth.uid()) returning * into r;
 insert into public.erp_audit_log(user_id,action,entity_type,entity_id,details) values(auth.uid(),'expense_added','expense',r.id,to_jsonb(r));
 return to_jsonb(r);
end $$;

create or replace function public.erp_vat_summary(p_from date,p_to date)
returns jsonb language plpgsql security definer set search_path=public as $$
begin
 if not public.is_admin() then raise exception 'Admin access required'; end if;
 return jsonb_build_object(
  'period_from',p_from,'period_to',p_to,
  'sales_net',coalesce((select sum(taxable_amount) from public.erp_invoices where issue_date between p_from and p_to and status<>'cancelled'),0),
  'output_vat',coalesce((select sum(vat_amount) from public.erp_invoices where issue_date between p_from and p_to and status<>'cancelled'),0),
  'purchase_net',coalesce((select sum(amount) from public.erp_expenses where expense_date between p_from and p_to),0),
  'input_vat',coalesce((select sum(vat_amount) from public.erp_expenses where expense_date between p_from and p_to),0),
  'net_vat',coalesce((select sum(vat_amount) from public.erp_invoices where issue_date between p_from and p_to and status<>'cancelled'),0)-coalesce((select sum(vat_amount) from public.erp_expenses where expense_date between p_from and p_to),0)
 );
end $$;

create or replace function public.erp_profit_loss(p_from date,p_to date)
returns jsonb language plpgsql security definer set search_path=public as $$
declare rev numeric; exp numeric;
begin
 if not public.is_admin() then raise exception 'Admin access required'; end if;
 select coalesce(sum(total),0) into rev from public.erp_invoices where issue_date between p_from and p_to and status<>'cancelled';
 select coalesce(sum(total),0) into exp from public.erp_expenses where expense_date between p_from and p_to;
 return jsonb_build_object('period_from',p_from,'period_to',p_to,'revenue',rev,'expenses',exp,'profit',rev-exp);
end $$;


create or replace function public.erp_company_settings_read()
returns jsonb language sql security definer set search_path=public as $$
  select to_jsonb(s) from public.erp_company_settings s where s.id='default' and public.is_admin();
$$;

create or replace function public.erp_save_settings(p_settings jsonb)
returns jsonb language plpgsql security definer set search_path=public as $$
declare r public.erp_company_settings;
begin
 if not public.is_admin() then raise exception 'Admin access required'; end if;
 update public.erp_company_settings set
   company_name=coalesce(nullif(trim(p_settings->>'company_name'),''),company_name),
   legal_name=nullif(trim(p_settings->>'legal_name'),''),
   tax_number=nullif(trim(p_settings->>'tax_number'),''),
   commercial_registration=nullif(trim(p_settings->>'commercial_registration'),''),
   address=nullif(trim(p_settings->>'address'),''),
   phone=nullif(trim(p_settings->>'phone'),''),
   email=nullif(trim(p_settings->>'email'),''),
   currency=coalesce(nullif(trim(p_settings->>'currency'),''),'OMR'),
   vat_rate=coalesce((p_settings->>'vat_rate')::numeric,vat_rate),
   invoice_prefix=coalesce(nullif(trim(p_settings->>'invoice_prefix'),''),invoice_prefix),
   updated_at=now()
 where id='default' returning * into r;
 return to_jsonb(r);
end $$;

create or replace function public.erp_get_invoice_items(p_invoice_id uuid)
returns jsonb language sql security definer set search_path=public as $$
 select coalesce(jsonb_agg(to_jsonb(i) order by i.created_at),'[]'::jsonb)
 from public.erp_invoice_items i
 where i.invoice_id=p_invoice_id and public.is_admin();
$$;

revoke all on function public.erp_company_settings_read() from public;
grant execute on function public.erp_company_settings_read() to authenticated;
revoke all on function public.erp_save_settings(jsonb) from public;
grant execute on function public.erp_save_settings(jsonb) to authenticated;
revoke all on function public.erp_get_invoice_items(uuid) from public;
grant execute on function public.erp_get_invoice_items(uuid) to authenticated;

revoke all on function public.erp_dashboard(date,date) from public;
grant execute on function public.erp_dashboard(date,date) to authenticated;
revoke all on function public.erp_list_bingo_users() from public;
grant execute on function public.erp_list_bingo_users() to authenticated;
revoke all on function public.erp_list_customers(text) from public;
grant execute on function public.erp_list_customers(text) to authenticated;
revoke all on function public.erp_upsert_customer(jsonb) from public;
grant execute on function public.erp_upsert_customer(jsonb) to authenticated;
revoke all on function public.erp_list_invoices(text,text) from public;
grant execute on function public.erp_list_invoices(text,text) to authenticated;
revoke all on function public.erp_create_invoice(jsonb,jsonb) from public;
grant execute on function public.erp_create_invoice(jsonb,jsonb) to authenticated;
revoke all on function public.erp_record_payment(jsonb) from public;
grant execute on function public.erp_record_payment(jsonb) to authenticated;
revoke all on function public.erp_list_expenses(date,date) from public;
grant execute on function public.erp_list_expenses(date,date) to authenticated;
revoke all on function public.erp_add_expense(jsonb) from public;
grant execute on function public.erp_add_expense(jsonb) to authenticated;
revoke all on function public.erp_vat_summary(date,date) from public;
grant execute on function public.erp_vat_summary(date,date) to authenticated;
revoke all on function public.erp_profit_loss(date,date) from public;
grant execute on function public.erp_profit_loss(date,date) to authenticated;
