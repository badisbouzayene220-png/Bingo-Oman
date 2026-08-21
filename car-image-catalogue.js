/* BINGO Oman — lightweight real car thumbnails. First batch: Toyota. */
(function(){
  const commons=file=>'https://commons.wikimedia.org/wiki/Special:FilePath/'+encodeURIComponent(file)+'?width=240';
  window.BINGO_CAR_IMAGES={
    brands:{
      'Toyota':commons('Toyota logo.svg')
    },
    models:{
      'Toyota':{
        'Land Cruiser':commons('Toyota Land Cruiser 300.jpg'),
        'Camry':commons('Toyota Camry (XV70) IMG 1999.jpg'),
        'Corolla':commons('2019 Toyota Corolla Hatchback SE front 4.2.18.jpg'),
        'Hilux':commons('Toyota Hilux (facelift) front.jpg'),
        'RAV4':commons('Toyota RAV4 2019 (XA50) CUV Quarter Front.jpg')
      }
    }
  };
})();
