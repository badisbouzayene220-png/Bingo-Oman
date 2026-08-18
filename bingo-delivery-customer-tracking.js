(function(){
  'use strict';
  if(window.__bingoCustomerTrackingLoaded)return;
  window.__bingoCustomerTrackingLoaded=true;

  const sb=window.sb;
  const esc=v=>String(v??'').replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
  const statusLabels={pending:'تم استلام الطلب',confirmed:'تم تأكيد الطلب',preparing:'قيد التجهيز',ready:'جاهز للاستلام',assigned:'تم تعيين المندوب',picked_up:'استلم المندوب الطلب',on_delivery:'المندوب في الطريق',delivered:'تم التسليم',cancelled:'تم إلغاء الطلب'};
  const steps=['pending','preparing','ready','assigned','picked_up','on_delivery','delivered'];
  const stepLabels=['تم الطلب','قيد التجهيز','جاهز','تم تعيين المندوب','تم الاستلام','في الطريق','تم التسليم'];

  function addStyles(){
    if(document.getElementById('bingo-customer-tracking-style'))return;
    const s=document.createElement('style');
    s.id='bingo-customer-tracking-style';
    s.textContent=`
      .bct-card{margin-top:18px}.bct-head{display:flex;justify-content:space-between;gap:12px;align-items:center;flex-wrap:wrap}.bct-head h2{margin:0}.bct-refresh{border:0;border-radius:11px;padding:9px 13px;font-weight:800;cursor:pointer;background:#eef4fb;color:#153d70}.bct-order{border:1px solid #e3e9f1;border-radius:18px;padding:16px;margin-top:14px;background:#fff}.bct-top{display:flex;justify-content:space-between;gap:10px;align-items:center;flex-wrap:wrap}.bct-no{font-size:18px;font-weight:900}.bct-status{padding:6px 10px;border-radius:999px;font-size:12px;font-weight:800;background:#fff3e4;color:#a85a00}.bct-status.done{background:#e9f8ef;color:#187845}.bct-status.cancel{background:#ffeaea;color:#a83232}.bct-progress{display:grid;grid-template-columns:repeat(7,1fr);gap:6px;margin:16px 0}.bct-step{position:relative;text-align:center;font-size:11px;color:#8893a3;padding-top:27px}.bct-step:before{content:'';position:absolute;top:6px;left:50%;transform:translateX(-50%);width:16px;height:16px;border-radius:50%;background:#d9e1eb;border:3px solid #fff;box-shadow:0 0 0 1px #cbd5e1}.bct-step.done{color:#183b65;font-weight:800}.bct-step.done:before{background:#1c7be5}.bct-step.current:before{background:#ff8a1f;box-shadow:0 0 0 4px rgba(255,138,31,.15)}.bct-step:not(:last-child):after{content:'';position:absolute;top:13px;width:calc(100% - 20px);height:2px;background:#d9e1eb;right:calc(-50% + 10px);z-index:0}.bct-step.done:not(:last-child):after{background:#1c7be5}.bct-grid{display:grid;grid-template-columns:1fr 1fr;gap:10px}.bct-info{background:#f7f9fc;border-radius:13px;padding:11px}.bct-info small{display:block;color:#7a8798;margin-bottom:5px}.bct-driver{margin-top:12px;padding:13px;border-radius:14px;background:#f1f6fc}.bct-driver strong{display:block;margin-bottom:5px}.bct-driver-meta{display:flex;gap:10px;flex-wrap:wrap;color:#66758a;font-size:13px}.bct-map-link{display:inline-block;margin-top:9px;text-decoration:none;background:#173f70;color:white;border-radius:10px;padding:9px 12px;font-weight:800;font-size:13px}.bct-empty{text-align:center;padding:24px;color:#778496;background:#f8fafc;border-radius:14px;margin-top:12px}.bct-note{font-size:12px;color:#778496;margin-top:10px}
      @media(max-width:760px){.bct-progress{grid-template-columns:1fr;gap:0;margin-inline-start:8px}.bct-step{text-align:start;padding:8px 34px 8px 0}.bct-step:before{top:8px;right:0;left:auto;transform:none}.bct-step:not(:last-child):after{top:24px;right:7px;width:2px;height:22px}.bct-grid{grid-template-columns:1fr}}
    `;
    document.head.appendChild(s);
  }

  function ensureSection(){
    let section=document.getElementById('bingo-customer-tracking');
    if(section)return section;
    const orders=document.getElementById('delivery-orders');
    if(!orders)return null;
    section=document.createElement('section');
    section.id='bingo-customer-tracking';
    section.className='bd-card bct-card';
    section.innerHTML='<div class="bct-head"><div><h2>متابعة الطلب</h2><div class="bd-muted">تابع حالة طلبك والمندوب خطوة بخطوة</div></div><button id="bct-refresh" class="bct-refresh" type="button">تحديث</button></div><div id="bct-content"><div class="bct-empty">جاري تحميل طلباتك...</div></div><div id="bct-last-check" class="bct-note"></div>';
    orders.closest('section')?.after(section);
    const fakeMap=document.querySelector('.bd-map');
    if(fakeMap?.closest('section'))fakeMap.closest('section').style.display='none';
    section.querySelector('#bct-refresh').onclick=loadTracking;
    return section;
  }

  function currentIndex(status){
    if(status==='confirmed')return 0;
    const i=steps.indexOf(status);
    return i<0?0:i;
  }

  function timeline(status){
    if(status==='cancelled')return '<div class="bct-status cancel" style="margin-top:14px;display:inline-block">تم إلغاء الطلب</div>';
    const idx=currentIndex(status);
    return '<div class="bct-progress">'+stepLabels.map((label,i)=>`<div class="bct-step ${i<idx?'done':i===idx?'done current':''}">${label}</div>`).join('')+'</div>';
  }

  function driverBlock(driver,assignment){
    if(!assignment)return '<div class="bct-driver"><strong>المندوب</strong><div class="bct-driver-meta"><span>لم يتم تعيين مندوب بعد</span></div></div>';
    const name=driver?.display_name||'تم تعيين مندوب';
    const online=driver?.is_online===true?'🟢 متصل':driver?.is_online===false?'⚫ غير متصل':'';
    const phone=driver?.phone?`<span>📞 ${esc(driver.phone)}</span>`:'';
    const loc=(driver?.latitude!=null&&driver?.longitude!=null)?`<a class="bct-map-link" target="_blank" rel="noopener" href="https://www.google.com/maps?q=${encodeURIComponent(driver.latitude+','+driver.longitude)}">📍 مشاهدة موقع المندوب</a>`:'';
    return `<div class="bct-driver"><strong>🛵 ${esc(name)}</strong><div class="bct-driver-meta"><span>${online}</span>${phone}<span>الحالة: ${esc(assignment.status||'assigned')}</span></div>${loc}</div>`;
  }

  async function loadTracking(){
    const section=ensureSection();
    if(!section||!sb?.auth)return;
    const host=section.querySelector('#bct-content');
    host.innerHTML='<div class="bct-empty">جاري تحديث حالة الطلب...</div>';
    try{
      const {data:{session}}=await sb.auth.getSession();
      if(!session?.user){host.innerHTML='<div class="bct-empty">سجّل الدخول لمتابعة طلباتك.</div>';return;}
      const q=await sb.from('delivery_orders').select('id,order_number,status,total,delivery_fee,delivery_address,created_at').eq('customer_id',session.user.id).order('created_at',{ascending:false}).limit(10);
      if(q.error)throw q.error;
      const orders=q.data||[];
      if(!orders.length){host.innerHTML='<div class="bct-empty">لا توجد طلبات للمتابعة حاليًا.</div>';return;}

      const ids=orders.map(o=>o.id);
      let assignments=[];
      try{
        const a=await sb.from('delivery_assignments').select('id,order_id,driver_id,status,offered_at').in('order_id',ids).order('offered_at',{ascending:false});
        if(!a.error)assignments=a.data||[];
      }catch(e){console.warn('BINGO customer assignments:',e);}
      const latestAssignment=new Map();
      assignments.forEach(a=>{if(!latestAssignment.has(a.order_id))latestAssignment.set(a.order_id,a);});

      const driverIds=[...new Set(assignments.map(a=>a.driver_id).filter(Boolean))];
      let drivers=[];
      if(driverIds.length){
        try{
          const d=await sb.from('delivery_drivers').select('id,display_name,phone,is_online,latitude,longitude,last_online_at').in('id',driverIds);
          if(!d.error)drivers=d.data||[];
        }catch(e){console.warn('BINGO customer drivers:',e);}
      }
      const driverMap=new Map(drivers.map(d=>[d.id,d]));

      host.innerHTML=orders.map(o=>{
        const a=latestAssignment.get(o.id);
        const d=a?driverMap.get(a.driver_id):null;
        const statusClass=o.status==='delivered'?'done':o.status==='cancelled'?'cancel':'';
        return `<article class="bct-order"><div class="bct-top"><div class="bct-no">#${esc(o.order_number||o.id)}</div><span class="bct-status ${statusClass}">${esc(statusLabels[o.status]||o.status)}</span></div>${timeline(o.status)}<div class="bct-grid"><div class="bct-info"><small>الإجمالي</small><strong>${Number(o.total||0).toFixed(3)} OMR</strong></div><div class="bct-info"><small>عنوان التوصيل</small><strong>${esc(o.delivery_address||'—')}</strong></div></div>${driverBlock(d,a)}</article>`;
      }).join('');
      section.querySelector('#bct-last-check').textContent='آخر تحديث: '+new Date().toLocaleString('ar-OM');
    }catch(e){
      console.error('BINGO customer tracking:',e);
      host.innerHTML='<div class="bct-empty">تعذر تحميل متابعة الطلب: '+esc(e?.message||String(e))+'</div>';
    }
  }

  function init(){addStyles();ensureSection();loadTracking();setInterval(loadTracking,15000);if(sb?.auth?.onAuthStateChange)sb.auth.onAuthStateChange(()=>setTimeout(loadTracking,300));}
  if(document.readyState==='loading')document.addEventListener('DOMContentLoaded',init,{once:true});else init();
})();