(function(){
  'use strict';
  if(location.pathname.endsWith('/admin.html')) return;
  let items=[], index=0, timer=null;

  function esc(s){return String(s??'').replace(/[&<>\'\"]/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;',"'":'&#39;','\"':'&quot;'}[c]));}

  function resolveMediaUrl(value){
    const raw=String(value||'').trim();
    if(!raw) return '';
    if(/^https?:\/\//i.test(raw) || /^data:/i.test(raw) || raw.startsWith('blob:')) return raw;
    try{
      const client=window.sb;
      if(client?.storage?.from){
        const path=raw.replace(/^\/+/, '').replace(/^bingo-banners\//,'');
        const {data}=client.storage.from('bingo-banners').getPublicUrl(path);
        if(data?.publicUrl) return data.publicUrl;
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
    if(header) header.insertAdjacentElement('afterend',wrap);
    else document.body.insertAdjacentElement('afterbegin',wrap);
    return document.getElementById('bingoGlobalBanner');
  }

  function normalize(row){
    return {
      ...row,
      media_type: String(row?.media_type||'image').toLowerCase()==='video'?'video':'image',
      media_url: row?.media_url || row?.image_url || row?.url || '',
      link_url: row?.link_url || row?.destination_url || null,
      starts_at: row?.starts_at || null,
      ends_at: row?.ends_at || null,
      sort_order: Number(row?.sort_order||0)
    };
  }

  function activeRows(data){
    const now=Date.now();
    return (Array.isArray(data)?data:[]).map(normalize).filter(a=>{
      const start=a.starts_at?new Date(a.starts_at).getTime():-Infinity;
      const end=a.ends_at?new Date(a.ends_at).getTime():Infinity;
      return a.media_url && start<=now && now<=end;
    }).sort((a,b)=>a.sort_order-b.sort_order);
  }

  function render(){
    const box=mount();
    clearInterval(timer);
    if(!items.length){box.innerHTML=''; return;}
    const a=items[index%items.length];
    const url=resolveMediaUrl(a.media_url);
    if(!url){box.innerHTML=''; return;}
    const media=a.media_type==='video'
      ? '<video class="bingo-global-media" src="'+esc(url)+'" autoplay muted loop playsinline preload="metadata"></video>'
      : '<img class="bingo-global-media" src="'+esc(url)+'" alt="" loading="eager" decoding="async">';
    const inner=a.link_url
      ? '<a class="bingo-global-link" href="'+esc(a.link_url)+'" target="_blank" rel="noopener noreferrer" aria-label="Advertisement">'+media+'</a>'
      : media;
    box.innerHTML='<div class="bingo-global-slide active">'+inner+'</div>';
    if(items.length>1) timer=setInterval(()=>{index=(index+1)%items.length;render();},6000);
    const video=box.querySelector('video');
    if(video){video.muted=true; video.play().catch(()=>{});}
  }

  async function load(){
    mount();
    const client=window.sb;
    if(!client?.from){console.warn('BINGO banner: Supabase client is unavailable'); return;}
    let data=null, error=null;
    // Preferred: a public security-definer RPC. This avoids RLS/schema-cache issues.
    try{
      const r=await client.rpc('get_public_site_banners');
      data=r.data; error=r.error;
    }catch(e){error=e;}
    // Fallback for installations that do not yet have the RPC.
    if(error){
      try{
        const r=await client.from('site_banners')
          .select('id,title,media_type,media_url,link_url,sort_order,created_at,starts_at,ends_at,status')
          .eq('status','published')
          .order('sort_order',{ascending:true})
          .order('created_at',{ascending:false});
        data=r.data; error=r.error;
      }catch(e){error=e;}
    }
    if(error){console.warn('BINGO global banners:',error); return;}
    items=activeRows(data);
    render();
  }

  function init(){mount(); load();}
  if(document.readyState==='loading') document.addEventListener('DOMContentLoaded',init); else init();
})();
