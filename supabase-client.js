(function(){
  'use strict';
  const path=(location.pathname||'').toLowerCase();
  const isDriver=path.endsWith('/bingo-delivery-driver.html');
  let storageKey=null;
  if(path.endsWith('/bingo-delivery-customer.html')) storageKey='bingo-delivery-auth-customer';
  else if(isDriver) storageKey='bingo-delivery-auth-driver';
  else if(path.endsWith('/bingo-delivery-seller.html')) storageKey='bingo-delivery-auth-seller';
  else if(path.endsWith('/bingo-delivery-admin.html')||path.endsWith('/bingo-delivery-control.html')) storageKey='bingo-delivery-auth-admin';
  const authOptions=storageKey?{storageKey,persistSession:true,autoRefreshToken:true,detectSessionInUrl:true}:null;
  if(isDriver && authOptions && window.sessionStorage) authOptions.storage=window.sessionStorage;
  const options=authOptions?{auth:authOptions}:undefined;
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
        const realUser=r?.data?.session?.user||null;
        if(!realUser) return {data:{user:null},error:null};
        const d=await window.sb.from('delivery_drivers').select('id').eq('id',realUser.id).maybeSingle();
        if(d.error) return {data:{user:null},error:d.error};
        if(!d.data) return {data:{user:null},error:new Error('هذا الحساب غير مسجل كمندوب BINGO')};
        window.BINGO_DRIVER_REAL_EMAIL=realUser.email||'';
        return {data:{user:{...realUser,email:'delivery.driver@test.com'}},error:null};
      }catch(e){
        if(/auth session missing/i.test(String(e?.message||e||''))) return {data:{user:null},error:null};
        return {data:{user:null},error:e};
      }
    };
    const restoreDriverEmail=()=>{const el=document.getElementById('driver-user');if(el&&window.BINGO_DRIVER_REAL_EMAIL&&el.textContent)el.textContent=window.BINGO_DRIVER_REAL_EMAIL};
    setInterval(restoreDriverEmail,500);
  }

  if(/bingo-delivery-customer\.html$/i.test(location.pathname)){
    const loadCustomerTracking=()=>{
      if(!document.querySelector('script[data-bingo-customer-checkout-fix]')){const s=document.createElement('script');s.src='bingo-delivery-customer-checkout-fix.js?v=20260818-2';s.setAttribute('data-bingo-customer-checkout-fix','1');document.body.appendChild(s)}
      if(!document.querySelector('script[data-bingo-customer-tracking-v5]')){const s=document.createElement('script');s.src='bingo-delivery-customer-tracking.js?v=20260818-2215';s.setAttribute('data-bingo-customer-tracking-v5','1');document.body.appendChild(s)}
      if(!document.querySelector('script[data-bingo-customer-eta]')){const s=document.createElement('script');s.src='bingo-delivery-customer-eta.js?v=20260818-2305';s.setAttribute('data-bingo-customer-eta','1');document.body.appendChild(s)}
      if(!document.querySelector('script[data-bingo-customer-code]')){const s=document.createElement('script');s.src='bingo-delivery-customer-code.js?v=20260818-1';s.setAttribute('data-bingo-customer-code','1');document.body.appendChild(s)}
      if(!document.querySelector('script[data-bingo-customer-rating]')){const s=document.createElement('script');s.src='bingo-delivery-customer-rating.js?v=20260819-1';s.setAttribute('data-bingo-customer-rating','1');document.body.appendChild(s)}
    };
    if(document.readyState==='loading')document.addEventListener('DOMContentLoaded',loadCustomerTracking,{once:true});else loadCustomerTracking();
  }

  if(/bingo-delivery-driver\.html$/i.test(location.pathname)){
    const loadDriverExperience=()=>{
      if(!document.querySelector('script[data-bingo-driver-experience]')){const s=document.createElement('script');s.src='bingo-driver-experience.js?v=20260819-3';s.setAttribute('data-bingo-driver-experience','1');document.body.appendChild(s)}
      if(!document.querySelector('script[data-bingo-driver-phase3]')){const p=document.createElement('script');p.src='bingo-driver-phase3.js?v=20260819-4';p.setAttribute('data-bingo-driver-phase3','1');document.body.appendChild(p)}
      if(!document.querySelector('script[data-bingo-driver-badges]')){const b=document.createElement('script');b.src='bingo-driver-badges.js?v=20260819-1';b.setAttribute('data-bingo-driver-badges','1');document.body.appendChild(b)}
      if(!document.querySelector('script[data-bingo-driver-levels]')){const r=document.createElement('script');r.src='bingo-driver-levels-rewards.js?v=20260819-1';r.setAttribute('data-bingo-driver-levels','1');document.body.appendChild(r)}
      if(!document.querySelector('script[data-bingo-driver-notifications]')){const n=document.createElement('script');n.src='bingo-driver-notifications.js?v=20260819-1';n.setAttribute('data-bingo-driver-notifications','1');document.body.appendChild(n)}
    };
    if(document.readyState==='loading')document.addEventListener('DOMContentLoaded',loadDriverExperience,{once:true});else loadDriverExperience();
  }

  if(/bingo-delivery-(control|admin)\.html$/i.test(location.pathname)){
    const loadAdminRewards=()=>{
      if(!document.querySelector('script[data-bingo-admin-leaderboard]')){const s=document.createElement('script');s.src='bingo-delivery-admin-leaderboard.js?v=20260819-1';s.setAttribute('data-bingo-admin-leaderboard','1');document.body.appendChild(s)}
      if(!document.querySelector('script[data-bingo-admin-rewards-drivers]')){const a=document.createElement('script');a.src='bingo-delivery-admin-rewards-drivers.js?v=20260819-2';a.setAttribute('data-bingo-admin-rewards-drivers','1');document.body.appendChild(a)}
      if(!document.querySelector('script[data-bingo-admin-driver-button]')){const b=document.createElement('script');b.src='bingo-delivery-admin-driver-button.js?v=20260819-1';b.setAttribute('data-bingo-admin-driver-button','1');document.body.appendChild(b)}
      if(!document.querySelector('script[data-bingo-admin-dispatch-control]')){const d=document.createElement('script');d.src='bingo-delivery-admin-dispatch-control.js?v=20260819-1';d.setAttribute('data-bingo-admin-dispatch-control','1');document.body.appendChild(d)}
      if(!document.querySelector('script[data-bingo-admin-capacity-fix]')){const c=document.createElement('script');c.src='bingo-delivery-admin-capacity-fix.js?v=20260819-2';c.setAttribute('data-bingo-admin-capacity-fix','1');document.body.appendChild(c)}
    };
    if(document.readyState==='loading')document.addEventListener('DOMContentLoaded',loadAdminRewards,{once:true});else loadAdminRewards();
  }
})();