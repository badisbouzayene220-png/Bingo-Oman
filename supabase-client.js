// Expose the Supabase client on window so every page script can use it reliably.
window.sb = window.supabase.createClient(
  window.BINGO_CONFIG.SUPABASE_URL,
  window.BINGO_CONFIG.SUPABASE_PUBLISHABLE_KEY
);
