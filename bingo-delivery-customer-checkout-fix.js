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
    s.textContent='.bd-checkout-field{display:grid;gap:8px;margin:12px 0}.bd-checkout-label{font-weight:800;color:#122c4d}.bd-checkout-field input,.bd-checkout-field select{width:100%;min-height:46px;border:1px solid #d6dee9;border-radius:12px;padding:10px 12px;background:#fff;color:#10243f}.bd-checkout-location-row{display:flex;gap:10px;align-items:center;flex-wrap:wrap}.bd-gps-status{font-size:12px;color:#63758a}.bd-checkout-fields-box{padding:14px;border:1px solid #e2e8f0;border-radius:16px;background:#f9fbfd;margin-bottom:14px}';
    document.head.appendChild(s);
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
      address.placeholder=t('اكتب عنوان التوصيل بالتفصيل','Enter your delivery address');
    }

    let locationBtn=document.getElementById('use-location');
    if(!locationBtn){
      locationBtn=document.createElement('button');
      locationBtn.id='use-location';
      locationBtn.type='button';
      locationBtn.className='bd-btn ghost';
      locationBtn.setAttribute('data-delivery-action','use-location');
      locationBtn.textContent=t('📍 استخدام موقعي الحالي','📍 Use my current location');
    }

    let option=document.getElementById('delivery-option');
    if(!option){
      option=document.createElement('select');
      option.id='delivery-option';
      option.innerHTML='<option value="1.500" selected>Standard Delivery · 1.500 OMR</option><option value="2.000">Express Delivery · 2.000 OMR</option>';
      option.addEventListener('change',()=>document.dispatchEvent(new Event('change',{bubbles:true})));
    }

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
    status.className='bd-gps-status';
    status.textContent=t('لم يتم تحديد الموقع بعد','Location not selected yet');
    row.append(locationBtn,status);
    locationWrap.append(locationTitle,row);
    box.appendChild(locationWrap);
    box.appendChild(buildField(t('خيار التوصيل','Delivery option'),option));

    locationBtn.onclick=()=>{
      if(!navigator.geolocation){status.textContent=t('GPS غير مدعوم في هذا المتصفح','GPS is not supported in this browser');return;}
      status.textContent=t('جاري تحديد الموقع...','Getting your location...');
      navigator.geolocation.getCurrentPosition(pos=>{
        let lat=document.getElementById('delivery-lat');
        let lng=document.getElementById('delivery-lng');
        if(!lat){lat=document.createElement('input');lat.type='hidden';lat.id='delivery-lat';form.appendChild(lat);}
        if(!lng){lng=document.createElement('input');lng.type='hidden';lng.id='delivery-lng';form.appendChild(lng);}
        lat.value=String(pos.coords.latitude);
        lng.value=String(pos.coords.longitude);
        status.textContent=t('✅ تم حفظ موقعك','✅ Location saved');
      },err=>{status.textContent=t('تعذر تحديد الموقع: ','Could not get location: ')+(err.message||'');},{enableHighAccuracy:true,timeout:12000,maximumAge:30000});
    };
  }

  function init(){ensureCheckout();setTimeout(ensureCheckout,500);setTimeout(ensureCheckout,1800);window.addEventListener('bingo:language',()=>setTimeout(ensureCheckout,0));}
  if(document.readyState==='loading')document.addEventListener('DOMContentLoaded',init,{once:true});else init();
})();