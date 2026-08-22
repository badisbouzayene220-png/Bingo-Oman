(function(){'use strict';
const page=(location.pathname.split('/').pop()||'').toLowerCase();
if(!['add-listing.html','dashboard.html'].includes(page))return;
let quota={free_limit:3,active_count:0,free_remaining:3,paid_credits:0,requires_payment:false};
const esc=s=>String(s??'').replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
function ar(){return (document.documentElement.lang||'').toLowerCase().startsWith('ar')||document.documentElement.dir==='rtl'}
function t(en,aa){return ar()?aa:en}
async function getQuota(){
  try{
    if(!window.sb)return quota;
    const {data,error}=await sb.rpc('get_my_listing_quota');
    if(!error&&Array.isArray(data)&&data[0]){quota={...quota,...data[0]};return quota}
    if(!error&&data&&typeof data==='object'&&!Array.isArray(data)){quota={...quota,...data};return quota}
    // Safe UI fallback before migration is installed.
    const u=await window.BingoAuth?.getUser?.();if(!u)return quota;
    const {count}=await sb.from('listings').select('id',{count:'exact',head:true}).eq('user_id',u.id).in('status',['draft','pending','published']);
    const n=Number(count||0);quota={free_limit:3,active_count:n,free_remaining:Math.max(3-n,0),paid_credits:0,requires_payment:n>=3};
  }catch(e){console.warn('Listing quota:',e)}
  return quota;
}
function cardHTML(){const used=Math.min(Number(quota.active_count||0),Number(quota.free_limit||3)),limit=Number(quota.free_limit||3),pct=Math.min(100,used/limit*100),paid=Number(quota.paid_credits||0);return `<div class="bingo-quota-card ${quota.requires_payment?'limit':''}" id="bingoQuotaCard"><div class="bingo-quota-main"><span class="bingo-quota-icon">${quota.requires_payment?'🔒':'🎁'}</span><div><strong>${quota.requires_payment?t('Free listings used','تم استخدام الإعلانات المجانية'):t('Your free listings','إعلاناتك المجانية')}</strong><small>${quota.requires_payment?(paid?t('You have a paid listing credit ready.','لديك رصيد إعلان مدفوع جاهز.'):t('Your next active listing requires payment.','إعلانك النشط التالي يحتاج إلى الدفع.')):t(`${quota.free_remaining} free slot${Number(quota.free_remaining)===1?'':'s'} remaining`,`متبقي ${quota.free_remaining} إعلان مجاني`)}</small></div></div><div class="bingo-quota-meter"><div class="bingo-quota-count">${used} / ${limit} FREE</div><div class="bingo-quota-bar"><i style="width:${pct}%"></i></div></div></div>`}
function gateHTML(){return `<div class="bingo-paid-gate ${quota.requires_payment?'show':''}" id="bingoPaidGate"><h3>💳 ${t('Paid listing required','الإعلان التالي مدفوع')}</h3><p>${t('Every account includes 3 active listings for free. To publish an additional active listing, continue to the paid listing step.','كل حساب يتضمن 3 إعلانات نشطة مجانًا. لنشر إعلان نشط إضافي، انتقل إلى خطوة الإعلان المدفوع.')}</p><button type="button" class="btn primary" id="bingoPaidListingBtn">${t('Continue to paid listing','متابعة إلى الإعلان المدفوع')}</button></div>`}
function mountAdd(){const form=document.getElementById('listingForm');if(!form||document.getElementById('bingoQuotaCard'))return;form.insertAdjacentHTML('afterbegin',cardHTML()+gateHTML());const btn=document.getElementById('bingoPaidListingBtn');if(btn)btn.onclick=()=>{sessionStorage.setItem('bingoPaidListingIntent','1');alert(t('Paid-listing pricing and payment method are the next setup step. Your 3-free-listing limit is already protected.','تحديد سعر الإعلان وطريقة الدفع هو الخطوة التالية. حد 3 إعلانات مجانية أصبح محميًا بالفعل.'))};
  form.addEventListener('submit',e=>{if(quota.requires_payment&&Number(quota.paid_credits||0)<1){e.preventDefault();e.stopImmediatePropagation();document.getElementById('bingoPaidGate')?.scrollIntoView({behavior:'smooth',block:'center'});alert(t('You have used your 3 free active listings. This listing requires payment.','لقد استخدمت 3 إعلانات نشطة مجانية. هذا الإعلان يحتاج إلى الدفع.'));}},true);
}
function mountDashboard(){const panel=document.querySelector('.dash .panel');if(!panel||document.getElementById('bingoQuotaCard'))return;const welcome=document.getElementById('welcome');if(welcome)welcome.insertAdjacentHTML('afterend',cardHTML());else panel.insertAdjacentHTML('afterbegin',cardHTML())}
async function refresh(){await getQuota();page==='add-listing.html'?mountAdd():mountDashboard()}
if(document.readyState==='loading')document.addEventListener('DOMContentLoaded',()=>setTimeout(refresh,250),{once:true});else setTimeout(refresh,250);
})();
