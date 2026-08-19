(function(){
'use strict';
if(!/bingo-delivery-driver\.html$/i.test(location.pathname)) return;

const css=document.createElement('link');
css.rel='stylesheet';
css.href='bingo-driver-experience.css?v=20260819-1';
document.head.appendChild(css);

const $=s=>document.querySelector(s);
let activeContext=null;
let lastPosition=null;
let distanceMeters=null;
let geoWatch=null;
let lastSuccessPay='';
let refreshQueued=false;

function haversineMeters(lat1,lon1,lat2,lon2){
  const R=6371000,toRad=v=>v*Math.PI/180;
  const dLat=toRad(lat2-lat1),dLon=toRad(lon2-lon1);
  const a=Math.sin(dLat/2)**2+Math.cos(toRad(lat1))*Math.cos(toRad(lat2))*Math.sin(dLon/2)**2;
  return 2*R*Math.atan2(Math.sqrt(a),Math.sqrt(1-a));
}

function domStage(){
  if($('.delivery-order-card.active-card .delivered')) return {key:'delivery',label:'في الطريق للعميل',pct:82,sub:'Smart Arrival جاهز'};
  if($('.delivery-order-card.active-card .delivery')) return {key:'pickup',label:'تم استلام الطلب',pct:58,sub:'توجه إلى العميل'};
  if($('.delivery-order-card.active-card .pickup')) return {key:'accepted',label:'تم قبول الطلب',pct:34,sub:'توجه إلى المتجر'};
  if($('.delivery-order-card:not(.active-card)')) return {key:'offer',label:'طلب جديد',pct:15,sub:'راجع الطلب ثم اقبله'};
  return {key:'ready',label:'جاهز',pct:5,sub:'بانتظار طلب جديد'};
}

function stage(){
  const base=domStage();
  if(activeContext?.assignment_status==='on_delivery'){
    if(distanceMeters!=null && distanceMeters<=25) return {key:'delivery',label:'وصلت تقريباً',pct:97,sub:'اطلب BINGO Code من العميل'};
    if(distanceMeters!=null && distanceMeters<=60) return {key:'delivery',label:'قريب جداً',pct:94,sub:'بقي '+Math.round(distanceMeters)+' متر'};
    if(distanceMeters!=null && distanceMeters<=180) return {key:'delivery',label:'Smart Arrival',pct:90,sub:'بقي '+Math.round(distanceMeters)+' متر'};
    if(distanceMeters!=null && distanceMeters<=500) return {key:'delivery',label:'اقتربت من العميل',pct:86,sub:'بقي '+Math.round(distanceMeters)+' متر'};
  }
  return base;
}

function inject(){
  const app=$('#app');
  if(!app||$('#bingo-xp')) return;
  const box=document.createElement('section');
  box.id='bingo-xp';
  box.className='bingo-xp';
  box.innerHTML=`<div class="bingo-xp-card bingo-xp-hero"><div class="bingo-xp-copy"><h2>مرحباً بك في BINGO Driver</h2><p>مساعدك الذكي للتوصيل في عُمان. تابع الطلب من لحظة الاستلام حتى لحظة BINGO!</p><div class="bingo-xp-assistant">🟠 BINGO <span id="bingo-assistant-text">أنا جاهز لمساعدتك</span></div></div><img class="bingo-xp-mascot" src="assets/bingo-omani-driver.jpg" alt="BINGO Oman Driver"></div><div class="bingo-xp-card bingo-xp-side"><div class="bingo-ring-wrap"><div class="bingo-ring bingo-pulse" id="bingo-ring"><div class="bingo-ring-core"><div class="bingo-ring-state">حالة الرحلة</div><div class="bingo-ring-value" id="bingo-ring-value">جاهز</div><div class="bingo-ring-sub" id="bingo-ring-sub">بانتظار طلب جديد</div></div></div></div><h3>رحلة BINGO</h3><div class="bingo-stage-list"><div class="bingo-stage" data-stage="offer"><i class="bingo-stage-dot"></i>طلب جديد</div><div class="bingo-stage" data-stage="accepted"><i class="bingo-stage-dot"></i>التوجه للمتجر</div><div class="bingo-stage" data-stage="pickup"><i class="bingo-stage-dot"></i>تم الاستلام</div><div class="bingo-stage" data-stage="delivery"><i class="bingo-stage-dot"></i>Smart Arrival</div></div><div class="bingo-smart-card"><strong>📍 Smart Arrival</strong><span id="bingo-smart-text">يتفعّل تلقائياً أثناء التوصيل.</span></div><button class="bingo-code-btn" id="bingo-code-open" disabled>BINGO Code</button></div>`;
  app.prepend(box);
  document.body.insertAdjacentHTML('beforeend',`<div class="bingo-code-modal" id="bingo-code-modal"><div class="bingo-code-box"><h3>BINGO Code</h3><p>اطلب الرمز المكوّن من 4 أرقام من العميل لتأكيد التسليم.</p><input class="bingo-code-input" id="bingo-code-input" inputmode="numeric" maxlength="4" autocomplete="one-time-code" placeholder="••••"><div class="bingo-code-actions"><button class="bingo-code-confirm" id="bingo-code-confirm">تأكيد التسليم</button><button class="bingo-code-cancel" id="bingo-code-cancel">إلغاء</button></div><small id="bingo-code-msg"></small></div></div><div class="bingo-success" id="bingo-success"><div class="bingo-success-card"><div class="bingo-success-word"><span>B</span><span>I</span><span>N</span><span>G</span><span>O!</span></div><h2>تم التسليم بنجاح 🎉</h2><p>أحسنت! تمت إضافة التوصيلة إلى إنجازاتك.</p><strong id="bingo-success-pay"></strong></div></div>`);
  $('#bingo-code-open').onclick=openCode;
  $('#bingo-code-cancel').onclick=closeCode;
  $('#bingo-code-confirm').onclick=confirmCode;
  $('#bingo-code-input').addEventListener('input',e=>{e.target.value=e.target.value.replace(/\D/g,'').slice(0,4)});
  refresh();
}

function openCode(){if(!activeContext||activeContext.assignment_status!=='on_delivery')return;$('#bingo-code-msg').textContent='';$('#bingo-code-input').value='';$('#bingo-code-modal').classList.add('is-open');setTimeout(()=>$('#bingo-code-input')?.focus(),80)}
function closeCode(){ $('#bingo-code-modal')?.classList.remove('is-open'); }

async function confirmCode(){
  const input=$('#bingo-code-input'),msg=$('#bingo-code-msg'),btn=$('#bingo-code-confirm');
  const code=(input?.value||'').trim();
  if(!/^\d{4}$/.test(code)){msg.textContent='أدخل 4 أرقام';return;}
  if(!activeContext?.assignment_id){msg.textContent='لا توجد رحلة نشطة';return;}
  btn.disabled=true;msg.textContent='جاري التحقق من BINGO Code...';
  try{
    const r=await window.sb.rpc('delivery_confirm_with_code',{p_assignment_id:activeContext.assignment_id,p_code:code});
    if(r.error) throw r.error;
    lastSuccessPay=Number(activeContext.driver_share||0).toFixed(3)+' OMR';
    closeCode();
    const pay=$('#bingo-success-pay');if(pay)pay.textContent=lastSuccessPay?'+'+lastSuccessPay:'';
    $('#bingo-success').classList.add('is-open');
    if(navigator.vibrate) navigator.vibrate([120,70,180]);
    setTimeout(()=>$('#bingo-success')?.classList.remove('is-open'),3200);
    activeContext=null;distanceMeters=null;
    setTimeout(()=>location.reload(),3400);
  }catch(e){
    const m=String(e?.message||'');
    msg.textContent=/Incorrect BINGO Code/i.test(m)?'الكود غير صحيح. اطلب الكود الظاهر للعميل.':'تعذر تأكيد التسليم: '+m;
    if(navigator.vibrate) navigator.vibrate(100);
  }finally{btn.disabled=false;}
}

async function loadContext(){
  if(!window.sb?.rpc) return;
  try{
    const session=await window.sb.auth.getSession();
    if(!session?.data?.session) return;
    const r=await window.sb.rpc('delivery_driver_active_context');
    if(r.error) throw r.error;
    const row=Array.isArray(r.data)?r.data[0]:r.data;
    activeContext=row||null;
    computeDistance();
    protectDeliveredButton();
    refresh();
  }catch(e){console.warn('BINGO active context unavailable',e)}
}

function computeDistance(){
  if(!activeContext||activeContext.assignment_status!=='on_delivery'||!lastPosition||activeContext.latitude==null||activeContext.longitude==null){distanceMeters=null;return;}
  distanceMeters=haversineMeters(lastPosition.coords.latitude,lastPosition.coords.longitude,Number(activeContext.latitude),Number(activeContext.longitude));
}

function startSmartArrival(){
  if(!navigator.geolocation||geoWatch!==null) return;
  geoWatch=navigator.geolocation.watchPosition(pos=>{lastPosition=pos;computeDistance();refresh();},()=>{}, {enableHighAccuracy:true,maximumAge:8000,timeout:15000});
}

function protectDeliveredButton(){document.querySelectorAll('[data-a="delivered"]').forEach(btn=>{btn.dataset.a='bingo-code';btn.textContent='🔐 تأكيد بواسطة BINGO Code';});}

function refresh(){
  if(!$('#bingo-xp')) return;
  protectDeliveredButton();
  const s=stage();
  $('#bingo-ring').style.setProperty('--p',(s.pct*3.6)+'deg');
  $('#bingo-ring-value').textContent=s.label;
  $('#bingo-ring-sub').textContent=s.sub;
  document.querySelectorAll('.bingo-stage').forEach(x=>x.classList.toggle('is-active',x.dataset.stage===s.key));
  const codeBtn=$('#bingo-code-open');if(codeBtn)codeBtn.disabled=!(activeContext?.assignment_status==='on_delivery');
  const text=$('#bingo-assistant-text');
  if(text){if(activeContext?.assignment_status==='on_delivery'&&distanceMeters!=null&&distanceMeters<=180)text.textContent='أنت قريب جداً. ابحث عن مدخل العميل ثم اطلب BINGO Code';else text.textContent=({ready:'أنت جاهز لاستقبال الطلبات',offer:'لديك طلب جديد، راجع التفاصيل',accepted:'توجه إلى المتجر لاستلام الطلب',pickup:'تم الاستلام، الآن إلى العميل',delivery:'أنا أتابع المسافة حتى نقطة الوصول'}[s.key]||'أنا معك');}
  const smart=$('#bingo-smart-text');
  if(smart){if(activeContext?.assignment_status==='on_delivery'&&distanceMeters!=null)smart.textContent=distanceMeters<1000?'المسافة إلى العميل: '+Math.round(distanceMeters)+' متر':'المسافة إلى العميل: '+(distanceMeters/1000).toFixed(1)+' كم';else if(activeContext?.assignment_status==='on_delivery')smart.textContent='جاري تحديد المسافة إلى العميل...';else smart.textContent='يتفعّل تلقائياً أثناء التوصيل.';}
}

function queueRefresh(){if(refreshQueued)return;refreshQueued=true;requestAnimationFrame(()=>{refreshQueued=false;protectDeliveredButton();refresh();});}

function boot(){
  inject();
  const target=$('#app');
  if(target)new MutationObserver(queueRefresh).observe(target,{childList:true,subtree:true});
  document.addEventListener('click',e=>{const b=e.target.closest('[data-a="bingo-code"]');if(!b)return;e.preventDefault();e.stopImmediatePropagation();openCode();},true);
  const startWhenSignedIn=async()=>{const session=await window.sb?.auth?.getSession?.();if(session?.data?.session){startSmartArrival();loadContext();}};
  startWhenSignedIn();
  window.sb?.auth?.onAuthStateChange?.((_event,session)=>{if(session){startSmartArrival();loadContext();}});
  setInterval(loadContext,7000);
  setInterval(refresh,2200);
}

if(document.readyState==='loading')document.addEventListener('DOMContentLoaded',()=>setTimeout(boot,400),{once:true});else setTimeout(boot,400);
})();