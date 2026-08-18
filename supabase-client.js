window.sb=window.supabase.createClient(window.BINGO_CONFIG.SUPABASE_URL,window.BINGO_CONFIG.SUPABASE_PUBLISHABLE_KEY);
const sb=window.sb;

// BINGO Delivery Admin: load the live driver map only on the delivery admin page.
if(/bingo-delivery-admin\.html$/i.test(location.pathname)){
  const s=document.createElement('script');
  s.src='bingo-delivery-live-map.js';
  s.defer=true;
  document.head.appendChild(s);
}