(function(){'use strict';
function active(x){return x?.promotion_type&&x?.promotion_expires_at&&new Date(x.promotion_expires_at).getTime()>Date.now()}
function rank(x){if(!active(x))return 0;return x.promotion_type==='top'?3:x.promotion_type==='featured'?2:x.promotion_type==='highlight'?1:0}
window.BINGO_PROMOTIONS={active,rank,label(x){if(!active(x))return'';return x.promotion_type==='top'?'TOP AD':x.promotion_type==='featured'?'FEATURED':'HIGHLIGHT'},className(x){if(!active(x))return'';return 'bingo-'+x.promotion_type},sort(list){return [...list].sort((a,b)=>rank(b)-rank(a)||(new Date(b.bumped_at||b.created_at)-new Date(a.bumped_at||a.created_at)))}};
})();
