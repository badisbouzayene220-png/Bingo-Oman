(function(){
'use strict';
if(!/bingo-delivery-customer\.html$/i.test(location.pathname)) return;
const $=s=>document.querySelector(s);
let currentOrderId=null;

function ensureStyles(){
  if($('#bingo-customer-code-style'))return;
  const s=document.createElement('style');s.id='bingo-customer-code-style';
  s.textContent='.bingo-customer-code{margin:16px 0;padding:18px;border-radius:20px;background:linear-gradient(135deg,#fff8ef,#fff);border:1px solid #f1dfcc;box-shadow:0 10px 30px rgba(90,63,35,.08);text-align:center}.bingo-customer-code small{color:#74685d}.bingo-customer-code h3{margin:5px 0 10px}.bingo-customer-code-value{display:flex;justify-content:center;gap:8px;direction:ltr;margin:12px 0}.bingo-customer-code-value span{width:48px;height:58px;display:grid;place-items:center;border-radius:14px;background:#fff;border:1px solid #ead9c8;font-size:30px;font-weight:950;color:#f47b20;box-shadow:0 5px 14px rgba(0,0,0,.05)}.bingo-customer-code-note{font-size:13px;line-height:1.6;color:#695f56}.bingo-customer-code.is-hidden{display:none}';
  document.head.appendChild(s);
}

function ensureCard(){
  if($('#bingo-customer-code'))return $('#bingo-customer-code');
  const card=document.createElement('section');card.id='bingo-customer-code';card.className='bingo-customer-code is-hidden';
  card.innerHTML='<small>BINGO Secure Handoff</small><h3>رمز استلام طلبك</h3><div class="bingo-customer-code-value" id="bingo-customer-code-value"><span>•</span><span>•</span><span>•</span><span>•</span></div><div class="bingo-customer-code-note" id="bingo-customer-code-note">أعطِ هذا الرمز للمندوب فقط عندما يكون الطلب معك.</div>';
  const main=document.querySelector('main')||document.body;
  const target=document.querySelector('.bd-main')||main;
  target.prepend(card);
  return card;
}

function renderCode(code){
  const card=ensureCard();
  if(!/^\d{4}$/.test(code||'')){card.classList.add('is-hidden');return;}
  $('#bingo-customer-code-value').innerHTML=code.split('').map(n=>'<span>'+n+'</span>').join('');
  card.classList.remove('is-hidden');
}

async function load(){
  if(!window.sb?.auth)return;
  try{
    const u=await window.sb.auth.getUser();if(!u.data?.user){ensureCard().classList.add('is-hidden');return;}
    const q=await window.sb.from('delivery_orders').select('id,status,created_at').in('status',['assigned','picked_up','on_delivery']).order('created_at',{ascending:false}).limit(1);
    if(q.error)throw q.error;
    const order=q.data?.[0];
    if(!order){currentOrderId=null;ensureCard().classList.add('is-hidden');return;}
    currentOrderId=order.id;
    const r=await window.sb.rpc('delivery_customer_bingo_code',{p_order_id:order.id});
    if(r.error)throw r.error;
    renderCode(String(r.data||''));
    const note=$('#bingo-customer-code-note');
    if(note)note.textContent=order.status==='on_delivery'?'المندوب في الطريق. أعطِ الرمز له فقط بعد استلام الطلب.':'احتفظ بالرمز حتى يصل المندوب.';
  }catch(e){console.warn('BINGO customer code unavailable',e);ensureCard().classList.add('is-hidden');}
}

function boot(){ensureStyles();ensureCard();load();setInterval(load,8000);}
if(document.readyState==='loading')document.addEventListener('DOMContentLoaded',boot,{once:true});else boot();
})();