-- BINGO Oman — manual package / promotion order workflow (no payment gateway)
begin;

create table if not exists public.bingo_package_catalog (
  code text primary key,
  kind text not null check (kind in ('promotion','republish_plan')),
  name_en text not null,
  name_ar text not null,
  amount_baisa integer not null check (amount_baisa >= 0),
  duration_days integer not null check (duration_days > 0),
  is_active boolean not null default true,
  sort_order integer not null default 0,
  updated_at timestamptz not null default now()
);

insert into public.bingo_package_catalog(code,kind,name_en,name_ar,amount_baisa,duration_days,is_active,sort_order)
values
 ('highlight','promotion','Highlight','تمييز الإعلان',1000,7,true,10),
 ('featured','promotion','Featured Ad','إعلان مميز',2000,7,true,20),
 ('top','promotion','Top Ad','إعلان في الأعلى',3000,7,true,30),
 ('monthly','republish_plan','Monthly Republish','إعادة نشر شهرية',5000,30,true,40),
 ('yearly','republish_plan','Yearly Republish','إعادة نشر سنوية',50000,365,true,50)
on conflict (code) do nothing;

alter table public.bingo_package_catalog enable row level security;
drop policy if exists "Anyone can view active package catalog" on public.bingo_package_catalog;
create policy "Anyone can view active package catalog" on public.bingo_package_catalog for select using (is_active=true);

create table if not exists public.bingo_purchase_orders (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  package_code text not null references public.bingo_package_catalog(code),
  package_kind text not null,
  listing_id uuid references public.listings(id) on delete cascade,
  amount_baisa integer not null,
  currency text not null default 'OMR',
  status text not null default 'pending' check (status in ('pending','approved','rejected','cancelled')),
  payment_method text not null default 'manual',
  customer_note text,
  admin_note text,
  created_at timestamptz not null default now(),
  decided_at timestamptz,
  approved_by uuid references auth.users(id)
);
create index if not exists bingo_purchase_orders_user_idx on public.bingo_purchase_orders(user_id,created_at desc);
create index if not exists bingo_purchase_orders_status_idx on public.bingo_purchase_orders(status,created_at desc);

alter table public.bingo_purchase_orders enable row level security;
drop policy if exists "Users view own purchase orders" on public.bingo_purchase_orders;
create policy "Users view own purchase orders" on public.bingo_purchase_orders for select to authenticated using (user_id=auth.uid());

create or replace function public.create_manual_purchase_order(p_package_code text,p_listing_id uuid default null,p_customer_note text default null)
returns uuid
language plpgsql security definer set search_path=public
as $$
declare v_user uuid:=auth.uid(); v_pkg public.bingo_package_catalog%rowtype; v_order uuid;
begin
 if v_user is null then raise exception 'Authentication required'; end if;
 select * into v_pkg from public.bingo_package_catalog where code=p_package_code and is_active=true;
 if not found then raise exception 'Package not available'; end if;
 if v_pkg.kind='promotion' then
   if p_listing_id is null then raise exception 'Listing required'; end if;
   if not exists(select 1 from public.listings where id=p_listing_id and user_id=v_user and status='published') then raise exception 'Published listing not found or not owned by you'; end if;
 else
   p_listing_id:=null;
 end if;
 if exists(select 1 from public.bingo_purchase_orders o where o.user_id=v_user and o.package_code=p_package_code and o.status='pending' and o.listing_id is not distinct from p_listing_id) then
   select id into v_order from public.bingo_purchase_orders o where o.user_id=v_user and o.package_code=p_package_code and o.status='pending' and o.listing_id is not distinct from p_listing_id order by created_at desc limit 1;
   return v_order;
 end if;
 insert into public.bingo_purchase_orders(user_id,package_code,package_kind,listing_id,amount_baisa,customer_note)
 values(v_user,v_pkg.code,v_pkg.kind,p_listing_id,v_pkg.amount_baisa,nullif(trim(p_customer_note),'')) returning id into v_order;
 return v_order;
end;$$;

create or replace function public.my_manual_purchase_orders()
returns table(order_id uuid,package_code text,package_kind text,listing_id uuid,listing_title text,amount_baisa integer,currency text,status text,customer_note text,admin_note text,created_at timestamptz,decided_at timestamptz)
language sql security definer set search_path=public
as $$
 select o.id,o.package_code,o.package_kind,o.listing_id,l.title::text,o.amount_baisa,o.currency,o.status,o.customer_note,o.admin_note,o.created_at,o.decided_at
 from public.bingo_purchase_orders o left join public.listings l on l.id=o.listing_id
 where o.user_id=auth.uid() order by o.created_at desc;
$$;

create or replace function public.admin_manual_purchase_orders()
returns table(order_id uuid,user_id uuid,user_name text,user_email text,package_code text,package_kind text,listing_id uuid,listing_title text,amount_baisa integer,currency text,status text,customer_note text,admin_note text,created_at timestamptz,decided_at timestamptz)
language plpgsql security definer set search_path=public
as $$
declare v_role text;
begin
 select role::text into v_role from public.profiles where id=auth.uid(); if coalesce(v_role,'')<>'admin' then raise exception 'Admin access required'; end if;
 return query select o.id,o.user_id,coalesce(p.full_name,p.username,'')::text,coalesce(p.email,'')::text,o.package_code,o.package_kind,o.listing_id,l.title::text,o.amount_baisa,o.currency,o.status,o.customer_note,o.admin_note,o.created_at,o.decided_at
 from public.bingo_purchase_orders o left join public.profiles p on p.id=o.user_id left join public.listings l on l.id=o.listing_id order by case when o.status='pending' then 0 else 1 end,o.created_at desc;
end;$$;

create or replace function public.admin_decide_manual_purchase_order(p_order_id uuid,p_action text,p_admin_note text default null)
returns boolean
language plpgsql security definer set search_path=public
as $$
declare v_role text; v_order public.bingo_purchase_orders%rowtype; v_pkg public.bingo_package_catalog%rowtype; v_end timestamptz;
begin
 select role::text into v_role from public.profiles where id=auth.uid(); if coalesce(v_role,'')<>'admin' then raise exception 'Admin access required'; end if;
 if p_action not in ('approve','reject') then raise exception 'Invalid action'; end if;
 select * into v_order from public.bingo_purchase_orders where id=p_order_id for update; if not found then raise exception 'Order not found'; end if;
 if v_order.status<>'pending' then raise exception 'Order already decided'; end if;
 select * into v_pkg from public.bingo_package_catalog where code=v_order.package_code; if not found then raise exception 'Package not found'; end if;
 if p_action='reject' then update public.bingo_purchase_orders set status='rejected',admin_note=p_admin_note,decided_at=now(),approved_by=auth.uid() where id=p_order_id; return true; end if;
 v_end:=now()+make_interval(days=>v_pkg.duration_days);
 if v_pkg.kind='promotion' then
   update public.listings set promotion_type=v_pkg.code,promoted_at=now(),promotion_expires_at=v_end where id=v_order.listing_id and user_id=v_order.user_id and status='published';
   if not found then raise exception 'Published listing no longer available'; end if;
 else
   update public.listing_republish_subscriptions set status='expired',updated_at=now() where user_id=v_order.user_id and status='active' and ends_at<=now();
   insert into public.listing_republish_subscriptions(user_id,plan,status,starts_at,ends_at) values(v_order.user_id,v_pkg.code,'active',now(),v_end);
 end if;
 update public.bingo_purchase_orders set status='approved',admin_note=p_admin_note,decided_at=now(),approved_by=auth.uid() where id=p_order_id;
 return true;
end;$$;

revoke all on function public.create_manual_purchase_order(text,uuid,text) from public,anon;
revoke all on function public.my_manual_purchase_orders() from public,anon;
revoke all on function public.admin_manual_purchase_orders() from public,anon;
revoke all on function public.admin_decide_manual_purchase_order(uuid,text,text) from public,anon;
grant execute on function public.create_manual_purchase_order(text,uuid,text) to authenticated;
grant execute on function public.my_manual_purchase_orders() to authenticated;
grant execute on function public.admin_manual_purchase_orders() to authenticated;
grant execute on function public.admin_decide_manual_purchase_order(uuid,text,text) to authenticated;

commit;