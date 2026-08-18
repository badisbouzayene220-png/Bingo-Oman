(function(){
  'use strict';

  const path=(location.pathname||'').toLowerCase();
  let storageKey=null;
  if(path.endsWith('/bingo-delivery-customer.html')) storageKey='bingo-delivery-auth-customer';
  else if(path.endsWith('/bingo-delivery-driver.html')) storageKey='bingo-delivery-auth-driver';
  else if(path.endsWith('/bingo-delivery-seller.html')) storageKey='bingo-delivery-auth-seller';
  else if(path.endsWith('/bingo-delivery-admin.html')||path.endsWith('/bingo-delivery-control.html')) storageKey='bingo-delivery-auth-admin';

  const options=storageKey?{auth:{storageKey,persistSession:true,autoRefreshToken:true,detectSessionInUrl:true}}:undefined;
  window.sb=window.supabase.createClient(window.BINGO_CONFIG.SUPABASE_URL,window.BINGO_CONFIG.SUPABASE_PUBLISHABLE_KEY,options);
  window.supabaseClient=window.sb;

  if(/bingo-delivery-customer\.html$/i.test(location.pathname)){
    const loadCustomerTracking=()=>{
      if(!document.querySelector('script[data-bingo-customer-checkout-fix]')){
        const sc=document.createElement('script');sc.src='bingo-delivery-customer-checkout-fix.js?v=20260818-2';sc.setAttribute('data-bingo-customer-checkout-fix','1');document.body.appendChild(sc);
      }
      if(!document.querySelector('script[data-bingo-customer-tracking-v4]')){
        const s=document.createElement('script');s.src='bingo-delivery-customer-tracking.js?v=20260818-2205';s.setAttribute('data-bingo-customer-tracking-v4','1');document.body.appendChild(s);
      }
    };
    if(document.readyState==='loading')document.addEventListener('DOMContentLoaded',loadCustomerTracking,{once:true});else loadCustomerTracking();
  }
})();