# BINGO Oman — Email Confirmation Fix

The registration page now sends Supabase confirmation emails back to the exact `register.html` URL that the user opened. After confirmation it exchanges the Supabase code/session and redirects to `dashboard.html`.

## Supabase setting
In Supabase Dashboard → Authentication → URL Configuration, add the deployed `register.html` URL to **Redirect URLs**.

Examples:
- `https://badisbouzayene220-png.github.io/register.html`
- If the site is deployed under a repository path: `https://badisbouzayene220-png.github.io/Bingo-Oman-main/register.html`

Keep the actual deployed URL that opens your BINGO Oman registration page.

## Important
The screenshot shows `otp_expired`, which means the specific email link clicked has already expired. That old link cannot be repaired; create a fresh registration/verification email after deploying this version.
