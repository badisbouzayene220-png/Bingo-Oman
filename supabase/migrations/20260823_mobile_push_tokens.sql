-- BINGO Oman — mobile push token registry
begin;

create table if not exists public.mobile_push_tokens (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  token text not null unique,
  platform text not null check (platform in ('android','ios')),
  device_name text,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  last_seen_at timestamptz not null default now()
);

create index if not exists mobile_push_tokens_user_idx
  on public.mobile_push_tokens(user_id, is_active);

alter table public.mobile_push_tokens enable row level security;

drop policy if exists "Users view own mobile push tokens" on public.mobile_push_tokens;
create policy "Users view own mobile push tokens"
on public.mobile_push_tokens
for select
to authenticated
using (user_id = auth.uid());

-- Writes go through SECURITY DEFINER RPCs so one physical device can safely
-- move from one signed-in BINGO account to another without exposing tokens.
create or replace function public.register_my_mobile_push_token(
  p_token text,
  p_platform text,
  p_device_name text default null
)
returns boolean
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user uuid := auth.uid();
  v_token text := trim(coalesce(p_token,''));
  v_platform text := lower(trim(coalesce(p_platform,'')));
begin
  if v_user is null then raise exception 'Authentication required'; end if;
  if length(v_token) < 16 or length(v_token) > 4096 then raise exception 'Invalid push token'; end if;
  if v_platform not in ('android','ios') then raise exception 'Invalid platform'; end if;

  insert into public.mobile_push_tokens(user_id,token,platform,device_name,is_active,last_seen_at,updated_at)
  values(v_user,v_token,v_platform,nullif(trim(p_device_name),''),true,now(),now())
  on conflict (token) do update
    set user_id = excluded.user_id,
        platform = excluded.platform,
        device_name = excluded.device_name,
        is_active = true,
        last_seen_at = now(),
        updated_at = now();

  return true;
end;
$$;

create or replace function public.disable_my_mobile_push_token(p_token text)
returns boolean
language plpgsql
security definer
set search_path = public
as $$
begin
  if auth.uid() is null then raise exception 'Authentication required'; end if;
  update public.mobile_push_tokens
     set is_active=false, updated_at=now()
   where user_id=auth.uid() and token=trim(coalesce(p_token,''));
  return true;
end;
$$;

revoke all on table public.mobile_push_tokens from anon, public;
grant select on table public.mobile_push_tokens to authenticated;

revoke all on function public.register_my_mobile_push_token(text,text,text) from public, anon;
revoke all on function public.disable_my_mobile_push_token(text) from public, anon;
grant execute on function public.register_my_mobile_push_token(text,text,text) to authenticated;
grant execute on function public.disable_my_mobile_push_token(text) to authenticated;

commit;
