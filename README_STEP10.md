# BINGO Oman ERP — Step 10

Step 10 integrates sales invoices with products, inventory, VAT, payments and customer balances.

## Supabase
Run only `setup_step10_invoices_sales.sql` once after Step 9.

## Sales flow
1. Create an invoice as Draft: no stock movement.
2. Select a product in each invoice line: description and sale price are filled automatically.
3. Change status to Issued and save: stock is reduced atomically and an accounting entry is created.
4. Record a payment: invoice paid amount/status and customer balance update automatically.
5. VAT is calculated from the taxable amount.
6. Invoice printing includes product information.
7. An issued invoice with no payments can be cancelled; its stock is restored and its journal entry removed.

## Test example
Product: Motorized Curtain
Stock before sale: 10
Quantity sold: 2
Sale price: 250 OMR
VAT: 5%

Expected:
- Subtotal: 500 OMR
- VAT: 25 OMR
- Total: 525 OMR
- Stock after issue: 8

Then record a 300 OMR payment:
- Paid: 300 OMR
- Balance: 225 OMR
- Invoice status: Partially Paid
