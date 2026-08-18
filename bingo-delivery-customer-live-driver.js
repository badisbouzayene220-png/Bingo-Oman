(function(){
  'use strict';
  // v2 guard: intentionally different from the old cached script guard.
  if(window.__bingoCustomerLiveDriverV2Loaded)return;
  window.__bingoCustomerLiveDriverV2Loaded=true;
  const sb=window.sb;
  const esc=v=>String(v??'').replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));

  function style(){
    if(document.getElementById('bingo-live-driver-style-v2'))return;
    const s=document.createElement('style');
    s.id='bingo-live-driver-style-v2';
    s.textContent='.bcld-box{margin-top:10px;padding:13px;border-radius:14px;background:#eef6ff;border:1px solid #d7e8fb}.bcld-top{display:flex;justify-content:space-between;gap:10px;align-items:center;flex-wrap:wrap}.bcld-name{font-weight:900}.bcld-meta{display:flex;gap:10px;flex-wrap:wrap;margin-top:7px;font-size:13px;color:#62738a}.bcld-map{display:inline-block;margin-top:9px;padding:9px 12px;border-radius:10px;background:#153d70;color:#fff;text-decoration:none;font-weight:800}.bcld-muted{color:#738196;font-size:12px;margin-top:7px}';
    document.head.appendChild(s);
  }

  function findOrderCard(orderNumber){
    return [...document.querySelectorAll('.bct-order')].find(card=>card.textContent.includes('#'+orderNumber)||card.textContent.includes(orderNumber));
  }

  function fillAddress(card,row){
    if(!row.delivery_address)return;
    const infos=[...card.querySelectorAll('.bct-info')];
    const addressBox=infos.find(x=>/Delivery address|عنوان التوصيل/i.test(x.textContent));
    if(!addressBox)return;
    const strong=addressBox.querySelector('strong');
    if(strong)strong.textContent=row.delivery_address;
  }

  function renderRow(row){
    const card=findOrderCard(row.order_number);
    if(!card)return;
    fillAddress(card,row);

    // Remove every old/generic driver block so one authoritative RPC block remains.
    card.querySelectorAll('.bct-driver,.bcld-box').forEach(el=>el.remove());

    const box=document.createElement('div');
    box.className='bcld-box';
    card.appendChild(box);

    if(!row.driver_id){
      box.innerHTML='<div class="bcld-muted">لم يتم تعيين مندوب لهذا الطلب بعد.</div>';
      return;
    }

    const online=row.driver_online===true?'🟢 متصل':'⚫ غير متصل';
    const phone=row.driver_phone?`<span>📞 ${esc(row.driver_phone)}</span>`:'';
    const rating=row.driver_rating!=null?`<span>⭐ ${Number(row.driver_rating).toFixed(2)}</span>`:'';
    const vehicle=row.vehicle_type?`<span>🛵 ${esc(row.vehicle_type)}</span>`:'';
    const location=(row.driver_latitude!=null&&row.driver_longitude!=null)?`<a class="bcld-map" target="_blank" rel="noopener" href="https://www.google.com/maps?q=${encodeURIComponent(row.driver_latitude+','+row.driver_longitude)}">📍 مشاهدة موقع المندوب</a>`:'';
    const updated=row.driver_location_updated_at?`<div class="bcld-muted">آخر تحديث للموقع: ${new Date(row.driver_location_updated_at).toLocaleString('ar-OM')}</div>`:'';
    box.innerHTML=`<div class="bcld-top"><div class="bcld-name">🛵 ${esc(row.driver_name||'المندوب')}</div><div>${online}</div></div><div class="bcld-meta">${phone}${vehicle}${rating}<span>الحالة: ${esc(row.assignment_status||row.order_status||'')}</span></div>${location}${updated}`;
  }

  async function refresh(){
    if(!sb?.rpc)return;
    try{
      const {data,error}=await sb.rpc('customer_delivery_tracking');
      if(error)throw error;
      let rows=data;
      if(typeof rows==='string'){try{rows=JSON.parse(rows)}catch{rows=[]}}
      rows=Array.isArray(rows)?rows:[];
      rows.forEach(renderRow);
    }catch(e){
      console.warn('BINGO customer live driver v2:',e);
    }
  }

  function init(){style();setTimeout(refresh,350);setTimeout(refresh,1200);setTimeout(refresh,2500);setInterval(refresh,15000);}
  if(document.readyState==='loading')document.addEventListener('DOMContentLoaded',init,{once:true});else init();
})();