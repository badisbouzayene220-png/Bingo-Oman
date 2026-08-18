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
      if(!document.querySelector('script[data-bingo-customer-tracking-v5]')){
        const s=document.createElement('script');s.src='bingo-delivery-customer-tracking.js?v=20260818-2215';s.setAttribute('data-bingo-customer-tracking-v5','1');document.body.appendChild(s);
      }
      if(!document.querySelector('script[data-bingo-customer-eta]')){
        const e=document.createElement('script');e.src='bingo-delivery-customer-eta.js?v=20260818-2305';e.setAttribute('data-bingo-customer-eta','1');document.body.appendChild(e);
      }
      if(!document.querySelector('script[data-bingo-customer-code]')){
        const c=document.createElement('script');c.src='bingo-delivery-customer-code.js?v=20260818-1';c.setAttribute('data-bingo-customer-code','1');document.body.appendChild(c);
      }
    };
    if(document.readyState==='loading')document.addEventListener('DOMContentLoaded',loadCustomerTracking,{once:true});else loadCustomerTracking();
  }

  if(/bingo-delivery-driver\.html$/i.test(location.pathname)){
    const loadDriverExperience=()=>{
      if(document.querySelector('script[data-bingo-driver-experience]')) return;
      const s=document.createElement('script');
      s.src='bingo-driver-experience.js?v=20260818-2';
      s.setAttribute('data-bingo-driver-experience','1');
      document.body.appendChild(s);
    };
    if(document.readyState==='loading')document.addEventListener('DOMContentLoaded',loadDriverExperience,{once:true});else loadDriverExperience();
  }
})();