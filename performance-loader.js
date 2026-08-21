(function(){'use strict';
const ABOVE_FOLD_SELECTOR='header img,.header img,.main-logo img,.logo img,#headerLogo,.hero img,.bingo-intro img,.intro img,[data-eager-image]';
function tuneImage(img){if(!(img instanceof HTMLImageElement))return;img.decoding='async';if(img.matches(ABOVE_FOLD_SELECTOR)){if(!img.loading)img.loading='eager';try{img.fetchPriority='high'}catch(e){}return;}if(!img.loading)img.loading='lazy';try{if(!img.fetchPriority)img.fetchPriority='low'}catch(e){}}
function tuneVideo(v){if(!(v instanceof HTMLVideoElement))return;if(!v.hasAttribute('preload')||v.getAttribute('preload')==='auto')v.setAttribute('preload','metadata');if(!v.hasAttribute('playsinline'))v.setAttribute('playsinline','');}
function scan(root=document){root.querySelectorAll?.('img').forEach(tuneImage);root.querySelectorAll?.('video').forEach(tuneVideo);}
function boot(){scan();const mo=new MutationObserver(list=>{for(const m of list){for(const n of m.addedNodes){if(n.nodeType!==1)continue;if(n.tagName==='IMG')tuneImage(n);else if(n.tagName==='VIDEO')tuneVideo(n);scan(n)}}});mo.observe(document.documentElement,{childList:true,subtree:true});window.addEventListener('pagehide',()=>mo.disconnect(),{once:true});}
if(document.readyState==='loading')document.addEventListener('DOMContentLoaded',boot,{once:true});else boot();
})();