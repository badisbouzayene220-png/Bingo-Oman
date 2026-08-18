(function(){
  'use strict';
  if(window.__bingoCustomerEtaLoaded)return;
  window.__bingoCustomerEtaLoaded=true;

  const sb=window.sb;
  let busy=false,channel=null,timer=null;
  const valid=v=>Number.isFinite(Number(v))&&Math.abs(Number(v))>0.000001;
  const km=(a,b,c,d)=>{const R=6371,r=x=>Number(x)*Math.PI/180,da=r(c-a),dl=r(d-b);const s=Math.sin(da/2)**2+Math.cos(r(a))*Math.cos(r(c))*Math.sin(dl/2)**2;return R*2*Math.atan2(Math.sqrt(s),Math.sqrt(1-s));};
  function estimate(row){
    if(!valid(row.customer_latitude)||!valid(row.customer_longitude)||!valid(row.driver_latitude)||!valid(row.driver_longitude))return null;
    const distance=km(row.driver_latitude,row.driver_longitude,row.customer_latitude,row.customer_longitude);
    if(distance<0.08)return {minutes:1,distance};
    let speed=Number(row.driver_speed_kmh);
    if(!Number.isFinite(speed)||speed<5||speed>100)speed=28;
    const trafficFactor=1.25;
    const minutes=Math.max(2,Math.ceil((distance/speed)*60*trafficFactor));
    return {minutes,distance};
  }
  function findCard(orderNumber){return [...document.querySelectorAll('.bct-order')].find(x=>x.dataset.orderNumber===String(orderNumber)||x.textContent.includes(String(orderNumber)));}
  function render(row){
    const card=findCard(row.order_number);if(!card)return;
    let box=card.querySelector('.bct-eta');
    if(!box){box=document.createElement('div');box.className='bct-eta';box.style.cssText='margin-top:10px;padding:12px 14px;border-radius:13px;background:#fff7e8;border:1px solid #ffd9a8;font-weight:800;color:#8a4d00;display:flex;gap:10px;align-items:center;flex-wrap:wrap';const mapWrap=card.querySelector('.bct-live-map-wrap');(mapWrap||card).insertAdjacentElement(mapWrap?'beforebegin':'beforeend',box);}
    if(!row.driver_id){box.style.display='none';return;}
    if(row.order_status==='delivered'){box.style.display='flex';box.textContent='✅ تم تسليم الطلب';return;}
    const e=estimate(row);
    if(!e){box.style.display='flex';box.textContent='🛵 جاري حساب وقت الوصول عند توفر GPS...';return;}
    box.style.display='flex';
    const mins=e.minutes<=1?'أقل من دقيقة':`حوالي ${e.minutes} دقيقة`;
    const dist=e.distance<1?`${Math.round(e.distance*1000)} م`:`${e.distance.toFixed(2)} كم`;
    box.innerHTML=`<span>⏱️ وقت الوصول المتوقع: <strong>${mins}</strong></span><span>• المسافة ${dist}</span>`;
  }
  async function refresh(){if(busy||!sb?.rpc)return;busy=true;try{const {data,error}=await sb.rpc('customer_delivery_tracking');if(error)throw error;let rows=data;if(typeof rows==='string'){try{rows=JSON.parse(rows||'[]')}catch{rows=[]}};(Array.isArray(rows)?rows:[]).forEach(render);}catch(e){console.warn('BINGO ETA:',e);}finally{busy=false;}}
  function queue(){clearTimeout(timer);timer=setTimeout(refresh,160);}
  function startRealtime(){if(channel||!sb?.channel)return;channel=sb.channel('bingo-customer-eta-'+Math.random().toString(36).slice(2)).on('postgres_changes',{event:'*',schema:'public',table:'delivery_orders'},queue).on('postgres_changes',{event:'*',schema:'public',table:'delivery_assignments'},queue).on('postgres_changes',{event:'UPDATE',schema:'public',table:'delivery_drivers'},queue).subscribe();}
  function init(){refresh();setTimeout(refresh,800);setInterval(refresh,15000);new MutationObserver(queue).observe(document.body,{childList:true,subtree:true});startRealtime();}
  if(document.readyState==='loading')document.addEventListener('DOMContentLoaded',init,{once:true});else init();
})();