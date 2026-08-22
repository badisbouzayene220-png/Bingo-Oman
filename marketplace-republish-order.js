(function(){
'use strict';
const page=(location.pathname.split('/').pop()||'').toLowerCase();if(page!=='marketplace.html')return;
async function apply(){if(!window.sb||!Array.isArray(window.allListings))return false;try{const {data,error}=await sb.from('listings').select('id,bumped_at').eq('status','published');if(error)return true;const map=new Map((data||[]).map(x=>[x.id,new Date(x.bumped_at||0).getTime()]));allListings.sort((a,b)=>(map.get(b.id)||new Date(b.created_at||0).getTime())-(map.get(a.id)||new Date(a.created_at||0).getTime()));if(document.getElementById('sort')?.value==='newest'&&typeof window.render==='function')window.render();return true}catch{return true}}
function boot(){let tries=0;const t=setInterval(async()=>{tries++;if(await apply()||tries>50)clearInterval(t)},120)}
document.readyState==='loading'?document.addEventListener('DOMContentLoaded',boot,{once:true}):boot();
})();
