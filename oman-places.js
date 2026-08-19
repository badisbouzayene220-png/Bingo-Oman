(function(){
  'use strict';
  const path=location.pathname.replace(/\/+$/,'');
  if(path && !/\/(index\.html)?$/i.test(path)) return;

  const places={
    'muscat':{img:'assets/oman/muscat-grand-mosque.jpg',label:'مسقط',credit:''},
    'al-batinah-north':{img:'https://commons.wikimedia.org/wiki/Special:FilePath/Liwa%20North%20Al%20Batinah%20Governorate%20Municipality%20in%202025.jpg?width=1000',label:'شمال الباطنة',credit:'Wikimedia Commons'},
    'al-batinah-south':{img:'https://commons.wikimedia.org/wiki/Special:FilePath/Rustaq%20flickr01.jpg?width=1000',label:'جنوب الباطنة',credit:'Wikimedia Commons'},
    'al-dakhiliyah':{img:'assets/oman/nizwa-fort.jpg',label:'الداخلية',credit:''},
    'al-dhahirah':{img:'https://commons.wikimedia.org/wiki/Special:FilePath/Ibri%2C%20Oman%20%282013%29.jpg?width=1000',label:'الظاهرة',credit:'Wikimedia Commons'},
    'al-buraimi':{img:'https://commons.wikimedia.org/wiki/Special:FilePath/A%20mosque%20in%20the%20Buraimi%20Oasis.jpg?width=1000',label:'البريمي',credit:'Wikimedia Commons'},
    'dhofar':{img:'assets/oman/salalah-beach.jpg',label:'ظفار',credit:''},
    'north-al-sharqiyah':{img:'https://commons.wikimedia.org/wiki/Special:FilePath/Wadi%20Bani%20Khalid%2C%20Oman.jpg?width=1000',label:'شمال الشرقية',credit:'Wikimedia Commons'},
    'south-al-sharqiyah':{img:'assets/oman/sur.jpg',label:'جنوب الشرقية',credit:''},
    'musandam':{img:'https://commons.wikimedia.org/wiki/Special:FilePath/Khasab%20view.jpg?width=1000',label:'مسندم',credit:'Wikimedia Commons'},
    'al-wusta':{img:'https://commons.wikimedia.org/wiki/Special:FilePath/%D9%85%D9%8A%D9%86%D8%A7%D8%A1%20%D8%A7%D9%84%D8%AF%D9%82%D9%85%20%D8%A7%D9%84%D8%AC%D8%AF%D9%8A%D8%AF.jpg?width=1000',label:'الوسطى',credit:'Wikimedia Commons'}
  };

  function slugFrom(link){
    try{return new URL(link.href,location.href).searchParams.get('place')||'';}catch(e){return'';}
  }

  function init(){
    const links=[...document.querySelectorAll('a[href*="place.html?place="]')].filter(a=>places[slugFrom(a)] && !a.classList.contains('hero-photo-main') && !a.classList.contains('hero-photo-mini'));
    if(links.length<8) return;
    const parent=links[0].parentElement;
    if(!parent) return;
    parent.classList.add('oman-governorates-photo-grid');

    if(!document.getElementById('oman-governorate-photo-style')){
      const style=document.createElement('style');
      style.id='oman-governorate-photo-style';
      style.textContent=`
      .oman-governorates-photo-grid{display:grid!important;grid-template-columns:repeat(4,minmax(0,1fr))!important;gap:14px!important;border:0!important;background:transparent!important;overflow:visible!important}
      .oman-governorates-photo-grid>a.gov-photo-card{position:relative!important;display:block!important;min-height:190px!important;padding:0!important;border:0!important;border-radius:18px!important;overflow:hidden!important;background:#092a82!important;box-shadow:0 10px 28px rgba(6,26,80,.10)!important;isolation:isolate!important;transition:transform .25s ease,box-shadow .25s ease!important}
      .gov-photo-card .gov-photo{position:absolute;inset:0;display:block}.gov-photo-card .gov-photo img{width:100%;height:100%;object-fit:cover;display:block;transition:transform .45s ease}.gov-photo-card:after{content:"";position:absolute;inset:0;background:linear-gradient(180deg,rgba(3,16,42,.02) 28%,rgba(3,16,42,.84) 100%);z-index:1}.gov-photo-card>b,.gov-photo-card>span:not(.gov-photo):not(.gov-credit){position:relative;z-index:2;display:block!important;margin:0!important;padding-left:16px!important;padding-right:16px!important;color:#fff!important;text-shadow:0 2px 10px rgba(0,0,0,.35)}.gov-photo-card>b{position:absolute!important;left:0;right:0;bottom:34px;font-size:15px!important}.gov-photo-card>span:not(.gov-photo):not(.gov-credit){position:absolute!important;left:0;right:0;bottom:15px;font-size:10px!important;color:#dce6f7!important}.gov-photo-card .gov-credit{position:absolute;z-index:3;top:9px;right:9px;font-size:8px;color:#fff;background:rgba(0,0,0,.38);padding:4px 6px;border-radius:999px;backdrop-filter:blur(5px)}
      .gov-photo-card:hover{transform:translateY(-4px)!important;box-shadow:0 18px 38px rgba(6,26,80,.18)!important}.gov-photo-card:hover .gov-photo img{transform:scale(1.055)}
      @media(max-width:1000px){.oman-governorates-photo-grid{grid-template-columns:repeat(3,minmax(0,1fr))!important}}
      @media(max-width:700px){.oman-governorates-photo-grid{grid-template-columns:repeat(2,minmax(0,1fr))!important;gap:10px!important}.oman-governorates-photo-grid>a.gov-photo-card{min-height:155px!important;border-radius:15px!important}.gov-photo-card>b{font-size:13px!important;bottom:31px}.gov-photo-card>span:not(.gov-photo):not(.gov-credit){font-size:9px!important;bottom:13px}}
      @media(max-width:420px){.oman-governorates-photo-grid{grid-template-columns:1fr!important}.oman-governorates-photo-grid>a.gov-photo-card{min-height:180px!important}}
      `;
      document.head.appendChild(style);
    }

    links.forEach(link=>{
      const slug=slugFrom(link),data=places[slug];
      link.classList.add('gov-photo-card');
      if(link.querySelector('.gov-photo')) return;
      const photo=document.createElement('span');photo.className='gov-photo';
      const img=document.createElement('img');img.src=data.img;img.alt=data.label+'، سلطنة عُمان';img.loading='lazy';img.decoding='async';
      img.addEventListener('error',()=>{img.src='assets/oman/muscat-grand-mosque.jpg';});
      photo.appendChild(img);link.prepend(photo);
      if(data.credit){const credit=document.createElement('span');credit.className='gov-credit';credit.textContent=data.credit;link.appendChild(credit);}
    });
  }
  if(document.readyState==='loading')document.addEventListener('DOMContentLoaded',init);else init();
})();
