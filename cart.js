(function(){
  "use strict";
  function read(){try{return JSON.parse(localStorage.getItem("bingo_cart")||"[]")}catch(e){return []}}
  function save(c){localStorage.setItem("bingo_cart",JSON.stringify(c));updateCount();render()}
  function money(v){return Number(v||0).toLocaleString("en-OM",{minimumFractionDigits:3,maximumFractionDigits:3})+" OMR"}
  function esc(s){return String(s??"").replace(/[&<>'"]/g,c=>({"&":"&amp;","<":"&lt;",">":"&gt;","'":"&#39;",'"':"&quot;"}[c]))}
  function t(en,ar){return (window.BingoLang&&window.BingoLang.get&&window.BingoLang.get()==="ar")?ar:en}
  function ensure(){
    if(document.getElementById("bingoCartOverlay")) return;
    const el=document.createElement("div");
    el.id="bingoCartOverlay"; el.className="bingo-cart-overlay"; el.innerHTML=
      '<aside class="bingo-cart-drawer" role="dialog" aria-modal="true" aria-labelledby="bingoCartTitle">'+
      '<div class="bingo-cart-head"><h2 id="bingoCartTitle"></h2><button class="bingo-cart-close" type="button" aria-label="Close">×</button></div>'+
      '<div class="bingo-cart-items" id="bingoCartItems"></div>'+
      '<div class="bingo-cart-foot"><div class="bingo-cart-total"><span id="bingoCartTotalLabel"></span><span id="bingoCartTotal"></span></div><a class="btn primary" id="bingoCartCheckout" href="checkout.html" style="width:100%;box-sizing:border-box;text-align:center"></a></div>'+
      '</aside>';
    document.body.appendChild(el);
    el.addEventListener("click",e=>{if(e.target===el)close()});
    el.querySelector(".bingo-cart-close").addEventListener("click",close);
    document.addEventListener("keydown",e=>{if(e.key==="Escape")close()});
  }
  function updateCount(){
    const count=read().reduce((n,x)=>n+Number(x.quantity||0),0);
    document.querySelectorAll("#cartCount").forEach(x=>x.textContent=count);
  }
  function render(){
    const el=document.getElementById("bingoCartOverlay"); if(!el)return;
    const items=read(), box=document.getElementById("bingoCartItems");
    document.getElementById("bingoCartTitle").textContent=t("Your cart","سلة المشتريات");
    document.getElementById("bingoCartTotalLabel").textContent=t("Total","الإجمالي");
    document.getElementById("bingoCartCheckout").textContent=t("Go to checkout","الانتقال إلى إتمام الطلب");
    if(!items.length){
      box.innerHTML='<div class="bingo-cart-empty"><p>'+esc(t("Your cart is empty.","سلة المشتريات فارغة."))+'</p><a class="btn small" href="store.html">'+esc(t("Browse products","تصفح المنتجات"))+'</a></div>';
      document.getElementById("bingoCartTotal").textContent=money(0);
      document.getElementById("bingoCartCheckout").style.display="none";
      return;
    }
    document.getElementById("bingoCartCheckout").style.display="block";
    box.innerHTML=items.map((x,i)=>'<div class="bingo-cart-item">'+
      '<div>'+(x.image_url?'<img src="'+esc(x.image_url)+'" alt="'+esc(x.title)+'">':'🛍️')+'</div>'+
      '<div><div class="bingo-cart-item-title">'+esc(x.title)+'</div><div class="bingo-cart-item-meta">'+Number(x.quantity||0)+' × '+money(x.price)+'</div></div>'+
      '<button class="bingo-cart-remove" type="button" data-remove="'+i+'">'+esc(t("Remove","حذف"))+'</button></div>').join("");
    box.querySelectorAll("[data-remove]").forEach(b=>b.addEventListener("click",()=>{const c=read();c.splice(Number(b.dataset.remove),1);save(c)}));
    const total=items.reduce((n,x)=>n+Number(x.price||0)*Number(x.quantity||0),0);
    document.getElementById("bingoCartTotal").textContent=money(total);
  }
  function open(){ensure();render();document.getElementById("bingoCartOverlay").classList.add("open");document.body.style.overflow="hidden"}
  function close(){const el=document.getElementById("bingoCartOverlay");if(!el)return;el.classList.remove("open");document.body.style.overflow=""}
  function bind(){
    ensure(); updateCount(); render();
    document.querySelectorAll(".bingo-cart-trigger").forEach(b=>{
      if(b.dataset.cartBound)return;
      b.dataset.cartBound="1";
      b.addEventListener("click",e=>{e.preventDefault();open()});
    });
  }
  window.BingoCart={open,close,add:function(item){
    const c=read(),x=c.find(i=>i.product_id===item.product_id);
    if(x)x.quantity+=Number(item.quantity||1);else c.push({...item,quantity:Number(item.quantity||1)});
    save(c);
  },update:updateCount};
  window.addEventListener("storage",updateCount);
  document.addEventListener("DOMContentLoaded",bind);
  window.setTimeout(bind,300);
})();