# BINGO Oman ERP — Step 24 Financial Reports

Updated the ERP financial reporting UI to use the existing accounting RPC functions.

## Step 24 fixes
- Profit & Loss
- Balance Sheet
- Cash Flow
- VAT Summary
- Trial Balance
- General Ledger
- Accounting Control
- Fixed browser date handling to use the computer's local calendar date instead of UTC `toISOString()`.
- Financial reports default to yesterday → today.

No database functions are duplicated or changed by this frontend update.
