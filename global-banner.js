(function(){
  'use strict';
  let items=[], index=0, timer=null, mounted=false;

  function esc(s){return String(s??'').replace(/[&<>\'\"]/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;',"'":'&#39;','"':'&quot;'}[c]));}

  function resolveMediaUrl(value){
    const raw=String(value||'').trim();
    if(!raw) return '';
    if(/^https?:\/\//i.test(raw) || /^data:/i.test(raw) || raw.startsWith('blob:')) return raw;
    try{
      const client=window.sb;
      if(client && client.storage){
        const path=raw.replace(/^\/+/, '').replace(/^bingo-banners\//i,'');
        const out=client.storage.from('bingo-banners').getPublicUrl(path);
        if(out && out.data && out.data.publicUrl) return out.data.publicUrl;
      }
    }catch(e){ console.warn('[BINGO Banner] URL resolve failed',e); }
    return raw;
  }

  function mount(){
    let box=document.getElementById('bingoGlobalBanner');
    if(box) return box;
    const wrap=document.createElement('section');
    wrap.id='bingoGlobalBannerWrap';
    wrap.className='bingo-global-banner-wrap';
    wrap.setAttribute('aria-label','BINGO Oman advertisement');
    wrap.innerHTML='<div id="bingoGlobalBanner" class="bingo-global-banner"></div>';
    const header=document.querySelector('header');
    if(header && header.parentNode) header.insertAdjacentElement('afterend',wrap);
    else document.body.insertAdjacentElement('afterbegin',wrap);
    mounted=true;
    return document.getElementById('bingoGlobalBanner');
  }

  function render(){
    const box=mount();
    if(timer){clearInterval(timer);timer=null;}
    if(!items.length){ box.innerHTML=''; box.parentElement.style.display='none'; return; }
    box.parentElement.style.display='block';
    const a=items[index%items.length];
    const url=resolveMediaUrl(a.media_url);
    if(!url){box.innerHTML='';return;}
    let media;
    if(String(a.media_type||'image').toLowerCase()==='video'){
      media='<video class="bingo-global-media" src="'+esc(url)+'" autoplay muted loop playsinline preload="auto"></video>';
    }else{
      media='<img class="bingo-global-media" src="'+esc(url)+'" alt="" loading="eager" decoding="async">';
    }
    const inner=a.link_url ? '<a class="bingo-global-link" href="'+esc(a.link_url)+'" target="_blank" rel="noopener noreferrer">'+media+'</a>' : media;
    box.innerHTML='<div class="bingo-global-slide">'+inner+'</div>';
    const video=box.querySelector('video');
    if(video){video.muted=true; const p=video.play(); if(p&&p.catch)p.catch(()=>{});}
    if(items.length>1) timer=setInterval(()=>{index=(index+1)%items.length;render();},6000);
  }

  function isActive(a){
    const now=Date.now();
    const start=a.starts_at?Date.parse(a.starts_at):-Infinity;
    const end=a.ends_at?Date.parse(a.ends_at):Infinity;
    return (!Number.isFinite(start)||start<=now) && (!Number.isFinite(end)||now<=end) && !!a.media_url;
  }

  async function queryDirect(){
    const client=window.sb;
    if(!client || !client.from) throw new Error('Supabase client not ready');
    return await client.from('site_banners')
      .select('id,media_type,media_url,link_url,sort_order,created_at,starts_at,ends_at,status')
      .eq('status','published')
      .order('sort_order',{ascending:true})
      .order('created_at',{ascending:false});
  }

  async function load(){
    mount();
    for(let attempt=0; attempt<6; attempt++){
      try{
        if(!window.sb || !window.sb.from){ await new Promise(r=>setTimeout(r,500)); continue; }
        const result=await queryDirect();
        if(result.error) throw result.error;
        items=(result.data||[]).filter(isActive);
        console.log('[BINGO Banner] loaded:',items.length);
        render();
        return;
      }catch(e){
        console.warn('[BINGO Banner] load attempt '+(attempt+1)+':',e.message||e);
        await new Promise(r=>setTimeout(r,700));
      }
    }
    render();
  }

  function init(){
    mount();
    load();
  }
  if(document.readyState==='loading') document.addEventListener('DOMContentLoaded',init,{once:true});
  else init();
})();
