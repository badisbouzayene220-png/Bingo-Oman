-- BINGO Oman: harden sensitive RPC execution privileges
begin;

revoke all on function public.admin_clear_listing_promotion(uuid) from public, anon;
revoke all on function public.admin_listing_performance(integer) from public, anon;
revoke all on function public.admin_set_listing_promotion(uuid,text,integer) from public, anon;
revoke all on function public.my_listing_analytics() from public, anon;

grant execute on function public.admin_clear_listing_promotion(uuid) to authenticated;
grant execute on function public.admin_listing_performance(integer) to authenticated;
grant execute on function public.admin_set_listing_promotion(uuid,text,integer) to authenticated;
grant execute on function public.my_listing_analytics() to authenticated;

commit;