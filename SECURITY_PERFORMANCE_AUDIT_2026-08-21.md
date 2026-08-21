# BINGO Oman — Security & Performance Audit
Date: 2026-08-21

## Verified security findings

- `config.js` contains a Supabase **publishable** key. This key is intended for browser use; no service-role key was found in the inspected frontend configuration.
- `admin.html` checks the signed-in user's `profiles.role = 'admin'` and `is_active` before showing the admin application.
- Delivery admin RPC `admin_delivery_drivers_all()` is `SECURITY DEFINER`, but it explicitly verifies `auth.uid()`, requires an active admin profile, revokes public execution and grants execution only to authenticated users.
- Admin UI protection is not considered the security boundary. Admin RPCs and RLS must continue to enforce authorization server-side.

## Performance findings

Large repository assets identified during the audit include:

- `assets/characters/bingo-mascot-phone-v2.png` ~2.23 MB
- `assets/bingo-oman-intro.png` ~1.85 MB
- `assets/bingo_no_deal.png` ~1.62 MB
- `assets/bingo_success.png` ~1.79 MB
- `assets/bingo_deal.png` ~1.45 MB
- `logo-en.png` ~1.04 MB
- `logo-ar.png` ~1.20 MB

These are candidates for future WebP/AVIF conversion while preserving visual quality.

## Fixes applied in this audit

### 1. Category module lazy loading
Previously Add Listing and Marketplace loaded every category-specific CSS and JavaScript module immediately. This caused many unnecessary network requests and parsing work.

Now `category-loader.js` loads only the module for the category currently selected. Additional category modules load only when the user selects them.

### 2. Banner video preload reduction
Global banner video preload was changed from `auto` to `metadata`, reducing unnecessary bandwidth before playback.

## Next audit items

1. Review every `SECURITY DEFINER` RPC for explicit role checks and restricted EXECUTE grants.
2. Verify RLS on conversations, messages, listings, listing images, favorites, reports, store orders and delivery tables.
3. Verify that admin mutation RPCs check admin role server-side and do not rely on `admin.html` checks.
4. Review storage bucket policies for listing images and banner uploads.
5. Convert large static PNG assets to modern compressed formats and update references safely.
6. Review Realtime subscriptions and MutationObservers for unnecessary persistent work.
7. Run regression tests on Add Listing and Marketplace after lazy module loading.

## Regression checklist after this commit

- Open `add-listing.html`, select Cars, Real Estate, Electronics, Mobile Phones, Jobs, Services, Fashion, Furniture, Home & Garden, Sports, Kids & Baby, Business & Industrial and Other.
- Confirm each specialized panel appears after selection.
- Open `marketplace.html` and repeat category selections; confirm corresponding filters appear.
- Confirm Home, Messages, Listing details and Admin pages still load normally.
