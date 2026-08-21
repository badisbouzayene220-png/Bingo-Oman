(function(){
'use strict';
const DURATION=7200;
const ASSET_VERSION='20260821-perf1';
(function ensureFreshCss(){const old=document.querySelector('link[href*="bingo-intro-safe.css"]');if(old)old.href='bingo-intro-safe.css?v='+ASSET_VERSION;else{const l=document.createElement('link');l.rel='stylesheet';l.href='bingo-intro-safe.css?v='+ASSET_VERSION;document.head.appendChild(l)}})();
function isHome(){const p=(location.pathname.split('/').pop()||'').toLowerCase();return !p||p==='index.html'}
function isArabic(){return (document.documentElement.lang||'').toLowerCase().startsWith('ar')||document.documentElement.dir==='rtl'}
function shouldShow(){if(!isHome())return false;const params=new URLSearchParams(location.search);if(params.get('intro')==='1')return true;try{return sessionStorage.getItem('bingoCinematicIntroSeenV4')!=='1'}catch(e){return true}}
function init(){
  if(!shouldShow()||document.getElementById('bingoSafeIntro'))return;
  const ar=isArabic();const root=document.createElement('div');root.id='bingoSafeIntro';root.setAttribute('role','dialog');root.setAttribute('aria-modal','true');root.setAttribute('aria-label','BINGO Oman introduction');root.innerHTML=`
    <button class="bsi-skip" type="button" aria-label="${ar?'تخطي المقدمة':'Skip introduction'}">${ar?'تخطي':'Skip'} <span>›</span></button>
    <div class="bsi-stage">
      <div class="bsi-phase bsi-map-phase" aria-hidden="true"><svg class="bsi-map" viewBox="0 0 460 550" role="img" aria-label="Oman map"><path class="bsi-main" pathLength="1" d="M256 87 L227 90 L236 139 L216 142 L216 164 L203 179 L199 209 L223 261 L191 356 L42 411 L34 425 L75 497 L74 516 L96 535 L141 519 L191 517 L209 474 L258 468 L284 421 L329 410 L330 345 L341 331 L369 333 L370 344 L379 339 L379 299 L404 275 L411 245 L425 230 L424 215 L402 206 L366 154 L289 136 Z"/><path class="bsi-musandam" pathLength="1" d="M256 9 L253 9 L253 11 L251 14 L246 14 L246 16 L244 18 L243 20 L245 23 L245 41 L244 46 L246 49 L250 49 L250 45 L254 41 L256 36 L260 34 L259 32 L259 17 L257 15 Z"/></svg><div class="bsi-map-label">${ar?'سلطنة عُمان':'SULTANATE OF OMAN'}</div></div>
      <div class="bsi-phase bsi-ring-phase" aria-hidden="true"><div class="bsi-ring"><div class="bsi-ring-core">BINGO</div></div><span class="bsi-node n1">🛍️<small>${ar?'تسوق':'Shop'}</small></span><span class="bsi-node n2">🚗<small>${ar?'سيارات':'Cars'}</small></span><span class="bsi-node n3">🏠<small>${ar?'عقارات':'Property'}</small></span><span class="bsi-node n4">🛠️<small>${ar?'خدمات':'Services'}</small></span><span class="bsi-node n5">🔨<small>${ar?'مزادات':'Auctions'}</small></span><span class="bsi-node n6">🛵<small>${ar?'توصيل':'Delivery'}</small></span></div>
      <div class="bsi-phase bsi-logo-phase"><div class="bsi-logo-fallback" aria-hidden="true">BINGO <span>OMAN</span></div><img class="bsi-logo" data-src="assets/bingo-oman-intro.png?v=${ASSET_VERSION}" alt="BINGO Oman" decoding="async"></div>
      <div class="bsi-phase bsi-mascot-phase"><div class="bsi-mascot-card"><img class="bsi-mascot" data-src="assets/characters/bingo-mascot-phone-v2.png?v=${ASSET_VERSION}" alt="BINGO Oman mascot and Oman map" decoding="async"></div></div>
      <div class="bsi-phase bsi-copy-phase"><div class="bsi-copy-panel"><div class="bsi-kicker">BINGO OMAN</div><h1>${ar?'كل ما تحتاجه… <span>في مكان واحد</span>':'Everything you need… <span>in one place</span>'}</h1><p>${ar?'تسوق • بيع • خدمات • مزادات • توصيل • اكتشف عُمان':'Shop • Sell • Services • Auctions • Delivery • Discover Oman'}</p></div></div>
      <div class="bsi-progress" aria-hidden="true"><i></i></div>
    </div>`;
  document.body.appendChild(root);
  const logo=root.querySelector('.bsi-logo'),mascot=root.querySelector('.bsi-mascot');
  const startImg=(img)=>{if(!img||img.src)return;const src=img.dataset.src;if(src)img.src=src};
  if(logo){logo.addEventListener('load',()=>root.classList.add('bsi-logo-loaded'),{once:true});logo.addEventListener('error',()=>{logo.src='logo-en.png?v='+ASSET_VERSION;logo.addEventListener('error',()=>logo.style.display='none',{once:true})},{once:true})}
  if(mascot){mascot.addEventListener('load',()=>root.classList.add('bsi-mascot-loaded'),{once:true});mascot.addEventListener('error',()=>{mascot.src='assets/characters/main.png?v='+ASSET_VERSION;mascot.addEventListener('error',()=>mascot.style.display='none',{once:true})},{once:true})}
  /* The first ~2 seconds are SVG/CSS only. Start heavy image downloads just before their phases. */
  const logoTimer=window.setTimeout(()=>startImg(logo),1050);
  const mascotTimer=window.setTimeout(()=>startImg(mascot),2150);
  let closed=false;const close=()=>{if(closed)return;closed=true;clearTimeout(logoTimer);clearTimeout(mascotTimer);try{sessionStorage.setItem('bingoCinematicIntroSeenV4','1')}catch(e){}root.classList.add('is-closing');window.setTimeout(()=>root.remove(),620)};root.querySelector('.bsi-skip')?.addEventListener('click',close,{once:true});document.addEventListener('keydown',e=>{if(e.key==='Escape'||e.key==='Enter')close()},{once:true});const timer=window.setTimeout(close,DURATION);window.addEventListener('pagehide',()=>{clearTimeout(timer);clearTimeout(logoTimer);clearTimeout(mascotTimer)},{once:true});
}
if(document.readyState==='loading')document.addEventListener('DOMContentLoaded',init,{once:true});else init();
})();