# BINGO Oman — Release Candidate Manifest (2026-08-22)

## Core entry pages
- index.html
- marketplace.html
- listing.html
- add-listing.html
- store.html
- product.html
- checkout.html
- orders.html
- order-tracking.html
- messages.html
- dashboard.html
- admin.html

## Core runtime files
- config.js
- supabase-client.js
- auth.js
- language.js
- style.css
- bingo-ui.css
- cart.js
- notifications.js

## Release hardening files
- release-mobile-v1.css
- release-performance-v1.js
- release-link-safety-v1.js

## Marketplace / promotion runtime
- listing-promotions.js
- listing-promotions.css
- marketplace-promotions-zone.js
- listing-analytics.js
- dashboard-listing-analytics.js
- admin-listing-promotions.js
- admin-listing-performance.js
- admin-manual-purchases.js

## Security migrations completed
- supabase/migrations/20260822_rpc_anon_hardening.sql
- supabase/migrations/20260822_final_rls_cleanup.sql

## Release rule
Historical README, FIX, audit, migration and troubleshooting files are retained for traceability and must not be deleted automatically. Only files proven unused after a production smoke test should be archived or removed.
