(function(){
  'use strict';
  if(window.__bingoCustomerDriverOverlay)return;
  window.__bingoCustomerDriverOverlay=true;
  const sb=window.sb;
  const esc=v=>String(v??'').replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));

  async function apply(){
    if(!sb?.rpc)return;
    let r;
    try{r=await sb.rpc('customer_delivery_tracking');}
    catch(e){console.warn('customer_delivery_tracking:',e);return;}
    if(r.error){console.warn('customer_delivery_tracking:',r.error);return;}
    let rows=r.data;
    if(typeof rows==='string'){try{rows=JSON.parse(rows)}catch{rows=[]}}
    if(!Array.isArray(rows))rows=[];

    document.querySelectorAll('#bingo-customer-tracking .bct-order').forEach(card=>{
      const no=(card.querySelector('.bct-no')?.textContent||'').replace(/^#/,'').trim();
      const row=rows.find(x=>String(x.order_number||'').trim()===no);
      if(!row)return;
      let box=card.querySelector('.bct-driver');
      if(!box){box=document.createElement('div');box.className='bct-driver';card.appendChild(box);}
      if(!row.driver_id){box.innerHTML='<strong>المندوب</strong><div class="bct-driver-meta"><span>لم يتم تعيين مندوب بعد</span></div>';return;}
      const online=row.driver_online===true?'🟢 متصل':row.driver_online===false?'⚫ غير متصل':'⚪ الحالة غير معروفة';
      const phone=row.driver_phone?`<span>📞 ${esc(row.driver_phone)}</span>`:'';
      const vehicle=row.vehicle_type?`<span>🏍️ ${esc(row.vehicle_type)}</span>`:'';
      const rating=row.driver_rating!=null?`<span>⭐ ${Number(row.driver_rating).toFixed(2)}</span>`:'';
      const updated=row.driver_location_updated_at?`<span>آخر تحديث للموقع: ${new Date(row.driver_location_updated_at).toLocaleString('ar-OM')}</span>`:'';
      const loc=(row.driver_latitude!=null&&row.driver_longitude!=null)?`<a class="bct-map-link" target="_blank" rel="noopener" href="https://www.google.com/maps?q=${encodeURIComponent(row.driver_latitude+','+row.driver_longitude)}">📍 مشاهدة موقع المندوب</a>`:'';
      box.innerHTML=`<strong>🛵 ${esc(row.driver_name||'المندوب')}</strong><div class="bct-driver-meta"><span>${online}</span>${phone}${vehicle}${rating}<span>الحالة: ${esc(row.assignment_status||row.order_status||'assigned')}</span>${updated}</div>${loc}`;

      const infos=card.querySelectorAll('.bct-info');
      if(infos[1]&&row.delivery_address){const strong=infos[1].querySelector('strong');if(strong)strong.textContent=row.delivery_address;}
    });
  }

  function init(){apply();setTimeout(apply,1200);setInterval(apply,15000);document.addEventListener('click',e=>{if(e.target?.id==='bct-refresh')setTimeout(apply,600)});}
  if(document.readyState==='loading')document.addEventListener('DOMContentLoaded',init,{once:true});else init();
})();