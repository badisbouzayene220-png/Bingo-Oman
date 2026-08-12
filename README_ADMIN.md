# BINGO Oman Admin Center

This version adds `admin.html` for moderation.

## How it works
- Only users whose `profiles.role = 'admin'` can enter.
- Pending listings can be published or rejected.
- Published/rejected/all queues are available.
- Admin can view or permanently delete a listing.
- Dashboard and the account menu show an Admin Center link for admin users.

No database migration is required for the core moderation flow because the supplied SQL already gives admins update/delete access to `listings` through `public.is_admin()`.

To create your first admin, update the role of your own profile in Supabase SQL Editor:

```sql
update public.profiles
set role = 'admin'
where id = 'YOUR_AUTH_USER_ID';
```

Do not make users admin from the public website.


## Floating Company Ads
In Admin Center → Company Ads, choose Placement: "Floating ad (character area)". Published ads appear in the floating BINGO widget where the character image used to appear. Ads can have an image/video URL, destination URL, schedule, and sort order.
