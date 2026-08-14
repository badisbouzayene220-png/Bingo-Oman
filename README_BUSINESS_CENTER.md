# BINGO Oman — Business Center

The Business Center is the management dashboard connecting the existing BINGO Admin area with the ERP financial dashboard.

## Access
- Admin Center → Business Center
- Direct page: `business-center.html`

## Data source
The dashboard uses the existing Supabase RPC `erp_dashboard` from `setup_erp.sql`.

## Security
Only active users with `profiles.role = 'admin'` can open the dashboard.
