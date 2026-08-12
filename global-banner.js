(function(){
  'use strict';
  if(location.pathname.endsWith('/admin.html')) return;
  let items=[], index=0, timer=null;

  function esc(s){return String(s??'').replace(/[&<>\'"]/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;',"'":'&#39;','"':'&quot;'}[c]));}

  function resolveMediaUrl(value){
    const raw=String(value||'').trim();
    if(!raw) return '';
    if(/^https?:\/\//i.test(raw) || /^data:/i.test(raw) || raw.startsWith('blob:')) return raw;
    try{
      if(window.sb && window.sb.storage && window.sb.storage.from){
        const path=raw.replace(/^\/+/, '').replace(/^bingo-banners\//,'');
        const {data}=window.sb.storage.from('bingo-banners').getPublicUrl(path);
        if(data && data.publicUrl) return data.publicUrl;
      }
    }catch(e){console.warn('BINGO banner URL:',e);}
    return raw;
  }

  function mount(){
    if(document.getElementById('bingoGlobalBannerWrap')) return document.getElementById('bingoGlobalBanner');
    const wrap=document.createElement('section');
    wrap.id='bingoGlobalBannerWrap';
    wrap.className='bingo-global-banner-wrap';
    wrap.setAttribute('aria-label','BINGO Oman advertisement');
    wrap.innerHTML='<div id="bingoGlobalBanner" class="bingo-global-banner"></div>';
    const header=document.querySelector('header');
    if(header) header.insertAdjacentElement('afterend',wrap); else document.body.insertAdjacentElement('afterbegin',wrap);
    return document.getElementById('bingoGlobalBanner');
  }

  function render(){
    const box=mount();
    clearInterval(timer);
    if(!items.length){box.innerHTML=''; return;}
    const a=items[index%items.length];
    const url=resolveMediaUrl(a.media_url);
    if(!url){box.innerHTML=''; return;}
    const media=a.media_type==='video'
      ? '<video class="bingo-global-media" src="'+esc(url)+'" autoplay muted loop playsinline preload="auto"></video>'
      : '<img class="bingo-global-media" src="'+esc(url)+'" alt="" loading="eager" decoding="async">';
    const inner=a.link_url
      ? '<a class="bingo-global-link" href="'+esc(a.link_url)+'" target="_blank" rel="noopener noreferrer" aria-label="Advertisement">'+media+'</a>'
      : media;
    box.innerHTML='<div class="bingo-global-slide active">'+inner+'</div>';
    if(items.length>1) timer=setInterval(()=>{index=(index+1)%items.length;render();},6000);
    const video=box.querySelector('video');
    if(video){ video.muted=true; video.play().catch(()=>{}); }
  }

  async function load(){
    mount();
    if(!window.sb || !window.sb.from) return;
    try{
      const {data,error}=await window.sb.from('site_banners')
        .select('id,media_type,media_url,link_url,sort_order,created_at,starts_at,ends_at,status')
        .eq('status','published')
        .order('sort_order',{ascending:true})
        .order('created_at',{ascending:false});
      if(error) throw error;
      const now=Date.now();
      items=(data||[]).filter(a=>{
        const start=a.starts_at?new Date(a.starts_at).getTime():-Infinity;
        const end=a.ends_at?new Date(a.ends_at).getTime():Infinity;
        return start<=now && now<=end && a.media_url;
      });
      render();
    }catch(e){console.warn('BINGO global banners:',e);}
  }

  function init(){ mount(); load(); }
  if(document.readyState==='loading') document.addEventListener('DOMContentLoaded',init); else init();
})();
