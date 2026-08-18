(function(){
  'use strict';
  let ads=[], index=0, timer=null, currentAd=null;
  const esc=s=>String(s??'').replace(/[&<>\'\"]/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;',"'":'&#39;','\"':'&quot;'}[c]));
  function valid(a){
    const now=Date.now();
    const start=a.starts_at?new Date(a.starts_at).getTime():-Infinity;
    const end=a.ends_at?new Date(a.ends_at).getTime():Infinity;
    return a && a.image_url && start<=now && now<=end;
  }
  function mediaHtml(a){
    const url=esc(a.image_url);
    const low=String(a.image_url||'').toLowerCase();
    const isVideo=/\.(mp4|webm|ogg)(\?|#|$)/i.test(low);
    if(isVideo) return '<video class="bingo-character-ad-media" src="'+url+'" autoplay muted loop playsinline preload="metadata"></video>';
    return '<img class="bingo-character-ad-media" src="'+url+'" alt="'+esc(a.title||'Company advertisement')+'" loading="eager" decoding="async">';
  }
  function mount(){
    if(document.getElementById('bingoCharacterSystem')) return;
    const html='<div class="bingo-character-system" id="bingoCharacterSystem"><div class="bingo-character-card"><div class="bingo-character-head"><div class="bingo-character-brand">BINGO <span>OMAN</span></div><button class="bingo-character-close" id="bingoCharacterClose">×</button></div><div id="bingoCompanyAdStage" class="bingo-character-stage bingo-company-ad-stage"></div><div class="bingo-character-info"><div id="bingoCompanyAdTitle" class="bingo-character-name">إعلانات الشركات</div><div class="bingo-character-role">إعلان ممول</div></div><div id="bingoCompanyAdMessage" class="bingo-character-message">إعلانات الشركات المميزة في BINGO Oman</div></div><button class="bingo-character-minimized" id="bingoCharacterOpen"><span id="bingoCompanyAdMini">AD</span></button></div>';
    document.body.insertAdjacentHTML('beforeend',html);
    const root=document.getElementById('bingoCharacterSystem');
    document.getElementById('bingoCharacterClose').onclick=()=>root.classList.add('minimized');
    document.getElementById('bingoCharacterOpen').onclick=()=>root.classList.remove('minimized');
  }
  function render(){
    mount();
    clearInterval(timer);
    const stage=document.getElementById('bingoCompanyAdStage');
    const title=document.getElementById('bingoCompanyAdTitle');
    const msg=document.getElementById('bingoCompanyAdMessage');
    const mini=document.getElementById('bingoCompanyAdMini');
    if(!ads.length){
      stage.innerHTML='<div class="bingo-company-ad-empty">لا توجد إعلانات حالياً</div>';
      title.textContent='إعلانات الشركات';
      msg.textContent='يمكنك التحكم بهذه الإعلانات من Admin → Company Ads';
      mini.textContent='AD';
      return;
    }
    const a=ads[index%ads.length]; currentAd=a;
    const inner=mediaHtml(a);
    stage.innerHTML=a.link_url
      ? '<a class="bingo-company-ad-link" href="'+esc(a.link_url)+'" target="_blank" rel="noopener noreferrer">'+inner+'</a>'
      : inner;
    title.textContent=a.title||'إعلان شركة';
    msg.textContent='إعلان شركة عبر BINGO Oman';
    mini.innerHTML='<span>AD</span>';
    const video=stage.querySelector('video'); if(video){video.muted=true;video.play().catch(()=>{});}
    if(ads.length>1) timer=setInterval(()=>{index=(index+1)%ads.length;render();},6000);
  }
  async function load(){
    mount();
    if(!window.sb || !sb.from) return;
    try{
      const {data,error}=await sb.from('company_ads').select('id,title,image_url,link_url,sort_order,starts_at,ends_at,status,placement').eq('status','published').eq('placement','floating_character').order('sort_order',{ascending:true}).order('created_at',{ascending:false});
      if(error) throw error;
      ads=(data||[]).filter(valid);
      render();
    }catch(e){
      console.warn('BINGO floating company ads:',e);
      render();
    }
  }
  function init(){mount();load();}
  if(document.readyState==='loading') document.addEventListener('DOMContentLoaded',init); else init();
})();

/* Admin-only HR navigation: keep ERP untouched and expose HR as its own page. */
(function(){
  function addHrLink(){
    if(!/\/admin(?:\.html)?$/i.test(window.location.pathname)) return;
    const side=document.querySelector('.admin-side');
    if(!side || side.querySelector('[data-bingo-hr-link]')) return;
    const link=document.createElement('a');
    link.href='hr.html';
    link.setAttribute('data-bingo-hr-link','1');
    link.textContent='👥 HR / الموارد البشرية';
    link.style.cssText='display:block;text-align:left;text-decoration:none;padding:12px;border-radius:10px;font-weight:800;color:#667085';
    link.addEventListener('mouseenter',()=>{link.style.background='#eef3ff';link.style.color='#092a82';});
    link.addEventListener('mouseleave',()=>{link.style.background='';link.style.color='#667085';});
    side.appendChild(link);
  }
  if(document.readyState==='loading') document.addEventListener('DOMContentLoaded',addHrLink); else addHrLink();
})();

/* =========================================================
   BINGO OMAN — CINEMATIC OMAN INTRO V2
   Rebuilds the existing homepage intro without touching auth.
   Sequence: Oman outline → service ring → logo → mascot → tagline.
   ========================================================= */
(function(){
  'use strict';

  function initCinematicIntro(){
    const intro=document.getElementById('bingoIntro');
    if(!intro || intro.dataset.cinematicV2==='1') return;
    intro.dataset.cinematicV2='1';

    const style=document.createElement('style');
    style.id='bingo-cinematic-intro-v2';
    style.textContent=`
      #bingoIntro{background:#03111f!important;overflow:hidden!important}
      #bingoIntro .intro-bg{background:
        radial-gradient(circle at 50% 38%,rgba(255,132,25,.11),transparent 28%),
        radial-gradient(circle at 50% 100%,rgba(12,99,68,.18),transparent 35%),
        linear-gradient(160deg,#020b16 0%,#061827 52%,#020913 100%)!important}
      #bingoIntro .intro-vignette{background:radial-gradient(ellipse at center,transparent 28%,rgba(0,0,0,.68) 100%)!important}
      #bingoIntro .intro-content{width:min(760px,94vw)!important;min-height:100%!important;padding:40px 0 34px!important;justify-content:center!important}
      #bingoIntro .intro-beam,#bingoIntro .intro-orbit{display:none!important}
      #bingoIntro .intro-skip{top:18px!important;right:18px!important;z-index:50!important}
      .cinematic-stage{position:relative;width:min(660px,92vw);height:min(620px,82vh);display:grid;place-items:center;isolation:isolate}
      .cinematic-glow{position:absolute;inset:12% 9%;border-radius:50%;background:radial-gradient(circle,rgba(255,127,17,.18),transparent 60%);filter:blur(22px);opacity:.75}
      .oman-map-wrap{position:absolute;width:min(300px,56vw);aspect-ratio:1/1.18;display:grid;place-items:center;animation:mapPhase 1.55s ease-in-out both}
      .oman-map{width:100%;height:100%;overflow:visible;filter:drop-shadow(0 0 12px rgba(255,143,41,.36))}
      .oman-map path{fill:rgba(255,141,33,.025);stroke:#ff982f;stroke-width:4;stroke-linecap:round;stroke-linejoin:round;stroke-dasharray:1300;stroke-dashoffset:1300;animation:drawOman 1.15s .08s ease-out forwards,mapFill .45s 1.02s ease-out forwards}
      .oman-label{position:absolute;bottom:4%;font:800 12px/1.4 "Noto Kufi Arabic",sans-serif;color:#ffd8a9;letter-spacing:.04em;opacity:0;animation:fadeUp .45s .72s ease-out forwards}
      .service-ring{position:absolute;width:min(370px,70vw);aspect-ratio:1;border:1px solid rgba(255,143,43,.48);border-radius:50%;box-shadow:0 0 35px rgba(255,105,0,.08),inset 0 0 28px rgba(255,122,0,.04);opacity:0;transform:scale(.66);animation:ringIn .65s 1.05s cubic-bezier(.2,.8,.2,1) forwards,ringFade .45s 2.55s ease forwards}
      .service-ring:before{content:"";position:absolute;inset:9%;border:1px dashed rgba(255,255,255,.12);border-radius:50%;animation:ringSpin 10s linear infinite}
      .service-node{position:absolute;left:50%;top:50%;width:58px;height:58px;margin:-29px;display:grid;place-items:center;border-radius:50%;background:rgba(5,20,31,.93);border:1px solid rgba(255,150,54,.7);box-shadow:0 9px 25px rgba(0,0,0,.3),0 0 20px rgba(255,117,0,.12);font-size:24px;opacity:0;transform:rotate(var(--a)) translateY(-185px) rotate(calc(var(--a) * -1)) scale(.5);animation:nodeIn .42s var(--delay) cubic-bezier(.2,.9,.25,1.2) forwards}
      .service-node span{filter:drop-shadow(0 2px 5px rgba(0,0,0,.4))}
      .service-center{position:absolute;inset:50% auto auto 50%;transform:translate(-50%,-50%);font:900 12px/1.5 "Noto Kufi Arabic",sans-serif;color:#fff;text-align:center;opacity:0;animation:fadeUp .4s 1.38s ease forwards}
      .service-center b{display:block;color:#ff9a32;font:900 13px/1.6 Inter,sans-serif;letter-spacing:.12em}
      .cinematic-logo{position:absolute;width:min(360px,68vw);opacity:0;transform:scale(.78);filter:blur(10px) drop-shadow(0 18px 36px rgba(0,0,0,.45));animation:logoReveal .72s 2.52s cubic-bezier(.16,1,.3,1) forwards,logoShift .72s 3.45s cubic-bezier(.16,1,.3,1) forwards}
      .cinematic-logo img{display:block;width:100%;height:auto}
      .cinematic-mascot{position:absolute;bottom:10%;right:4%;width:min(245px,39vw);opacity:0;transform:translateX(58px) translateY(18px) scale(.93);filter:drop-shadow(0 28px 35px rgba(0,0,0,.48));animation:mascotIn .72s 3.36s cubic-bezier(.16,1,.3,1) forwards}
      .cinematic-copy{position:absolute;left:6%;bottom:15%;width:min(430px,62vw);text-align:left;opacity:0;transform:translateY(22px);animation:copyFinal .65s 3.78s ease-out forwards}
      .cinematic-copy .kicker{font:900 11px/1.3 Inter,sans-serif;color:#ff9a32;letter-spacing:.18em;margin-bottom:8px}
      .cinematic-copy h2{margin:0;color:#fff;font:900 clamp(24px,4.7vw,40px)/1.35 "Noto Kufi Arabic",sans-serif;text-shadow:0 9px 25px rgba(0,0,0,.36)}
      .cinematic-copy h2 em{font-style:normal;color:#ff9a32}
      .cinematic-copy p{margin:7px 0 0;color:#d8e2ed;font:600 clamp(12px,2.4vw,16px)/1.6 Inter,sans-serif}
      .cinematic-actions{position:absolute;left:6%;bottom:4%;display:flex;gap:9px;opacity:0;transform:translateY(12px);animation:copyFinal .5s 4.28s ease-out forwards}
      .cinematic-action{border:1px solid rgba(255,255,255,.22);background:rgba(255,255,255,.08);backdrop-filter:blur(10px);color:#fff;text-decoration:none;border-radius:999px;padding:10px 15px;font:800 12px/1 "Noto Kufi Arabic",Inter,sans-serif;cursor:pointer}
      .cinematic-action.primary{background:linear-gradient(135deg,#ff9c2d,#ff6218);border-color:transparent}
      .cinematic-progress{position:absolute;left:50%;bottom:0;width:min(280px,55vw);height:2px;transform:translateX(-50%);background:rgba(255,255,255,.12);overflow:hidden;border-radius:999px}
      .cinematic-progress i{display:block;height:100%;width:100%;background:linear-gradient(90deg,#d51f2f,#ff9b2e,#218b57);transform-origin:left;animation:introProgress 5.8s linear forwards}
      @keyframes drawOman{to{stroke-dashoffset:0}}
      @keyframes mapFill{to{fill:rgba(255,145,38,.09)}}
      @keyframes mapPhase{0%,76%{opacity:1;transform:scale(.9)}100%{opacity:.18;transform:scale(.7)}}
      @keyframes ringIn{to{opacity:1;transform:scale(1)}}
      @keyframes ringFade{to{opacity:0;transform:scale(1.08)}}
      @keyframes ringSpin{to{transform:rotate(360deg)}}
      @keyframes nodeIn{to{opacity:1;transform:rotate(var(--a)) translateY(-185px) rotate(calc(var(--a) * -1)) scale(1)}}
      @keyframes fadeUp{from{opacity:0;transform:translateY(12px)}to{opacity:1;transform:translateY(0)}}
      @keyframes logoReveal{to{opacity:1;transform:scale(1);filter:blur(0) drop-shadow(0 18px 36px rgba(0,0,0,.45))}}
      @keyframes logoShift{to{transform:translate(-13%,-34%) scale(.72)}}
      @keyframes mascotIn{to{opacity:1;transform:translateX(0) translateY(0) scale(1)}}
      @keyframes copyFinal{to{opacity:1;transform:translateY(0)}}
      @keyframes introProgress{from{transform:scaleX(0)}to{transform:scaleX(1)}}
      @media(max-width:640px){
        .cinematic-stage{height:min(700px,86vh)}
        .service-node{transform:rotate(var(--a)) translateY(-145px) rotate(calc(var(--a) * -1)) scale(.5)}
        @keyframes nodeIn{to{opacity:1;transform:rotate(var(--a)) translateY(-145px) rotate(calc(var(--a) * -1)) scale(1)}}
        .cinematic-logo{top:31%;width:min(300px,70vw)}
        .cinematic-copy{left:5%;bottom:18%;width:62vw}
        .cinematic-copy h2{font-size:clamp(21px,6vw,28px)}
        .cinematic-mascot{right:-2%;bottom:10%;width:min(220px,43vw)}
        .cinematic-actions{left:5%;bottom:5%;gap:7px}
        .cinematic-action{padding:9px 12px;font-size:10px}
      }
      @media(prefers-reduced-motion:reduce){
        .oman-map-wrap,.oman-map path,.service-ring,.service-node,.service-center,.cinematic-logo,.cinematic-mascot,.cinematic-copy,.cinematic-actions,.cinematic-progress i{animation-duration:.01ms!important;animation-delay:0!important}
      }
    `;
    document.head.appendChild(style);

    const content=intro.querySelector('.intro-content');
    if(!content) return;
    content.innerHTML=`
      <div class="cinematic-stage" aria-label="BINGO Oman cinematic intro">
        <div class="cinematic-glow" aria-hidden="true"></div>
        <div class="oman-map-wrap" aria-hidden="true">
          <svg class="oman-map" viewBox="0 0 360 430" role="img" aria-label="Oman outline">
            <path d="M105 36 L143 61 L167 101 L203 108 L229 136 L254 149 L279 184 L292 228 L274 254 L289 284 L272 315 L243 326 L225 354 L195 364 L179 393 L143 379 L132 344 L102 324 L92 291 L69 268 L80 236 L61 208 L76 181 L72 150 L92 130 L86 94 L104 72 Z M264 69 L290 52 L313 67 L298 86 L277 88 Z"/>
          </svg>
          <div class="oman-label">عُمان... بكل جمالها</div>
        </div>

        <div class="service-ring" aria-hidden="true">
          <div class="service-node" style="--a:0deg;--delay:1.12s"><span>🛍️</span></div>
          <div class="service-node" style="--a:60deg;--delay:1.22s"><span>🚗</span></div>
          <div class="service-node" style="--a:120deg;--delay:1.32s"><span>🏠</span></div>
          <div class="service-node" style="--a:180deg;--delay:1.42s"><span>🛠️</span></div>
          <div class="service-node" style="--a:240deg;--delay:1.52s"><span>🔨</span></div>
          <div class="service-node" style="--a:300deg;--delay:1.62s"><span>🚚</span></div>
          <div class="service-center"><b>BINGO OMAN</b>كل الخدمات في حلقة واحدة</div>
        </div>

        <div class="cinematic-logo"><img src="assets/bingo-oman-intro.png" alt="BINGO Oman"></div>
        <img class="cinematic-mascot" src="assets/characters/main.png" alt="BINGO Oman mascot">

        <div class="cinematic-copy">
          <div class="kicker">BINGO OMAN</div>
          <h2>كل ما تحتاجه...<br><em>في مكان واحد</em></h2>
          <p>من التسوق إلى الخدمات والتوصيل — عُمان بين يديك.</p>
        </div>

        <div class="cinematic-actions">
          <a class="cinematic-action primary" href="travel.html">اكتشف عُمان</a>
          <button class="cinematic-action" id="cinematicEnterBingo" type="button">BINGO OMAN</button>
        </div>
        <div class="cinematic-progress"><i></i></div>
      </div>`;

    const closeButton=document.getElementById('cinematicEnterBingo');
    if(closeButton){
      closeButton.addEventListener('click',function(){
        const skip=document.getElementById('skipIntro');
        if(skip) skip.click();
        else intro.classList.add('is-hidden');
      });
    }

    window.setTimeout(function(){
      if(!document.body.contains(intro)) return;
      const skip=document.getElementById('skipIntro');
      if(skip) skip.click();
      else intro.classList.add('is-hidden');
    },5800);
  }

  if(document.readyState==='loading') document.addEventListener('DOMContentLoaded',initCinematicIntro); else initCinematicIntro();
})();
