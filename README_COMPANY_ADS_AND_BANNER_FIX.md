# BINGO Oman — Company Ads + Top Banner Fix

Run `setup_company_ads_and_banner_fix.sql` once in Supabase SQL Editor.

This migration:
- Allows `floating_character` in `company_ads.placement`.
- Keeps the Admin UI value `Floating ad (character area)` mapped to `floating_character`.
- Makes the `bingo-banners` Storage bucket public for banner display.
- Adds public read access for published `site_banners` within their schedule.
- Exposes the Supabase client as `window.sb`, which is required by the global banner and floating company-ad scripts.

After running SQL, deploy the website files and hard-refresh with Ctrl+F5.
