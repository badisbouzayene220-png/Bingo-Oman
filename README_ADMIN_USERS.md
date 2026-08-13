# BINGO Oman — Admin Users

The Admin → Users page reads users securely from Supabase `auth.users` through the `admin_list_users()` RPC.

## One-time Supabase setup

1. Open Supabase Dashboard for the BINGO Oman project.
2. Go to **SQL Editor**.
3. Open/copy `setup_admin_users.sql` from this project.
4. Run the complete SQL.
5. Return to `admin.html` and click **Refresh**.

After setup, Admin → Users will show all registered accounts, including email, name, username, role, status and registration date.

The **Export Excel** button exports the complete loaded user list, not just the currently filtered search results.

The SQL uses `SECURITY DEFINER` and checks that the current signed-in user has `profiles.role = 'admin'` and is active before returning any users.
