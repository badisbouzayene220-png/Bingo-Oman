-- BINGO Oman ERP - Step 11 Payments & Collections
-- Run once in Supabase SQL Editor after Step 10.

INSERT INTO public.erp_accounts (code, name, account_type)
VALUES
 ('1000','Cash','asset'),
 ('1100','Bank','asset'),
 ('1200','Accounts Receivable','asset'),
 ('2100','VAT Payable','liability'),
 ('3000','Owner Equity','equity'),
 ('4000','Sales Revenue','revenue'),
 ('5000','Operating Expenses','expense')
ON CONFLICT (code) DO NOTHING;

ALTER TABLE public.erp_payments ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS erp_admin_all_payments ON public.erp_payments;
CREATE POLICY erp_admin_all_payments ON public.erp_payments
FOR ALL TO authenticated
USING (public.is_admin())
WITH CHECK (public.is_admin());

CREATE INDEX IF NOT EXISTS idx_erp_payments_invoice ON public.erp_payments(invoice_id);
CREATE INDEX IF NOT EXISTS idx_erp_payments_customer ON public.erp_payments(customer_id);
CREATE INDEX IF NOT EXISTS idx_erp_payments_date ON public.erp_payments(payment_date);

REVOKE ALL ON FUNCTION public.erp_record_payment(jsonb) FROM public;
GRANT EXECUTE ON FUNCTION public.erp_record_payment(jsonb) TO authenticated;
