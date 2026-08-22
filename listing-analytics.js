(function(){'use strict';
function sessionKey(){let k=localStorage.getItem('bingo_analytics_session');if(!k){k='s_'+Date.now().toString(36)+'_'+Math.random().toString(36).slice(2);localStorage.setItem('bingo_analytics_session',k)}return k}
async function recordView(){const id=new URLSearchParams(location.search).get('id');if(!id||!window.sb?.rpc)return;try{await sb.rpc('record_listing_view',{p_listing_id:id,p_session_key:sessionKey()})}catch(e){console.warn('Listing view analytics:',e)}}
async function recordContact(id){if(!id||!window.sb?.rpc)return;try{await sb.rpc('record_listing_contact',{p_listing_id:id})}catch(e){console.warn('Listing contact analytics:',e)}}
window.BingoListingAnalytics={recordContact};
function wrapContact(){if(typeof window.contactSeller!=='function'||window.contactSeller.__bingoAnalyticsWrapped)return false;const original=window.contactSeller;const wrapped=async function(){const id=new URLSearchParams(location.search).get('id');await recordContact(id);return original.apply(this,arguments)};wrapped.__bingoAnalyticsWrapped=true;window.contactSeller=wrapped;return true}
function start(){recordView();let tries=0;const timer=setInterval(()=>{if(wrapContact()||++tries>40)clearInterval(timer)},250)}
if((location.pathname.split('/').pop()||'').toLowerCase()==='listing.html'){document.readyState==='loading'?document.addEventListener('DOMContentLoaded',start,{once:true}):start()}
})();