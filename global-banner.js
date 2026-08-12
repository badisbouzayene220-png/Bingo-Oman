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
    const mediaUrl=String(a.media_url||'').trim();
    const media=a.media_type==='video'
      ? '<video class="bingo-global-media" src="'+esc(mediaUrl)+'" autoplay muted loop playsinline preload="auto" controlslist="nodownload"></video>'
      : '<img class="bingo-global-media" src="'+esc(mediaUrl)+'" alt="'+esc(a.title||'Advertisement')+'" loading="eager" decoding="async">';
    const cta=a.link_url?'<a class="bingo-global-cta" href="'+esc(a.link_url)+'" target="_blank" rel="noopener noreferrer">'+esc(a.button_text||'Shop Now')+' <span>→</span></a>':'';
    const content='<div class="bingo-global-content"><div class="eyebrow">BINGO Oman</div><h2>'+esc(a.title||'Special Offer')+'</h2>'+(a.subtitle?'<p>'+esc(a.subtitle)+'</p>':'')+cta+'</div>';
    box.innerHTML='<div class="bingo-global-slide active">'+media+'<div class="bingo-global-overlay"></div>'+content+'</div>'+(items.length>1
      ? '<button class="bingo-global-arrow prev" type="button" aria-label="Previous banner">‹</button><button class="bingo-global-arrow next" type="button" aria-label="Next banner">›</button><div class="bingo-global-dots">'+items.map((_,i)=>'<button class="bingo-global-dot '+(i===index?'active':'')+'" type="button" aria-label="Banner '+(i+1)+'" data-banner-index="'+i+'"></button>').join('')+'</div><div class="bingo-global-progress"></div>' : '');
    if(items.length>1 && !paused) timer=setInterval(()=>{index=(index+1)%items.length;render();},6000);
    const mediaEl=box.querySelector('.bingo-global-media');
    if(mediaEl){
      mediaEl.addEventListener('error',()=>{
        console.warn('BINGO banner media failed to load:',a.media_url);
        mediaEl.style.display='none';
        box.querySelector('.bingo-global-overlay')?.setAttribute('style','display:none');
      },{once:true});
    }
    const video=box.querySelector('video'); if(video) video.play().catch(()=>{});
  }
  function go(i){if(!items.length)return;index=(i+items.length)%items.length;render();}
  async function load(){
    mount();
    if(!window.sb || !sb.from) return;
    try{
      const {data,error}=await sb.from('site_banners').select('id,title,subtitle,button_text,media_type,media_url,link_url,sort_order,starts_at,ends_at').eq('status','published').order('sort_order',{ascending:true}).order('created_at',{ascending:false});
      if(error) throw error;
      const now=Date.now();
      items=(data||[]).filter(x=>(!x.starts_at || new Date(x.starts_at).getTime()<=now) && (!x.ends_at || new Date(x.ends_at).getTime()>=now)).map(x=>{
        let u=String(x.media_url||'').trim();
        // Accept either a full public URL or a storage object path.
        if(u && !/^https?:\/\//i.test(u) && window.sb?.storage){
          const r=sb.storage.from('bingo-banners').getPublicUrl(u);
          u=r?.data?.publicUrl||u;
        }
        return {...x,media_url:u};
      }).filter(x=>x.media_url);
      render();
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
