window.BINGO_CONFIG={SUPABASE_URL:"https://ekjrizhsviftjiuumapg.supabase.co",SUPABASE_PUBLISHABLE_KEY:"sb_publishable_duAz3JsRhOyE1oyTlo69SA_R2n1OY84"};
(function(){
  function css(h){if(document.querySelector('link[href="'+h+'"]'))return;const l=document.createElement('link');l.rel='stylesheet';l.href=h;document.head.appendChild(l);}
  function js(s,id){if(document.getElementById(id)||document.querySelector('script[src="'+s+'"]'))return;const x=document.createElement('script');x.id=id;x.src=s;x.defer=false;document.head.appendChild(x);}
  css('bingo-ui.css');
  if(/(?:^|\/)(?:bingo-delivery-seller|bingo-delivery-driver)\.html$/i.test(location.pathname)){
    css('bingo-delivery-modern-v1.css?v=20260822-1');
    css('bingo-delivery-modern-v2.css?v=20260822-1');
    js('bingo-delivery-modern-v2.js?v=20260822-1','bingo-delivery-modern-v2-loader');
  }
  // Heavy page-wide translator is only needed in ERP/HR/Admin areas.
  // Loading it on Home caused a full DOM rescan after every dynamic widget mount.
  if(/(?:^|\/)(?:erp|hr|admin)\.html$/i.test(location.pathname)){
    js('bingo-page-i18n.js','bingo-page-i18n-loader');
  }
  if(/(?:^|\/)admin\.html$/i.test(location.pathname)){
    js('admin-product-seller-link.js?v=20260820-1','admin-product-seller-link-loader');
    js('admin-listing-promotions.js?v=20260822-4','admin-listing-promotions-loader');
  }
  if(/(?:^|\/)marketplace\.html$/i.test(location.pathname)){
    js('marketplace-promotions-zone.js?v=20260822-1','marketplace-promotions-zone-loader');
  }
  if(/(?:^|\/)listing\.html$/i.test(location.pathname)){
    js('listing-analytics.js?v=20260822-2','listing-analytics-loader');
  }
  if(/(?:^|\/)dashboard\.html$/i.test(location.pathname)){
    js('dashboard-listing-analytics.js?v=20260822-1','dashboard-listing-analytics-loader');
  }

  // Delivery Control: load order quantity/unit details without replacing the page itself.
  if(/(?:^|\/)bingo-delivery-control\.html$/i.test(location.pathname)){
    js('bingo-order-units-v1.js?v=20260822-1','bingo-order-units-loader');
    js('bingo-admin-order-items-v1.js?v=20260822-1','bingo-admin-order-items-loader');
  }

  // Delivery admin driver management is handled entirely by bingo-delivery-admin.html.
  // Do NOT load admin-driver-management.js here: it reads delivery_drivers directly
  // and can overwrite the RPC-rendered table while RLS is enabled.

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
    const signature=[totals.pending,totals.approved,totals.paid,totals.total].join('|');
    if(box.dataset.signature===signature)return;
    box.dataset.signature=signature;
    const card=(title,value,cls)=>`<div class="bd-card" style="margin:0"><div style="opacity:.7">${title}</div><div style="font-size:24px;font-weight:800" class="${cls||''}">${value.toFixed(3)} OMR</div></div>`;
    box.innerHTML=card('Pending',totals.pending,'warning')+card('Approved',totals.approved,'warning')+card('Paid',totals.paid,'success')+card('الإجمالي',totals.total,'');
  }
  document.addEventListener('DOMContentLoaded',()=>{
    if(!location.pathname.endsWith('bingo-delivery-admin.html')) return;
    addSummary();
    new MutationObserver(addSummary).observe(document.body,{childList:true,subtree:true});
  });
})();