# BINGO Oman — Full Admin Center

## Included
- Dashboard statistics.
- Create / edit / delete auctions and tenders.
- Open, schedule, close or cancel opportunities.
- View all bids and tender offers.
- Select a winning bid/offer.
- Automatically close the opportunity when a winner is selected.
- Automatically create a winner notification.
- User management: activate/deactivate users and grant/remove admin role.
- Marketplace listing moderation: publish/reject/delete.
- Database-side admin authorization for every admin RPC.

## Install
1. Keep the existing files from `Bingo-Oman-Fixed-Bidding.zip`.
2. Run `setup_bidding.sql` if it has not already been run.
3. Run `setup_admin.sql` once in Supabase SQL Editor.
4. Upload the `bingo` folder to your site, replacing the previous files.
5. Give your first account the admin role:
   update public.profiles set role='admin' where id='YOUR_AUTH_USER_ID';
6. Open `admin.html`.

## Security
The browser only checks the UI for convenience. Every admin operation is also checked by `public.is_admin()` inside Supabase security-definer functions.

Do not put a Supabase service-role key in `config.js`.

## Winner workflow
Admin Center → Auctions & Tenders → Bids → Winner.
Selecting a winner:
- marks that bid as winner;
- saves the winning user;
- closes the opportunity;
- creates a notification for the winning user.

For auctions, the current amount is already maintained by the secure bidding RPC.
