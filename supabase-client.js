window.sb=window.supabase.createClient(window.BINGO_CONFIG.SUPABASE_URL,window.BINGO_CONFIG.SUPABASE_PUBLISHABLE_KEY);
const sb=window.sb;

if(/bingo-delivery-customer\.html$/i.test(location.pathname)){
  const loadCustomerTracking=()=>{
    if(document.querySelector('script[data-bingo-customer-tracking]'))return;
    const s=document.createElement('script');
    s.src='bingo-delivery-customer-tracking.js?v=20260818-3';
    s.setAttribute('data-bingo-customer-tracking','1');
    document.body.appendChild(s);
  };
  if(document.readyState==='loading')document.addEventListener('DOMContentLoaded',loadCustomerTracking,{once:true});
  else loadCustomerTracking();
}
