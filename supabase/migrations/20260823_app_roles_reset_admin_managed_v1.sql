-- BINGO Oman: one source of truth for mobile app roles.
-- Safe reset: keeps auth users, orders, stores, drivers, payments and history.

create table if not exists public.bingo_app_roles (
  user_id uuid primary key references auth.users(id) on delete cascade,
  app_role text not null default 'customer' check (app_role in ('customer','seller','driver')),
  assigned_by uuid null references auth.users(id),
  assigned_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.bingo_app_roles enable row level security;

drop policy if exists bingo_app_roles_read_own on public.bingo_app_roles;
create policy bingo_app_roles_read_own on public.bingo_app_roles
for select to authenticated using (user_id = auth.uid());

-- RESET all existing authenticated users to customer. Admin website role remains untouched in profiles.
insert into public.bingo_app_roles(user_id,app_role,assigned_by,assigned_at,updated_at)
select id,'customer',null,now(),now() from auth.users
on conflict (user_id) do update set app_role='customer',assigned_by=null,assigned_at=now(),updated_at=now();

create or replace function public.bingo_my_app_role()
returns text language sql security definer set search_path=public,auth stable as $$
  select coalesce((select r.app_role from public.bingo_app_roles r where r.user_id=auth.uid()),'customer');
$$;
revoke all on function public.bingo_my_app_role() from public;
grant execute on function public.bingo_my_app_role() to authenticated;

create or replace function public.admin_set_bingo_app_role(p_user_id uuid,p_role text)
returns text language plpgsql security definer set search_path=public,auth as $$
begin
  if not exists(select 1 from public.profiles p where p.id=auth.uid() and p.role='admin' and coalesce(p.is_active,true)) then
    raise exception 'Admin access required';
  end if;
  if p_role not in ('customer','seller','driver') then raise exception 'Invalid app role'; end if;
  if not exists(select 1 from auth.users where id=p_user_id) then raise exception 'User not found'; end if;
  insert into public.bingo_app_roles(user_id,app_role,assigned_by,assigned_at,updated_at)
  values(p_user_id,p_role,auth.uid(),now(),now())
  on conflict(user_id) do update set app_role=excluded.app_role,assigned_by=excluded.assigned_by,assigned_at=now(),updated_at=now();
  return p_role;
end;$$;
revoke all on function public.admin_set_bingo_app_role(uuid,text) from public;
grant execute on function public.admin_set_bingo_app_role(uuid,text) to authenticated;

create or replace function public.admin_list_bingo_app_roles()
returns table(user_id uuid,app_role text) language sql security definer set search_path=public,auth stable as $$
  select r.user_id,r.app_role from public.bingo_app_roles r
  where exists(select 1 from public.profiles p where p.id=auth.uid() and p.role='admin' and coalesce(p.is_active,true));
$$;
revoke all on function public.admin_list_bingo_app_roles() from public;
grant execute on function public.admin_list_bingo_app_roles() to authenticated;

-- Automatically give every future signup customer app access until Admin changes it.
create or replace function public.bingo_init_app_role()
returns trigger language plpgsql security definer set search_path=public,auth as $$
begin
  insert into public.bingo_app_roles(user_id,app_role) values(new.id,'customer') on conflict(user_id) do nothing;
  return new;
end;$$;
drop trigger if exists bingo_auth_user_init_app_role on auth.users;
create trigger bingo_auth_user_init_app_role after insert on auth.users for each row execute function public.bingo_init_app_role();
