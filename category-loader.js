(function(){
'use strict';
const page=(location.pathname.split('/').pop()||'').toLowerCase();
if(page!=='add-listing.html'&&page!=='marketplace.html')return;
const MAP=[
 {keys:['real estate','العقارات'],base:'real-estate-category',v:'20260820-2'},
 {keys:['electronics','الإلكترونيات'],base:'electronics-category',v:'20260820-1'},
 {keys:['mobile phones','الهواتف'],base:'mobile-phones-category',v:'20260820-1'},
 {keys:['jobs','الوظائف'],base:'jobs-category',v:'20260820-1'},
 {keys:['services','الخدمات'],base:'services-category',v:'20260820-1'},
 {keys:['fashion','الأزياء'],base:'fashion-category',v:'20260820-1'},
 {keys:['furniture','الأثاث'],base:'furniture-category',v:'20260820-1'},
 {keys:['home & garden','home and garden','المنزل والحديقة'],base:'home-garden-category',v:'20260821-1'},
 {keys:['sports','الرياضة'],base:'sports-category',v:'20260821-1'},
 {keys:['kids & baby','الأطفال والرضع'],base:'kids-baby-category',v:'20260821-1'},
 {keys:['business & industrial','business and industrial','الأعمال والصناعة'],base:'business-industrial-category',v:'20260821-1'},
 {keys:['other','أخرى'],base:'other-category',v:'20260821-1'}
];
const loaded=new Set();
function loadAsset(tag,type,url){if(document.querySelector('['+tag+']'))return;const el=document.createElement(type);if(type==='link'){el.rel='stylesheet';el.href=url}else{el.src=url;el.defer=true}el.setAttribute(tag,'1');document.head.appendChild(el)}
function detect(select){const text=(select?.selectedOptions?.[0]?.textContent||'').trim().toLowerCase();if(!text)return null;return MAP.find(m=>m.keys.some(k=>text.includes(k)))||null}
function ensure(select){const m=detect(select);if(!m||loaded.has(m.base))return;loaded.add(m.base);const tag=m.base.replace(/[^a-z0-9]+/g,'-');loadAsset('data-bingo-cat-'+tag,'link',m.base+'.css?v='+m.v);loadAsset('data-bingo-cat-'+tag+'-js','script',m.base+'.js?v='+m.v)}
function boot(){const id=page==='add-listing.html'?'category':'cat';const select=document.getElementById(id);if(!select)return false;ensure(select);select.addEventListener('change',()=>ensure(select));new MutationObserver(()=>ensure(select)).observe(select,{childList:true,subtree:true});return true}
let n=0;const timer=setInterval(()=>{if(boot()||++n>100)clearInterval(timer)},100);
})();