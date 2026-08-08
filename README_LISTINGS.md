# BINGO Oman — User Listings

The project now includes:
- `add-listing.html`: authenticated users can create an ad, choose a category/city, add price/condition/description and upload up to 8 images.
- Images are uploaded to Supabase Storage bucket `listing-images` under `<user_id>/<listing_id>/...`.
- Listing rows are inserted into `public.listings` with `status = 'pending'`.
- Image rows are inserted into `public.listing_images`.
- `marketplace.html` reads published listings from Supabase.
- `listing.html` shows the listing gallery/details.
- Dashboard shows the user's own listings.

Before using image upload, run `setup_listing_storage.sql` once in Supabase SQL Editor.
The existing SQL schema you provided already contains `listings` and `listing_images` tables and the required RLS for authenticated listing creation/image insertion.
