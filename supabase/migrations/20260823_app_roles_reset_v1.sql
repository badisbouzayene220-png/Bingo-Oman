-- BINGO App Roles Reset V1
-- Resets app access roles without deleting users, orders, stores or payments.

alter table public.profiles add column if not exists app_role text;

update public.profiles
set app_role = case when role::text='admin' then 'admin' else 'customer' end;

alter table public.profiles alter column app_role set default 'customer';

create or replace function public.my_app_role()
returns text
language sql
security definer
set search_path=public
stable
as $$
  select coalesce(
    (select case when p.role::text='admin' then 'admin' else coalesce(nullif(p.app_role,''),'customer') end
     from public.profiles p where p.id=auth.uid()),
    'customer'
  );
$$;

create or replace function public.admin_app_users()
returns table(
  user_id uuid,
  email text,
  full_name text,
  platform_role text,
  app_role text,
  is_active boolean
)
language plpgsql
security definer
set search_path=public
as $$
begin
  if not exists(select 1 from public.profiles p where p.id=auth.uid() and p.role::text='admin' and coalesce(p.is_active,true)=true) then
    raise exception 'Admin access required';
  end if;

  return query
  select p.id,
         coalesce(u.email,'')::text,
         coalesce(p.full_name,'')::text,
         p.role::text,
         case when p.role::text='admin' then 'admin' else coalesce(nullif(p.app_role,''),'customer') end::text,
         coalesce(p.is_active,true)
  from public.profiles p
  left join auth.users u on u.id=p.id
  order by lower(coalesce(p.full_name,u.email,''));
end;
$$;

create or replace function public.admin_set_app_role(p_user_id uuid,p_app_role text)
returns jsonb
language plpgsql
security definer
set search_path=public
as $$
declare
  v_role text:=lower(trim(coalesce(p_app_role,'')));
  v_platform_role text;
begin
  if not exists(select 1 from public.profiles p where p.id=auth.uid() and p.role::text='admin' and coalesce(p.is_active,true)=true) then
    raise exception 'Admin access required';
  end if;
  if v_role not in ('customer','seller','driver') then
    raise exception 'Invalid app role';
  end if;

  select role::text into v_platform_role from public.profiles where id=p_user_id for update;
  if not found then raise exception 'User not found'; end if;
  if v_platform_role='admin' then raise exception 'Admin role cannot be changed here'; end if;

  update public.profiles set app_role=v_role where id=p_user_id;
  return jsonb_build_object('ok',true,'user_id',p_user_id,'app_role',v_role);
end;
$$;

revoke all on function public.my_app_role() from public;
grant execute on function public.my_app_role() to authenticated;
revoke all on function public.admin_app_users() from public;
grant execute on function public.admin_app_users() to authenticated;
revoke all on function public.admin_set_app_role(uuid,text) from public;
grant execute on function public.admin_set_app_role(uuid,text) to authenticated;

notify pgrst,'reload schema';