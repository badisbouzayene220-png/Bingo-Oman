-- BINGO DELIVERY V1
-- Safe, additive migration. No ERP tables/functions are modified.

create extension if not exists pgcrypto;

create table if not exists public.delivery_zones (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  name_ar text,
  name_en text,
  is_active boolean not null default true,
  created_at timestamptz not null default now()
);

create table if not exists public.delivery_pricing_rules (
  id uuid primary key default gen_random_uuid(),
  zone_id uuid references public.delivery_zones(id) on delete cascade,
  min_km numeric(10,2) not null default 0,
  max_km numeric(10,2),
  customer_fee numeric(12,3) not null default 0,
  driver_share numeric(12,3) not null default 0,
  bingo_share numeric(12,3) not null default 0,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  constraint delivery_pricing_nonnegative check (min_km >= 0 and (max_km is null or max_km >= min_km) and customer_fee >= 0 and driver_share >= 0 and bingo_share >= 0)
);

create table if not exists public.delivery_drivers (
  id uuid primary key references auth.users(id) on delete cascade,
  display_name text,
  phone text,
  vehicle_type text,
  is_online boolean not null default false,
  is_available boolean not null default false,
  rating numeric(3,2) not null default 5.00,
  total_deliveries integer not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint driver_rating check (rating between 0 and 5)
);

create table if not exists public.delivery_driver_locations (
  driver_id uuid primary key references public.delivery_drivers(id) on delete cascade,
  latitude numeric(10,7) not null,
  longitude numeric(10,7) not null,
  accuracy_m numeric(10,2),
  heading numeric(6,2),
  speed_kmh numeric(8,2),
  updated_at timestamptz not null default now(),
  constraint valid_latitude check (latitude between -90 and 90),
  constraint valid_longitude check (longitude between -180 and 180)
);

create table if not exists public.delivery_stores (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid references auth.users(id) on delete set null,
  store_name text not null,
  store_name_ar text,
  store_name_en text,
  phone text,
  address text,
  latitude numeric(10,7),
  longitude numeric(10,7),
  is_active boolean not null default true,
  created_at timestamptz not null default now()
);

create table if not exists public.delivery_orders (
  id uuid primary key default gen_random_uuid(),
  order_number text not null unique default ('BGO-' || upper(substr(replace(gen_random_uuid()::text,'-',''),1,8))),
  customer_id uuid not null references auth.users(id) on delete restrict,
  store_id uuid references public.delivery_stores(id) on delete set null,
  status text not null default 'pending',
  payment_status text not null default 'pending',
  delivery_address text,
  latitude numeric(10,7),
  longitude numeric(10,7),
  distance_km numeric(10,2),
  subtotal numeric(12,3) not null default 0,
  delivery_fee numeric(12,3) not null default 0,
  driver_share numeric(12,3) not null default 0,
  bingo_share numeric(12,3) not null default 0,
  store_commission numeric(12,3) not null default 0,
  total numeric(12,3) not null default 0,
  notes text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint delivery_order_status check (status in ('pending','confirmed','preparing','ready','assigned','picked_up','on_delivery','delivered','cancelled')),
  constraint delivery_payment_status check (payment_status in ('pending','paid','failed','refunded')),
  constraint delivery_order_amounts check (subtotal >= 0 and delivery_fee >= 0 and driver_share >= 0 and bingo_share >= 0 and store_commission >= 0 and total >= 0)
);

create table if not exists public.delivery_order_items (
  id uuid primary key default gen_random_uuid(),
  order_id uuid not null references public.delivery_orders(id) on delete cascade,
  product_id uuid,
  description text not null,
  quantity numeric(18,3) not null,
  unit_price numeric(18,3) not null,
  line_total numeric(18,3) generated always as (quantity * unit_price) stored,
  created_at timestamptz not null default now(),
  constraint delivery_item_positive check (quantity > 0 and unit_price >= 0)
);

create table if not exists public.delivery_assignments (
  id uuid primary key default gen_random_uuid(),
  order_id uuid not null references public.delivery_orders(id) on delete cascade,
  driver_id uuid not null references public.delivery_drivers(id) on delete restrict,
  status text not null default 'offered',
  offered_at timestamptz not null default now(),
  accepted_at timestamptz,
  picked_up_at timestamptz,
  delivered_at timestamptz,
  rejected_at timestamptz,
  constraint assignment_status check (status in ('offered','accepted','rejected','picked_up','on_delivery','delivered','cancelled'))
);

create unique index if not exists delivery_one_active_assignment_per_order
on public.delivery_assignments(order_id)
where status in ('offered','accepted','picked_up','on_delivery');

create table if not exists public.delivery_earnings (
  id uuid primary key default gen_random_uuid(),
  driver_id uuid not null references public.delivery_drivers(id) on delete restrict,
  order_id uuid not null references public.delivery_orders(id) on delete restrict,
  amount numeric(12,3) not null,
  status text not null default 'pending',
  paid_at timestamptz,
  created_at timestamptz not null default now(),
  constraint earning_status check (status in ('pending','approved','paid','cancelled')),
  constraint earning_amount check (amount >= 0),
  unique(driver_id, order_id)
);

create table if not exists public.delivery_ratings (
  id uuid primary key default gen_random_uuid(),
  order_id uuid not null unique references public.delivery_orders(id) on delete cascade,
  customer_id uuid not null references auth.users(id) on delete restrict,
  driver_id uuid not null references public.delivery_drivers(id) on delete restrict,
  rating integer not null,
  comment text,
  created_at timestamptz not null default now(),
  constraint delivery_rating_range check (rating between 1 and 5)
);

create table if not exists public.delivery_complaints (
  id uuid primary key default gen_random_uuid(),
  order_id uuid references public.delivery_orders(id) on delete set null,
  customer_id uuid references auth.users(id) on delete set null,
  driver_id uuid references public.delivery_drivers(id) on delete set null,
  store_id uuid references public.delivery_stores(id) on delete set null,
  subject text not null,
  description text,
  status text not null default 'open',
  created_at timestamptz not null default now(),
  resolved_at timestamptz,
  constraint complaint_status check (status in ('open','in_review','resolved','closed'))
);

create index if not exists delivery_orders_customer_idx on public.delivery_orders(customer_id, created_at desc);
create index if not exists delivery_orders_status_idx on public.delivery_orders(status, created_at desc);
create index if not exists delivery_assignments_driver_idx on public.delivery_assignments(driver_id, status);
create index if not exists delivery_locations_updated_idx on public.delivery_driver_locations(updated_at desc);
create index if not exists delivery_earnings_driver_idx on public.delivery_earnings(driver_id, created_at desc);

alter table public.delivery_zones enable row level security;
alter table public.delivery_pricing_rules enable row level security;
alter table public.delivery_drivers enable row level security;
alter table public.delivery_driver_locations enable row level security;
alter table public.delivery_stores enable row level security;
alter table public.delivery_orders enable row level security;
alter table public.delivery_order_items enable row level security;
alter table public.delivery_assignments enable row level security;
alter table public.delivery_earnings enable row level security;
alter table public.delivery_ratings enable row level security;
alter table public.delivery_complaints enable row level security;

-- Publicly readable configuration.
create policy if not exists delivery_zones_read on public.delivery_zones for select to authenticated using (is_active);
create policy if not exists delivery_pricing_read on public.delivery_pricing_rules for select to authenticated using (is_active);

-- Customers can see/create their own orders and rate their completed delivery.
create policy if not exists delivery_orders_customer_read on public.delivery_orders for select to authenticated using (customer_id = auth.uid());
create policy if not exists delivery_orders_customer_insert on public.delivery_orders for insert to authenticated with check (customer_id = auth.uid());
create policy if not exists delivery_order_items_customer_read on public.delivery_order_items for select to authenticated using (exists (select 1 from public.delivery_orders o where o.id = order_id and o.customer_id = auth.uid()));
create policy if not exists delivery_ratings_customer_read on public.delivery_ratings for select to authenticated using (customer_id = auth.uid());
create policy if not exists delivery_ratings_customer_insert on public.delivery_ratings for insert to authenticated with check (customer_id = auth.uid());

-- Drivers can read/update their own profile/location and see their assignments/earnings.
create policy if not exists delivery_driver_self_read on public.delivery_drivers for select to authenticated using (id = auth.uid());
create policy if not exists delivery_driver_self_update on public.delivery_drivers for update to authenticated using (id = auth.uid()) with check (id = auth.uid());
create policy if not exists delivery_location_self_all on public.delivery_driver_locations for all to authenticated using (driver_id = auth.uid()) with check (driver_id = auth.uid());
create policy if not exists delivery_assignment_driver_read on public.delivery_assignments for select to authenticated using (driver_id = auth.uid());
create policy if not exists delivery_assignment_driver_update on public.delivery_assignments for update to authenticated using (driver_id = auth.uid()) with check (driver_id = auth.uid());
create policy if not exists delivery_earnings_driver_read on public.delivery_earnings for select to authenticated using (driver_id = auth.uid());

-- Store owners can see their own stores and related orders.
create policy if not exists delivery_store_owner_read on public.delivery_stores for select to authenticated using (owner_id = auth.uid());
create policy if not exists delivery_orders_store_read on public.delivery_orders for select to authenticated using (exists (select 1 from public.delivery_stores s where s.id = store_id and s.owner_id = auth.uid()));
create policy if not exists delivery_order_items_store_read on public.delivery_order_items for select to authenticated using (exists (select 1 from public.delivery_orders o join public.delivery_stores s on s.id=o.store_id where o.id=order_id and s.owner_id=auth.uid()));

-- Realtime is intentionally limited to delivery operational tables; enable publication only if not already present.
DO $$
BEGIN
  BEGIN alter publication supabase_realtime add table public.delivery_orders; EXCEPTION WHEN duplicate_object THEN NULL; END;
  BEGIN alter publication supabase_realtime add table public.delivery_assignments; EXCEPTION WHEN duplicate_object THEN NULL; END;
  BEGIN alter publication supabase_realtime add table public.delivery_driver_locations; EXCEPTION WHEN duplicate_object THEN NULL; END;
END $$;
