(function(){
'use strict';
const isHome=(()=>{const p=(location.pathname.split('/').pop()||'').toLowerCase();return !p||p==='index.html';})();
if(!isHome)return;
document.body.classList.add('bingo-home-upgraded');
const ar=(document.documentElement.lang||'').toLowerCase().startsWith('ar')||document.documentElement.dir==='rtl';
const items=[
['🛍️','Marketplace','السوق','marketplace.html'],['🏪','Store','المتجر','store.html'],['🚗','Cars','السيارات','marketplace.html?category=cars'],['🏠','Property','العقارات','marketplace.html?category=real-estate'],['🔨','Auctions','المزادات','auctions.html'],['📋','Tenders','المناقصات','tenders.html'],['🛵','Delivery','التوصيل','delivery/index.html'],['🇴🇲','Discover Oman','اكتشف عُمان','#discover-oman']];
function mountQuick(){if(document.querySelector('.bingo-quick-wrap'))return;const target=document.querySelector('.hero')||document.querySelector('main')||document.body;const sec=document.createElement('section');sec.className='bingo-quick-wrap';sec.setAttribute('aria-label',ar?'وصول سريع':'Quick access');sec.innerHTML='<div class="container"><div class="bingo-quick-head"><div><h2>'+(ar?'كل BINGO بضغطة واحدة':'Everything in BINGO, one tap away')+'</h2><p>'+(ar?'تسوق، بع، اكتشف واطلب من مكان واحد':'Shop, sell, discover and order from one place')+'</p></div></div><div class="bingo-quick-grid">'+items.map(i=>'<a class="bingo-quick-card" href="'+i[3]+'"><span class="bingo-quick-icon">'+i[0]+'</span><strong>'+(ar?i[2]:i[1])+'</strong></a>').join('')+'</div></div>';target.insertAdjacentElement('afterend',sec)}
function mountMobile(){if(document.querySelector('.bingo-mobile-nav'))return;const nav=document.createElement('nav');nav.className='bingo-mobile-nav';nav.setAttribute('aria-label',ar?'التنقل الرئيسي':'Main navigation');const x=(href,icon,en,aa,cls='')=>'<a class="'+cls+'" href="'+href+'"><span>'+icon+'</span>'+(ar?aa:en)+'</a>';nav.innerHTML=x('index.html','⌂','Home','الرئيسية','active')+x('marketplace.html','⌕','Discover','اكتشف')+x('create-listing.html','＋','Add','أضف','bingo-add')+x('messages.html','💬','Messages','الرسائل')+x('account.html','◉','Account','حسابي');document.body.appendChild(nav)}
function anchorDiscover(){const candidates=[...document.querySelectorAll('section,div')];const el=candidates.find(e=>/discover oman|اكتشف عُمان/i.test((e.textContent||'').slice(0,180)));if(el&&!el.id)el.id='discover-oman'}
function init(){anchorDiscover();mountQuick();mountMobile()}
if(document.readyState==='loading')document.addEventListener('DOMContentLoaded',init);else init();
})();