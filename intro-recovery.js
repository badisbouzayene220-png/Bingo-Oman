(function(){
'use strict';
function hideIntro(){const intro=document.getElementById('bingoIntro');if(!intro)return;intro.classList.add('is-hidden');intro.style.pointerEvents='none';setTimeout(()=>{if(intro)intro.style.display='none'},760)}
function ensure(){const intro=document.getElementById('bingoIntro');if(!intro)return;
  let style=document.getElementById('bingo-intro-recovery-style');if(!style){style=document.createElement('style');style.id='bingo-intro-recovery-style';style.textContent=`
  #bingoIntro .cinematic-stage{z-index:5!important;overflow:visible!important;min-height:560px!important}
  #bingoIntro .cinematic-logo{z-index:12!important}
  #bingoIntro .cinematic-mascot{z-index:13!important}
  #bingoIntro .cinematic-copy{z-index:14!important}
  #bingoIntro .cinematic-actions{z-index:15!important}
  #bingoIntro .oman-map-wrap,#bingoIntro .service-ring{z-index:7!important}
  #bingoIntro .intro-skip{z-index:999!important;opacity:1!important;visibility:visible!important;display:inline-flex!important}
  #bingoIntro.bingo-intro-recovered .cinematic-logo,
  #bingoIntro.bingo-intro-recovered .cinematic-mascot,
  #bingoIntro.bingo-intro-recovered .cinematic-copy,
  #bingoIntro.bingo-intro-recovered .cinematic-actions{opacity:1!important;visibility:visible!important;filter:none!important;animation:none!important}
  #bingoIntro.bingo-intro-recovered .cinematic-logo{transform:translate(-13%,-34%) scale(.72)!important}
  #bingoIntro.bingo-intro-recovered .cinematic-mascot{transform:none!important}
  #bingoIntro.bingo-intro-recovered .cinematic-copy,#bingoIntro.bingo-intro-recovered .cinematic-actions{transform:none!important}
  @media(max-width:640px){#bingoIntro.bingo-intro-recovered .cinematic-logo{transform:none!important;top:26%!important;width:min(300px,70vw)!important}.cinematic-stage{min-height:620px!important}}
  `;document.head.appendChild(style)}
  const skip=document.getElementById('skipIntro');if(skip&&!skip.dataset.recoveryBound){skip.dataset.recoveryBound='1';skip.addEventListener('click',hideIntro)}
  setTimeout(()=>{const logo=intro.querySelector('.cinematic-logo'),copy=intro.querySelector('.cinematic-copy'),mascot=intro.querySelector('.cinematic-mascot');if(!intro.classList.contains('is-hidden')&&logo&&copy&&mascot){const ls=getComputedStyle(logo),cs=getComputedStyle(copy);if(Number(ls.opacity)<.35||Number(cs.opacity)<.35||logo.getBoundingClientRect().width<20){intro.classList.add('bingo-intro-recovered')}}},3300);
  setTimeout(()=>{if(!intro.classList.contains('is-hidden'))intro.classList.add('bingo-intro-recovered')},4400);
  setTimeout(()=>{if(!intro.classList.contains('is-hidden'))hideIntro()},6800);
}
if(document.readyState==='loading')document.addEventListener('DOMContentLoaded',()=>setTimeout(ensure,80));else setTimeout(ensure,80);
window.addEventListener('load',()=>setTimeout(ensure,120),{once:true});
})();