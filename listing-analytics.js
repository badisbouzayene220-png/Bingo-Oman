(function(){'use strict';
function sessionKey(){let k=localStorage.getItem('bingo_analytics_session');if(!k){k='s_'+Date.now().toString(36)+'_'+Math.random().toString(36).slice(2);localStorage.setItem('bingo_analytics_session',k)}return k}
async function recordView(){const id=new URLSearchParams(location.search).get('id');if(!id||!window.sb?.rpc)return;try{await sb.rpc('record_listing_view',{p_listing_id:id,p_session_key:sessionKey()})}catch(e){console.warn('Listing view analytics:',e)}}
window.BingoListingAnalytics={recordContact:async function(id){if(!id||!window.sb?.rpc)return;try{await sb.rpc('record_listing_contact',{p_listing_id:id})}catch(e){console.warn('Listing contact analytics:',e)}}};
if((location.pathname.split('/').pop()||'').toLowerCase()==='listing.html'){document.readyState==='loading'?document.addEventListener('DOMContentLoaded',recordView,{once:true}):recordView()}
})();