(function(){
  'use strict';
  if(location.pathname.endsWith('/admin.html') || location.pathname.endsWith('/ar.html')) return;
  let items=[], index=0, timer=null, paused=false, touchX=0;
  const esc=s=>String(s??'').replace(/[&<>\'"]/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;',"'":'&#39;','"':'&quot;'}[c]));
  function mount(){
    if(document.getElementById('bingoGlobalBannerWrap')) return document.getElementById('bingoGlobalBanner');
    const wrap=document.createElement('section');
    wrap.id='bingoGlobalBannerWrap'; wrap.className='bingo-global-banner-wrap'; wrap.setAttribute('aria-label','BINGO Oman advertisements');
    wrap.innerHTML='<div id="bingoGlobalBanner" class="bingo-global-banner"><div class="bingo-global-empty"></div></div>';
    const header=document.querySelector('header');
    if(header) header.insertAdjacentElement('afterend',wrap); else document.body.insertAdjacentElement('afterbegin',wrap);
    return document.getElementById('bingoGlobalBanner');
  }
  function render(){
    const box=mount(); clearInterval(timer);
    if(!items.length){box.innerHTML='<div class="bingo-global-empty"></div>';return;}
    const a=items[index%items.length];
    const resolvedMediaUrl=mediaUrl(a.media_url);
    const media=a.media_type==='video'
      ? '<video class="bingo-global-media" src="'+esc(resolvedMediaUrl)+'" autoplay muted loop playsinline preload="auto"></video>'
      : '<img class="bingo-global-media" src="'+esc(resolvedMediaUrl)+'" alt="" loading="eager">';
    const inner='<div class="bingo-global-slide active">'+media+'</div>';
    box.innerHTML=a.link_url
      ? '<a class="bingo-global-click" href="'+esc(a.link_url)+'" target="_blank" rel="noopener noreferrer">'+inner+'</a>'
      : inner;
    if(items.length>1 && !paused) timer=setInterval(()=>{index=(index+1)%items.length;render();},6000);
    const video=box.querySelector('video'); if(video) video.play().catch(()=>{});
  }
  function go(i){if(!items.length)return;index=(i+items.length)%items.length;render();}
  async function load(){
    mount();
    if(!window.sb || !sb.from) return;
    try{
      const {data,error}=await sb.from('site_banners').select('id,title,subtitle,button_text,media_type,media_url,link_url,sort_order').eq('status','published').order('sort_order',{ascending:true}).order('created_at',{ascending:false});
      if(error) throw error; items=data||[]; render();
    }catch(e){console.warn('BINGO global banners:',e);}
  }
  function init(){
    const box=mount();
    box.addEventListener('mouseenter',()=>{paused=true;clearInterval(timer);});
    box.addEventListener('mouseleave',()=>{paused=false;render();});
    box.addEventListener('touchstart',e=>{touchX=e.changedTouches[0].clientX;},{passive:true});
    box.addEventListener('touchend',e=>{const dx=e.changedTouches[0].clientX-touchX;if(Math.abs(dx)>45)go(dx<0?index+1:index-1);},{passive:true});
    box.addEventListener('click',e=>{const b=e.target.closest('[data-banner-index]');if(b)go(Number(b.dataset.bannerIndex));const p=e.target.closest('.bingo-global-arrow.prev');const n=e.target.closest('.bingo-global-arrow.next');if(p)go(index-1);if(n)go(index+1);});
    document.addEventListener('keydown',e=>{if(e.key==='ArrowLeft')go(index-1);if(e.key==='ArrowRight')go(index+1);});
    load();
  }
  if(document.readyState==='loading') document.addEventListener('DOMContentLoaded',init); else init();
})();
