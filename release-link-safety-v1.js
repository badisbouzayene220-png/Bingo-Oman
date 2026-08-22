(function(){'use strict';
function fixEmptyAdLinks(){document.querySelectorAll('#ads a[href="#"],#ads a[href$="/#"]').forEach(a=>{a.removeAttribute('href');a.removeAttribute('target');a.style.cursor='default';a.setAttribute('aria-disabled','true')})}
if(document.readyState==='loading')document.addEventListener('DOMContentLoaded',()=>{fixEmptyAdLinks();setTimeout(fixEmptyAdLinks,800)},{once:true});else{fixEmptyAdLinks();setTimeout(fixEmptyAdLinks,800)}
document.addEventListener('bingo:ads-updated',fixEmptyAdLinks);
})();