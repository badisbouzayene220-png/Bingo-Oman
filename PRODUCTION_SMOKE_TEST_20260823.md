# BINGO Oman — Production Smoke Test
Date: 2026-08-23

## Static checks completed
- [x] Core release manifest exists.
- [x] Login / register session flow reviewed.
- [x] Safe return-to-page after login/verification.
- [x] Marketplace listing rendering and promotion runtime present.
- [x] Listing detail opens conversations through authenticated user flow.
- [x] Add Listing requires authenticated user and image upload.
- [x] Store → Product → Cart → Checkout → Orders flow present.
- [x] Product mobile navigation fixed (hamburger menu added).
- [x] Dashboard analytics and seller insights runtime present.
- [x] Admin promotion analytics and manual purchase approval runtime present.
- [x] Messages and notifications use authenticated/RLS-protected data.
- [x] Release mobile/performance/link-safety layers loaded from config.js.
- [x] Anonymous execution removed from sensitive analytics/admin RPCs.
- [x] Final RLS cleanup completed.

## Manual production smoke tests still required
These require a live browser session and real Supabase account state.

### Customer account
- [ ] Register a new user and verify email.
- [ ] Login and confirm session survives navigation/reload.
- [ ] Create listing with photos.
- [ ] Confirm 3-free-listing limit.
- [ ] Delete own published listing.
- [ ] Republish listing once.
- [ ] Submit Promote purchase request.
- [ ] View seller analytics in Dashboard.
- [ ] Favorite/unfavorite a listing.
- [ ] Start a seller conversation and send/read message.

### Store / Delivery
- [ ] Open Store and add multiple quantities to cart.
- [ ] Confirm cart count matches total quantity.
- [ ] Checkout while logged in.
- [ ] Confirm order appears in My Orders.
- [ ] Confirm delivery/tracking page opens for linked delivery order.
- [ ] Confirm tracking updates and BINGO Code behavior when applicable.

### Admin account
- [ ] Open Admin with admin user.
- [ ] Confirm non-admin user cannot access admin RPC behavior.
- [ ] Approve/reject listing.
- [ ] Approve/reject manual package purchase.
- [ ] Confirm promotion activates with expiry.
- [ ] Confirm Marketplace Performance loads 7/30/all-time filters.
- [ ] Confirm Delivery Admin summary loads without page hang.

### Mobile / browser
- [ ] Android Chrome: core navigation and checkout.
- [ ] iPhone Safari: core navigation and checkout.
- [ ] Firefox desktop: open Home/Admin/Delivery for 5+ minutes; confirm no hang.
- [ ] No horizontal scrolling on Marketplace, Dashboard, Messages, Checkout.

## Release blockers
A Release Candidate should not be marked production-ready until all manual boxes above are tested on the deployed site. Static code review cannot validate Supabase runtime state, browser permissions, live realtime channels, or payment/manual approval data end-to-end.
