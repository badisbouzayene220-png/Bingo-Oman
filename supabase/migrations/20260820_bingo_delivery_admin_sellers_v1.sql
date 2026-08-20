-- BINGO Delivery Admin Sellers V1
-- Admin-only Seller/store management for the Delivery Control panel.

create or replace function public.admin_delivery_sellers_all()
returns table(
  store_id uuid,
  seller_id uuid,
  seller_name text,
  email text,
  store_name text,
  address text,
  is_active boolean,
  created_at timestamptz
)
language plpgsql
security definer
set search_path=public,auth
stable
as $$
begin
  if not public.delivery_is_admin() then
    raise exception 'Admin permission required';
  end if;

  return query
  select
    s.id,
    s.owner_id,
    coalesce(p.full_name, u.raw_user_meta_data->>'full_name', split_part(u.email,'@',1), 'Seller')::text,
    u.email::text,
    coalesce(s.store_name_ar,s.store_name_en,s.store_name)::text,
    s.address::text,
    s.is_active,
    s.created_at
  from public.delivery_stores s
  left join auth.users u on u.id=s.owner_id
  left join public.profiles p on p.id=s.owner_id
  order by s.created_at desc;
end;
$$;

revoke all on function public.admin_delivery_sellers_all() from public;
grant execute on function public.admin_delivery_sellers_all() to authenticated;

create or replace function public.admin_delivery_seller_create(
  p_email text,
  p_store_name text,
  p_address text default null
)
returns jsonb
language plpgsql
security definer
set search_path=public,auth
as $$
declare
  v_uid uuid;
  v_email text:=lower(trim(coalesce(p_email,'')));
  v_name text:=trim(coalesce(p_store_name,''));
  v_store uuid;
begin
  if not public.delivery_is_admin() then raise exception 'Admin permission required'; end if;
  if v_email='' then raise exception 'Seller email is required'; end if;
  if v_name='' then raise exception 'Store name is required'; end if;

  select u.id into v_uid
  from auth.users u
  where lower(u.email)=v_email
  order by u.created_at desc
  limit 1;

  if v_uid is null then
    raise exception 'Seller Auth account not found. Create the user in Authentication first.';
  end if;

  if exists(select 1 from public.profiles p where p.id=v_uid and p.role='admin') then
    raise exception 'Admin account cannot be assigned as Seller. Use a separate Seller email.';
  end if;

  if exists(select 1 from public.delivery_drivers d where d.id=v_uid) then
    raise exception 'This account is already a Driver. Use a separate Seller account.';
  end if;

  select s.id into v_store from public.delivery_stores s where s.owner_id=v_uid limit 1;
  if v_store is not null then
    raise exception 'This Seller already has a Delivery store.';
  end if;

  insert into public.delivery_stores(owner_id,store_name,store_name_ar,store_name_en,address,is_active)
  values(v_uid,v_name,v_name,v_name,nullif(trim(coalesce(p_address,'')),''),true)
  returning id into v_store;

  return jsonb_build_object('ok',true,'seller_id',v_uid,'store_id',v_store,'email',v_email);
end;
$$;

revoke all on function public.admin_delivery_seller_create(text,text,text) from public;
grant execute on function public.admin_delivery_seller_create(text,text,text) to authenticated;

create or replace function public.admin_delivery_seller_update(
  p_store_id uuid,
  p_store_name text default null,
  p_address text default null,
  p_is_active boolean default null
)
returns jsonb
language plpgsql
security definer
set search_path=public
as $$
declare v_exists boolean;
begin
  if not public.delivery_is_admin() then raise exception 'Admin permission required'; end if;

  select exists(select 1 from public.delivery_stores s where s.id=p_store_id) into v_exists;
  if not v_exists then raise exception 'Seller store not found'; end if;

  update public.delivery_stores
  set store_name=case when p_store_name is null then store_name else trim(p_store_name) end,
      store_name_ar=case when p_store_name is null then store_name_ar else trim(p_store_name) end,
      store_name_en=case when p_store_name is null then store_name_en else trim(p_store_name) end,
      address=case when p_address is null then address else nullif(trim(p_address),'') end,
      is_active=coalesce(p_is_active,is_active)
  where id=p_store_id;

  return jsonb_build_object('ok',true,'store_id',p_store_id);
end;
$$;

revoke all on function public.admin_delivery_seller_update(uuid,text,text,boolean) from public;
grant execute on function public.admin_delivery_seller_update(uuid,text,text,boolean) to authenticated;
