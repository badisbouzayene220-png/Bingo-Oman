(function(){'use strict';
function tune(root){const imgs=(root||document).querySelectorAll?root.querySelectorAll('img'):[];imgs.forEach((img,i)=>{if(!img.hasAttribute('decoding'))img.decoding='async';if(!img.hasAttribute('loading')&&!img.closest('.hero,.header,.pagehead,.authbrand')&&i>1)img.loading='lazy';});}
function boot(){tune(document);let runs=0;const timer=setInterval(()=>{tune(document);if(++runs>=6)clearInterval(timer)},700);document.addEventListener('bingo:cart-updated',()=>tune(document));}
if(document.readyState==='loading')document.addEventListener('DOMContentLoaded',boot,{once:true});else boot();
})();