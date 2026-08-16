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
