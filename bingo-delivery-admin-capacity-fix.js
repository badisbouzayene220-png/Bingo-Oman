(function(){
'use strict';
const sb=window.sb;if(!sb?.rpc)return;
let rows=[];
const esc=v=>String(v??'').replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot',"'":'&#39;'}[c]));
async function refreshCapacity(){
  const card=document.getElementById('bingo-dispatch-control');
  if(!card)return;
  let host=document.getElementById('dispatch-cap-status');
  if(!host){
    host=document.createElement('div');host.id='dispatch-cap-status';
    host.style.cssText='margin-top:10px;display:flex;gap:8px;flex-wrap:wrap';
    const save=document.getElementById('dispatch-cap-save');save?.parentElement?.parentElement?.appendChild(host);
  }
  try{
    const r=await sb.rpc('admin_delivery_reconcile_driver_capacity');
    if(r.error)throw r.error;
    const q=await sb.rpc('admin_delivery_driver_capacities');
    if(q.error)throw q.error;
    rows=Array.isArray(q.data)?q.data:[];
    host.innerHTML=rows.length?rows.map(x=>`<span class="admin-pill ${Number(x.remaining_capacity)>0?'success':'warning'}" style="padding:7px 10px"><strong>${esc(x.driver_name)}</strong> — الحد ${Number(x.max_concurrent_orders||1)} — الحمل ${Number(x.active_load||0)}/${Number(x.max_concurrent_orders||1)} — المتبقي ${Number(x.remaining_capacity||0)}</span>`).join(''):'<span class="admin-muted">لا يوجد مندوبون</span>';
    syncSelected();
  }catch(e){host.innerHTML=`<span class="admin-error">تعذر قراءة الحد المحفوظ: ${esc(e.message||e)}</span>`;}
}
function syncSelected(){
  const driver=document.getElementById('dispatch-cap-driver');
  const max=document.getElementById('dispatch-cap-max');
  if(!driver||!max)return;
  const row=rows.find(x=>x.driver_id===driver.value);
  if(row)max.value=String(Number(row.max_concurrent_orders||1));
}
function boot(){
  const timer=setInterval(()=>{
    const driver=document.getElementById('dispatch-cap-driver');
    if(!driver)return;
    clearInterval(timer);
    driver.addEventListener('change',syncSelected);
    document.getElementById('dispatch-cap-save')?.addEventListener('click',()=>setTimeout(refreshCapacity,500));
    document.getElementById('dispatch-refresh')?.addEventListener('click',()=>setTimeout(refreshCapacity,300));
    refreshCapacity();
    setInterval(refreshCapacity,15000);
  },250);
}
if(document.readyState==='loading')document.addEventListener('DOMContentLoaded',boot,{once:true});else boot();
})();