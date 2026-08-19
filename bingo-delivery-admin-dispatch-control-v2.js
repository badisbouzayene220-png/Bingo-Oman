(function(){
'use strict';
const sb=window.sb;
if(!sb?.rpc)return;
const esc=v=>String(v??'').replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
let board=[];
let capacities=[];
function driverList(){return capacities.map(x=>({id:x.driver_id,name:x.driver_name||'BINGO Driver'}));}
function ensureCard(){
  let card=document.getElementById('bingo-dispatch-control');
  if(card)return card;
  const app=document.getElementById('admin-app');if(!app)return null;
  card=document.createElement('section');
  card.id='bingo-dispatch-control';card.className='bd-card';card.style.marginTop='18px';
  card.innerHTML=`<div class="admin-toolbar"><div><h2 style="margin:0">🧠 BINGO Dispatch Control</h2><div class="admin-muted">سبب الاختيار • إعادة التعيين • حد الطلبات لكل مندوب</div></div><button class="bd-btn ghost" id="dispatch-refresh" type="button">تحديث</button></div>
  <div id="dispatch-msg" class="admin-muted" style="margin-top:10px"></div>
  <div style="overflow:auto;margin-top:10px"><table class="admin-table"><thead><tr><th>الطلب</th><th>المندوب</th><th>الحمل</th><th>سبب الاختيار</th><th>إجراء</th></tr></thead><tbody id="dispatch-body"><tr><td colspan="5">جاري التحميل...</td></tr></tbody></table></div>
  <div style="margin-top:14px;padding-top:14px;border-top:1px solid #e5e7eb"><strong>⚙️ حد الطلبات المتزامنة</strong><div class="admin-muted" style="margin:5px 0 10px">اختر المندوب وحدد من 1 إلى 5 طلبات.</div><div style="display:flex;gap:8px;flex-wrap:wrap"><select id="dispatch-cap-driver" style="padding:9px;border:1px solid #d7dee8;border-radius:9px;min-width:190px"></select><select id="dispatch-cap-max" style="padding:9px;border:1px solid #d7dee8;border-radius:9px"><option value="1">1 طلب</option><option value="2">2 طلب</option><option value="3">3 طلبات</option><option value="4">4 طلبات</option><option value="5">5 طلبات</option></select><button class="bd-btn orange" id="dispatch-cap-save" type="button">حفظ الحد</button></div><div id="dispatch-cap-status" style="display:flex;gap:8px;flex-wrap:wrap;margin-top:10px"></div></div>`;
  const driversSection=document.querySelector('#drivers')?.closest('section.bd-card');
  if(driversSection?.nextSibling)driversSection.parentNode.insertBefore(card,driversSection.nextSibling);else app.appendChild(card);
  card.querySelector('#dispatch-refresh').onclick=load;
  card.querySelector('#dispatch-cap-save').onclick=setCapacity;
  card.querySelector('#dispatch-cap-driver').onchange=syncSelectedLimit;
  card.querySelector('#dispatch-body').addEventListener('click',e=>{const b=e.target.closest('[data-reassign]');if(b)reassign(b.dataset.reassign);});
  return card;
}
function fillDrivers(){
  const sel=document.getElementById('dispatch-cap-driver');if(!sel)return;
  const previous=sel.value;
  sel.innerHTML=capacities.length?capacities.map(d=>`<option value="${esc(d.driver_id)}">${esc(d.driver_name||'BINGO Driver')}</option>`).join(''):'<option value="">لا يوجد مندوبون</option>';
  if(capacities.some(d=>d.driver_id===previous))sel.value=previous;
  syncSelectedLimit();
}
function syncSelectedLimit(){
  const id=document.getElementById('dispatch-cap-driver')?.value;
  const row=capacities.find(x=>x.driver_id===id);
  if(row)document.getElementById('dispatch-cap-max').value=String(row.max_concurrent_orders||1);
}
function renderCapacities(){
  const host=document.getElementById('dispatch-cap-status');if(!host)return;
  host.innerHTML=capacities.length?capacities.map(x=>`<span class="admin-pill ${Number(x.remaining_capacity)>0?'success':'warning'}"><strong>${esc(x.driver_name||'BINGO Driver')}</strong> — الحد ${Number(x.max_concurrent_orders||1)} — الحمل ${Number(x.active_load||0)}/${Number(x.max_concurrent_orders||1)} — المتبقي ${Number(x.remaining_capacity||0)}</span>`).join(''):'<span class="admin-muted">لا توجد بيانات مندوبين</span>';
}
function renderBoard(){
  const body=document.getElementById('dispatch-body');if(!body)return;
  const ds=driverList();
  if(!board.length){body.innerHTML='<tr><td colspan="5">لا توجد توزيعات نشطة الآن</td></tr>';return;}
  body.innerHTML=board.map(x=>{const can=['offered','accepted'].includes(x.assignment_status);const opts=ds.filter(d=>d.id!==x.driver_id).map(d=>`<option value="${esc(d.id)}">${esc(d.name)}</option>`).join('');const action=can&&opts?`<div style="display:flex;gap:6px;align-items:center;min-width:250px"><select data-select-for="${esc(x.assignment_id)}" style="padding:7px;border:1px solid #d7dee8;border-radius:8px;max-width:160px">${opts}</select><button class="bd-btn ghost" data-reassign="${esc(x.assignment_id)}" type="button">إعادة تعيين</button></div>`:`<span class="admin-muted">لا يمكن بعد الاستلام</span>`;return `<tr><td><strong>#${esc(x.order_number||x.order_id)}</strong><br><span class="admin-pill warning">${esc(x.assignment_status)}</span></td><td><strong>${esc(x.driver_name)}</strong></td><td>${Number(x.active_load||0)} / ${Number(x.max_concurrent||1)}</td><td>${esc(x.dispatch_reason||'—')}${x.distance_km!=null?`<br><span class="admin-muted">${Number(x.distance_km).toFixed(2)} كم</span>`:''}</td><td>${action}</td></tr>`;}).join('');
}
async function load(){
  ensureCard();const msg=document.getElementById('dispatch-msg');
  try{
    const [b,c]=await Promise.all([sb.rpc('admin_delivery_dispatch_board'),sb.rpc('admin_delivery_driver_capacities')]);
    if(b.error)throw b.error;if(c.error)throw c.error;
    board=Array.isArray(b.data)?b.data:[];capacities=Array.isArray(c.data)?c.data:[];
    fillDrivers();renderCapacities();renderBoard();
    if(msg){msg.className='admin-ok';msg.textContent=`تم تحديث Smart Dispatch — ${board.length} توزيع نشط — ${capacities.length} مندوب`;}
  }catch(e){if(msg){msg.className='admin-error';msg.textContent='تعذر تحميل Dispatch Control: '+(e.message||e);}}
}
async function setCapacity(){
  const driver=document.getElementById('dispatch-cap-driver')?.value;const max=Number(document.getElementById('dispatch-cap-max')?.value||1);if(!driver)return;
  const msg=document.getElementById('dispatch-msg');
  try{const r=await sb.rpc('admin_delivery_set_driver_capacity',{p_driver_id:driver,p_max:max});if(r.error)throw r.error;await load();if(msg){msg.className='admin-ok';msg.textContent=`تم حفظ الحد ${max} لهذا المندوب.`;}}catch(e){if(msg){msg.className='admin-error';msg.textContent=e.message||String(e);}}
}
async function reassign(id){
  const select=document.querySelector(`[data-select-for="${CSS.escape(id)}"]`);const driver=select?.value;if(!driver)return;const target=driverList().find(d=>d.id===driver);if(!confirm(`إعادة تعيين الطلب إلى ${target?.name||'المندوب المختار'}؟`))return;
  const msg=document.getElementById('dispatch-msg');
  try{const r=await sb.rpc('admin_delivery_reassign_order',{p_assignment_id:id,p_new_driver_id:driver});if(r.error)throw r.error;await load();document.getElementById('refresh')?.click();if(msg){msg.className='admin-ok';msg.textContent='تمت إعادة تعيين الطلب.';}}catch(e){if(msg){msg.className='admin-error';msg.textContent='تعذر إعادة التعيين: '+(e.message||e);}}
}
function boot(){ensureCard();load();setInterval(()=>{if(!document.getElementById('admin-app')?.classList.contains('admin-hidden'))load();},15000);}
if(document.readyState==='loading')document.addEventListener('DOMContentLoaded',boot,{once:true});else boot();
})();