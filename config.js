window.BINGO_CONFIG={SUPABASE_URL:"https://ekjrizhsviftjiuumapg.supabase.co",SUPABASE_PUBLISHABLE_KEY:"sb_publishable_duAz3JsRhOyE1oyTlo69SA_R2nOY84"};
(function(){
  function css(h){if(document.querySelector('link[href="'+h+'"]'))return;const l=document.createElement('link');l.rel='stylesheet';l.href=h;document.head.appendChild(l);}
  function js(s,id){if(document.getElementById(id)||document.querySelector('script[src="'+s+'"]'))return;const x=document.createElement('script');x.id=id;x.src=s;x.defer=false;document.head.appendChild(x);}
  css('bingo-ui.css');
  js('bingo-page-i18n.js','bingo-page-i18n-loader');

  function addSummary(){
    if(!location.pathname.endsWith('bingo-delivery-admin.html')) return;
    const earnings=document.querySelector('#earnings');
    if(!earnings) return;
    let box=document.querySelector('#delivery-earnings-summary');
    if(!box){
      box=document.createElement('div');
      box.id='delivery-earnings-summary';
      box.style.cssText='display:grid;grid-template-columns:repeat(auto-fit,minmax(160px,1fr));gap:12px;margin:14px 0';
      const section=earnings.closest('.bd-card')||earnings.parentElement;
      section.parentNode.insertBefore(box,section);
    }
    const totals={pending:0,approved:0,paid:0,total:0};
    [...earnings.querySelectorAll('tr')].forEach(tr=>{
      const cells=[...tr.children];
      if(cells.length<4)return;
      const status=(cells[3].textContent||'').trim().toLowerCase();
      const raw=(cells[2].textContent||'').replace(/[^0-9.\-]/g,'');
      const amount=Number(raw||0);
      if(!Number.isFinite(amount))return;
      if(Object.prototype.hasOwnProperty.call(totals,status))totals[status]+=amount;
      totals.total+=amount;
    });
    const card=(title,value,cls)=>`<div class="bd-card" style="margin:0"><div style="opacity:.7">${title}</div><div style="font-size:24px;font-weight:800" class="${cls||''}">${value.toFixed(3)} OMR</div></div>`;
    box.innerHTML=card('Pending',totals.pending,'warning')+card('Approved',totals.approved,'warning')+card('Paid',totals.paid,'success')+card('الإجمالي',totals.total,'');
  }
  document.addEventListener('DOMContentLoaded',()=>{addSummary();new MutationObserver(addSummary).observe(document.body,{childList:true,subtree:true});});
})();