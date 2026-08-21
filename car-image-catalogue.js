/* BINGO Oman — lightweight car thumbnails. */
(function(){
  const commons=file=>'https://commons.wikimedia.org/wiki/Special:FilePath/'+encodeURIComponent(file)+'?width=240';
  window.BINGO_CAR_IMAGES={
    brands:{
      'Toyota':commons('Toyota logo.svg'),
      'Lexus':commons('Lexus logo.svg'),
      'Nissan':commons('Nissan Motor Corporation 2020 logo.svg')
    },
    models:{
      'Toyota':{
        'Land Cruiser':commons('Toyota Land Cruiser 300.jpg'),
        'Camry':commons('Toyota Camry (XV70) IMG 1999.jpg'),
        'Corolla':commons('2019 Toyota Corolla Hatchback SE front 4.2.18.jpg'),
        'Hilux':commons('Toyota Hilux (facelift) front.jpg'),
        'RAV4':commons('Toyota RAV4 2019 (XA50) CUV Quarter Front.jpg')
      },
      'Lexus':{
        'IS':commons('2006 Lexus IS 350 17 (5492833566).jpg'),
        'GS':commons('2012 Lexus GS350 F-Sport - Flickr - Moto@Club4AG (4).jpg'),
        'ES':commons('2019 Lexus ES 250 Premium (3).jpg'),
        'NX':commons('2019 Lexus NX 300 F Sport (16).jpg'),
        'LS':commons('Lexus LS 500h GVF50 Obsidian (6).jpg'),
        'LC':commons('Lexus LC500h CN-Spec in Tianhe 03.jpg')
      },
      'Nissan':{
        'Maxima':commons('Nissan Maxima granate (3).jpg'),
        '370Z':commons('NISSAN 370Z (3106407273).jpg'),
        'Z':commons('NISSAN 370Z (3106407273).jpg')
      },
      'Infiniti':{
        'QX80':commons('Infiniti QX80.jpg')
      },
      'Mitsubishi':{
        'Pajero':commons('Mitsubishi Pajero.jpg'),
        'Montero':commons('Mitsubishi Pajero.jpg')
      },
      'Hyundai':{
        'Tucson':commons('Hyundai Tucson.jpg')
      },
      'Kia':{
        'Sportage':commons('Kia Sportage V 001.jpg')
      }
    }
  };
})();
