window.sb=window.supabase.createClient(window.BINGO_CONFIG.SUPABASE_URL,window.BINGO_CONFIG.SUPABASE_PUBLISHABLE_KEY);
const sb=window.sb;

// BINGO Delivery Admin: force-load the versioned live driver map only here.
if(/bingo-delivery-admin\.html$/i.test(location.pathname)){
  const loadMapScript=()=>{
    if(document.querySelector('script[data-bingo-driver-map]')) return;
    const s=document.createElement('script');
    s.src='bingo-delivery-live-map.js?v=20260818-2';
    s.setAttribute('data-bingo-driver-map','1');
    s.onload=()=>{ console.log('BINGO Delivery live map loaded'); };
    s.onerror=()=>{ console.error('BINGO Delivery live map failed to load'); };
    document.body.appendChild(s);
  };
  if(document.readyState==='loading') document.addEventListener('DOMContentLoaded',loadMapScript,{once:true});
  else loadMapScript();
}