-- BINGO Oman ERP — Supplier Refunds V1
-- Run after the current purchase/cancellation SQL. Safe to re-run.


-- ============================================================
-- Supplier Refunds for cancelled purchases
-- ============================================================

insert into public.erp_accounts(code,name,account_type)
values ('1210','Supplier Refund Receivable','asset')
on conflict (code) do nothing;

create table if not exists public.erp_supplier_refunds (
  id uuid primary key default gen_random_uuid(),
  purchase_id uuid not null references public.erp_purchases(id) on delete restrict,
  supplier_id uuid references public.erp_suppliers(id) on delete set null,
  refund_date date not null default current_date,
  amount numeric(14,3) not null check (amount > 0),
  method varchar(30) not null default 'bank',
  reference varchar(100),
  notes text,
  created_by uuid references public.profiles(id) on delete set null,
  created_at timestamptz not null default now(),
  unique (id)
);

alter table public.erp_supplier_refunds enable row level security;
drop policy if exists erp_admin_all_supplier_refunds on public.erp_supplier_refunds;
create policy erp_admin_all_supplier_refunds on public.erp_supplier_refunds
for all to authenticated using (public.is_admin()) with check (public.is_admin());
create index if not exists idx_erp_supplier_refunds_purchase on public.erp_supplier_refunds(purchase_id);

create or replace function public.erp_get_supplier_refund_status(p_purchase_id uuid)
returns jsonb language plpgsql security definer set search_path=public as $$
declare
  v_receivable numeric := 0;
  v_refunded numeric := 0;
  v_balance numeric := 0;
  v_refundacct uuid;
begin
  if not public.is_admin() then raise exception 'Admin access required'; end if;
  select id into v_refundacct from public.erp_accounts where code='1210';
  if v_refundacct is null then raise exception 'Supplier Refund Receivable account 1210 is missing'; end if;

  select coalesce(sum(jl.debit-jl.credit),0)
    into v_receivable
  from public.erp_journal_entries je
  join public.erp_journal_lines jl on jl.entry_id=je.id
  where je.source_type='purchase_cancellation'
    and je.source_id=p_purchase_id
    and jl.account_id=v_refundacct;

  select coalesce(sum(amount),0)
    into v_refunded
  from public.erp_supplier_refunds
  where purchase_id=p_purchase_id;

  v_balance:=greatest(round(v_receivable-v_refunded,3),0);
  return jsonb_build_object(
    'purchase_id',p_purchase_id,
    'refund_receivable',round(v_receivable,3),
    'refunded_amount',round(v_refunded,3),
    'refund_balance',v_balance,
    'refundable',v_balance>0
  );
end $$;

grant execute on function public.erp_get_supplier_refund_status(uuid) to authenticated;

create or replace function public.erp_record_supplier_refund(p_refund jsonb)
returns jsonb language plpgsql security definer set search_path=public as $$
declare
  pid uuid;
  sid uuid;
  amt numeric;
  bal numeric;
  m text;
  cashacct uuid;
  refundacct uuid;
  entryid uuid;
  r public.erp_supplier_refunds;
begin
  if not public.is_admin() then raise exception 'Admin access required'; end if;

  pid:=nullif(p_refund->>'purchase_id','')::uuid;
  amt:=(p_refund->>'amount')::numeric;
  m:=lower(coalesce(nullif(trim(p_refund->>'method'),''),'bank'));

  if pid is null then raise exception 'Purchase is required'; end if;
  if amt is null or amt<=0 then raise exception 'Invalid refund amount'; end if;
  if m not in ('cash','bank') then raise exception 'Refund method must be cash or bank'; end if;

  perform 1 from public.erp_purchases where id=pid for update;
  if not found then raise exception 'Purchase not found'; end if;

  select supplier_id into sid from public.erp_purchases where id=pid;
  if (select status from public.erp_purchases where id=pid) <> 'cancelled' then
    raise exception 'Purchase must be cancelled before recording a supplier refund';
  end if;

  select refund_balance::numeric
    into bal
  from jsonb_to_record(public.erp_get_supplier_refund_status(pid))
       as x(purchase_id uuid, refund_receivable numeric, refunded_amount numeric, refund_balance numeric, refundable boolean);

  if bal<=0 then raise exception 'No supplier refund is currently due for this purchase'; end if;
  if amt>bal then raise exception 'Refund exceeds supplier refund balance of %', round(bal,3); end if;

  select id into refundacct from public.erp_accounts where code='1210';
  select id into cashacct from public.erp_accounts where code=case when m='cash' then '1000' else '1100' end;
  if refundacct is null then raise exception 'Supplier Refund Receivable account 1210 is missing'; end if;
  if cashacct is null then raise exception 'Cash/Bank account is missing'; end if;

  insert into public.erp_supplier_refunds(purchase_id,supplier_id,refund_date,amount,method,reference,notes,created_by)
  values(pid,sid,coalesce((p_refund->>'refund_date')::date,current_date),amt,m,
         nullif(trim(p_refund->>'reference'),''),
         nullif(trim(p_refund->>'notes'),''),auth.uid())
  returning * into r;

  insert into public.erp_journal_entries(entry_number,entry_date,description,source_type,source_id,created_by)
  values('SR-JE-'||replace(r.id::text,'-',''),r.refund_date,'Supplier refund received','supplier_refund',r.id,auth.uid())
  returning id into entryid;

  insert into public.erp_journal_lines(entry_id,account_id,debit,credit,description)
  values(entryid,cashacct,amt,0,'Cash/Bank received from supplier refund');

  insert into public.erp_journal_lines(entry_id,account_id,debit,credit,description)
  values(entryid,refundacct,0,amt,'Clear Supplier Refund Receivable');

  return jsonb_build_object(
    'success',true,
    'refund_id',r.id,
    'purchase_id',pid,
    'amount',amt,
    'method',m,
    'journal_id',entryid,
    'remaining_refund',greatest(round(bal-amt,3),0)
  );
end $$;

grant execute on function public.erp_record_supplier_refund(jsonb) to authenticated;
