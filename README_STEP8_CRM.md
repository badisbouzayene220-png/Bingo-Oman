# BINGO Oman — Step 8 CRM

Customers/CRM now links ERP customers to existing BINGO profiles.

1. Replace your project files with this version.
2. Run `setup_erp.sql` in Supabase SQL Editor. It is migration-safe and adds `profile_id`.
3. Open Admin → ERP → Customers.
4. Create/edit a customer and select a BINGO account to link it.
5. Customer search includes name, company, phone, email, customer code, username and linked email.

No change is required to login/register.
