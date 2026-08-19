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

  if(/bingo-delivery-driver\.html$/i.test(location.pathname) && window.sb?.auth?.getSession){
    window.sb.auth.getUser=async function(){
      try{
        const r=await window.sb.auth.getSession();
        if(r?.error){
          if(/auth session missing/i.test(String(r.error.message||''))) return {data:{user:null},error:null};
          return {data:{user:null},error:r.error};
        }
        return {data:{user:r?.data?.session?.user||null},error:null};
      }catch(e){
        if(/auth session missing/i.test(String(e?.message||e||''))) return {data:{user:null},error:null};
        return {data:{user:null},error:e};
      }
    };
  }

  if(/bingo-delivery-customer\.html$/i.test(location.pathname)){
    const loadCustomerTracking=()=>{
      if(!document.querySelector('script[data-bingo-customer-checkout-fix]')){const s=document.createElement('script');s.src='bingo-delivery-customer-checkout-fix.js?v=20260818-2';s.setAttribute('data-bingo-customer-checkout-fix','1');document.body.appendChild(s)}
      if(!document.querySelector('script[data-bingo-customer-tracking-v5]')){const s=document.createElement('script');s.src='bingo-delivery-customer-tracking.js?v=20260818-2215';s.setAttribute('data-bingo-customer-tracking-v5','1');document.body.appendChild(s)}
      if(!document.querySelector('script[data-bingo-customer-eta]')){const s=document.createElement('script');s.src='bingo-delivery-customer-eta.js?v=20260818-2305';s.setAttribute('data-bingo-customer-eta','1');document.body.appendChild(s)}
      if(!document.querySelector('script[data-bingo-customer-code]')){const s=document.createElement('script');s.src='bingo-delivery-customer-code.js?v=20260818-1';s.setAttribute('data-bingo-customer-code','1');document.body.appendChild(s)}
    };
    if(document.readyState==='loading')document.addEventListener('DOMContentLoaded',loadCustomerTracking,{once:true});else loadCustomerTracking();
  }

  if(/bingo-delivery-driver\.html$/i.test(location.pathname)){
    const loadDriverExperience=()=>{
      if(!document.querySelector('script[data-bingo-driver-experience]')){
        const s=document.createElement('script');s.src='bingo-driver-experience.js?v=20260819-3';s.setAttribute('data-bingo-driver-experience','1');document.body.appendChild(s);
      }
      if(!document.querySelector('script[data-bingo-driver-phase3]')){
        const p=document.createElement('script');p.src='bingo-driver-phase3.js?v=20260819-1';p.setAttribute('data-bingo-driver-phase3','1');document.body.appendChild(p);
      }
    };
    if(document.readyState==='loading')document.addEventListener('DOMContentLoaded',loadDriverExperience,{once:true});else loadDriverExperience();
  }
})();