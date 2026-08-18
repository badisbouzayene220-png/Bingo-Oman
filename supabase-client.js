window.sb=window.supabase.createClient(window.BINGO_CONFIG.SUPABASE_URL,window.BINGO_CONFIG.SUPABASE_PUBLISHABLE_KEY);
const sb=window.sb;

if(/bingo-delivery-customer\.html$/i.test(location.pathname)){
  const loadCustomerTracking=()=>{
    if(!document.querySelector('script[data-bingo-customer-tracking]')){
      const s=document.createElement('script');
      s.src='bingo-delivery-customer-tracking.js?v=20260818-3';
      s.setAttribute('data-bingo-customer-tracking','1');
      document.body.appendChild(s);
    }
    if(!document.querySelector('script[data-bingo-customer-live-driver]')){
      const s2=document.createElement('script');
      s2.src='bingo-delivery-customer-live-driver.js?v=20260818-1';
      s2.setAttribute('data-bingo-customer-live-driver','1');
      document.body.appendChild(s2);
    }
  };
  if(document.readyState==='loading')document.addEventListener('DOMContentLoaded',loadCustomerTracking,{once:true});
  else loadCustomerTracking();
}
