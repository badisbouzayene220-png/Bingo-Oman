(function(){
  'use strict';
  // Global BINGO banner: media only, no text/overlay/controls.
  // Admin page is intentionally excluded.
  if(/\/admin\.html$/i.test(location.pathname)) return;

  let items=[], index=0, timer=null;

  function resolveMediaUrl(value){
    const raw=String(value||'').trim();
    if(!raw) return '';
    if(/^https?:\/\//i.test(raw) || /^data:/i.test(raw) || /^blob:/i.test(raw)) return raw;
    try{
      if(window.sb && window.sb.storage){
        let path=raw.replace(/^\/+/, '');
        path=path.replace(/^bingo-banners\//i,'');
        const result=window.sb.storage.from('bingo-banners').getPublicUrl(path);
        if(result && result.data && result.data.publicUrl) return result.data.publicUrl;
      }
    }catch(e){ console.warn('BINGO banner URL:',e); }
    return raw;
  }

  function esc(s){
    return String(s??'').replace(/[&<>'"]/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;',"'":'&#39;','"':'&quot;'}[c]));
  }

  function mount(){
    let wrap=document.getElementById('bingoGlobalBannerWrap');
    if(wrap) return document.getElementById('bingoGlobalBanner');

    wrap=document.createElement('section');
    wrap.id='bingoGlobalBannerWrap';
    wrap.className='bingo-global-banner-wrap';
    wrap.setAttribute('aria-label','BINGO Oman banner');

    const box=document.createElement('div');
    box.id='bingoGlobalBanner';
    box.className='bingo-global-banner';
    wrap.appendChild(box);

    const header=document.querySelector('header');
    if(header && header.parentNode) header.insertAdjacentElement('afterend',wrap);
    else if(document.body) document.body.insertAdjacentElement('afterbegin',wrap);

    return box;
  }

  function render(){
    const box=mount();
    if(timer){clearInterval(timer);timer=null;}
    if(!items.length){box.innerHTML='';box.style.display='none';return;}

    const a=items[index%items.length];
    const url=resolveMediaUrl(a.media_url);
    if(!url){box.innerHTML='';box.style.display='none';return;}

    box.style.display='block';

    const media=a.media_type==='video'
      ? '<video class="bingo-global-media" autoplay muted loop playsinline preload="metadata" src="'+esc(url)+'"></video>'
      : '<img class="bingo-global-media" src="'+esc(url)+'" alt="" loading="eager" decoding="async">';

    box.innerHTML=a.link_url
      ? '<a class="bingo-global-link" href="'+esc(a.link_url)+'" target="_blank" rel="noopener noreferrer">'+media+'</a>'
      : media;

    const video=box.querySelector('video');
    if(video){
      video.muted=true;
      video.setAttribute('muted','');
      video.play().catch(()=>{});
    }

    if(items.length>1){
      timer=setInterval(()=>{
        index=(index+1)%items.length;
        render();
      },6000);
    }
  }

  async function load(){
    mount();
    if(!window.sb || typeof window.sb.from!=='function'){
      console.warn('BINGO banner: Supabase client not ready.');
      return;
    }

    try{
      // Public policy should allow published banners only.
      const result=await window.sb.from('site_banners')
        .select('id,media_type,media_url,link_url,sort_order,created_at,starts_at,ends_at,status')
        .eq('status','published')
        .order('sort_order',{ascending:true})
        .order('created_at',{ascending:false});

      if(result.error) throw result.error;

      const now=Date.now();
      items=(result.data||[]).filter(a=>{
        if(!a || !a.media_url) return false;
        const start=a.starts_at ? new Date(a.starts_at).getTime() : -Infinity;
        const end=a.ends_at ? new Date(a.ends_at).getTime() : Infinity;
        return !Number.isNaN(start) && !Number.isNaN(end) && start<=now && now<=end;
      });

      render();
    }catch(e){
      console.error('BINGO global banner load failed:',e);
      // Do not show a fake/blue banner when the database or policy is unavailable.
      const box=mount();
      box.innerHTML='';
      box.style.display='none';
    }
  }

  function init(){
    mount();
    // supabase-client.js is loaded before this file on normal pages.
    load();
  }

  if(document.readyState==='loading') document.addEventListener('DOMContentLoaded',init);
  else init();
})();