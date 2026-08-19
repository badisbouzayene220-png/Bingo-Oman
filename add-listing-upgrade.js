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
  const step1=document.createElement('section');step1.className='bingo-wizard-step';step1.dataset.wstep='0';step1.innerHTML='<h3>'+txt('Add photos','أضف الصور')+'</h3><p class="bingo-step-lead">'+txt('Start with clear photos. The first image becomes the cover.','ابدأ بصور واضحة، وستكون الصورة الأولى هي صورة الغلاف.')+'</p>';step1.append(upload,previews);
  const step2=document.createElement('section');step2.className='bingo-wizard-step';step2.dataset.wstep='1';step2.innerHTML='<h3>'+txt('Basic information','المعلومات الأساسية')+'</h3><p class="bingo-step-lead">'+txt('Tell buyers what you are offering and the price.','أخبر المشترين بما تعرضه والسعر.')+'</p>';step2.append(basic,desc);
  const step3=document.createElement('section');step3.className='bingo-wizard-step';step3.dataset.wstep='2';step3.innerHTML='<h3>'+txt('Details & location','التفاصيل والموقع')+'</h3><p class="bingo-step-lead">'+txt('Add useful specifications and the item location.','أضف المواصفات المفيدة وموقع السلعة.')+'</p>';step3.append(details);
  const step4=document.createElement('section');step4.className='bingo-wizard-step';step4.dataset.wstep='3';step4.innerHTML='<h3>'+txt('Review & publish','راجع وانشر')+'</h3><p class="bingo-step-lead">'+txt('Check the most important information before sending it for review.','راجع أهم المعلومات قبل إرسال الإعلان للمراجعة.')+'</p><div id="bingoListingReview" class="bingo-review"></div>';actions.classList.add('bingo-original-actions');step4.append(actions,message);
  form.append(step1,step2,step3,step4);
  const nav=document.createElement('div');nav.className='bingo-wizard-nav';nav.innerHTML='<button type="button" class="btn outline bingo-back">'+txt('Back','رجوع')+'</button><button type="button" class="btn primary bingo-next">'+txt('Next','التالي')+'</button>';form.append(nav);
  let step=0;const max=3;const back=nav.querySelector('.bingo-back'),next=nav.querySelector('.bingo-next');
  function validStep(){
    if(step===0){const f=window.files;if(Array.isArray(f)&&f.length)return true;const previews=document.querySelectorAll('#previewGrid .preview');if(previews.length)return true;alert(txt('Please add at least one photo.','أضف صورة واحدة على الأقل.'));return false}
    if(step===1){const req=[...step2.querySelectorAll('[required]')];for(const el of req){if(!el.checkValidity()){el.reportValidity();el.focus();return false}}}
    return true
  }
  function buildReview(){const r=document.getElementById('bingoListingReview');if(!r)return;const val=id=>document.getElementById(id)?.value?.trim()||'—';const category=document.getElementById('category');const categoryText=category?.selectedOptions?.[0]?.textContent||'—';const city=val('city');r.innerHTML='<div class="bingo-review-card"><small>'+txt('Title','العنوان')+'</small><strong>'+escapeHtml(val('title'))+'</strong></div><div class="bingo-review-card"><small>'+txt('Category / City','التصنيف / المدينة')+'</small><strong>'+escapeHtml(categoryText)+' · '+escapeHtml(city)+'</strong></div><div class="bingo-review-card"><small>'+txt('Price','السعر')+'</small><strong>'+escapeHtml(val('price'))+' OMR</strong></div><div class="bingo-review-card"><small>'+txt('Description','الوصف')+'</small><strong>'+escapeHtml(val('description')).slice(0,220)+'</strong></div><div class="bingo-review-card"><small>'+txt('Photos','الصور')+'</small><div class="bingo-review-images">'+[...document.querySelectorAll('#previewGrid img')].map(x=>'<img src="'+x.src+'" alt="">').join('')+'</div></div>'}
  function escapeHtml(s){return String(s).replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]))}
  function show(n){step=Math.max(0,Math.min(max,n));document.querySelectorAll('.bingo-wizard-step').forEach((el,i)=>el.classList.toggle('active',i===step));document.querySelectorAll('.bingo-listing-step-dot').forEach((el,i)=>{el.classList.toggle('active',i===step);el.classList.toggle('done',i<step)});back.hidden=step===0;next.hidden=step===max;if(step===max)buildReview();head.scrollIntoView({behavior:'smooth',block:'start'})}
  back.addEventListener('click',()=>show(step-1));next.addEventListener('click',()=>{if(validStep())show(step+1)});document.querySelectorAll('.bingo-listing-step-dot').forEach((el,i)=>el.addEventListener('click',()=>{if(i<step||validStep())show(i)}));
  const submit=document.getElementById('submitBtn');submit?.addEventListener('click',e=>{if(step!==max){e.preventDefault();show(max)}});
  show(0);
}
if(document.readyState==='loading')document.addEventListener('DOMContentLoaded',init,{once:true});else init();
})();