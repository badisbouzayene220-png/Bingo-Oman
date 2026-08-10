(function(){
  const C={
    main:{name:'بينجو',role:'الشخصية الرئيسية',message:'مرحباً بك في BINGO عمان! كيف يمكنني مساعدتك اليوم؟',img:'assets/characters/main.png'},
    women:{name:'بنجة',role:'التسوق والموضة',message:'اكتشفي الموضة، الجمال، المنزل والمنتجات النسائية بسهولة.',img:'assets/characters/women.png'},
    trader:{name:'تاجر بنجو',role:'البيع والتجارة',message:'جاهز للبيع؟ أضف إعلانك ووصل إلى مشترين من كل عُمان.',img:'assets/characters/trader.png'},
    services:{name:'خدمات بنجو',role:'الخدمات والحرف',message:'ابحث عن الخدمات، الوظائف والحرفيين الموثوقين.',img:'assets/characters/services.png'},
    fun:{name:'لولو بنجو',role:'العروض والترفيه',message:'عروض، خصومات وتنبيهات مميزة بانتظارك!',img:'assets/characters/fun.png'}
  };
  const p=location.pathname.toLowerCase();
  let current='main';
  if(p.includes('add-listing')||p.includes('dashboard')) current='trader';
  else if(p.includes('checkout')||p.includes('orders')) current='women';
  else if(p.includes('messages')||p.includes('admin')||p.includes('opportunity')) current='services';
  else if(p.includes('auctions')||p.includes('tenders')||p.includes('marketplace')||p.includes('product')||p.includes('listing')||p.includes('store')) current='trader';
  const html=`<div class="bingo-character-system" id="bingoCharacterSystem"><div class="bingo-character-card"><div class="bingo-character-head"><div class="bingo-character-brand">BINGO <span>OMAN</span></div><button class="bingo-character-close" id="bingoCharacterClose">×</button></div><div class="bingo-character-stage"><img id="bingoCharacterImg" class="bingo-character-img" src="${C[current].img}" alt="${C[current].name}"></div><div class="bingo-character-info"><div id="bingoCharacterName" class="bingo-character-name">${C[current].name}</div><div id="bingoCharacterRole" class="bingo-character-role">${C[current].role}</div></div><div id="bingoCharacterMessage" class="bingo-character-message">${C[current].message}</div><div class="bingo-character-switcher"><button class="bingo-character-btn" data-character="main">الرئيسية</button><button class="bingo-character-btn" data-character="women">النساء</button><button class="bingo-character-btn" data-character="trader">التجارة</button><button class="bingo-character-btn" data-character="services">الخدمات</button><button class="bingo-character-btn" data-character="fun">العروض</button></div></div><button class="bingo-character-minimized" id="bingoCharacterOpen"><img src="${C.main.img}" alt="BINGO"></button></div>`;
  function mount(){
    if(document.getElementById('bingoCharacterSystem')) return;
    document.body.insertAdjacentHTML('beforeend',html);
    const root=document.getElementById('bingoCharacterSystem'),img=document.getElementById('bingoCharacterImg'),name=document.getElementById('bingoCharacterName'),role=document.getElementById('bingoCharacterRole'),msg=document.getElementById('bingoCharacterMessage');
    function setCharacter(k){const c=C[k]; if(!c)return; current=k; img.classList.add('is-switching'); setTimeout(()=>{img.src=c.img;img.alt=c.name;name.textContent=c.name;role.textContent=c.role;msg.textContent=c.message;img.classList.remove('is-switching')},180);root.querySelectorAll('.bingo-character-btn').forEach(b=>b.classList.toggle('active',b.dataset.character===k));}
    setCharacter(current);
    root.querySelectorAll('.bingo-character-btn').forEach(b=>b.addEventListener('click',()=>setCharacter(b.dataset.character)));
    document.getElementById('bingoCharacterClose').onclick=()=>root.classList.add('minimized');
    document.getElementById('bingoCharacterOpen').onclick=()=>root.classList.remove('minimized');
    document.querySelectorAll('a[href*="add-listing"],a[href*="register"]').forEach(a=>a.addEventListener('mouseenter',()=>setCharacter('trader')));
  }
  if(document.readyState==='loading')document.addEventListener('DOMContentLoaded',mount);else mount();
})();
