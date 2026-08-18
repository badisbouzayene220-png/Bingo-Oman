(function(){
  'use strict';
  if(window.__bingoCustomerCheckoutFixLoaded)return;
  window.__bingoCustomerCheckoutFixLoaded=true;

  function lang(){return localStorage.getItem('bingo_delivery_lang')==='en'?'en':'ar';}
  function t(ar,en){return lang()==='ar'?ar:en;}

  function buildField(labelText,control){
    const wrap=document.createElement('label');
    wrap.className='bd-checkout-field';
    const title=document.createElement('span');
    title.className='bd-checkout-label';
    title.textContent=labelText;
    wrap.appendChild(title);
    wrap.appendChild(control);
    return wrap;
  }

  function ensureStyles(){
    if(document.getElementById('bingo-checkout-fix-style'))return;
    const s=document.createElement('style');
    s.id='bingo-checkout-fix-style';
    s.textContent='.bd-checkout-field{display:grid;gap:8px;margin:12px 0}.bd-checkout-label{font-weight:800;color:#122c4d}.bd-checkout-field input,.bd-checkout-field select{width:100%;min-height:46px;border:1px solid #d6dee9;border-radius:12px;padding:10px 12px;background:#fff;color:#10243f}.bd-checkout-location-row{display:flex;gap:10px;align-items:center;flex-wrap:wrap}.bd-gps-status{font-size:12px;color:#63758a}.bd-gps-status.ok{color:#187845;font-weight:700}.bd-gps-status.warn{color:#a85a00}.bd-checkout-fields-box{padding:14px;border:1px solid #e2e8f0;border-radius:16px;background:#f9fbfd;margin-bottom:14px}';
    document.head.appendChild(s);
  }

  function saveCoords(form,pos,status){
    let lat=document.getElementById('delivery-lat');
    let lng=document.getElementById('delivery-lng');
    if(!lat){lat=document.createElement('input');lat.type='hidden';lat.id='delivery-lat';form.appendChild(lat);}
    if(!lng){lng=document.createElement('input');lng.type='hidden';lng.id='delivery-lng';form.appendChild(lng);}
    lat.value=String(pos.coords.latitude);
    lng.value=String(pos.coords.longitude);
    status.className='bd-gps-status ok';
    const accuracy=Math.round(Number(pos.coords.accuracy||0));
    status.textContent=t('✅ تم حفظ موقعك'+(accuracy?' — دقة تقريبية '+accuracy+' م':''),'✅ Location saved'+(accuracy?' — approx. accuracy '+accuracy+' m':''));
  }

  function friendlyGeoError(err,status){
    status.className='bd-gps-status warn';
    if(err?.code===1){
      status.textContent=t('تعذر استخدام GPS لأن إذن الموقع غير متاح. يمكنك متابعة الطلب بكتابة العنوان يدويًا.','Location permission is unavailable. You can continue using the typed address.');
    }else if(err?.code===2){
      status.textContent=t('تعذر تحديد الموقع من الجهاز الآن. يمكنك متابعة الطلب بالعنوان اليدوي.','Your device could not determine a location. You can continue with the typed address.');
    }else{
      status.textContent=t('استغرق تحديد الموقع وقتًا طويلًا. يمكنك متابعة الطلب بالعنوان اليدوي أو المحاولة مرة أخرى.','Location took too long. You can continue with the typed address or try again.');
    }
  }

  function requestLocation(form,status){
    if(!navigator.geolocation){
      status.className='bd-gps-status warn';
      status.textContent=t('GPS غير مدعوم في هذا المتصفح. استخدم العنوان اليدوي.','GPS is not supported in this browser. Use the typed address.');
      return;
    }
    status.className='bd-gps-status';
    status.textContent=t('جاري تحديد موقع تقريبي...','Getting an approximate location...');

    navigator.geolocation.getCurrentPosition(
      pos=>{
        saveCoords(form,pos,status);
        navigator.geolocation.getCurrentPosition(
          better=>saveCoords(form,better,status),
          ()=>{},
          {enableHighAccuracy:true,timeout:20000,maximumAge:60000}
        );
      },
      firstErr=>{
        status.textContent=t('تعذر الموقع السريع، جاري محاولة ثانية...','Quick location failed, trying again...');
        navigator.geolocation.getCurrentPosition(
          pos=>saveCoords(form,pos,status),
          err=>friendlyGeoError(err||firstErr,status),
          {enableHighAccuracy:false,timeout:25000,maximumAge:300000}
        );
      },
      {enableHighAccuracy:false,timeout:10000,maximumAge:300000}
    );
  }

  function ensureCheckout(){
    const form=document.querySelector('.bd-form');
    if(!form)return;
    ensureStyles();

    let box=document.getElementById('bd-checkout-fields-box');
    if(!box){
      box=document.createElement('div');
      box.id='bd-checkout-fields-box';
      box.className='bd-checkout-fields-box';
      form.prepend(box);
    }

    let address=document.getElementById('delivery-address');
    if(!address){
      address=document.createElement('input');
      address.id='delivery-address';
      address.type='text';
      address.autocomplete='street-address';
    }
    address.placeholder=t('اكتب عنوان التوصيل بالتفصيل','Enter your delivery address');

    let locationBtn=document.getElementById('use-location');
    if(!locationBtn){
      locationBtn=document.createElement('button');
      locationBtn.id='use-location';
      locationBtn.type='button';
      locationBtn.className='bd-btn ghost';
      locationBtn.setAttribute('data-delivery-action','use-location');
    }
    locationBtn.textContent=t('📍 استخدام موقعي الحالي','📍 Use my current location');

    let option=document.getElementById('delivery-option');
    if(!option){
      option=document.createElement('select');
      option.id='delivery-option';
      option.innerHTML='<option value="1.500" selected>Standard Delivery · 1.500 OMR</option><option value="2.000">Express Delivery · 2.000 OMR</option>';
    }

    const oldStatus=document.getElementById('bd-gps-status');
    const previousStatus=oldStatus?.textContent||'';
    const hadSavedLocation=Boolean(document.getElementById('delivery-lat')?.value&&document.getElementById('delivery-lng')?.value);

    box.innerHTML='';
    box.appendChild(buildField(t('عنوان التوصيل','Delivery address'),address));

    const locationWrap=document.createElement('div');
    locationWrap.className='bd-checkout-field';
    const locationTitle=document.createElement('span');
    locationTitle.className='bd-checkout-label';
    locationTitle.textContent=t('الموقع','Location');
    const row=document.createElement('div');
    row.className='bd-checkout-location-row';
    const status=document.createElement('span');
    status.id='bd-gps-status';
    status.className='bd-gps-status'+(hadSavedLocation?' ok':'');
    status.textContent=hadSavedLocation?t('✅ تم حفظ موقعك','✅ Location saved'):(previousStatus||t('الموقع اختياري — يمكنك إدخال العنوان فقط','Location is optional — you can use the typed address only'));
    row.append(locationBtn,status);
    locationWrap.append(locationTitle,row);
    box.appendChild(locationWrap);
    box.appendChild(buildField(t('خيار التوصيل','Delivery option'),option));

    locationBtn.onclick=()=>requestLocation(form,status);
  }

  function init(){ensureCheckout();setTimeout(ensureCheckout,500);setTimeout(ensureCheckout,1800);window.addEventListener('bingo:language',()=>setTimeout(ensureCheckout,0));}
  if(document.readyState==='loading')document.addEventListener('DOMContentLoaded',init,{once:true});else init();
})();