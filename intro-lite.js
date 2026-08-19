(function(){
'use strict';
function isArabic(){return (document.documentElement.lang||'').toLowerCase().startsWith('ar')||document.documentElement.dir==='rtl'}
function init(){
  const intro=document.getElementById('bingoIntro');
  if(!intro||intro.dataset.introLite==='2')return;
  intro.dataset.introLite='2';
  const content=intro.querySelector('.intro-content');
  if(!content)return;
  const ar=isArabic();
  content.innerHTML=`
    <div class="bingo-intro-lite bingo-intro-polished">
      <div class="bingo-intro-map" aria-hidden="true">
        <svg viewBox="0 0 460 550"><path d="M256 87 L227 90 L236 139 L216 142 L216 164 L203 179 L199 209 L223 261 L191 356 L42 411 L34 425 L75 497 L74 516 L96 535 L141 519 L191 517 L209 474 L258 468 L284 421 L329 410 L330 345 L341 331 L369 333 L370 344 L379 339 L379 299 L404 275 L411 245 L425 230 L424 215 L402 206 L366 154 L289 136 Z"/><path d="M256 9 L253 9 L253 11 L251 14 L246 14 L246 16 L244 18 L243 20 L245 23 L245 41 L244 46 L246 49 L250 49 L250 45 L254 41 L256 36 L260 34 L259 32 L259 17 L257 15 Z"/></svg>
      </div>
      <div class="bingo-intro-lite-copy">
        <img class="bingo-intro-lite-logo" src="logo-en.png?v=20260819-7" alt="BINGO Oman">
        <div class="bingo-intro-lite-kicker">BINGO OMAN</div>
        <h1>${ar?'كل ما تحتاجه في <span>مكان واحد</span>':'Everything you need. <span>One place.</span>'}</h1>
        <p>${ar?'تسوق • بيع • خدمات • مزادات • توصيل • اكتشف عُمان':'Shop • Sell • Services • Auctions • Delivery • Discover Oman'}</p>
        <div class="bingo-intro-services" aria-hidden="true"><span>🛍️</span><span>🚗</span><span>🏠</span><span>🔨</span><span>🛵</span></div>
        <div class="bingo-intro-lite-actions">
          <button type="button" class="bingo-intro-lite-btn primary" id="bingoLiteEnter">${ar?'ابدأ الآن':'Start now'}</button>
          <a class="bingo-intro-lite-btn" href="#discover-oman" id="bingoLiteDiscover">${ar?'اكتشف عُمان':'Discover Oman'}</a>
        </div>
      </div>
      <div class="bingo-intro-lite-mascot-wrap"><div class="bingo-intro-mascot-card"><img class="bingo-intro-lite-mascot" src="assets/characters/bingo-mascot-phone-v2.png?v=20260819-7" alt="BINGO Oman"></div></div>
      <div class="bingo-intro-lite-progress"><i></i></div>
    </div>`;

  let closed=false;
  function close(){
    if(closed)return; closed=true;
    intro.classList.add('is-hidden');
    document.documentElement.classList.remove('bingo-intro-lock');
    document.body.classList.remove('bingo-intro-lock');
    try{
      sessionStorage.setItem('bingoIntroSeen','1');
      sessionStorage.setItem('bingoOmanIntroSeen','1');
    }catch(e){}
    setTimeout(()=>{if(intro&&intro.parentNode)intro.remove()},450);
  }
  document.getElementById('bingoLiteEnter')?.addEventListener('click',close);
  document.getElementById('bingoLiteDiscover')?.addEventListener('click',()=>setTimeout(close,0));
  document.getElementById('skipIntro')?.addEventListener('click',e=>{e.preventDefault();close()},{once:true});
  document.addEventListener('keydown',e=>{if(e.key==='Escape'||e.key==='Enter')close()},{once:true});
  window.setTimeout(close,5500);
}
if(document.readyState==='loading')document.addEventListener('DOMContentLoaded',init);else init();
})();