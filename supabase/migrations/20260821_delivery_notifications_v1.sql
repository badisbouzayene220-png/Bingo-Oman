-- BINGO Delivery Notifications V1
create table if not exists public.user_notifications (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  type text not null,
  title text not null,
  body text,
  href text,
  order_id uuid references public.delivery_orders(id) on delete cascade,
  is_read boolean not null default false,
  created_at timestamptz not null default now(),
  dedupe_key text
);
create unique index if not exists user_notifications_dedupe_idx on public.user_notifications(user_id,dedupe_key) where dedupe_key is not null;
create index if not exists user_notifications_user_idx on public.user_notifications(user_id,is_read,created_at desc);
alter table public.user_notifications enable row level security;
DO $$ BEGIN
  create policy user_notifications_read on public.user_notifications for select to authenticated using (user_id=auth.uid());
EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN
  create policy user_notifications_update on public.user_notifications for update to authenticated using (user_id=auth.uid()) with check (user_id=auth.uid());
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

create or replace function public.delivery_notify_user(p_user uuid,p_type text,p_title text,p_body text,p_href text,p_order uuid,p_key text)
returns void language plpgsql security definer set search_path=public as $$
begin
  if p_user is null then return; end if;
  insert into public.user_notifications(user_id,type,title,body,href,order_id,dedupe_key)
  values(p_user,p_type,p_title,p_body,p_href,p_order,p_key)
  on conflict(user_id,dedupe_key) where dedupe_key is not null do nothing;
end;$$;
revoke all on function public.delivery_notify_user(uuid,text,text,text,text,uuid,text) from public;

create or replace function public.delivery_order_notification_trigger()
returns trigger language plpgsql security definer set search_path=public as $$
declare v_owner uuid; v_title text; v_body text; v_href text;
begin
  select owner_id into v_owner from public.delivery_stores where id=new.store_id;
  v_href := 'order-tracking.html?delivery='||new.order_number;
  if tg_op='INSERT' then
    perform public.delivery_notify_user(new.customer_id,'order_created','تم استلام طلبك','تم إنشاء طلب '||new.order_number||' بنجاح.',v_href,new.id,'order:'||new.id||':created:customer');
    perform public.delivery_notify_user(v_owner,'seller_new_order','طلب جديد','لديك طلب جديد '||new.order_number||' يحتاج مراجعة.','bingo-delivery-seller.html',new.id,'order:'||new.id||':created:seller');
    return new;
  end if;
  if old.status is not distinct from new.status then return new; end if;
  case new.status
    when 'confirmed' then v_title:='تم تأكيد الطلب'; v_body:='تم تأكيد طلبك وسيبدأ التجهيز قريبًا.';
    when 'preparing' then v_title:='جاري تجهيز طلبك'; v_body:='المتجر بدأ تجهيز طلب '||new.order_number||'.';
    when 'ready' then v_title:='طلبك جاهز'; v_body:='الطلب جاهز الآن وينتظر المندوب.';
    when 'assigned' then v_title:='تم تعيين المندوب'; v_body:='تم تعيين مندوب لطلبك.';
    when 'picked_up' then v_title:='استلم المندوب الطلب'; v_body:='المندوب استلم طلبك من المتجر.';
    when 'on_delivery' then v_title:='المندوب في الطريق'; v_body:='طلبك في الطريق إليك الآن.';
    when 'delivered' then v_title:='تم تسليم الطلب'; v_body:='تم تسليم طلبك بنجاح. شكرًا لاستخدام BINGO.';
    when 'cancelled' then v_title:='تم إلغاء الطلب'; v_body:='تم إلغاء الطلب '||new.order_number||'.';
    else return new;
  end case;
  perform public.delivery_notify_user(new.customer_id,'order_status',v_title,v_body,v_href,new.id,'order:'||new.id||':'||new.status||':customer');
  if v_owner is not null then
    perform public.delivery_notify_user(v_owner,'seller_order_status',v_title,v_body,'bingo-delivery-seller.html',new.id,'order:'||new.id||':'||new.status||':seller');
  end if;
  return new;
end;$$;
drop trigger if exists trg_delivery_order_notifications on public.delivery_orders;
create trigger trg_delivery_order_notifications after insert or update of status on public.delivery_orders for each row execute function public.delivery_order_notification_trigger();

create or replace function public.delivery_assignment_notification_trigger()
returns trigger language plpgsql security definer set search_path=public as $$
declare v_order public.delivery_orders%rowtype;
begin
  select * into v_order from public.delivery_orders where id=new.order_id;
  if tg_op='INSERT' or old.status is distinct from new.status then
    if new.status='offered' then
      perform public.delivery_notify_user(new.driver_id,'driver_offer','طلب توصيل جديد','تم إرسال طلب '||coalesce(v_order.order_number,'')||' إليك.','bingo-delivery-driver.html',new.order_id,'assignment:'||new.id||':offered');
    elsif new.status='accepted' then
      perform public.delivery_notify_user(new.driver_id,'driver_status','تم قبول التوصيل','تم قبول مهمة التوصيل بنجاح.','bingo-delivery-driver.html',new.order_id,'assignment:'||new.id||':accepted');
    elsif new.status='cancelled' or new.status='rejected' then
      perform public.delivery_notify_user(new.driver_id,'driver_status','تحديث مهمة التوصيل','تم تحديث/إلغاء مهمة التوصيل.','bingo-delivery-driver.html',new.order_id,'assignment:'||new.id||':'||new.status);
    end if;
  end if;
  return new;
end;$$;
drop trigger if exists trg_delivery_assignment_notifications on public.delivery_assignments;
create trigger trg_delivery_assignment_notifications after insert or update of status on public.delivery_assignments for each row execute function public.delivery_assignment_notification_trigger();

create or replace function public.user_notifications_mark_read(p_id uuid default null)
returns boolean language plpgsql security definer set search_path=public as $$
begin
  if auth.uid() is null then raise exception 'Authentication required'; end if;
  if p_id is null then update public.user_notifications set is_read=true where user_id=auth.uid() and is_read=false;
  else update public.user_notifications set is_read=true where id=p_id and user_id=auth.uid(); end if;
  return true;
end;$$;
revoke all on function public.user_notifications_mark_read(uuid) from public;
grant execute on function public.user_notifications_mark_read(uuid) to authenticated;

DO $$ BEGIN
  BEGIN alter publication supabase_realtime add table public.user_notifications; EXCEPTION WHEN duplicate_object THEN NULL; END;
END $$;
NOTIFY pgrst, 'reload schema';
