(function(){
  'use strict';
  const images={
    'muscat':'assets/oman/muscat-grand-mosque.jpg',
    'nizwa':'assets/oman/nizwa-fort.jpg',
    'salalah':'assets/oman/salalah-beach.jpg',
    'sur':'assets/oman/sur.jpg',
    'jabal-akhdar':'assets/oman/jabal-akhdar.jpg',
    'al-batinah-north':'https://commons.wikimedia.org/wiki/Special:FilePath/Liwa%20North%20Al%20Batinah%20Governorate%20Municipality%20in%202025.jpg?width=1600',
    'al-batinah-south':'https://commons.wikimedia.org/wiki/Special:FilePath/Rustaq%20flickr01.jpg?width=1600',
    'al-dakhiliyah':'assets/oman/nizwa-fort.jpg',
    'al-dhahirah':'https://commons.wikimedia.org/wiki/Special:FilePath/Ibri%2C%20Oman%20%282013%29.jpg?width=1600',
    'al-buraimi':'https://commons.wikimedia.org/wiki/Special:FilePath/A%20mosque%20in%20the%20Buraimi%20Oasis.jpg?width=1600',
    'dhofar':'assets/oman/salalah-beach.jpg',
    'north-al-sharqiyah':'https://commons.wikimedia.org/wiki/Special:FilePath/Wadi%20Bani%20Khalid%2C%20Oman.jpg?width=1600',
    'south-al-sharqiyah':'assets/oman/sur.jpg',
    'musandam':'https://commons.wikimedia.org/wiki/Special:FilePath/Khasab%20view.jpg?width=1600',
    'al-wusta':'https://commons.wikimedia.org/wiki/Special:FilePath/%D9%85%D9%8A%D9%86%D8%A7%D8%A1%20%D8%A7%D9%84%D8%AF%D9%82%D9%85%20%D8%A7%D9%84%D8%AC%D8%AF%D9%8A%D8%AF.jpg?width=1600'
  };
  function apply(){
    const key=new URLSearchParams(location.search).get('place')||'muscat';
    const src=images[key]; if(!src) return;
    const img=document.querySelector('.place-hero img');
    if(!img) return;
    img.src=src;
    img.loading='eager'; img.decoding='async';
    img.addEventListener('error',function(){ if(!this.dataset.fallback){this.dataset.fallback='1';this.src='assets/oman/muscat-grand-mosque.jpg';} });
  }
  if(document.readyState==='loading') document.addEventListener('DOMContentLoaded',apply); else apply();
  setTimeout(apply,250);
})();
