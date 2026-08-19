(function(){
'use strict';
const sb=window.sb;
if(!sb?.rpc)return;
const esc=v=>String(v??'').replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
let board=[];
function driversFromTable(){
  const map=new Map();
  document.querySelectorAll('#drivers button[data-driver-id]').forEach(b=>{
    const id=b.dataset.driverId;if(map.has(id))return;
    const tr=b.closest('tr');const name=tr?.querySelector('td strong')?.textContent?.trim()||'BINGO Driver';
    map.set(id,{id,name});
  });
  return [...map.values()];
}
function ensureCard(){
  if(document.getElementById('bingo-dispatch-control'))return document.getElementById('bingo-dispatch-control');
  const app=document.getElementById('admin-app');if(!app)return null;
  const card=document.createElement('section');
  card.id='bingo-dispatch-control';card.className='bd-card';card.style.marginTop='18px';
  card.innerHTML=`<div class="admin-toolbar"><div><h2 style="margin:0">🧠 BINGO Dispatch Control</h2><div class="admin-muted">سبب الاختيار • إعادة التعيين • حد الطلبات لكل مندوب</div></div><button class="bd-btn ghost" id="dispatch-refresh" type="button">تحديث</button></div><div id="dispatch-msg" class="admin-muted" style="margin-top:10px"></div><div style="overflow:auto;margin-top:10px"><table class="admin-table"><thead><tr><th>الطلب</th><th>المندوب</th><th>الحمل</th><th>سبب الاختيار</th><th>إجراء</th></tr></thead><tbody id="dispatch-body"><tr><td colspan="5">جاري التحميل...</td></tr></tbody></table></div><div style="margin-top:14px;padding-top:14px;border-top:1px solid #e5e7eb"><strong>⚙️ حد الطلبات المتزامنة</strong><div class="admin-muted" style="margin:5px 0 10px">اختر المندوب وحدد من 1 إلى 5 طلبات. الافتراضي 1.</div><div style="display:flex;gap:8px;flex-wrap:wrap"><select id="dispatch-cap-driver" style="padding:9px;border:1px solid #d7dee8;border-radius:9px;min-width:190px"></select><select id="dispatch-cap-max" style="padding:9px;border:1px solid #d7dee8;border-radius:9px"><option value="1">1 طلب</option><option value="2">2 طلب</option><option value="3">3 طلبات</option><option value="4">4 طلبات</option><option value="5">5 طلبات</option></select><button class="bd-btn orange" id="dispatch-cap-save" type="button">حفظ الحد</button></div></div>`;
  const driversSection=document.querySelector('#drivers')?.closest('section.bd-card');
  if(driversSection?.nextSibling)driversSection.parentNode.insertBefore(card,driversSection.nextSibling);else app.appendChild(card);
  card.querySelector('#dispatch-refresh').onclick=load;
  card.querySelector('#dispatch-cap-save').onclick=setCapacity;
  card.querySelector('#dispatch-body').addEventListener('click',e=>{const b=e.target.closest('[data-reassign]');if(b)reassign(b.dataset.reassign);});
  return card;
}
function fillDrivers(){
  const sel=document.getElementById('dispatch-cap-driver');if(!sel)return;
  const previous=sel.value;const ds=driversFromTable();
  sel.innerHTML=ds.length?ds.map(d=>`<option value="${esc(d.id)}">${esc(d.name)}</option>`).join(''):'<option value="">لا يوجد مندوبون</option>';
  if(ds.some(d=>d.id===previous))sel.value=previous;
}
function render(){
  const body=document.getElementById('dispatch-body');if(!body)return;
  const ds=driversFromTable();
  if(!board.length){body.innerHTML='<tr><td colspan="5">لا توجد توزيعات نشطة الآن</td></tr>';return;}
  body.innerHTML=board.map(x=>{
    const can=['offered','accepted'].includes(x.assignment_status);
    const opts=ds.filter(d=>d.id!==x.driver_id).map(d=>`<option value="${esc(d.id)}">${esc(d.name)}</option>`).join('');
    const action=can&&opts?`<div style="display:flex;gap:6px;align-items:center;min-width:250px"><select data-select-for="${esc(x.assignment_id)}" style="padding:7px;border:1px solid #d7dee8;border-radius:8px;max-width:160px">${opts}</select><button class="bd-btn ghost" data-reassign="${esc(x.assignment_id)}" type="button">إعادة تعيين</button></div>`:`<span class="admin-muted">لا يمكن بعد الاستلام</span>`;
    return `<tr><td><strong>#${esc(x.order_number||x.order_id)}</strong><br><span class="admin-pill warning">${esc(x.assignment_status)}</span></td><td><strong>${esc(x.driver_name)}</strong></td><td>${Number(x.active_load||0)} / ${Number(x.max_concurrent||1)}</td><td><div style="max-width:420px;line-height:1.55">${esc(x.dispatch_reason||'—')}${x.distance_km!=null?`<br><span class="admin-muted">المسافة التقريبية: ${Number(x.distance_km).toFixed(2)} كم</span>`:''}</div></td><td>${action}</td></tr>`;
  }).join('');
}
async function load(){
  ensureCard();fillDrivers();
  const msg=document.getElementById('dispatch-msg');
  try{
    const r=await sb.rpc('admin_delivery_dispatch_board');if(r.error)throw r.error;
    board=Array.isArray(r.data)?r.data:[];render();
    if(msg){msg.className='admin-ok';msg.textContent=`تم تحديث Smart Dispatch — ${board.length} توزيع نشط`;}
  }catch(e){
    if(msg){msg.className='admin-error';msg.textContent='شغّل migration Dispatch Control في Supabase: '+(e.message||e);}
  }
}
async function setCapacity(){
  const driver=document.getElementById('dispatch-cap-driver')?.value;
  const max=Number(document.getElementById('dispatch-cap-max')?.value||1);
  if(!driver)return;
  const msg=document.getElementById('dispatch-msg');
  try{
    const r=await sb.rpc('admin_delivery_set_driver_capacity',{p_driver_id:driver,p_max:max});if(r.error)throw r.error;
    if(msg){msg.className='admin-ok';msg.textContent=`تم ضبط الحد إلى ${max} طلب/طلبات لهذا المندوب.`;}
    await load();
  }catch(e){if(msg){msg.className='admin-error';msg.textContent=e.message||String(e);}}
}
async function reassign(assignmentId){
  const select=document.querySelector(`[data-select-for="${CSS.escape(assignmentId)}"]`);const driver=select?.value;if(!driver)return;
  const target=driversFromTable().find(d=>d.id===driver);
  if(!confirm(`إعادة تعيين الطلب إلى ${target?.name||'المندوب المختار'}؟`))return;
  const msg=document.getElementById('dispatch-msg');
  try{
    const r=await sb.rpc('admin_delivery_reassign_order',{p_assignment_id:assignmentId,p_new_driver_id:driver});if(r.error)throw r.error;
    if(msg){msg.className='admin-ok';msg.textContent='تمت إعادة تعيين الطلب وإرسال العرض للمندوب الجديد.';}
    await load();
    document.getElementById('refresh')?.click();
  }catch(e){if(msg){msg.className='admin-error';msg.textContent='تعذر إعادة التعيين: '+(e.message||e);}}
}
function boot(){ensureCard();load();setInterval(()=>{if(!document.getElementById('admin-app')?.classList.contains('admin-hidden'))load();},15000);}
if(document.readyState==='loading')document.addEventListener('DOMContentLoaded',boot,{once:true});else boot();
})();