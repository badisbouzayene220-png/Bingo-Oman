-- BINGO Oman — Delivery Finance & Seller Settlements V1
-- Additive: does not change existing delivery pricing or driver share logic.

alter table public.delivery_stores
  add column if not exists bingo_commission_percent numeric(5,2) not null default 0;

DO $$ BEGIN
  alter table public.delivery_stores
    add constraint delivery_store_commission_percent_check
    check (bingo_commission_percent between 0 and 100);
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

create table if not exists public.delivery_seller_settlements (
  id uuid primary key default gen_random_uuid(),
  order_id uuid not null unique references public.delivery_orders(id) on delete cascade,
  store_id uuid not null references public.delivery_stores(id) on delete restrict,
  seller_id uuid not null references auth.users(id) on delete restrict,
  order_subtotal numeric(12,3) not null default 0,
  commission_percent numeric(5,2) not null default 0,
  bingo_commission numeric(12,3) not null default 0,
  seller_net numeric(12,3) not null default 0,
  status text not null default 'pending',
  approved_at timestamptz,
  paid_at timestamptz,
  admin_note text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint delivery_seller_settlement_status_check check (status in ('pending','approved','paid','cancelled')),
  constraint delivery_seller_settlement_amounts_check check (
    order_subtotal >= 0 and commission_percent between 0 and 100 and bingo_commission >= 0 and seller_net >= 0
  )
);

create index if not exists delivery_seller_settlements_store_idx
  on public.delivery_seller_settlements(store_id, created_at desc);
create index if not exists delivery_seller_settlements_seller_idx
  on public.delivery_seller_settlements(seller_id, created_at desc);
create index if not exists delivery_seller_settlements_status_idx
  on public.delivery_seller_settlements(status, created_at desc);

alter table public.delivery_seller_settlements enable row level security;

DO $$ BEGIN
  create policy delivery_seller_settlement_owner_read
  on public.delivery_seller_settlements
  for select to authenticated
  using (seller_id = auth.uid());
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

-- Central settlement calculator. External Sellers only; official BINGO Store has owner_id NULL.
create or replace function public.delivery_sync_seller_settlement(p_order_id uuid)
returns void
language plpgsql
security definer
set search_path=public
as $$
declare
  v_order public.delivery_orders%rowtype;
  v_store public.delivery_stores%rowtype;
  v_rate numeric(5,2);
  v_commission numeric(12,3);
  v_net numeric(12,3);
begin
  select * into v_order from public.delivery_orders where id=p_order_id;
  if not found then return; end if;

  select * into v_store from public.delivery_stores where id=v_order.store_id;
  if not found then return; end if;

  -- Official BINGO Store: all merchandise subtotal belongs to BINGO; no Seller settlement row.
  if v_store.owner_id is null then
    update public.delivery_orders set store_commission=0, updated_at=now() where id=v_order.id;
    delete from public.delivery_seller_settlements where order_id=v_order.id;
    return;
  end if;

  -- A Seller becomes payable only after completed delivery.
  if v_order.status <> 'delivered' then
    return;
  end if;

  v_rate := greatest(0,least(100,coalesce(v_store.bingo_commission_percent,0)));
  v_commission := round((coalesce(v_order.subtotal,0) * v_rate / 100)::numeric,3);
  v_net := round((greatest(coalesce(v_order.subtotal,0)-v_commission,0))::numeric,3);

  update public.delivery_orders
  set store_commission=v_commission, updated_at=now()
  where id=v_order.id;

  insert into public.delivery_seller_settlements(
    order_id,store_id,seller_id,order_subtotal,commission_percent,bingo_commission,seller_net,status,updated_at
  ) values (
    v_order.id,v_store.id,v_store.owner_id,coalesce(v_order.subtotal,0),v_rate,v_commission,v_net,'pending',now()
  )
  on conflict(order_id) do update set
    store_id=excluded.store_id,
    seller_id=excluded.seller_id,
    order_subtotal=excluded.order_subtotal,
    commission_percent=excluded.commission_percent,
    bingo_commission=excluded.bingo_commission,
    seller_net=excluded.seller_net,
    updated_at=now()
  where public.delivery_seller_settlements.status <> 'paid';
end;
$$;

revoke all on function public.delivery_sync_seller_settlement(uuid) from public;

create or replace function public.delivery_order_finance_sync_trigger()
returns trigger
language plpgsql
security definer
set search_path=public
as $$
begin
  if new.status='delivered' and (old.status is distinct from new.status or old.subtotal is distinct from new.subtotal or old.store_id is distinct from new.store_id) then
    perform public.delivery_sync_seller_settlement(new.id);
  end if;
  return new;
end;
$$;

drop trigger if exists trg_delivery_order_finance_sync on public.delivery_orders;
create trigger trg_delivery_order_finance_sync
after update of status,subtotal,store_id on public.delivery_orders
for each row execute function public.delivery_order_finance_sync_trigger();

-- Backfill completed Seller orders safely.
do $$
declare r record;
begin
  for r in
    select o.id
    from public.delivery_orders o
    join public.delivery_stores s on s.id=o.store_id
    where o.status='delivered' and s.owner_id is not null
  loop
    perform public.delivery_sync_seller_settlement(r.id);
  end loop;
end $$;

-- Admin guard used by finance RPCs.
create or replace function public.delivery_finance_require_admin()
returns void
language plpgsql
security definer
set search_path=public
as $$
begin
  if auth.uid() is null or not exists(
    select 1 from public.profiles p
    where p.id=auth.uid() and p.role='admin' and p.is_active=true
  ) then
    raise exception 'Admin access required';
  end if;
end;
$$;

revoke all on function public.delivery_finance_require_admin() from public;

create or replace function public.admin_delivery_store_set_commission(
  p_store_id uuid,
  p_percent numeric
) returns boolean
language plpgsql
security definer
set search_path=public
as $$
begin
  perform public.delivery_finance_require_admin();
  if p_percent is null or p_percent < 0 or p_percent > 100 then
    raise exception 'Commission percent must be between 0 and 100';
  end if;
  update public.delivery_stores
  set bingo_commission_percent=round(p_percent::numeric,2)
  where id=p_store_id and owner_id is not null;
  if not found then raise exception 'Seller store not found'; end if;
  return true;
end;
$$;

revoke all on function public.admin_delivery_store_set_commission(uuid,numeric) from public;
grant execute on function public.admin_delivery_store_set_commission(uuid,numeric) to authenticated;

create or replace function public.admin_delivery_settlement_set_status(
  p_settlement_id uuid,
  p_status text,
  p_note text default null
) returns boolean
language plpgsql
security definer
set search_path=public
as $$
begin
  perform public.delivery_finance_require_admin();
  if p_status not in ('pending','approved','paid','cancelled') then raise exception 'Invalid settlement status'; end if;
  update public.delivery_seller_settlements
  set status=p_status,
      approved_at=case when p_status in ('approved','paid') then coalesce(approved_at,now()) else approved_at end,
      paid_at=case when p_status='paid' then coalesce(paid_at,now()) when p_status<>'paid' then null else paid_at end,
      admin_note=coalesce(nullif(trim(coalesce(p_note,'')),''),admin_note),
      updated_at=now()
  where id=p_settlement_id;
  if not found then raise exception 'Settlement not found'; end if;
  return true;
end;
$$;

revoke all on function public.admin_delivery_settlement_set_status(uuid,text,text) from public;
grant execute on function public.admin_delivery_settlement_set_status(uuid,text,text) to authenticated;

create or replace function public.admin_delivery_driver_earning_set_status(
  p_earning_id uuid,
  p_status text
) returns boolean
language plpgsql
security definer
set search_path=public
as $$
begin
  perform public.delivery_finance_require_admin();
  if p_status not in ('pending','approved','paid','cancelled') then raise exception 'Invalid earning status'; end if;
  update public.delivery_earnings
  set status=p_status,
      paid_at=case when p_status='paid' then coalesce(paid_at,now()) when p_status<>'paid' then null else paid_at end
  where id=p_earning_id;
  if not found then raise exception 'Driver earning not found'; end if;
  return true;
end;
$$;

revoke all on function public.admin_delivery_driver_earning_set_status(uuid,text) from public;
grant execute on function public.admin_delivery_driver_earning_set_status(uuid,text) to authenticated;

create or replace function public.admin_delivery_finance_dashboard()
returns jsonb
language plpgsql
security definer
set search_path=public
stable
as $$
declare v_result jsonb;
begin
  perform public.delivery_finance_require_admin();
  select jsonb_build_object(
    'summary',jsonb_build_object(
      'seller_payable',coalesce((select sum(seller_net) from public.delivery_seller_settlements where status in ('pending','approved')),0),
      'seller_paid',coalesce((select sum(seller_net) from public.delivery_seller_settlements where status='paid'),0),
      'merchandise_commission',coalesce((select sum(bingo_commission) from public.delivery_seller_settlements where status<>'cancelled'),0),
      'driver_payable',coalesce((select sum(amount) from public.delivery_earnings where status in ('pending','approved')),0),
      'driver_paid',coalesce((select sum(amount) from public.delivery_earnings where status='paid'),0),
      'bingo_delivery_share',coalesce((select sum(bingo_share) from public.delivery_orders where status='delivered'),0),
      'official_bingo_sales',coalesce((select sum(o.subtotal) from public.delivery_orders o join public.delivery_stores s on s.id=o.store_id where o.status='delivered' and s.owner_id is null),0)
    ),
    'stores',coalesce((
      select jsonb_agg(jsonb_build_object(
        'id',s.id,'store_name',coalesce(s.store_name_ar,s.store_name_en,s.store_name),
        'owner_id',s.owner_id,'commission_percent',s.bingo_commission_percent,
        'pending_net',coalesce(x.pending_net,0),'paid_net',coalesce(x.paid_net,0),
        'commission_total',coalesce(x.commission_total,0)
      ) order by coalesce(s.store_name_ar,s.store_name_en,s.store_name))
      from public.delivery_stores s
      left join lateral (
        select sum(ss.seller_net) filter(where ss.status in ('pending','approved')) pending_net,
               sum(ss.seller_net) filter(where ss.status='paid') paid_net,
               sum(ss.bingo_commission) filter(where ss.status<>'cancelled') commission_total
        from public.delivery_seller_settlements ss where ss.store_id=s.id
      ) x on true
      where s.owner_id is not null
    ),'[]'::jsonb),
    'settlements',coalesce((
      select jsonb_agg(jsonb_build_object(
        'id',ss.id,'order_id',ss.order_id,'order_number',o.order_number,
        'store_id',ss.store_id,'store_name',coalesce(s.store_name_ar,s.store_name_en,s.store_name),
        'subtotal',ss.order_subtotal,'commission_percent',ss.commission_percent,
        'commission',ss.bingo_commission,'seller_net',ss.seller_net,
        'status',ss.status,'created_at',ss.created_at,'paid_at',ss.paid_at
      ) order by ss.created_at desc)
      from (select * from public.delivery_seller_settlements order by created_at desc limit 100) ss
      join public.delivery_orders o on o.id=ss.order_id
      join public.delivery_stores s on s.id=ss.store_id
    ),'[]'::jsonb),
    'driver_earnings',coalesce((
      select jsonb_agg(jsonb_build_object(
        'id',e.id,'driver_id',e.driver_id,'driver_name',coalesce(d.display_name,d.phone,'Driver'),
        'order_id',e.order_id,'order_number',o.order_number,'amount',e.amount,
        'status',e.status,'created_at',e.created_at,'paid_at',e.paid_at
      ) order by e.created_at desc)
      from (select * from public.delivery_earnings order by created_at desc limit 100) e
      join public.delivery_drivers d on d.id=e.driver_id
      join public.delivery_orders o on o.id=e.order_id
    ),'[]'::jsonb)
  ) into v_result;
  return v_result;
end;
$$;

revoke all on function public.admin_delivery_finance_dashboard() from public;
grant execute on function public.admin_delivery_finance_dashboard() to authenticated;

NOTIFY pgrst, 'reload schema';
