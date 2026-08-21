-- BINGO Oman Security Hardening v3A
-- Scope: admin RPC execute grants + conversation creation policy.
-- Safe to run after 20260821_security_hardening_core_v2.sql.

begin;

-- =========================================================
-- 1) ADMIN RPCs
-- Remove anonymous/public EXECUTE from every public.admin_* function.
-- Keep authenticated grants unchanged so existing Admin UI keeps working.
-- IMPORTANT: authorization must still be checked inside each admin function;
-- a later audit will verify those function bodies individually.
-- =========================================================
do $$
declare
  r record;
begin
  for r in
    select p.oid::regprocedure as function_signature
    from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public'
      and p.proname like 'admin\_%' escape '\'
  loop
    execute format('revoke all on function %s from public', r.function_signature);
    execute format('revoke all on function %s from anon', r.function_signature);
  end loop;
end $$;

-- =========================================================
-- 2) CONVERSATIONS
-- Remove the broad legacy INSERT policy that allowed any authenticated
-- user to create a conversation merely by supplying listing_id/auction_id.
-- PostgreSQL permissive policies are OR'ed, so this policy weakened the
-- stricter ownership policy.
-- =========================================================
alter table if exists public.conversations enable row level security;

drop policy if exists "conversations_create" on public.conversations;

-- Recreate the intended strict policy.
-- Buyer must be the logged-in user.
-- Seller must be the actual owner of the listing/auction.
-- Buyer and seller cannot be the same user.
-- Exactly one context (listing OR auction) must be supplied.
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

commit;

-- Verification query (read-only):
-- Run after the migration if desired.
select
  schemaname,
  tablename,
  policyname,
  cmd,
  roles,
  qual,
  with_check
from pg_policies
where schemaname='public'
  and tablename='conversations'
order by policyname;
