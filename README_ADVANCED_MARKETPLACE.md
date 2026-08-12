# BINGO Oman — Advanced Marketplace & Admin

## New features
### Advanced marketplace filters
- Category
- Brand / make
- Model
- Year
- Min/max price
- Condition
- City
- New "Use my location" button
- Nearest-first sorting using item latitude/longitude
- The same structured attributes work for cars, electronics, property, furniture and other categories.

### Seller location
The Add Listing page now lets the seller click "Use my current location". Latitude/longitude are stored on the listing. The buyer can click "Use my location" on Marketplace and sort by nearest.

### Company advertisements
Admin Center → Company Ads:
- Create an ad
- Image/banner URL
- Destination URL
- Placement
- Start/end date
- Publish / pause / draft / delete
- Sorting
- Click counter foundation

Marketplace displays published `marketplace_top` company ads.

### Pending listings fixed
The SQL includes a secure admin moderation RPC. Admin can publish or reject pending listings even if direct table RLS blocks the browser. The RPC verifies `profiles.role = 'admin'` inside Supabase.

## Install
1. Run `setup_advanced_marketplace.sql` in Supabase SQL Editor AFTER your existing bidding/admin SQL.
2. Replace your site files with this package.
3. Ensure your admin profile has:
   `role = 'admin'`
   and `is_active = true`.
4. Test:
   - Add a listing → it starts as pending.
   - Admin Center → Marketplace → Pending → Publish or Reject.
   - Marketplace → select Cars → use Brand/Model/Year filters.
   - Seller → Add Listing → Use my current location.
   - Buyer → Marketplace → Use my location → Nearest.

## Note about maps
The current "View item location" uses a Google Maps URL. No Google Maps API key is needed for this basic link.
