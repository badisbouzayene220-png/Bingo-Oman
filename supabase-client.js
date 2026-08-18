window.sb=window.supabase.createClient(window.BINGO_CONFIG.SUPABASE_URL,window.BINGO_CONFIG.SUPABASE_PUBLISHABLE_KEY);
const sb=window.sb;

if(/bingo-delivery-customer\.html$/i.test(location.pathname)){
  const loadCustomerTracking=()=>{
    if(!document.querySelector('script[data-bingo-customer-checkout-fix]')){
      const sc=document.createElement('script');
      sc.src='bingo-delivery-customer-checkout-fix.js?v=20260818-2';
      sc.setAttribute('data-bingo-customer-checkout-fix','1');
      document.body.appendChild(sc);
    }
    if(!document.querySelector('script[data-bingo-customer-tracking-v2]')){
      const s=document.createElement('script');
      s.src='bingo-delivery-customer-tracking.js?v=20260818-8';
      s.setAttribute('data-bingo-customer-tracking-v2','1');
      document.body.appendChild(s);
    }
    if(!document.querySelector('script[data-bingo-customer-driver-stabilizer]')){
      const s2=document.createElement('script');
      s2.src='bingo-delivery-customer-driver-stabilizer.js?v=20260818-1';
      s2.setAttribute('data-bingo-customer-driver-stabilizer','1');
      document.body.appendChild(s2);
    }
  };
  if(document.readyState==='loading')document.addEventListener('DOMContentLoaded',loadCustomerTracking,{once:true});
  else loadCustomerTracking();
}
