-- BINGO Oman — safely clear the current user's notification center
begin;

create or replace function public.user_notifications_delete_all()
returns boolean
language plpgsql
security definer
set search_path=public
as $$
declare
  v_user uuid := auth.uid();
begin
  if v_user is null then
    raise exception 'Authentication required';
  end if;

  -- Remove only notification-center records owned by the current user.
  delete from public.user_notifications
  where user_id = v_user;

  -- Message alerts in the notification center are derived from unread messages.
  -- Clear the alerts without deleting any message or conversation.
  update public.messages m
     set is_read = true
   where m.sender_id <> v_user
     and coalesce(m.is_read,false) = false
     and exists (
       select 1
       from public.conversations c
       where c.id = m.conversation_id
         and (c.buyer_id = v_user or c.seller_id = v_user)
     );

  return true;
end;
$$;

revoke all on function public.user_notifications_delete_all() from public, anon;
grant execute on function public.user_notifications_delete_all() to authenticated;

commit;
