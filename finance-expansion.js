/* BINGO Oman ERP Finance Expansion — Suppliers & Purchases */
(function(){
  const E=window.esc||((s)=>String(s??'').replace(/&/g,'&amp;').replace(/</g,'&lt;').replace(/>/g,'&gt;').replace(/\"/g,'&quot;').replace(/'/g,'&#39;'));
  const M=window.money||((n)=>Number(n||0).toLocaleString('en-OM',{minimumFractionDigits:3,maximumFractionDigits:3})+' OMR');
  let suppliers=[];
  let purchaseLines=[];
  window.suppliers=suppliers;
  window.purchaseLines=purchaseLines;

  async function fx(name,args={}){const {data,error}=await sb.rpc(name,args);if(error)throw error;return data}
  function rows(x){return Array.isArray(x)?x:(x? [x]:[])}
  function status(s){const labels={draft:'مسودة',received:'مستلمة',partially_paid:'مدفوعة جزئياً',paid:'مدفوعة',cancelled:'ملغاة'};return `<span class="badge b-${E(s)}">${E(labels[s]||s)}</span>`}

  window.loadSuppliers=async function(){
    try{
      const d=await fx('erp_list_suppliers',{p_search:$('supplierSearch')?.value||null});
      suppliers=rows(d); window.suppliers=suppliers;
      $('supplierTable').innerHTML=!suppliers.length?'<div class="notice">لا يوجد موردون.</div>':`<div class="fin-table-wrap"><table class="fin-table"><thead><tr><th>الكود</th><th>المورد</th><th>الهاتف</th><th>الرقم الضريبي</th><th>إجمالي المشتريات</th><th>المدفوع</th><th>المتبقي</th><th>الحالة</th><th>إجراءات</th></tr></thead><tbody>${suppliers.map(s=>`<tr class="${s.is_active?'':'supplier-disabled'}"><td>${E(s.supplier_code)}</td><td><b>${E(s.name)}</b>${s.contact_person?'<br><small>جهة الاتصال: '+E(s.contact_person)+'</small>':''}${s.company_name?'<br><small>'+E(s.company_name)+'</small>':''}</td><td>${E(s.phone||'—')}</td><td>${E(s.tax_number||'—')}</td><td><b>${M(s.purchased)}</b></td><td>${M(s.paid)}</td><td><b>${M(s.balance)}</b></td><td><span class="badge ${s.is_active?'b-received':'b-cancelled'}">${s.is_active?'نشط':'معطل'}</span></td><td style="white-space:nowrap"><button class="btnx" onclick="editSupplier('${s.id}')">تعديل</button> <button class="btnx" onclick="toggleSupplier('${s.id}',${s.is_active})">${s.is_active?'تعطيل':'تفعيل'}</button> <button class="btnx" onclick="deleteSupplier('${s.id}')">حذف</button></td></tr>`).join('')}</tbody></table></div>`;
    }catch(e){msg(e.message,'err')}
  };

  window.openSupplierModal=function(s){
    const modal=$('supplierModal');
    if(!modal){console.error('supplierModal not found');return;}
    s=s||null;
    ['suId','suName','suContact','suCompany','suPhone','suEmail','suTax','suCR','suCity','suAddress','suNotes'].forEach(id=>$(id).value='');
    $('suTerms').value=30;
    if(s){$('suId').value=s.id;$('suName').value=s.name||'';$('suContact').value=s.contact_person||'';$('suCompany').value=s.company_name||'';$('suPhone').value=s.phone||'';$('suEmail').value=s.email||'';$('suTax').value=s.tax_number||'';$('suCR').value=s.commercial_registration||'';$('suCity').value=s.city||'';$('suAddress').value=s.address||'';$('suNotes').value=s.notes||'';$('suTerms').value=s.payment_terms??30}
    modal.classList.add('open');
    document.body.classList.add('modal-open');
    setTimeout(()=>{$('suName')?.focus()},50);
  };
  window.editSupplier=function(id){openSupplierModal(suppliers.find(x=>x.id===id))};
  // Direct event binding: guarantees the '+ مورد جديد' button works even if inline handlers are restricted.
  document.addEventListener('click',function(ev){const b=ev.target.closest?.('[data-open-supplier]');if(b){ev.preventDefault();window.openSupplierModal();}});

  window.toggleSupplier=async function(id,isActive){
    const action=isActive?'تعطيل':'تفعيل';
    if(!confirm(`هل تريد ${action} هذا المورد؟`))return;
    try{await fx('erp_set_supplier_status',{p_supplier_id:id,p_is_active:!isActive});msg(isActive?'تم تعطيل المورد.':'تم تفعيل المورد.');loadSuppliers();if(window.loadPurchases)loadPurchases();}
    catch(e){msg(e.message,'err')}
  };
  window.deleteSupplier=async function(id){
    if(!confirm('سيتم حذف المورد نهائياً إذا لم تكن له مشتريات أو دفعات. هل تريد المتابعة؟'))return;
    try{await fx('erp_delete_supplier',{p_supplier_id:id});msg('تم حذف المورد نهائياً.');loadSuppliers();}
    catch(e){msg(e.message,'err')}
  };
  document.addEventListener('submit',async function(ev){
    if(ev.target.id!=='supplierForm')return;
    ev.preventDefault();
    try{
      await fx('erp_upsert_supplier',{p_supplier:{id:$('suId').value||null,name:$('suName').value,contact_person:$('suContact').value,company_name:$('suCompany').value,phone:$('suPhone').value,email:$('suEmail').value,tax_number:$('suTax').value,commercial_registration:$('suCR').value,city:$('suCity').value,address:$('suAddress').value,notes:$('suNotes').value,payment_terms:Number($('suTerms').value||30)}});
      closeModal('supplierModal');msg('تم حفظ المورد.');loadSuppliers();
    }catch(e){msg(e.message,'err')}
  });

  function supplierOptions(selected=''){return `<option value="">بدون مورد</option>`+suppliers.map(s=>`<option value="${s.id}" ${s.id===selected?'selected':''}>${E(s.name)}${s.company_name?' — '+E(s.company_name):''}</option>`).join('')}
  function productOptions(selected=''){return `<option value="">اختر المنتج</option>`+(window.products||products||[]).map(p=>`<option value="${p.id}" data-cost="${p.cost_price||0}" ${p.id===selected?'selected':''}>${E(p.sku||'')} — ${E(p.name)}</option>`).join('')}

  window.openPurchaseModal=async function(p){
    if(!suppliers.length)await loadSuppliers();
    $('puId').value=p?.id||'';$('puSupplier').innerHTML=supplierOptions(p?.supplier_id||'');
    $('puDate').value=p?.purchase_date||today();$('puDue').value=p?.due_date||'';$('puVat').value=p?.vat_rate??(settings.vat_rate??5);$('puNotes').value=p?.notes||'';$('puReceived').checked=p?.status==='received';
    purchaseLines=[]; window.purchaseLines=purchaseLines;
    if(p?.id){const items=rows(await fx('erp_get_purchase_items',{p_purchase_id:p.id}));purchaseLines=items.map(x=>({product_id:x.product_id||'',description:x.description||'',quantity:Number(x.quantity||1),unit_cost:Number(x.unit_cost||0),discount:Number(x.discount||0)}));}
    if(!purchaseLines.length)addPurchaseLine();else renderPurchaseLines();
    openModal('purchaseModal');
  };
  window.addPurchaseLine=function(){purchaseLines.push({product_id:'',description:'',quantity:1,unit_cost:0,discount:0});renderPurchaseLines()};
  window.removePurchaseLine=function(i){purchaseLines.splice(i,1);renderPurchaseLines()};
  window.syncPurchaseLine=function(i,field,val){
    purchaseLines[i][field]=field==='product_id'||field==='description'?val:Number(val||0);
    if(field==='product_id'){const p=(window.products||products||[]).find(x=>x.id===val);if(p){purchaseLines[i].description=p.name;purchaseLines[i].unit_cost=Number(p.cost_price||0)}}
    renderPurchaseLines();
  };
  function renderPurchaseLines(){
    const box=$('purchaseItems');if(!box)return;
    box.innerHTML=purchaseLines.map((x,i)=>`<div class="invoice-line" style="display:grid;grid-template-columns:2fr 2fr .8fr 1fr 1fr auto;gap:7px;align-items:end;margin-bottom:8px"><label>المنتج<select onchange="syncPurchaseLine(${i},'product_id',this.value)">${productOptions(x.product_id)}</select></label><label>الوصف<input value="${E(x.description)}" onchange="syncPurchaseLine(${i},'description',this.value)"></label><label>الكمية<input type="number" min=".001" step=".001" value="${x.quantity}" onchange="syncPurchaseLine(${i},'quantity',this.value)"></label><label>تكلفة الوحدة<input type="number" min="0" step=".001" value="${x.unit_cost}" onchange="syncPurchaseLine(${i},'unit_cost',this.value)"></label><label>الخصم<input type="number" min="0" step=".001" value="${x.discount}" onchange="syncPurchaseLine(${i},'discount',this.value)"></label><button type="button" class="btnx" onclick="removePurchaseLine(${i})">×</button></div>`).join('');
    const sub=purchaseLines.reduce((a,x)=>a+Number(x.quantity||0)*Number(x.unit_cost||0),0),disc=purchaseLines.reduce((a,x)=>a+Number(x.discount||0),0),tax=Math.max(sub-disc,0)*Number($('puVat')?.value||0)/100;
    $('puTotal').textContent=M(Math.max(sub-disc,0)+tax);
  }
  document.addEventListener('input',e=>{if(e.target.id==='puVat')renderPurchaseLines()});
  document.addEventListener('submit',async function(ev){
    if(ev.target.id!=='purchaseForm')return;
    ev.preventDefault();
    try{
      if(!purchaseLines.length)throw new Error('أضف منتجاً واحداً على الأقل.');
      const payload={id:$('puId').value||null,supplier_id:$('puSupplier').value||null,purchase_date:$('puDate').value,due_date:$('puDue').value||null,vat_rate:Number($('puVat').value||0),status:$('puReceived').checked?'received':'draft',notes:$('puNotes').value};
      const items=purchaseLines.map(x=>({product_id:x.product_id||null,description:x.description,quantity:Number(x.quantity),unit_cost:Number(x.unit_cost),discount:Number(x.discount||0)}));
      await fx('erp_create_purchase',{p_purchase:payload,p_items:items});
      closeModal('purchaseModal');msg(payload.status==='received'?'تم حفظ الشراء وإضافة الكميات للمخزون.':'تم حفظ فاتورة الشراء كمسودة.');loadPurchases();if(window.loadProducts)loadProducts();if(window.loadDashboard)loadDashboard();
    }catch(e){msg(e.message,'err')}
  });

  function ensurePurchaseDetailsModal(){
    if($('purchaseDetailsModal'))return;
    document.body.insertAdjacentHTML('beforeend',`<div class="modal" id="purchaseDetailsModal"><div class="modalbox" style="max-width:1050px"><div class="modalhead"><h2>تفاصيل فاتورة الشراء</h2><button class="close" type="button" onclick="closeModal('purchaseDetailsModal')">×</button></div><div id="purchaseDetailsContent"></div></div></div>`);
  }
  window.viewPurchase=async function(id){
    try{
      ensurePurchaseDetailsModal();
      const p=(window.purchases||[]).find(x=>x.id===id);
      if(!p)throw new Error('فاتورة الشراء غير موجودة.');
      const items=rows(await fx('erp_get_purchase_items',{p_purchase_id:id}));
      const paid=Number(p.calculated_paid ?? p.paid_amount ?? 0);
      const balance=Math.max(Number(p.total||0)-paid,0);
      $('purchaseDetailsContent').innerHTML=`<div class="fin-kpis"><div class="fin-kpi"><small>رقم الشراء</small><strong>${E(p.purchase_number)}</strong></div><div class="fin-kpi"><small>المورد</small><strong>${E(p.supplier_name||'—')}</strong></div><div class="fin-kpi"><small>الإجمالي</small><strong>${M(p.total)}</strong></div><div class="fin-kpi"><small>المدفوع</small><strong>${M(paid)}</strong></div><div class="fin-kpi"><small>المتبقي</small><strong>${M(balance)}</strong></div></div><div class="fin-section"><p><b>التاريخ:</b> ${E(p.purchase_date||'—')} &nbsp; <b>الاستحقاق:</b> ${E(p.due_date||'—')} &nbsp; <b>الحالة:</b> ${status(p.status)}</p><div class="fin-table-wrap"><table class="fin-table"><thead><tr><th>SKU</th><th>المنتج / الوصف</th><th>الكمية</th><th>تكلفة الوحدة</th><th>الخصم</th><th>الإجمالي</th></tr></thead><tbody>${items.length?items.map(x=>`<tr><td>${E(x.sku||'—')}</td><td>${E(x.product_name||x.description||'—')}</td><td>${Number(x.quantity||0).toLocaleString('en-OM',{maximumFractionDigits:3})}</td><td>${M(x.unit_cost)}</td><td>${M(x.discount)}</td><td><b>${M(x.line_total)}</b></td></tr>`).join(''):`<tr><td colspan="6" style="text-align:center">لا توجد منتجات.</td></tr>`}</tbody></table></div><div style="margin-top:16px;display:flex;justify-content:flex-end;gap:25px;flex-wrap:wrap"><b>الصافي قبل VAT: ${M(p.taxable_amount)}</b><b>VAT: ${M(p.vat_amount)}</b><b>الإجمالي: ${M(p.total)}</b></div>${p.notes?`<div class="notice" style="margin-top:14px">${E(p.notes)}</div>`:''}</div>`;
      openModal('purchaseDetailsModal');
    }catch(e){msg(e.message,'err')}
  };
  window.loadPurchases=async function(){
    try{
      const d=await fx('erp_list_purchases',{p_search:$('purchaseSearch')?.value||null,p_status:$('purchaseStatus')?.value||null});
      const ps=rows(d);window.purchases=ps;
      $('purchaseTable').innerHTML=!ps.length?'<div class="notice">لا توجد مشتريات.</div>':`<div class="fin-table-wrap"><table class="fin-table"><thead><tr><th>رقم الشراء</th><th>المورد</th><th>التاريخ</th><th>الحالة</th><th>الإجمالي</th><th>المدفوع</th><th>المتبقي</th><th>إجراء</th></tr></thead><tbody>${ps.map(p=>`<tr><td><b>${E(p.purchase_number)}</b></td><td>${E(p.supplier_name||'—')}</td><td>${E(p.purchase_date||'—')}</td><td>${status(p.status)}</td><td>${M(p.total)}</td><td>${M(p.calculated_paid ?? p.paid_amount)}</td><td><b>${M(p.balance)}</b></td><td style="white-space:nowrap"><button class="btnx" onclick="viewPurchase('${p.id}')">تفاصيل</button> ${p.status==='draft'?`<button class="btnx" onclick="editPurchase('${p.id}')">تعديل</button>`:''} ${Number(p.balance)>0&&p.status!=='draft'&&p.status!=='cancelled'?`<button class="btnx primary" onclick="paySupplier('${p.id}')">دفع للمورد</button>`:''}</td></tr>`).join('')}</tbody></table></div>`;
    }catch(e){msg(e.message,'err')}
  };
  window.editPurchase=async function(id){const p=(window.purchases||[]).find(x=>x.id===id);if(p)openPurchaseModal(p)};
  window.paySupplier=async function(id){
    const p=(window.purchases||[]).find(x=>x.id===id);if(!p)return;
    const max=Number(p.balance||0);const amount=prompt(`المبلغ المراد دفعه للمورد (المتبقي ${M(max)}):`,max.toFixed(3));if(amount===null)return;
    const n=Number(amount);if(!n||n<=0||n>max){msg('مبلغ الدفع غير صحيح.','err');return}
    const method=prompt('طريقة الدفع: cash أو bank','bank')||'bank';
    try{await fx('erp_record_supplier_payment',{p_payment:{purchase_id:id,amount:n,method,payment_date:today()}});msg('تم تسجيل دفعة المورد.');loadPurchases();loadSuppliers();loadDashboard()}catch(e){msg(e.message,'err')}
  };

  // Load expansion data when ERP is ready and expose dashboard metrics.
  async function boot(){
    if(!$('app')||$('app').style.display==='none')return;
    try{await loadSuppliers();await loadPurchases()}catch(e){}
  }
  setTimeout(boot,1200);
})();
