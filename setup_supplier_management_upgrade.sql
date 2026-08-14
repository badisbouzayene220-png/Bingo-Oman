-- BINGO Oman ERP — Supplier Management Upgrade (SAFE)
-- Run this file in Supabase SQL Editor after the supplier table exists.
-- This version fixes: column s.contact_person does not exist.

alter table public.erp_suppliers add column if not exists contact_person varchar(200);
alter table public.erp_suppliers add column if not exists company_name varchar(200);
alter table public.erp_suppliers add column if not exists phone varchar(50);
alter table public.erp_suppliers add column if not exists email varchar(255);
alter table public.erp_suppliers add column if not exists tax_number varchar(100);
alter table public.erp_suppliers add column if not exists commercial_registration varchar(100);
alter table public.erp_suppliers add column if not exists address text;
alter table public.erp_suppliers add column if not exists city varchar(100);
alter table public.erp_suppliers add column if not exists payment_terms integer not null default 30;
alter table public.erp_suppliers add column if not exists notes text;
alter table public.erp_suppliers add column if not exists is_active boolean not null default true;
alter table public.erp_suppliers add column if not exists created_at timestamptz not null default now();
alter table public.erp_suppliers add column if not exists updated_at timestamptz not null default now();


create or replace function public.erp_list_suppliers(p_search text default null)
returns jsonb language plpgsql security definer set search_path=public as $$
begin
 if not public.is_admin() then raise exception 'Admin access required'; end if;
 return coalesce((select jsonb_agg(to_jsonb(x) order by x.created_at desc) from (
   select s.*,
     coalesce((select sum(p.total) from public.erp_purchases p where p.supplier_id=s.id and p.status<>'cancelled'),0) as purchased,
     coalesce((select sum(sp.amount) from public.erp_supplier_payments sp where sp.supplier_id=s.id),0) as paid,
     coalesce((select sum(p.total) from public.erp_purchases p where p.supplier_id=s.id and p.status<>'cancelled'),0)
      - coalesce((select sum(sp.amount) from public.erp_supplier_payments sp where sp.supplier_id=s.id),0) as balance
   from public.erp_suppliers s
   where (p_search is null or p_search='' or lower(concat_ws(' ',s.supplier_code,s.name,s.contact_person,s.company_name,s.phone,s.email,s.tax_number)) like '%'||lower(p_search)||'%')
   limit 500
 ) x),'[]'::jsonb);
end $$;

create or replace function public.erp_upsert_supplier(p_supplier jsonb)
returns jsonb language plpgsql security definer set search_path=public as $$
declare r public.erp_suppliers;
begin
 if not public.is_admin() then raise exception 'Admin access required'; end if;
 if nullif(trim(p_supplier->>'name'),'') is null then raise exception 'Supplier name is required'; end if;
 if nullif(p_supplier->>'id','') is null then
   insert into public.erp_suppliers
     (supplier_code,name,contact_person,company_name,phone,email,tax_number,commercial_registration,address,city,payment_terms,notes,created_by)
   values
     ('SUP-'||upper(substr(replace(gen_random_uuid()::text,'-',''),1,8)),
      trim(p_supplier->>'name'),
      nullif(trim(p_supplier->>'contact_person'),''),
      nullif(trim(p_supplier->>'company_name'),''),
      nullif(trim(p_supplier->>'phone'),''),
      nullif(trim(p_supplier->>'email'),''),
      nullif(trim(p_supplier->>'tax_number'),''),
      nullif(trim(p_supplier->>'commercial_registration'),''),
      nullif(trim(p_supplier->>'address'),''),
      nullif(trim(p_supplier->>'city'),''),
      coalesce(nullif(trim(p_supplier->>'payment_terms'),'')::int,30),
      nullif(trim(p_supplier->>'notes'),''),
      auth.uid()) returning * into r;
 else
   update public.erp_suppliers set
     name=trim(p_supplier->>'name'),
     contact_person=nullif(trim(p_supplier->>'contact_person'),''),
     company_name=nullif(trim(p_supplier->>'company_name'),''),
     phone=nullif(trim(p_supplier->>'phone'),''),
     email=nullif(trim(p_supplier->>'email'),''),
     tax_number=nullif(trim(p_supplier->>'tax_number'),''),
     commercial_registration=nullif(trim(p_supplier->>'commercial_registration'),''),
     address=nullif(trim(p_supplier->>'address'),''),
     city=nullif(trim(p_supplier->>'city'),''),
     payment_terms=coalesce(nullif(trim(p_supplier->>'payment_terms'),'')::int,30),
     notes=nullif(trim(p_supplier->>'notes'),''),
     updated_at=now()
   where id=(p_supplier->>'id')::uuid returning * into r;
 end if;
 if r.id is null then raise exception 'Supplier not found'; end if;
 return to_jsonb(r);
end $$;

grant execute on function public.erp_upsert_supplier(jsonb) to authenticated;

create or replace function public.erp_set_supplier_status(p_supplier_id uuid,p_is_active boolean)
returns jsonb language plpgsql security definer set search_path=public as $$
declare r public.erp_suppliers;
begin
 if not public.is_admin() then raise exception 'Admin access required'; end if;
 update public.erp_suppliers set is_active=p_is_active,updated_at=now() where id=p_supplier_id returning * into r;
 if r.id is null then raise exception 'Supplier not found'; end if;
 return to_jsonb(r);
end $$;

create or replace function public.erp_delete_supplier(p_supplier_id uuid)
returns jsonb language plpgsql security definer set search_path=public as $$
declare r public.erp_suppliers; c1 bigint; c2 bigint;
begin
 if not public.is_admin() then raise exception 'Admin access required'; end if;
 select count(*) into c1 from public.erp_purchases where supplier_id=p_supplier_id;
 select count(*) into c2 from public.erp_supplier_payments where supplier_id=p_supplier_id;
 if c1>0 or c2>0 then
   raise exception 'لا يمكن حذف المورد لأنه مرتبط بمشتريات أو دفعات. استخدم تعطيل المورد بدلاً من الحذف.';
 end if;
 delete from public.erp_suppliers where id=p_supplier_id returning * into r;
 if r.id is null then raise exception 'Supplier not found'; end if;
 return to_jsonb(r);
end $$;

grant execute on function public.erp_list_suppliers(text) to authenticated;
grant execute on function public.erp_set_supplier_status(uuid,boolean) to authenticated;
grant execute on function public.erp_delete_supplier(uuid) to authenticated;
