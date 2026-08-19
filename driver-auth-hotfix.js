(function(){
  'use strict';
  if(!/bingo-delivery-driver\.html$/i.test(location.pathname)) return;
  const sb=window.sb;
  if(!sb?.auth) return;

  const loginMsg=document.getElementById('loginMsg');
  const login=document.getElementById('login');
  const app=document.getElementById('app');
  const logout=document.getElementById('logout');

  function showLoggedOut(){
    if(login) login.style.display='block';
    if(app) app.style.display='none';
    if(logout) logout.style.display='none';
    if(loginMsg && /auth session missing/i.test(loginMsg.textContent||'')) loginMsg.textContent='';
  }

  const originalGetUser=sb.auth.getUser.bind(sb.auth);
  sb.auth.getUser=async function(...args){
    try{
      const r=await originalGetUser(...args);
      if(r?.error && /auth session missing/i.test(String(r.error.message||''))) return {data:{user:null},error:null};
      return r;
    }catch(e){
      if(/auth session missing/i.test(String(e?.message||''))) return {data:{user:null},error:null};
      throw e;
    }
  };

  window.addEventListener('unhandledrejection',e=>{
    if(/auth session missing/i.test(String(e.reason?.message||e.reason||''))){
      e.preventDefault();
      showLoggedOut();
    }
  });

  document.addEventListener('DOMContentLoaded',()=>{
    setTimeout(()=>{
      if(loginMsg && /auth session missing/i.test(loginMsg.textContent||'')) loginMsg.textContent='';
    },100);
  });
})();
