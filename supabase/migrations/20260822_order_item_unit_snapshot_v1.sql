-- BINGO Order Item Unit Snapshot V1
-- Keeps the selling unit with each order item so operational screens stay accurate.

alter table public.store_order_items
  add column if not exists unit text not null default 'piece';

alter table public.delivery_order_items
  add column if not exists unit text not null default 'piece';

update public.store_order_items oi
set unit = coalesce(p.unit,'piece')
from public.store_products p
where oi.product_id = p.id
  and coalesce(oi.unit,'piece') = 'piece';

update public.delivery_order_items oi
set unit = coalesce(p.unit,'piece')
from public.store_products p
where oi.product_id = p.id
  and coalesce(oi.unit,'piece') = 'piece';

create or replace function public.bingo_fill_order_item_unit()
returns trigger
language plpgsql
set search_path=public
as $$
begin
  if new.product_id is not null then
    select coalesce(p.unit,'piece') into new.unit
    from public.store_products p
    where p.id=new.product_id;
  end if;
  new.unit:=coalesce(nullif(new.unit,''),'piece');
  return new;
end;
$$;

drop trigger if exists trg_store_order_item_unit on public.store_order_items;
create trigger trg_store_order_item_unit
before insert or update of product_id on public.store_order_items
for each row execute function public.bingo_fill_order_item_unit();

drop trigger if exists trg_delivery_order_item_unit on public.delivery_order_items;
create trigger trg_delivery_order_item_unit
before insert or update of product_id on public.delivery_order_items
for each row execute function public.bingo_fill_order_item_unit();

notify pgrst,'reload schema';