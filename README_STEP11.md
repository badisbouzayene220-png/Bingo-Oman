# BINGO Oman ERP — Step 11 Payments & Collections

This step extends the working Step 10 ERP with a complete collections workflow:

- Customer payments linked to invoices
- Cash / bank transfer / card / other
- Automatic invoice status: partially paid / paid
- Balance protection (no overpayment)
- Payment receipt printing
- Payments Excel export
- Collection summary by method
- Accounting journal for each payment
- Payment RLS and indexes

## Supabase
Run `setup_step11_payments.sql` once after Step 10.

## Test
Use an issued invoice of 525 OMR:
1. Register 300 OMR cash.
2. Invoice should become Partially Paid, balance 225 OMR.
3. Register 225 OMR.
4. Invoice should become Paid, balance 0 OMR.
5. Print the receipt from the Payments tab.
