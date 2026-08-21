(function(){
'use strict';
if(!/order-tracking\.html$/i.test(location.pathname))return;
if(document.querySelector('script[data-bingo-rating-v2]'))return;
const s=document.createElement('script');
s.src='bingo-order-rating-v2.js?v=20260821-2';
s.async=false;
s.dataset.bingoRatingV2='1';
document.head.appendChild(s);
})();