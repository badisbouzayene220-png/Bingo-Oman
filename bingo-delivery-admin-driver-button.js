(function(){
'use strict';
if(!/bingo-delivery-(control|admin)\.html$/i.test(location.pathname))return;
function loadSellers(){if(document.getElementById('bingo-admin-sellers-script'))return;const s=document.createElement('script');s.id='bingo-admin-sellers-script';s.src='bingo-delivery-admin-sellers.js?v=20260820-1';s.defer=true;document.head.appendChild(s)}
function place(){
  if(document.getElementById('bingo-add-driver-section'))return;
  const tbody=document.getElementById('drivers');
  const section=tbody?.closest('.bd-card');
  const h2=section?.querySelector('h2');
  if(!section||!h2)return;
  const wrap=document.createElement('div');
  wrap.className='admin-toolbar';
  wrap.style.marginBottom='12px';
  h2.parentNode.insertBefore(wrap,h2);
  wrap.appendChild(h2);
  const btn=document.createElement('button');
  btn.id='bingo-add-driver-section';
  btn.type='button';
  btn.className='bd-btn orange';
  btn.textContent='＋ إضافة مندوب جديد';
  btn.style.fontWeight='800';
  btn.addEventListener('click',()=>{
    const original=document.getElementById('bingo-add-driver');
    if(original){original.click();return;}
    setTimeout(()=>document.getElementById('bingo-add-driver')?.click(),250);
  });
  wrap.appendChild(btn);
}
function boot(){loadSellers();place();const app=document.getElementById('admin-app');if(app)new MutationObserver(()=>place()).observe(app,{childList:true,subtree:true});setInterval(place,2500)}
if(document.readyState==='loading')document.addEventListener('DOMContentLoaded',()=>setTimeout(boot,700),{once:true});else setTimeout(boot,700);
})();
