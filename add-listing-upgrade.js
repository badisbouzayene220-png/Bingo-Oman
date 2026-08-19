(function(){
'use strict';
const page=(location.pathname.split('/').pop()||'').toLowerCase();if(page!=='add-listing.html')return;
function ar(){return (document.documentElement.lang||'').toLowerCase().startsWith('ar')||document.documentElement.dir==='rtl'}
function txt(en,aa){return ar()?aa:en}
function init(){
  const form=document.getElementById('listingForm');if(!form||form.dataset.wizard==='1')return;form.dataset.wizard='1';document.body.classList.add('bingo-add-upgraded');
  const title=form.querySelector('h2');const basic=form.querySelector('.form-grid');const desc=[...form.children].find(x=>x.tagName==='LABEL'&&x.querySelector('#description'));const upload=document.getElementById('dropzone');const previews=document.getElementById('previewGrid');const details=form.querySelector('.form-section');const actions=form.querySelector('.form-actions');const message=document.getElementById('message');if(!basic||!desc||!upload||!previews||!details||!actions)return;
  title?.remove();
  const head=document.createElement('div');head.className='bingo-listing-wizard-head';head.innerHTML='<h2>'+txt('Create your listing','أنشئ إعلانك')+'</h2><p>'+txt('Complete four simple steps. You can go back before publishing.','أكمل أربع خطوات بسيطة، ويمكنك الرجوع قبل النشر.')+'</p><div class="bingo-listing-progress">'+[['Photos','الصور'],['Details','المعلومات'],['Location','التفاصيل والموقع'],['Review','المراجعة']].map((v,i)=>'<div class="bingo-listing-step-dot" data-wstepdot="'+i+'"><b>'+(i+1)+'</b>'+(ar()?v[1]:v[0])+'</div>').join('')+'</div>';
  form.prepend(head);

  /* Cars-specific fields. They live inside attributes JSON, so no DB migration is needed. */
  const carPanel=document.createElement('section');
  carPanel.id='bingoCarDetails';
  carPanel.className='bingo-category-panel';
  carPanel.hidden=true;
  carPanel.innerHTML=`
    <div class="bingo-category-panel-head">
      <div><span>🚗</span><div><h4>${txt('Vehicle details','تفاصيل السيارة')}</h4><p>${txt('These details help buyers find the right car faster.','هذه التفاصيل تساعد المشتري على إيجاد السيارة المناسبة بسرعة.')}</p></div></div>
    </div>
    <div class="bingo-car-grid">
      <label>${txt('Mileage (km)','عدد الكيلومترات')}
        <input id="carMileage" type="number" min="0" step="1" inputmode="numeric" placeholder="85000">
      </label>
      <label>${txt('Transmission','ناقل الحركة')}
        <select id="carTransmission"><option value="">${txt('Select transmission','اختر ناقل الحركة')}</option><option value="automatic">${txt('Automatic','أوتوماتيك')}</option><option value="manual">${txt('Manual','عادي')}</option><option value="cvt">CVT</option></select>
      </label>
      <label>${txt('Fuel type','نوع الوقود')}
        <select id="carFuel"><option value="">${txt('Select fuel','اختر الوقود')}</option><option value="petrol">${txt('Petrol','بنزين')}</option><option value="diesel">${txt('Diesel','ديزل')}</option><option value="hybrid">${txt('Hybrid','هايبرد')}</option><option value="electric">${txt('Electric','كهربائي')}</option></select>
      </label>
      <label>${txt('Insurance','نوع التأمين')}
        <select id="carInsurance"><option value="">${txt('Select insurance','اختر نوع التأمين')}</option><option value="comprehensive">${txt('Comprehensive','شامل')}</option><option value="third_party">${txt('Third party','طرف ثالث')}</option><option value="expired">${txt('Expired / No insurance','منتهي / بدون تأمين')}</option></select>
      </label>
      <label>${txt('Insurance expiry','انتهاء التأمين')}
        <input id="carInsuranceExpiry" type="date">
      </label>
      <label>${txt('Body type','نوع الهيكل')}
        <select id="carBodyType"><option value="">${txt('Select body type','اختر نوع الهيكل')}</option><option value="sedan">${txt('Sedan','سيدان')}</option><option value="suv">SUV</option><option value="hatchback">${txt('Hatchback','هاتشباك')}</option><option value="pickup">${txt('Pickup','بيك أب')}</option><option value="coupe">${txt('Coupe','كوبيه')}</option><option value="van">${txt('Van','فان')}</option></select>
      </label>
    </div>
    <div class="bingo-car-color-block">
      <strong>${txt('Vehicle color','لون السيارة')}</strong>
      <p>${txt('Choose the closest color.','اختر اللون الأقرب للسيارة.')}</p>
      <div class="bingo-color-palette" id="carColorPalette">
        ${[
          ['White','أبيض','#ffffff'],['Black','أسود','#111111'],['Silver','فضي','#c8ccd2'],['Gray','رمادي','#737982'],['Red','أحمر','#c9242f'],['Blue','أزرق','#185db5'],['Green','أخضر','#26734d'],['Brown','بني','#79523b'],['Beige','بيج','#d8c4a5'],['Gold','ذهبي','#c69a3b'],['Orange','برتقالي','#ef741c'],['Yellow','أصفر','#e5c324']
        ].map((c,i)=>`<label class="bingo-color-choice" title="${ar()?c[1]:c[0]}"><input type="radio" name="carColor" value="${c[0]}" data-hex="${c[2]}"><span style="--swatch:${c[2]}"></span><small>${ar()?c[1]:c[0]}</small></label>`).join('')}
      </div>
      <label class="bingo-custom-color">${txt('Other color','لون آخر')}<input id="carColorOther" maxlength="40" placeholder="${txt('e.g. Pearl White','مثال: أبيض لؤلؤي')}"></label>
    </div>`;
  details.appendChild(carPanel);

  const category=document.getElementById('category');
  function isCars(){const opt=category?.selectedOptions?.[0];const slug=(opt?.dataset?.slug||'').toLowerCase();const label=(opt?.textContent||'').toLowerCase();return slug==='cars'||label.includes('cars')||label.includes('السيارات')}
  function toggleCarPanel(){const yes=isCars();carPanel.hidden=!yes;document.body.classList.toggle('bingo-category-cars',yes);if(yes){const brand=document.getElementById('brand')?.closest('div');const model=document.getElementById('model')?.closest('div');const year=document.getElementById('year')?.closest('div');if(brand?.querySelector('label'))brand.querySelector('label').textContent=txt('Make / Brand','نوع / ماركة السيارة');if(model?.querySelector('label'))model.querySelector('label').textContent=txt('Model','الموديل');if(year?.querySelector('label'))year.querySelector('label').textContent=txt('Year of manufacture','سنة الصنع')}}
  category?.addEventListener('change',toggleCarPanel);
  /* Categories load asynchronously; observe only this select, not the page. */
  if(category)new MutationObserver(()=>toggleCarPanel()).observe(category,{childList:true});

  const step1=document.createElement('section');step1.className='bingo-wizard-step';step1.dataset.wstep='0';step1.innerHTML='<h3>'+txt('Add photos','أضف الصور')+'</h3><p class="bingo-step-lead">'+txt('Start with clear photos. The first image becomes the cover.','ابدأ بصور واضحة، وستكون الصورة الأولى هي صورة الغلاف.')+'</p>';step1.append(upload,previews);
  const step2=document.createElement('section');step2.className='bingo-wizard-step';step2.dataset.wstep='1';step2.innerHTML='<h3>'+txt('Basic information','المعلومات الأساسية')+'</h3><p class="bingo-step-lead">'+txt('Tell buyers what you are offering and the price.','أخبر المشترين بما تعرضه والسعر.')+'</p>';step2.append(basic,desc);
  const step3=document.createElement('section');step3.className='bingo-wizard-step';step3.dataset.wstep='2';step3.innerHTML='<h3>'+txt('Details & location','التفاصيل والموقع')+'</h3><p class="bingo-step-lead">'+txt('Add useful specifications and the item location.','أضف المواصفات المفيدة وموقع السلعة.')+'</p>';step3.append(details);
  const step4=document.createElement('section');step4.className='bingo-wizard-step';step4.dataset.wstep='3';step4.innerHTML='<h3>'+txt('Review & publish','راجع وانشر')+'</h3><p class="bingo-step-lead">'+txt('Check the most important information before sending it for review.','راجع أهم المعلومات قبل إرسال الإعلان للمراجعة.')+'</p><div id="bingoListingReview" class="bingo-review"></div>';actions.classList.add('bingo-original-actions');step4.append(actions,message);
  form.append(step1,step2,step3,step4);
  const nav=document.createElement('div');nav.className='bingo-wizard-nav';nav.innerHTML='<button type="button" class="btn outline bingo-back">'+txt('Back','رجوع')+'</button><button type="button" class="btn primary bingo-next">'+txt('Next','التالي')+'</button>';form.append(nav);
  let step=0;const max=3;const back=nav.querySelector('.bingo-back'),next=nav.querySelector('.bingo-next');
  function validStep(){
    if(step===0){const previews=document.querySelectorAll('#previewGrid .preview');if(previews.length)return true;alert(txt('Please add at least one photo.','أضف صورة واحدة على الأقل.'));return false}
    if(step===1){const req=[...step2.querySelectorAll('[required]')];for(const el of req){if(!el.checkValidity()){el.reportValidity();el.focus();return false}}}
    return true
  }
  function carSummary(){if(!isCars())return'';const val=id=>document.getElementById(id)?.value||'';const selected=document.querySelector('input[name="carColor"]:checked');const color=val('carColorOther')||selected?.value||'';const parts=[val('carMileage')?Number(val('carMileage')).toLocaleString()+' km':'',val('carTransmission'),val('carFuel'),val('carInsurance'),color].filter(Boolean);return parts.join(' · ')}
  function buildReview(){const r=document.getElementById('bingoListingReview');if(!r)return;const val=id=>document.getElementById(id)?.value?.trim()||'—';const categoryText=category?.selectedOptions?.[0]?.textContent||'—';const city=val('city');r.innerHTML='<div class="bingo-review-card"><small>'+txt('Title','العنوان')+'</small><strong>'+escapeHtml(val('title'))+'</strong></div><div class="bingo-review-card"><small>'+txt('Category / City','التصنيف / المدينة')+'</small><strong>'+escapeHtml(categoryText)+' · '+escapeHtml(city)+'</strong></div><div class="bingo-review-card"><small>'+txt('Price','السعر')+'</small><strong>'+escapeHtml(val('price'))+' OMR</strong></div>'+(isCars()?'<div class="bingo-review-card"><small>'+txt('Vehicle','السيارة')+'</small><strong>'+escapeHtml([val('brand'),val('model'),val('year'),carSummary()].filter(x=>x&&x!=='—').join(' · '))+'</strong></div>':'')+'<div class="bingo-review-card"><small>'+txt('Description','الوصف')+'</small><strong>'+escapeHtml(val('description')).slice(0,220)+'</strong></div><div class="bingo-review-card"><small>'+txt('Photos','الصور')+'</small><div class="bingo-review-images">'+[...document.querySelectorAll('#previewGrid img')].map(x=>'<img src="'+x.src+'" alt="">').join('')+'</div></div>'}
  function escapeHtml(s){return String(s).replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]))}
  function show(n){step=Math.max(0,Math.min(max,n));document.querySelectorAll('.bingo-wizard-step').forEach((el,i)=>el.classList.toggle('active',i===step));document.querySelectorAll('.bingo-listing-step-dot').forEach((el,i)=>{el.classList.toggle('active',i===step);el.classList.toggle('done',i<step)});back.hidden=step===0;next.hidden=step===max;if(step===max)buildReview();head.scrollIntoView({behavior:'smooth',block:'start'})}
  back.addEventListener('click',()=>show(step-1));next.addEventListener('click',()=>{if(validStep())show(step+1)});document.querySelectorAll('.bingo-listing-step-dot').forEach((el,i)=>el.addEventListener('click',()=>{if(i<step||validStep())show(i)}));

  /* Replace the original submit handler so category-specific attributes are stored as structured JSON. */
  form.onsubmit=async e=>{e.preventDefault();const user=await requireUser();if(!user)return;if(!files.length){msg(txt('Please add at least one photo.','أضف صورة واحدة على الأقل.'),'error');show(0);return}const btn=document.getElementById('submitBtn');btn.disabled=true;btn.textContent=txt('Publishing…','جارٍ النشر…');msg('');
    try{
      const selectedColor=document.querySelector('input[name="carColor"]:checked');
      const attributes={brand:document.getElementById('brand').value.trim(),make:document.getElementById('brand').value.trim(),model:document.getElementById('model').value.trim(),year:Number(document.getElementById('year').value)||null,details:document.getElementById('extraDetails').value.trim()};
      if(isCars())Object.assign(attributes,{vehicle_type:'car',mileage_km:Number(document.getElementById('carMileage').value)||null,transmission:document.getElementById('carTransmission').value||null,fuel_type:document.getElementById('carFuel').value||null,insurance_type:document.getElementById('carInsurance').value||null,insurance_expiry:document.getElementById('carInsuranceExpiry').value||null,body_type:document.getElementById('carBodyType').value||null,color:document.getElementById('carColorOther').value.trim()||selectedColor?.value||null,color_hex:document.getElementById('carColorOther').value.trim()?null:(selectedColor?.dataset?.hex||null)});
      const payload={user_id:user.id,category_id:document.getElementById('category').value,title:document.getElementById('title').value.trim(),description:document.getElementById('description').value.trim(),price:Number(document.getElementById('price').value),city:document.getElementById('city').value,condition:document.getElementById('condition').value||null,status:'pending',attributes,latitude:Number(document.getElementById('latitude').value)||null,longitude:Number(document.getElementById('longitude').value)||null};
      const {data:listing,error:le}=await sb.from('listings').insert(payload).select('id').single();if(le)throw le;
      for(let i=0;i<files.length;i++){const f=files[i],ext=f.name.split('.').pop().toLowerCase(),path=`${user.id}/${listing.id}/${crypto.randomUUID()}.${ext}`;const {error:ue}=await sb.storage.from('listing-images').upload(path,f,{contentType:f.type,upsert:false});if(ue)throw ue;const {data:pub}=sb.storage.from('listing-images').getPublicUrl(path);const {error:ie}=await sb.from('listing_images').insert({listing_id:listing.id,image_url:pub.publicUrl,sort_order:i});if(ie)throw ie}
      msg(txt('Your listing was submitted for review.','تم إرسال إعلانك للمراجعة.'),'success');setTimeout(()=>location.href='dashboard.html#myListings',700);
    }catch(err){console.error(err);msg(err.message||txt('Could not create listing.','تعذر إنشاء الإعلان.'),'error');btn.disabled=false;btn.textContent=txt('Publish listing','نشر الإعلان')}
  };
  const submit=document.getElementById('submitBtn');submit?.addEventListener('click',e=>{if(step!==max){e.preventDefault();show(max)}});
  toggleCarPanel();show(0);
}
if(document.readyState==='loading')document.addEventListener('DOMContentLoaded',init,{once:true});else init();
})();