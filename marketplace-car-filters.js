(function(){
'use strict';
const page=(location.pathname.split('/').pop()||'').toLowerCase();if(page!=='marketplace.html')return;
function $(id){return document.getElementById(id)}
function esc(s){return String(s??'').replace(/[&<>'"]/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;',"'":'&#39;','"':'&quot;'}[c]))}
function isCarsSelected(){const sel=$('cat');if(!sel)return false;const opt=sel.selectedOptions?.[0];return /cars|السيارات/i.test(opt?.textContent||'')}
function num(id){const v=Number($(id)?.value);return Number.isFinite(v)&&v!==0?v:null}
function str(id){return ($(id)?.value||'').trim().toLowerCase()}
function makeOptions(){const cars=window.BINGO_CARS||{};return '<option value="">Any make / كل الشركات</option>'+Object.keys(cars).sort((a,b)=>a.localeCompare(b)).map(x=>`<option value="${esc(x)}">${esc(x)}</option>`).join('')}
function modelOptions(make){const list=window.BINGO_CARS?.[make]||[];return '<option value="">Any model / كل الموديلات</option>'+list.map(x=>`<option value="${esc(x)}">${esc(x)}</option>`).join('')}
function mount(){
 const extra=$('extra');if(!extra||document.getElementById('carAdvancedFilters')||!window.BINGO_CARS)return false;
 const panel=document.createElement('div');panel.id='carAdvancedFilters';panel.className='car-advanced';panel.innerHTML=`
 <div class="car-filter-head"><div><h3>🚗 Choose your car</h3><small>Select make and model — no typing needed</small></div><button type="button" class="car-filter-reset" id="carFilterReset">Reset car filters</button></div>
 <div class="car-filter-grid">
  <label>Brand / Make<select id="carBrand">${makeOptions()}</select></label>
  <label>Model<select id="carModel" disabled><option value="">Choose make first</option></select></label>
  <label>Year from<input id="carYearFrom" type="number" min="1950" max="2100" placeholder="2018"></label>
  <label>Year to<input id="carYearTo" type="number" min="1950" max="2100" placeholder="2026"></label>
  <label>Min mileage (km)<input id="carKmMin" type="number" min="0" step="1000" placeholder="0"></label>
  <label>Max mileage (km)<input id="carKmMax" type="number" min="0" step="1000" placeholder="100000"></label>
  <label>Transmission<select id="carTransmission"><option value="">Any</option><option>Automatic</option><option>Manual</option><option>CVT</option></select></label>
  <label>Fuel<select id="carFuel"><option value="">Any</option><option>Petrol</option><option>Diesel</option><option>Hybrid</option><option>Electric</option></select></label>
  <label>Insurance<select id="carInsurance"><option value="">Any</option><option>Comprehensive</option><option>Third Party</option><option>Expired</option><option>No insurance</option></select></label>
  <label>Body type<select id="carBody"><option value="">Any</option><option>SUV</option><option>Sedan</option><option>Hatchback</option><option>Coupe</option><option>Pickup</option><option>Van</option><option>Wagon</option></select></label>
  <label class="car-color-filter">Color<div class="car-color-palette" id="carColorPalette"></div><input id="carColor" type="hidden"></label>
 </div>`;
 extra.insertAdjacentElement('afterend',panel);
 const colors=[['White','#f4f4f4'],['Black','#111'],['Silver','#c0c0c0'],['Gray','#777'],['Red','#d62828'],['Blue','#1d4ed8'],['Green','#16803a'],['Brown','#7c4a2d'],['Beige','#d8c3a5'],['Gold','#c9a227'],['Orange','#f97316'],['Yellow','#eab308']];
 $('carColorPalette').innerHTML=colors.map(([n,c])=>`<button type="button" class="car-color-dot" title="${n}" data-color="${n}" style="background:${c}"></button>`).join('');
 $('carColorPalette').addEventListener('click',e=>{const b=e.target.closest('.car-color-dot');if(!b)return;const current=$('carColor').value;const next=current===b.dataset.color?'':b.dataset.color;$('carColor').value=next;document.querySelectorAll('.car-color-dot').forEach(x=>x.classList.toggle('active',x.dataset.color===next));window.render?.()});
 $('carBrand').addEventListener('change',()=>{const make=$('carBrand').value;$('carModel').innerHTML=modelOptions(make);$('carModel').disabled=!make;window.render?.()});
 ['carModel','carYearFrom','carYearTo','carKmMin','carKmMax','carTransmission','carFuel','carInsurance','carBody'].forEach(id=>$(id)?.addEventListener('change',()=>window.render?.()));
 $('carFilterReset').onclick=()=>{['carBrand','carYearFrom','carYearTo','carKmMin','carKmMax','carTransmission','carFuel','carInsurance','carBody','carColor'].forEach(id=>{if($(id))$(id).value=''});$('carModel').innerHTML='<option value="">Choose make first</option>';$('carModel').disabled=true;document.querySelectorAll('.car-color-dot').forEach(x=>x.classList.remove('active'));window.render?.()};
 const cat=$('cat');cat.addEventListener('change',togglePanel);togglePanel();return true;
}
function togglePanel(){const car=isCarsSelected();$('carAdvancedFilters')?.classList.toggle('show',car);$('extra')?.classList.toggle('show',!car && !!$('cat')?.value)}
function installRenderOverride(){
 if(typeof window.render!=='function' || window.__bingoCarRenderInstalled)return;window.__bingoCarRenderInstalled=true;
 window.render=function(){
  const q=$('search').value.trim().toLowerCase(),cat=$('cat').value,city=$('city').value,cond=$('condition').value,brand=$('brand').value.trim().toLowerCase(),model=$('model').value.trim().toLowerCase(),year=Number($('year').value)||null,min=Number($('minPrice').value),max=Number($('maxPrice').value),sort=$('sort').value;
  const cars=isCarsSelected();const cBrand=str('carBrand'),cModel=str('carModel'),y1=num('carYearFrom'),y2=num('carYearTo'),km1=num('carKmMin'),km2=num('carKmMax'),trans=str('carTransmission'),fuel=str('carFuel'),ins=str('carInsurance'),body=str('carBody'),color=str('carColor');
  let d=allListings.map(x=>{const a=attrs(x),text=Object.values(a).join(' ').toLowerCase();return {...x,_a:a,_text:text,_dist:(myLat!=null&&x.latitude!=null)?km(myLat,myLng,Number(x.latitude),Number(x.longitude)):Infinity}})
  .filter(x=>{const a=x._a||{};const base=(!q||`${x.title} ${x.description||''} ${x._text}`.toLowerCase().includes(q))&&(!cat||x.category_id===cat)&&(!city||x.city===city)&&(!cond||x.condition===cond)&&(!brand||String(a.brand||a.make||'').toLowerCase().includes(brand))&&(!model||String(a.model||'').toLowerCase().includes(model))&&(!year||Number(a.year)===year)&&(!min||Number(x.price)>=min)&&(!max||Number(x.price)<=max);if(!base)return false;if(!cars)return true;const ay=Number(a.year)||0,akm=Number(a.mileage_km??a.mileage??0)||0;return (!cBrand||String(a.brand||a.make||'').toLowerCase()===cBrand)&&(!cModel||String(a.model||'').toLowerCase()===cModel)&&(!y1||ay>=y1)&&(!y2||ay<=y2)&&(!km1||akm>=km1)&&(!km2||akm<=km2)&&(!trans||String(a.transmission||'').toLowerCase()===trans)&&(!fuel||String(a.fuel||a.fuel_type||'').toLowerCase()===fuel)&&(!ins||String(a.insurance||a.insurance_type||'').toLowerCase()===ins)&&(!body||String(a.body_type||a.body||'').toLowerCase()===body)&&(!color||String(a.color||a.exterior_color||'').toLowerCase()===color)});
  if(sort==='price_low')d.sort((a,b)=>a.price-b.price);else if(sort==='price_high')d.sort((a,b)=>b.price-a.price);else if(sort==='near')d.sort((a,b)=>a._dist-b._dist);
  $('status').textContent=`${d.length} listings`;if(myLat!=null)$('locationStatus').textContent='Showing results with location data where available';
  $('listings').innerHTML=d.map(x=>{const imgs=(x.listing_images||[]).sort((a,b)=>a.sort_order-b.sort_order),img=imgs[0]?.image_url,cc=categories.find(c=>c.id===x.category_id),distance=Number.isFinite(x._dist)?`${x._dist.toFixed(1)} km away`:'';const a=x._a||{};const car=/cars|السيارات/i.test((cc?.name_en||'')+' '+(cc?.name_ar||''));const specs=car?`<div class="car-specs">${a.brand||a.make?`<span>🚘 ${esc(a.brand||a.make)}</span>`:''}${a.model?`<span>${esc(a.model)}</span>`:''}${a.year?`<span>📅 ${esc(a.year)}</span>`:''}${a.mileage_km||a.mileage?`<span>🛣️ ${Number(a.mileage_km||a.mileage).toLocaleString()} km</span>`:''}</div>`:'';return `<article class="card listing-card ${car?'car-card':''}"><a class="thumb ${img?'has-image':''}" href="listing.html?id=${x.id}"><span class="tag">${esc(cc?.name_en||'Other')}</span>${img?`<img src="${esc(img)}" alt="" loading="lazy" decoding="async">`:'<span class="empty-thumb">📦</span>'}</a><div class="cardbody"><h3>${esc(x.title)}</h3><div class="price">${Number(x.price||0).toLocaleString('en-OM',{minimumFractionDigits:3})} OMR</div>${specs}<div class="meta"><span>📍 ${esc(x.city||'Oman')}</span><span>${esc(distance)}</span></div></div></article>`}).join('')||'<div class="empty-state"><h3>No listings found</h3><p>Try another filter or expand the location.</p></div>';
 };
}
function init(){if(!mount()){let tries=0;const t=setInterval(()=>{tries++;if(mount()||tries>50){clearInterval(t);installRenderOverride();togglePanel();window.render?.()}},100);return}installRenderOverride();togglePanel();window.render?.()}
if(document.readyState==='loading')document.addEventListener('DOMContentLoaded',()=>setTimeout(init,0),{once:true});else setTimeout(init,0);
})();