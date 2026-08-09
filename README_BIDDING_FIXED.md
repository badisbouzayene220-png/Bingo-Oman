# BINGO Oman — Fixed Auctions & Tenders

## What was fixed
- Clicking an auction/tender no longer sends the user directly to the generic login page.
- Each opportunity opens a real detail page.
- If the visitor is not logged in and clicks **Place bid / Submit offer**, login opens with a `next` URL and returns the user to that exact opportunity after login.
- Logged-in users can submit auction bids or tender offers.
- Auction bids are checked atomically on the server and must be higher than the current bid.
- Tender offers are stored privately per bidder.
- The database uses Supabase Row Level Security and server-side RPC functions; the browser never receives a service-role key.

## One required step
Open the Supabase SQL Editor and run:

`setup_bidding.sql`

This creates:
- `opportunities`
- `opportunity_bids`
- RLS policies
- `place_auction_bid(...)`
- `submit_tender_offer(...)`
- the six demo opportunities used by the pages

Then upload the contents of the `bingo` folder to the same GitHub Pages/site location as before.

## Important
The current Supabase project key in `config.js` is a publishable browser key. Do not replace it with a service-role key.

After the SQL is run, test:
1. Open Auctions or Tenders.
2. Open an opportunity.
3. Click Place bid / Submit offer while logged out.
4. Log in.
5. You should return automatically to the same opportunity.
6. Enter an amount and submit.
