-- BINGO Oman - activate republish plan prices
begin;

update public.listing_plan_catalog
set amount_baisa = 3000,
    is_active = true,
    updated_at = now()
where plan_code = 'monthly';

update public.listing_plan_catalog
set amount_baisa = 24000,
    is_active = true,
    updated_at = now()
where plan_code = 'yearly';

commit;
