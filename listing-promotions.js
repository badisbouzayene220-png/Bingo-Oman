(function(){'use strict';
function active(x){return !!(x?.promotion_type&&x?.promotion_expires_at&&new Date(x.promotion_expires_at).getTime()>Date.now())}
function rank(x){if(!active(x))return 0;return x.promotion_type==='top'?3:x.promotion_type==='featured'?2:x.promotion_type==='highlight'?1:0}
function label(x){if(!active(x))return'';return x.promotion_type==='top'?'TOP AD':x.promotion_type==='featured'?'FEATURED':'HIGHLIGHT'}
function className(x){if(!active(x))return'';return 'bingo-'+x.promotion_type}
function remaining(x){if(!active(x))return'';const ms=new Date(x.promotion_expires_at).getTime()-Date.now(),h=Math.max(1,Math.ceil(ms/36e5));if(h<24)return h+'h left';const d=Math.ceil(h/24);return d+' day'+(d===1?'':'s')+' left'}
function sort(list){return [...list].sort((a,b)=>rank(b)-rank(a)||(new Date(b.promoted_at||b.bumped_at||b.created_at)-new Date(a.promoted_at||a.bumped_at||a.created_at)))}
window.BINGO_PROMOTIONS={active,rank,label,className,remaining,sort};
})();
