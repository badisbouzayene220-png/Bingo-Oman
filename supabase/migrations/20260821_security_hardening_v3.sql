-- BINGO Oman security hardening v3
-- Focus: admin RPC exposure + conversation creation policy.
-- Safe to run after v2.

-- 1) Remove anonymous/public execute from every admin_* function in public schema.
--    Keep authenticated access because the admin UI uses the logged-in user's JWT;
--    individual functions must still perform their own admin check internally.
do $$
declare
  r record;
begin
  for r in
    select n.nspname as schema_name,
           p.proname as function_name,
           pg_get_function_identity_arguments(p.oid) as args
    from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public'
      and p.proname like 'admin\_%' escape '\'
  loop
    execute format('revoke execute on function %I.%I(%s) from anon', r.schema_name, r.function_name, r.args);
    execute format('revoke execute on function %I.%I(%s) from public', r.schema_name, r.function_name, r.args);
  end loop;
end $$;

-- 2) Conversations: remove the weak generic insert policy.
drop policy if exists "conversations_create" on public.conversations;

-- Replace the buyer/seller create policy with a strict relation to the selected listing/auction.
drop policy if exists "Users can create conversations" on public.conversations;
create policy "Users can create conversations"
on public.conversations
for insert
to authenticated
with check (
  buyer_id = auth.uid()
  and seller_id <> auth.uid()
  and (
    (
      listing_id is not null
      and auction_id is null
      and exists (
        select 1
        from public.listings l
        where l.id = conversations.listing_id
          and l.user_id = conversations.seller_id
      )
    )
    or
    (
      auction_id is not null
      and listing_id is null
      and exists (
        select 1
        from public.auctions a
        where a.id = conversations.auction_id
          and a.seller_id = conversations.seller_id
      )
    )
  )
);

-- 3) Keep the existing direct participant message policies.
-- Remove only duplicate member-based policies if the conversation_members table exists,
-- because the current website uses buyer_id/seller_id conversations directly.
do $$
begin
  if to_regclass('public.conversation_members') is not null then
    execute 'drop policy if exists "conversations_read_members" on public.conversations';
    execute 'drop policy if exists "messages_members_read" on public.messages';
    execute 'drop policy if exists "messages_members_send" on public.messages';
    execute 'drop policy if exists "messages_mark_read" on public.messages';
  end if;
end $$;

-- 4) Explicitly preserve authenticated execution for admin functions that already exist.
--    This does not grant anon/public access.
do $$
declare
  r record;
begin
  for r in
    select n.nspname as schema_name,
           p.proname as function_name,
           pg_get_function_identity_arguments(p.oid) as args
    from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public'
      and p.proname like 'admin\_%' escape '\'
  loop
    execute format('grant execute on function %I.%I(%s) to authenticated', r.schema_name, r.function_name, r.args);
  end loop;
end $$;
