(function(){
  'use strict';
  if(window.__bingoCustomerDriverStabilizerLoaded)return;
  window.__bingoCustomerDriverStabilizerLoaded=true;
  const sb=window.sb;
  const esc=v=>String(v??'').replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
  let busy=false,timer=null;

  function findCard(orderNumber){
    return [...document.querySelectorAll('.bct-order')].find(card=>card.textContent.includes(orderNumber));
  }

  function render(row){
    const card=findCard(row.order_number);
    if(!card)return;
    const old=card.querySelector('.bct-driver');
    if(!old)return;
    if(!row.driver_id)return;
    const online=row.driver_online===true?'🟢 متصل':'⚫ غير متصل';
    const phone=row.driver_phone?`<span>📞 ${esc(row.driver_phone)}</span>`:'';
    const vehicle=row.vehicle_type?`<span>🛵 ${esc(row.vehicle_type)}</span>`:'';
    const rating=row.driver_rating!=null?`<span>⭐ ${Number(row.driver_rating).toFixed(2)}</span>`:'';
    const map=(row.driver_latitude!=null&&row.driver_longitude!=null)?`<a class="bct-map-link" target="_blank" rel="noopener" href="https://www.google.com/maps?q=${encodeURIComponent(row.driver_latitude+','+row.driver_longitude)}">📍 مشاهدة موقع المندوب</a>`:'';
    const updated=row.driver_location_updated_at?`<div class="bct-note">آخر تحديث للموقع: ${new Date(row.driver_location_updated_at).toLocaleString('ar-OM')}</div>`:'';
    old.innerHTML=`<div class="bct-driver-top"><strong>🛵 ${esc(row.driver_name||'المندوب')}</strong><span>${online}</span></div><div class="bct-driver-meta">${phone}${vehicle}${rating}<span>الحالة: ${esc(row.assignment_status||row.order_status||'')}</span></div>${map}${updated}`;
  }

  async function sync(){
    if(busy||!sb?.rpc)return;
    busy=true;
    try{
      const {data,error}=await sb.rpc('customer_delivery_tracking');
      if(error)throw error;
      let rows=data;
      if(typeof rows==='string'){try{rows=JSON.parse(rows)}catch{rows=[]}}
      (Array.isArray(rows)?rows:[]).forEach(render);
    }catch(e){console.warn('BINGO driver stabilizer:',e);}finally{busy=false;}
  }

  function schedule(){clearTimeout(timer);timer=setTimeout(sync,120);}
  function init(){sync();setTimeout(sync,800);setInterval(sync,7000);const root=document.getElementById('bingo-customer-tracking')||document.body;new MutationObserver(schedule).observe(root,{childList:true,subtree:true});}
  if(document.readyState==='loading')document.addEventListener('DOMContentLoaded',init,{once:true});else init();
})();