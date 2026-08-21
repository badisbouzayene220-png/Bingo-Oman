-- BINGO Oman — Customer Profile + Saved Addresses V1

create table if not exists public.customer_saved_addresses (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  label text not null default 'Home',
  recipient_name text,
  phone text,
  address_line text not null,
  building text,
  apartment text,
  landmark text,
  delivery_instructions text,
  latitude numeric(10,7),
  longitude numeric(10,7),
  is_default boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint customer_saved_address_lat check (latitude is null or latitude between -90 and 90),
  constraint customer_saved_address_lng check (longitude is null or longitude between -180 and 180)
);

create index if not exists customer_saved_addresses_user_idx
  on public.customer_saved_addresses(user_id, is_default desc, created_at desc);

alter table public.customer_saved_addresses enable row level security;

do $$ begin
  create policy customer_saved_addresses_read on public.customer_saved_addresses
    for select to authenticated using (user_id=auth.uid());
exception when duplicate_object then null; end $$;
do $$ begin
  create policy customer_saved_addresses_insert on public.customer_saved_addresses
    for insert to authenticated with check (user_id=auth.uid());
exception when duplicate_object then null; end $$;
do $$ begin
  create policy customer_saved_addresses_update on public.customer_saved_addresses
    for update to authenticated using (user_id=auth.uid()) with check (user_id=auth.uid());
exception when duplicate_object then null; end $$;
do $$ begin
  create policy customer_saved_addresses_delete on public.customer_saved_addresses
    for delete to authenticated using (user_id=auth.uid());
exception when duplicate_object then null; end $$;

create or replace function public.customer_profile_save(
  p_full_name text,
  p_phone text,
  p_city text default null
) returns boolean
language plpgsql
security definer
set search_path=public
as $$
declare uid uuid:=auth.uid();
begin
  if uid is null then raise exception 'Authentication required'; end if;
  if trim(coalesce(p_full_name,''))='' then raise exception 'Full name is required'; end if;
  if trim(coalesce(p_phone,''))='' then raise exception 'Phone number is required'; end if;

  update public.profiles
  set full_name=trim(p_full_name), phone=trim(p_phone), city=nullif(trim(coalesce(p_city,'')),''), updated_at=now()
  where id=uid;

  if not found then
    insert into public.profiles(id,full_name,phone,city)
    values(uid,trim(p_full_name),trim(p_phone),nullif(trim(coalesce(p_city,'')),''));
  end if;

  update auth.users
  set raw_user_meta_data=coalesce(raw_user_meta_data,'{}'::jsonb)
      || jsonb_build_object('full_name',trim(p_full_name),'phone',trim(p_phone),'city',nullif(trim(coalesce(p_city,'')),'')),
      updated_at=now()
  where id=uid;
  return true;
end;
$$;
revoke all on function public.customer_profile_save(text,text,text) from public;
grant execute on function public.customer_profile_save(text,text,text) to authenticated;

create or replace function public.customer_saved_address_save(
  p_id uuid,
  p_label text,
  p_recipient_name text,
  p_phone text,
  p_address_line text,
  p_building text default null,
  p_apartment text default null,
  p_landmark text default null,
  p_delivery_instructions text default null,
  p_latitude numeric default null,
  p_longitude numeric default null,
  p_is_default boolean default false
) returns uuid
language plpgsql
security definer
set search_path=public
as $$
declare uid uuid:=auth.uid(); v_id uuid;
begin
  if uid is null then raise exception 'Authentication required'; end if;
  if trim(coalesce(p_address_line,''))='' then raise exception 'Address is required'; end if;
  if p_latitude is not null and (p_latitude < -90 or p_latitude > 90) then raise exception 'Invalid latitude'; end if;
  if p_longitude is not null and (p_longitude < -180 or p_longitude > 180) then raise exception 'Invalid longitude'; end if;

  if coalesce(p_is_default,false) then
    update public.customer_saved_addresses set is_default=false,updated_at=now() where user_id=uid and is_default=true;
  end if;

  if p_id is null then
    insert into public.customer_saved_addresses(user_id,label,recipient_name,phone,address_line,building,apartment,landmark,delivery_instructions,latitude,longitude,is_default)
    values(uid,coalesce(nullif(trim(p_label),''),'Home'),nullif(trim(coalesce(p_recipient_name,'')),''),nullif(trim(coalesce(p_phone,'')),''),trim(p_address_line),nullif(trim(coalesce(p_building,'')),''),nullif(trim(coalesce(p_apartment,'')),''),nullif(trim(coalesce(p_landmark,'')),''),nullif(trim(coalesce(p_delivery_instructions,'')),''),p_latitude,p_longitude,coalesce(p_is_default,false))
    returning id into v_id;
  else
    update public.customer_saved_addresses
    set label=coalesce(nullif(trim(p_label),''),'Home'),recipient_name=nullif(trim(coalesce(p_recipient_name,'')),''),phone=nullif(trim(coalesce(p_phone,'')),''),address_line=trim(p_address_line),building=nullif(trim(coalesce(p_building,'')),''),apartment=nullif(trim(coalesce(p_apartment,'')),''),landmark=nullif(trim(coalesce(p_landmark,'')),''),delivery_instructions=nullif(trim(coalesce(p_delivery_instructions,'')),''),latitude=p_latitude,longitude=p_longitude,is_default=coalesce(p_is_default,false),updated_at=now()
    where id=p_id and user_id=uid returning id into v_id;
    if v_id is null then raise exception 'Address not found'; end if;
  end if;

  -- First address becomes default automatically.
  if not exists(select 1 from public.customer_saved_addresses where user_id=uid and is_default=true) then
    update public.customer_saved_addresses set is_default=true where id=v_id;
  end if;
  return v_id;
end;
$$;
revoke all on function public.customer_saved_address_save(uuid,text,text,text,text,text,text,text,text,numeric,numeric,boolean) from public;
grant execute on function public.customer_saved_address_save(uuid,text,text,text,text,text,text,text,text,numeric,numeric,boolean) to authenticated;

create or replace function public.customer_saved_address_delete(p_id uuid)
returns boolean language plpgsql security definer set search_path=public as $$
declare uid uuid:=auth.uid(); was_default boolean;
begin
  if uid is null then raise exception 'Authentication required'; end if;
  select is_default into was_default from public.customer_saved_addresses where id=p_id and user_id=uid;
  delete from public.customer_saved_addresses where id=p_id and user_id=uid;
  if not found then raise exception 'Address not found'; end if;
  if coalesce(was_default,false) then
    update public.customer_saved_addresses set is_default=true,updated_at=now()
    where id=(select id from public.customer_saved_addresses where user_id=uid order by created_at desc limit 1);
  end if;
  return true;
end;
$$;
revoke all on function public.customer_saved_address_delete(uuid) from public;
grant execute on function public.customer_saved_address_delete(uuid) to authenticated;

NOTIFY pgrst, 'reload schema';
