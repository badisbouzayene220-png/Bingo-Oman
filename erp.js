const $=id=>document.getElementById(id); const esc=s=>String(s??'').replace(/[&<>'"]/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;',"'":'&#39;','"':'&quot;'}[c]));
const money=n=>Number(n||0).toLocaleString('en-OM',{minimumFractionDigits:3,maximumFractionDigits:3})+' OMR';
function localDateISO(d=new Date()){const y=d.getFullYear();const m=String(d.getMonth()+1).padStart(2,'0');const day=String(d.getDate()).padStart(2,'0');return `${y}-${m}-${day}`;} const today=()=>localDateISO(); const monthAgo=()=>{let d=new Date();d.setDate(d.getDate()-30);return localDateISO(d)};
let customers=[],invoices=[],expenses=[],settings={},invoiceItems=[],bingoUsers=[],products=[],financialAccounts=[];
function msg(t,type='ok'){ $('msg').innerHTML=t?`<div class="notice ${type}">${esc(t)}</div>`:''; if(t)setTimeout(()=>{$('msg').innerHTML=''},4500)}
function openModal(id){$(id).classList.add('open')} function closeModal(id){$(id).classList.remove('open')}
function badge(s){return `<span class="badge b-${esc(s)}">${esc(s)}</span>`}
async function adminCheck(){const u=await BingoAuth.getUser();if(!u)return false;const {data}=await sb.from('profiles').select('id,role,is_active').eq('id',u.id).maybeSingle();return data?.role==='admin'&&data?.is_active!==false}
async function init(){if(!await adminCheck()){$('denied').style.display='block';return}$('app').style.display='block';$('from').value=monthAgo();$('to').value=today();$('vatFrom').value=monthAgo();$('vatTo').value=today();await loadSettings();await loadBingoUsers();await loadCustomers();await loadSuppliers();await loadProducts();await loadPurchases();await loadInvoices();await loadExpenses();await loadDashboard();await loadPayments();await loadVat();await loadFinancialAccounts();await loadReports()}
async function rpc(name,args={}){const {data,error}=await sb.rpc(name,args);if(error)throw error;return data}
async function loadDashboard(){try{let d=await rpc('erp_dashboard',{p_from:$('from').value,p_to:$('to').value});$('sales').textContent=money(d.sales);$('paid').textContent=money(d.paid);$('expenses').textContent=money(d.expenses);$('receivable').textContent=money(d.receivable);$('vatSales').textContent=money(d.vat_sales);$('vatExpenses').textContent=money(d.vat_expenses);$('customersCount').textContent=d.customers||0}catch(e){msg(e.message,'err')}}
async function loadSettings(){try{settings=await rpc('erp_company_settings_read').catch(()=>null);if(!settings){const {data}=await sb.from('erp_company_settings').select('*').eq('id','default').maybeSingle();settings=data||{}};$('sCompany').value=settings.company_name||'';$('sLegal').value=settings.legal_name||'';$('sTax').value=settings.tax_number||'';$('sCR').value=settings.commercial_registration||'';$('sPhone').value=settings.phone||'';$('sEmail').value=settings.email||'';$('sCurrency').value=settings.currency||'OMR';$('sVat').value=settings.vat_rate??5;$('sPrefix').value=settings.invoice_prefix||'INV-'}catch(e){console.warn(e.message)}}
async function saveSettings(){try{const payload={company_name:$('sCompany').value.trim(),legal_name:$('sLegal').value.trim()||null,tax_number:$('sTax').value.trim()||null,commercial_registration:$('sCR').value.trim()||null,phone:$('sPhone').value.trim()||null,email:$('sEmail').value.trim()||null,currency:$('sCurrency').value.trim()||'OMR',vat_rate:Number($('sVat').value||5),invoice_prefix:$('sPrefix').value.trim()||'INV-'};await rpc('erp_save_settings',{p_settings:payload});msg('تم حفظ إعدادات الشركة.');await loadSettings()}catch(e){msg(e.message,'err')}}
async function loadBingoUsers(){try{bingoUsers=await rpc('erp_list_bingo_users',{})||[]}catch(e){bingoUsers=[]}}
function fillProfileSelect(selected=''){const s=$('cProfile');if(!s)return;s.innerHTML='<option value="">بدون ربط</option>'+bingoUsers.map(u=>`<option value="${u.id}" ${u.id===selected?'selected':''}>${esc(u.display_name||u.email||u.id)}${u.email?' — '+esc(u.email):''}</option>`).join('')}
function customerDetails(id){const c=customers.find(x=>x.id===id);if(!c)return;const balance=Number(c.invoiced||0)-Number(c.paid||0);msg(`العميل: ${c.name} | المبيعات: ${money(c.invoiced)} | المدفوع: ${money(c.paid)} | المتبقي: ${money(balance)}`,'ok');editCustomer(id)}
async function loadCustomers(){try{customers=await rpc('erp_list_customers',{p_search:$('customerSearch')?.value||null})||[];renderCustomers();fillCustomerSelects()}catch(e){$('customerTable').innerHTML='<div class="notice err">'+esc(e.message)+'</div>'}}
function renderCustomers(){if(!customers.length){$('customerTable').innerHTML='<div style="padding:30px;text-align:center;color:#718096">لا يوجد عملاء.</div>';return}$('customerTable').innerHTML=`<table class="table"><thead><tr><th>الكود</th><th>العميل</th><th>الهاتف</th><th>البريد</th><th>حساب BINGO</th><th>المبيعات</th><th>المدفوع</th><th>المتبقي</th><th>إجراء</th></tr></thead><tbody>${customers.map(c=>`<tr><td>${esc(c.customer_code)}</td><td><b>${esc(c.name)}</b><br><small>${esc(c.company_name||'')}</small></td><td>${esc(c.phone||'—')}</td><td>${esc(c.email||'—')}</td><td>${c.profile_id?'<span class="badge b-issued">'+esc(c.profile_display_name||c.profile_email||'مرتبط')+'</span>':'<span class="badge b-draft">غير مرتبط</span>'}</td><td>${money(c.invoiced)}</td><td>${money(c.paid)}</td><td>${money(Number(c.invoiced||0)-Number(c.paid||0))}</td><td><button class="btnx" onclick="editCustomer('${c.id}')">تعديل</button> <button class="btnx" onclick="customerDetails('${c.id}')">عرض</button></td></tr>`).join('')}</tbody></table>`}
function fillCustomerSelects(){if(!$('iCustomer'))return;$('iCustomer').innerHTML='<option value="">بدون عميل</option>'+customers.map(c=>`<option value="${c.id}">${esc(c.name)}${c.company_name?' — '+esc(c.company_name):''}</option>`).join('');$('pInvoice').innerHTML='<option value="">اختر فاتورة</option>'+invoices.filter(i=>i.status!=='cancelled'&&Number(i.total)>Number(i.paid_amount)).map(i=>`<option value="${i.id}">${esc(i.invoice_number)} — ${esc(i.customer_name||'بدون عميل')} — ${money(Number(i.total)-Number(i.paid_amount))}</option>`).join('')}
function newCustomer(){fillProfileSelect('');['cId','cName','cCompany','cPhone','cEmail','cTax','cCR','cCity','cAddress','cNotes'].forEach(x=>$(x).value='');$('cType').value='individual';openModal('customerModal')}
function editCustomer(id){const c=customers.find(x=>x.id===id);if(!c)return;fillProfileSelect(c.profile_id||'');$('cId').value=c.id;$('cType').value=c.customer_type;$('cName').value=c.name||'';$('cCompany').value=c.company_name||'';$('cPhone').value=c.phone||'';$('cEmail').value=c.email||'';$('cTax').value=c.tax_number||'';$('cCR').value=c.commercial_registration||'';$('cCity').value=c.city||'';$('cAddress').value=c.address||'';$('cNotes').value=c.notes||'';openModal('customerModal')}
$('customerForm').onsubmit=async e=>{e.preventDefault();try{await rpc('erp_upsert_customer',{p_customer:{id:$('cId').value||null,profile_id:$('cProfile').value||null,customer_type:$('cType').value,name:$('cName').value,company_name:$('cCompany').value,phone:$('cPhone').value,email:$('cEmail').value,tax_number:$('cTax').value,commercial_registration:$('cCR').value,city:$('cCity').value,address:$('cAddress').value,notes:$('cNotes').value}});closeModal('customerModal');msg('تم حفظ العميل.');await loadCustomers()}catch(e){msg(e.message,'err')}};
function exportCustomers(){if(!customers.length)return msg('لا توجد بيانات للتصدير.','err');const ws=XLSX.utils.json_to_sheet(customers.map(c=>({'Code':c.customer_code,'Name':c.name,'Company':c.company_name||'','Phone':c.phone||'','Email':c.email||'','Tax No.':c.tax_number||'','Invoiced':Number(c.invoiced||0),'Paid':Number(c.paid||0)})));const wb=XLSX.utils.book_new();XLSX.utils.book_append_sheet(wb,ws,'Customers');XLSX.writeFile(wb,'BINGO-Oman-Customers.xlsx')}

async function loadProducts(){try{products=await rpc('erp_list_products',{p_search:$('productSearch')?.value||null,p_stock_filter:$('productStockFilter')?.value||null})||[];renderProducts()}catch(e){$('productTable').innerHTML='<div class="notice err">'+esc(e.message)+'</div>'}}
function renderProducts(){if(!products.length){$('productTable').innerHTML='<div style="padding:30px;text-align:center;color:#718096">لا توجد منتجات.</div>';return}$('productTable').innerHTML=`<table class="table"><thead><tr><th>SKU</th><th>المنتج</th><th>التصنيف</th><th>التكلفة</th><th>سعر البيع</th><th>المخزون</th><th>الحد الأدنى</th><th>الحالة</th><th>إجراء</th></tr></thead><tbody>${products.map(p=>{const q=Number(p.stock_qty||0),min=Number(p.min_stock||0);const low=q<=min;const out=q<=0;return `<tr><td><b>${esc(p.sku||'—')}</b></td><td><b>${esc(p.name)}</b><br><small>${esc(p.unit||'pcs')}</small></td><td>${esc(p.category||'—')}</td><td>${money(p.cost_price)}</td><td>${money(p.sale_price)}</td><td><b>${q.toLocaleString('en-OM',{maximumFractionDigits:3})}</b></td><td>${min.toLocaleString('en-OM',{maximumFractionDigits:3})}</td><td>${out?'<span class="badge b-cancelled">نفد</span>':low?'<span class="badge b-partially_paid">منخفض</span>':'<span class="badge b-paid">متوفر</span>'}</td><td><button class="btnx" onclick="editProduct('${p.id}')">تعديل</button> <button class="btnx green" onclick="adjustStock('${p.id}')">مخزون</button></td></tr>`}).join('')}</tbody></table>`}
function newProduct(){['prId','prSku','prName','prCategory','prCost','prSale','prDescription'].forEach(x=>$(x).value='');$('prUnit').value='pcs';$('prVat').value=settings.vat_rate??5;$('prMin').value=0;openModal('productModal')}
function editProduct(id){const p=products.find(x=>x.id===id);if(!p)return;$('prId').value=p.id;$('prSku').value=p.sku||'';$('prName').value=p.name||'';$('prCategory').value=p.category||'';$('prUnit').value=p.unit||'pcs';$('prCost').value=p.cost_price||0;$('prSale').value=p.sale_price||0;$('prVat').value=p.vat_rate??(settings.vat_rate??5);$('prMin').value=p.min_stock||0;$('prDescription').value=p.description||'';openModal('productModal')}
$('productForm').onsubmit=async e=>{e.preventDefault();try{await rpc('erp_upsert_product',{p_product:{id:$('prId').value||null,sku:$('prSku').value,name:$('prName').value,category:$('prCategory').value,unit:$('prUnit').value,cost_price:Number($('prCost').value||0),sale_price:Number($('prSale').value||0),vat_rate:Number($('prVat').value||0),min_stock:Number($('prMin').value||0),description:$('prDescription').value}});closeModal('productModal');msg('تم حفظ المنتج.');await loadProducts()}catch(e){msg(e.message,'err')}};
function adjustStock(id){const p=products.find(x=>x.id===id);if(!p)return;$('stProductId').value=p.id;$('stProductName').value=`${p.name} — ${p.sku||'بدون SKU'} | المخزون الحالي: ${p.stock_qty||0}`;$('stType').value='in';$('stQty').value='';$('stReference').value='';$('stDate').value=today();$('stNotes').value='';openModal('stockModal')}
$('stockForm').onsubmit=async e=>{e.preventDefault();try{await rpc('erp_adjust_stock',{p_product_id:$('stProductId').value,p_movement_type:$('stType').value,p_quantity:Number($('stQty').value),p_reference:$('stReference').value,p_movement_date:$('stDate').value||today(),p_notes:$('stNotes').value});closeModal('stockModal');msg('تم تسجيل حركة المخزون.');await loadProducts()}catch(e){msg(e.message,'err')}};
function exportProducts(){if(!products.length)return msg('لا توجد منتجات للتصدير.','err');const ws=XLSX.utils.json_to_sheet(products.map(p=>({'SKU':p.sku||'','Name':p.name,'Category':p.category||'','Unit':p.unit||'','Cost Price':Number(p.cost_price||0),'Sale Price':Number(p.sale_price||0),'VAT %':Number(p.vat_rate||0),'Stock':Number(p.stock_qty||0),'Min Stock':Number(p.min_stock||0),'Status':Number(p.stock_qty||0)<=0?'Out of stock':Number(p.stock_qty||0)<=Number(p.min_stock||0)?'Low':'Available'})));const wb=XLSX.utils.book_new();XLSX.utils.book_append_sheet(wb,ws,'Products');XLSX.writeFile(wb,'BINGO-Oman-Products-Inventory.xlsx')}


// ============================================================
// PURCHASES — V18 UI repair
// Uses the protected ERP RPCs. No direct destructive table writes.
// ============================================================
let suppliers=[];
let purchaseItems=[];
let purchases=[];

async function loadSuppliers(){
  try{
    const q=$('supplierSearch')?.value?.trim()||'';
    // Prefer an admin RPC if the project has one; otherwise read the
    // supplier table through the authenticated admin session.
    let data=null,error=null;
    if(sb.rpc){
      ({data,error}=await sb.rpc('erp_list_suppliers',{p_search:q||null}));
    }
    if(error || !Array.isArray(data)){
      const r=await sb.from('erp_suppliers').select('*').order('name',{ascending:true}).limit(500);
      if(r.error) throw r.error;
      data=r.data||[];
      if(q) data=data.filter(x=>`${x.name||''} ${x.company_name||''} ${x.contact_person||''}`.toLowerCase().includes(q.toLowerCase()));
    }
    suppliers=data||[];
    renderSuppliers();
    fillPurchaseSupplierSelect();
  }catch(e){
    if($('supplierTable')) $('supplierTable').innerHTML='<div class="notice err">'+esc(e.message)+'</div>';
  }
}

function renderSuppliers(){
  if(!$('supplierTable')) return;
  if(!suppliers.length){$('supplierTable').innerHTML='<div style="padding:30px;text-align:center;color:#718096">لا يوجد موردون.</div>';return;}
  $('supplierTable').innerHTML=`<table class="table"><thead><tr><th>المورد</th><th>جهة الاتصال</th><th>الهاتف</th><th>VAT</th><th>إجراء</th></tr></thead><tbody>${suppliers.map(s=>`<tr><td><b>${esc(s.name||'—')}</b><br><small>${esc(s.company_name||'')}</small></td><td>${esc(s.contact_person||'—')}</td><td>${esc(s.phone||'—')}</td><td>${esc(s.tax_number||'—')}</td><td><button class="btnx" onclick="editSupplier('${s.id}')">تعديل</button></td></tr>`).join('')}</tbody></table>`;
}

function fillPurchaseSupplierSelect(selected=''){
  const el=$('puSupplier'); if(!el)return;
  el.innerHTML='<option value="">اختر المورد</option>'+suppliers.map(s=>`<option value="${s.id}" ${s.id===selected?'selected':''}>${esc(s.name||s.company_name||'مورد')}${s.company_name&&s.company_name!==s.name?' — '+esc(s.company_name):''}</option>`).join('');
}

function openSupplierModal(id=''){
  const s=id?suppliers.find(x=>x.id===id):null;
  $('suId').value=s?.id||'';$('suName').value=s?.name||'';$('suContact').value=s?.contact_person||'';$('suCompany').value=s?.company_name||'';$('suPhone').value=s?.phone||'';$('suEmail').value=s?.email||'';$('suTax').value=s?.tax_number||'';$('suCR').value=s?.commercial_registration||'';$('suCity').value=s?.city||'';$('suTerms').value=s?.payment_terms_days??30;$('suAddress').value=s?.address||'';$('suNotes').value=s?.notes||'';openModal('supplierModal');
}
function editSupplier(id){openSupplierModal(id)}

$('supplierForm')?.addEventListener('submit',async e=>{
  e.preventDefault();
  try{
    const payload={id:$('suId').value||null,name:$('suName').value.trim(),contact_person:$('suContact').value.trim(),company_name:$('suCompany').value.trim(),phone:$('suPhone').value.trim(),email:$('suEmail').value.trim(),tax_number:$('suTax').value.trim(),commercial_registration:$('suCR').value.trim(),city:$('suCity').value.trim(),payment_terms_days:Number($('suTerms').value||30),address:$('suAddress').value.trim(),notes:$('suNotes').value.trim()};
    let {error}=await sb.rpc('erp_upsert_supplier',{p_supplier:payload});
    if(error) throw error;
    closeModal('supplierModal');msg('تم حفظ المورد.');await loadSuppliers();
  }catch(e){msg(e.message,'err')}
});

function addPurchaseLine(x={}){
  purchaseItems.push({product_id:x.product_id||'',description:x.description||'',quantity:Number(x.quantity||1),unit_cost:Number(x.unit_cost||0),discount:Number(x.discount||0)});
  renderPurchaseItems();
}
function removePurchaseLine(i){purchaseItems.splice(i,1);if(!purchaseItems.length)addPurchaseLine();else renderPurchaseItems();}
function selectPurchaseProduct(i,value){purchaseItems[i].product_id=value;const p=products.find(x=>x.id===value);if(p){purchaseItems[i].description=p.name;purchaseItems[i].unit_cost=Number(p.cost_price||0)}renderPurchaseItems();}
function purchaseProductOptions(selected=''){return '<option value="">اختر المنتج</option>'+products.filter(p=>p.is_active!==false).map(p=>`<option value="${p.id}" ${p.id===selected?'selected':''}>${esc(p.name)}${p.sku?' — '+esc(p.sku):''} | مخزون: ${Number(p.stock_qty||0)}</option>`).join('')}
function renderPurchaseItems(){
  if(!$('purchaseItems'))return;
  $('purchaseItems').innerHTML=purchaseItems.map((x,i)=>`<div class="item-row"><select onchange="selectPurchaseProduct(${i},this.value)">${purchaseProductOptions(x.product_id)}</select><input value="${esc(x.description)}" placeholder="الوصف" oninput="purchaseItems[${i}].description=this.value"><input type="number" min="0.001" step="0.001" value="${x.quantity}" oninput="purchaseItems[${i}].quantity=Number(this.value);calcPurchase()"><input type="number" min="0" step="0.001" value="${x.unit_cost}" oninput="purchaseItems[${i}].unit_cost=Number(this.value);calcPurchase()"><input type="number" min="0" step="0.001" value="${x.discount}" oninput="purchaseItems[${i}].discount=Number(this.value);calcPurchase()"><button type="button" class="remove-item" onclick="removePurchaseLine(${i})">×</button></div>`).join('');
  calcPurchase();
}
function calcPurchase(){
  let sub=0,disc=0;purchaseItems.forEach(x=>{sub+=Number(x.quantity||0)*Number(x.unit_cost||0);disc+=Number(x.discount||0)});const taxable=Math.max(sub-disc,0),vat=taxable*Number($('puVat')?.value||0)/100,total=taxable+vat;if($('puTotal'))$('puTotal').textContent=money(total);
}
function openPurchaseModal(id=''){
  const p=id?purchases.find(x=>x.id===id):null;
  $('puId').value=p?.id||'';$('puDate').value=p?.purchase_date||today();$('puDue').value=p?.due_date||'';$('puVat').value=p?.vat_rate??(settings.vat_rate??5);$('puNotes').value=p?.notes||'';$('puReceived').checked=p?.status==='received';
  fillPurchaseSupplierSelect(p?.supplier_id||'');purchaseItems=[];
  if(p){rpc('erp_get_purchase_items',{p_purchase_id:p.id}).then(items=>{purchaseItems=items||[];renderPurchaseItems()}).catch(e=>msg(e.message,'err'))}else addPurchaseLine();
  openModal('purchaseModal');
}
$('puVat')?.addEventListener('input',calcPurchase);

async function loadPurchases(){
  try{
    purchases=await rpc('erp_list_purchases',{p_search:$('purchaseSearch')?.value||null,p_status:$('purchaseStatus')?.value||null})||[];
    renderPurchases();
  }catch(e){if($('purchaseTable'))$('purchaseTable').innerHTML='<div class="notice err">'+esc(e.message)+'</div>';}
}
function renderPurchases(){
  if(!$('purchaseTable'))return;
  if(!purchases.length){$('purchaseTable').innerHTML='<div style="padding:30px;text-align:center;color:#718096">لا توجد مشتريات.</div>';return;}
  $('purchaseTable').innerHTML=`<table class="table"><thead><tr><th>رقم الشراء</th><th>المورد</th><th>التاريخ</th><th>الإجمالي</th><th>المدفوع</th><th>المتبقي</th><th>الحالة</th><th>إجراء</th></tr></thead><tbody>${purchases.map(p=>{
    const total=Number(p.total||0),paid=Number(p.calculated_paid??p.paid_amount??0),bal=Math.max(total-paid,0),status=p.status||'draft';
    const canEdit=status==='draft';
    const canPay=['received','partially_paid'].includes(status)&&bal>0;
    const canCancel=status!=='cancelled';
    return `<tr><td><b>${esc(p.purchase_number)}</b></td><td>${esc(p.supplier_name||p.supplier_company||'—')}</td><td>${esc(p.purchase_date||'')}</td><td>${money(total)}</td><td>${money(paid)}</td><td>${money(bal)}</td><td>${badge(status)}</td><td class="actions-cell"><button class="btnx" onclick="viewPurchase('${p.id}')">عرض</button>${canEdit?`<button class="btnx" onclick="openPurchaseModal('${p.id}')">تعديل</button>`:''}${canPay?`<button class="btnx green" onclick="supplierPayment('${p.id}')">دفعة</button>`:''}${canCancel?`<button type="button" class="btnx danger purchase-cancel-btn" data-purchase-cancel="${p.id}" onclick="cancelPurchase('${p.id}')" style="display:inline-flex!important;visibility:visible!important;opacity:1!important;align-items:center;gap:5px;color:#a52020!important;border:2px solid #d33!important;background:#fff1f1!important;font-weight:900!important;cursor:pointer!important;min-width:86px">🗑 إلغاء</button>`:''}</td></tr>`;
  }).join('')}</tbody></table>`;
}
async function viewPurchase(id){
  const p=purchases.find(x=>x.id===id);if(!p)return;
  try{const items=await rpc('erp_get_purchase_items',{p_purchase_id:id});const text=(items||[]).map(x=>`${x.product_name||x.description||'Item'} × ${x.quantity} @ ${money(x.unit_cost)}`).join('\n');alert(`شراء: ${p.purchase_number}\nالحالة: ${p.status}\nالإجمالي: ${money(p.total)}\nالمدفوع: ${money(p.calculated_paid??p.paid_amount)}\nالمتبقي: ${money(Math.max(Number(p.total)-Number((p.calculated_paid??p.paid_amount)??0),0))}\n\n${text}`)}catch(e){msg(e.message,'err')}
}
async function cancelPurchase(id){
  const p=purchases.find(x=>x.id===id);
  if(!p)return;
  const paid=Number(p.calculated_paid??p.paid_amount??0);
  const reason=prompt(`إلغاء الشراء ${p.purchase_number}\nاكتب سبب الإلغاء:`,'Cancelled by admin');
  if(reason===null)return;
  if(!confirm(`تأكيد إلغاء ${p.purchase_number}؟\nسيتم تنفيذ عكس المخزون والقيد المحاسبي بواسطة النظام.`))return;

  const btn=document.querySelector(`[data-purchase-cancel="${id}"]`);
  const original=btn?btn.innerHTML:'🗑 إلغاء';
  if(btn){btn.disabled=true;btn.innerHTML='⏳ جاري الإلغاء...';btn.style.pointerEvents='none';}
  msg('⏳ جاري الإلغاء...','ok');

  try{
    // Do not allow the UI to hang forever if the RPC/auth request never returns.
    const rpcPromise=rpc('erp_cancel_purchase',{p_purchase_id:id,p_reason:reason.trim()||'Cancelled by admin'});
    const timeout=new Promise((_,reject)=>setTimeout(()=>reject(new Error('انتهت مهلة طلب الإلغاء. تحقق من جلسة تسجيل الدخول وصلاحية admin ثم أعد المحاولة.')),20000));
    const result=await Promise.race([rpcPromise,timeout]);

    msg(result?.supplier_refund_required||paid>0
      ?'تم إلغاء الشراء. توجد دفعة مورد سابقة وتتطلب معالجة رد المورد.'
      :'تم إلغاء الشراء وعكس المخزون والقيد المحاسبي.');

    await loadPurchases();
    await loadProducts();
    await loadDashboard();
    await loadVat();
    await loadFinancialAccounts();
    await loadReports();
  }catch(e){
    console.error('erp_cancel_purchase failed:',e);
    msg(`❌ فشل إلغاء الشراء: ${e?.message||e}`,'err');
  }finally{
    if(btn){btn.disabled=false;btn.innerHTML=original;btn.style.pointerEvents='auto';}
  }
}
async function supplierPayment(purchaseId){
  const p=purchases.find(x=>x.id===purchaseId);if(!p)return;
  const paid=Number(p.calculated_paid??p.paid_amount??0),bal=Math.max(Number(p.total||0)-paid,0);if(bal<=0)return msg('لا يوجد رصيد مستحق.','err');
  const amount=Number(prompt(`دفعة للمورد — المتبقي ${bal.toFixed(3)} OMR`,bal.toFixed(3))||0);if(!(amount>0))return;if(amount>bal+0.000001)return msg('مبلغ الدفعة أكبر من المتبقي.','err');
  const method=prompt('طريقة الدفع: cash / bank / card','bank')||'bank';
  try{await rpc('erp_record_supplier_payment',{p_payment:{purchase_id:purchaseId,amount,method,payment_date:today(),notes:'Supplier payment from ERP'}});msg('تم تسجيل دفعة المورد.');await loadPurchases();await loadDashboard();await loadFinancialReports()}catch(e){msg(e.message,'err')}
}
// Purchase saving is handled exclusively by finance-expansion.js.
// The legacy submit handler was removed because it registered a second
// erp_create_purchase RPC call using the old purchaseItems array.
// That duplicate call could overwrite the correct DOM quantity (e.g. 10)
// with a stale value (e.g. 2).

async function loadInvoices(){try{invoices=await rpc('erp_list_invoices',{p_search:$('invoiceSearch')?.value||null,p_status:$('invoiceStatus')?.value||null})||[];renderInvoices();fillCustomerSelects()}catch(e){$('invoiceTable').innerHTML='<div class="notice err">'+esc(e.message)+'</div>'}}
function renderInvoices(){if(!invoices.length){$('invoiceTable').innerHTML='<div style="padding:30px;text-align:center;color:#718096">لا توجد فواتير.</div>';return}$('invoiceTable').innerHTML=`<table class="table"><thead><tr><th>رقم</th><th>العميل</th><th>التاريخ</th><th>الإجمالي</th><th>المدفوع</th><th>المتبقي</th><th>الحالة</th><th>إجراء</th></tr></thead><tbody>${invoices.map(i=>`<tr><td><b>${esc(i.invoice_number)}</b></td><td>${esc(i.customer_name||'—')}</td><td>${esc(i.issue_date||'')}</td><td>${money(i.total)}</td><td>${money(i.paid_amount)}</td><td>${money(Math.max(Number(i.total)-Number(i.paid_amount),0))}</td><td>${badge(i.status)}</td><td class="actions-cell"><button class="btnx" onclick="printInvoice('${i.id}')">🖨</button>${Number(i.total)>Number(i.paid_amount)&&i.status!=='cancelled'?`<button class="btnx green" onclick="newPayment('${i.id}')">دفعة</button>`:''}${i.status==='issued'&&Number(i.paid_amount||0)===0?`<button class="btnx danger" onclick="cancelInvoice('${i.id}')">إلغاء</button>`:''}</td></tr>`).join('')}</tbody></table>`}
async function cancelInvoice(id){if(!confirm('هل تريد إلغاء الفاتورة؟ سيتم إعادة الكمية إلى المخزون.'))return;try{await rpc('erp_cancel_invoice',{p_invoice_id:id,p_reason:'Cancelled by admin'});msg('تم إلغاء الفاتورة وإعادة المخزون.');await loadInvoices();await loadProducts();await loadDashboard()}catch(e){msg(e.message,'err')}}
function resetInvoice(){invoiceItems=[];addItem();$('iId').value='';$('iCustomer').value='';$('iStatus').value='issued';$('iDate').value=today();$('iDue').value=today();$('iVat').value=settings.vat_rate??5;$('iNotes').value='';updateInvoiceAction();renderItems()}
function newInvoice(){resetInvoice();openModal('invoiceModal')}
function addItem(x={}){invoiceItems.push({product_id:x.product_id||'',description:x.description||'',quantity:x.quantity||1,unit_price:x.unit_price||0,discount:x.discount||0});renderItems()}
function productOptions(selected=''){return '<option value="">بند مخصص / بدون منتج</option>'+products.filter(p=>p.is_active!==false).map(p=>`<option value="${p.id}" ${p.id===selected?'selected':''}>${esc(p.name)}${p.sku?' — '+esc(p.sku):''} | مخزون: ${Number(p.stock_qty||0)}</option>`).join('')}
function selectInvoiceProduct(i,value){invoiceItems[i].product_id=value;const p=products.find(x=>x.id===value);if(p){invoiceItems[i].description=p.name;invoiceItems[i].unit_price=Number(p.sale_price||0)}renderItems()}
function removeItem(i){invoiceItems.splice(i,1);if(!invoiceItems.length)addItem();renderItems()}
function normalizeDecimalInput(value){return String(value??'').replace(/[٠-٩]/g,d=>String(d.charCodeAt(0)-1632)).replace(/[۰-۹]/g,d=>String(d.charCodeAt(0)-1776)).replace(/٫/g,'.').replace(/,/g,'.').replace(/[^0-9.]/g,'').replace(/(\..*)\./g,'$1')}
function normalizeDecimalInput(value){return String(value??'').replace(/[٠-٩]/g,d=>String(d.charCodeAt(0)-1632)).replace(/[۰-۹]/g,d=>String(d.charCodeAt(0)-1776)).replace(/٫/g,'.').replace(/,/g,'.').replace(/[^0-9.]/g,'').replace(/(\..*)\./g,'$1')}
function updateItemQuantity(i,value){const v=normalizeDecimalInput(value);invoiceItems[i].quantity=v===''?0:Number(v);calcInvoice()}
function bindInvoiceItemInputs(){
  document.querySelectorAll('#invoiceItems .invoice-qty').forEach(input=>{
    const i=Number(input.dataset.index);
    input.addEventListener('focus',()=>{input.select()});
    input.addEventListener('click',e=>{e.stopPropagation();input.focus()});
    input.addEventListener('keydown',e=>{
      if(['ArrowUp','ArrowDown'].includes(e.key)){e.preventDefault();return;}
      e.stopPropagation();
    });
    input.addEventListener('input',()=>updateItemQuantity(i,input.value));
    input.addEventListener('change',()=>updateItemQuantity(i,input.value));
    input.addEventListener('blur',()=>{input.value=invoiceItems[i].quantity===0?'0':String(invoiceItems[i].quantity)});
  });
}
function renderItems(){
  $('invoiceItems').innerHTML=invoiceItems.map((x,i)=>`<div class="item-row"><select onchange="selectInvoiceProduct(${i},this.value)">${productOptions(x.product_id)}</select><input value="${esc(x.description)}" placeholder="الوصف" oninput="invoiceItems[${i}].description=this.value"><input class="invoice-qty" type="text" inputmode="decimal" autocomplete="off" dir="ltr" tabindex="0" data-index="${i}" aria-label="الكمية" value="${esc(x.quantity)}"><input type="number" min="0" step="0.001" value="${x.unit_price}" oninput="invoiceItems[${i}].unit_price=Number(this.value);calcInvoice()"><input type="number" min="0" step="0.001" value="${x.discount}" oninput="invoiceItems[${i}].discount=Number(this.value);calcInvoice()"><button type="button" class="remove-item" onclick="removeItem(${i})">×</button></div>`).join('');
  bindInvoiceItemInputs();
  calcInvoice();
}
function calcInvoice(){let sub=0,disc=0;invoiceItems.forEach(x=>{sub+=Number(x.quantity||0)*Number(x.unit_price||0);disc+=Number(x.discount||0)});let taxable=Math.max(sub-disc,0),vat=taxable*Number($('iVat')?.value||0)/100,total=taxable+vat;$('sumSub').textContent=money(sub);$('sumDisc').textContent=money(disc);$('sumTaxable').textContent=money(taxable);$('sumVat').textContent=money(vat);$('sumTotal').textContent=money(total)}
$('iVat').oninput=calcInvoice;
function updateInvoiceAction(){const b=$('invoiceSubmit');if(!b)return;const issued=$('iStatus').value==='issued';b.textContent=issued?'إصدار الفاتورة':'حفظ المسودة';b.classList.toggle('primary',issued);b.classList.toggle('green',!issued)}
$('iStatus').onchange=updateInvoiceAction;
$('invoiceForm').onsubmit=async e=>{e.preventDefault();try{if(!invoiceItems.some(x=>String(x.description||'').trim()))throw new Error('أضف بنداً واحداً على الأقل.');const issued=$('iStatus').value==='issued';if(issued){for(const x of invoiceItems){if(!x.product_id)continue;const p=products.find(v=>v.id===x.product_id);if(!p)throw new Error('المنتج غير موجود.');const q=Number(x.quantity||0),stock=Number(p.stock_qty||0);if(q<=0)throw new Error('الكمية يجب أن تكون أكبر من صفر.');if(q>stock)throw new Error(`المخزون غير كافٍ للمنتج ${p.name}. المتوفر: ${stock}`)}}const result=await rpc('erp_create_invoice',{p_invoice:{id:$('iId').value||null,customer_id:$('iCustomer').value||null,issue_date:$('iDate').value,due_date:$('iDue').value,status:$('iStatus').value,vat_rate:Number($('iVat').value||0),notes:$('iNotes').value},p_items:invoiceItems});closeModal('invoiceModal');msg(issued?`تم إصدار الفاتورة ${result?.invoice_number||''} وخصم المخزون وتسجيل VAT.`:'تم حفظ مسودة الفاتورة.');await loadInvoices();await loadProducts();await loadDashboard();await loadVat();await loadFinancialAccounts();await loadReports()}catch(e){msg(e.message||'حدث خطأ أثناء حفظ الفاتورة','err')}};
function exportInvoices(){if(!invoices.length)return msg('لا توجد فواتير للتصدير.','err');const ws=XLSX.utils.json_to_sheet(invoices.map(i=>({'Invoice':i.invoice_number,'Customer':i.customer_name||'','Issue Date':i.issue_date,'Due Date':i.due_date||'','Subtotal':Number(i.subtotal),'VAT':Number(i.vat_amount),'Total':Number(i.total),'Paid':Number(i.paid_amount),'Balance':Number(i.total)-Number(i.paid_amount),'Status':i.status})));const wb=XLSX.utils.book_new();XLSX.utils.book_append_sheet(wb,ws,'Invoices');XLSX.writeFile(wb,'BINGO-Oman-Invoices.xlsx')}
async function newPayment(invoiceId){fillCustomerSelects();$('pDate').value=today();$('pAmount').value='';$('pMethod').value='cash';$('pRef').value='';$('pNotes').value='';$('pInvoice').value=invoiceId||'';updatePaymentBalance();openModal('paymentModal')}
function updatePaymentBalance(){const id=$('pInvoice')?.value;const inv=invoices.find(x=>x.id===id);if(!inv){if($('pBalance'))$('pBalance').textContent='';return}const bal=Math.max(Number(inv.total||0)-Number(inv.paid_amount||0),0);$('pBalance').textContent=`المتبقي الحالي: ${money(bal)} — الحد الأقصى للدفعة: ${money(bal)}`;$('pAmount').max=bal.toFixed(3)}
$('paymentForm').onsubmit=async e=>{e.preventDefault();try{const inv=invoices.find(x=>x.id===$('pInvoice').value);if(!inv)throw new Error('اختر الفاتورة.');const amount=Number($('pAmount').value||0);const balance=Math.max(Number(inv.total||0)-Number(inv.paid_amount||0),0);if(amount<=0)throw new Error('مبلغ الدفعة يجب أن يكون أكبر من صفر.');if(amount>balance+0.000001)throw new Error(`المبلغ أكبر من المتبقي. المتبقي: ${money(balance)}`);const result=await rpc('erp_record_payment',{p_payment:{invoice_id:$('pInvoice').value,customer_id:inv.customer_id||null,payment_date:$('pDate').value,amount,method:$('pMethod').value,reference:$('pRef').value,notes:$('pNotes').value}});closeModal('paymentModal');msg('تم تسجيل الدفعة بنجاح.');await loadInvoices();await loadCustomers();await loadDashboard();await loadPayments();if(result?.id)printPayment(result.id)}catch(e){msg(e.message||'حدث خطأ أثناء تسجيل الدفعة','err')}};
async function loadPayments(){try{const {data,error}=await sb.from('erp_payments').select('*,erp_invoices(invoice_number,total,paid_amount),erp_customers(name,company_name)').order('payment_date',{ascending:false}).limit(500);if(error)throw error;const rows=data||[];const total=rows.reduce((a,p)=>a+Number(p.amount||0),0);const cash=rows.filter(p=>p.method==='cash').reduce((a,p)=>a+Number(p.amount||0),0);const bank=rows.filter(p=>p.method==='bank').reduce((a,p)=>a+Number(p.amount||0),0);const card=rows.filter(p=>p.method==='card').reduce((a,p)=>a+Number(p.amount||0),0);$('paymentSummary').innerHTML=`<div class="report-box"><small>إجمالي التحصيل</small><strong>${money(total)}</strong></div><div class="report-box"><small>نقدي</small><strong>${money(cash)}</strong></div><div class="report-box"><small>تحويل بنكي</small><strong>${money(bank)}</strong></div><div class="report-box"><small>بطاقات</small><strong>${money(card)}</strong></div>`;$('paymentTable').innerHTML=rows.length?`<table class="table"><thead><tr><th>التاريخ</th><th>الإيصال</th><th>الفاتورة</th><th>العميل</th><th>المبلغ</th><th>الطريقة</th><th>المرجع</th><th>إجراء</th></tr></thead><tbody>${rows.map(p=>`<tr><td>${esc(p.payment_date)}</td><td><b>PAY-${esc(String(p.id).slice(0,8).toUpperCase())}</b></td><td>${esc(p.erp_invoices?.invoice_number||'—')}</td><td>${esc(p.erp_customers?.name||'—')}</td><td><b>${money(p.amount)}</b></td><td>${esc({cash:'نقدي',bank:'تحويل بنكي',card:'بطاقة',other:'أخرى'}[p.method]||p.method)}</td><td>${esc(p.reference||'—')}</td><td><button class="btnx" onclick="printPayment('${p.id}')">🧾 إيصال</button></td></tr>`).join('')}</tbody></table>`:'<div style="padding:30px;text-align:center;color:#718096">لا توجد دفعات.</div>'}catch(e){$('paymentTable').innerHTML='<div class="notice err">'+esc(e.message)+'</div>';if($('paymentSummary'))$('paymentSummary').innerHTML=''}}
function exportPayments(){const table=$('paymentTable')?.querySelector('table');if(!table)return msg('لا توجد دفعات للتصدير.','err');const rows=[...table.querySelectorAll('tbody tr')].map(tr=>{const c=tr.querySelectorAll('td');return {'Date':c[0]?.innerText||'','Receipt':c[1]?.innerText||'','Invoice':c[2]?.innerText||'','Customer':c[3]?.innerText||'','Amount':c[4]?.innerText.replace(/[^0-9.]/g,'')||0,'Method':c[5]?.innerText||'','Reference':c[6]?.innerText||''}});const ws=XLSX.utils.json_to_sheet(rows);const wb=XLSX.utils.book_new();XLSX.utils.book_append_sheet(wb,ws,'Payments');XLSX.writeFile(wb,'BINGO-Oman-Payments.xlsx')}
async function printPayment(id){try{const {data,error}=await sb.from('erp_payments').select('*,erp_invoices(invoice_number,total,paid_amount),erp_customers(name,company_name,phone,email)').eq('id',id).single();if(error)throw error;const p=data;const inv=p.erp_invoices||{};const c=p.erp_customers||{};const w=window.open('','_blank');w.document.write(`<html dir="rtl"><head><title>إيصال ${esc(String(p.id).slice(0,8))}</title><style>body{font-family:Arial;padding:40px;color:#111;max-width:760px;margin:auto}h1{color:#092a82}.head{display:flex;justify-content:space-between}.box{border:1px solid #ddd;padding:16px;margin:16px 0;border-radius:8px}table{width:100%;border-collapse:collapse}td{padding:10px;border-bottom:1px solid #eee}.amount{font-size:28px;font-weight:bold;text-align:center;padding:20px}.footer{text-align:center;margin-top:35px;color:#777}</style></head><body><div class="head"><div><h1>${esc(settings.company_name||'BINGO Oman')}</h1><div>${esc(settings.tax_number||'')}</div><div>${esc(settings.phone||'')}</div></div><div><h2>إيصال استلام</h2><b>PAY-${esc(String(p.id).slice(0,8).toUpperCase())}</b><div>${esc(p.payment_date||'')}</div></div></div><div class="box"><b>العميل:</b> ${esc(c.name||'—')}<br>${esc(c.company_name||'')}<br>${esc(c.phone||'')}</div><div class="box"><b>الفاتورة:</b> ${esc(inv.invoice_number||'—')}<br><b>طريقة الدفع:</b> ${esc({cash:'نقدي',bank:'تحويل بنكي',card:'بطاقة',other:'أخرى'}[p.method]||p.method)}<br><b>المرجع:</b> ${esc(p.reference||'—')}</div><div class="amount">المبلغ المستلم: ${money(p.amount)}</div><div class="box"><b>إجمالي الفاتورة:</b> ${money(inv.total)}<br><b>المدفوع بعد العملية:</b> ${money(inv.paid_amount)}<br><b>المتبقي:</b> ${money(Math.max(Number(inv.total||0)-Number(inv.paid_amount||0),0))}</div><div class="footer">شكراً لتعاملكم معنا</div></body></html>`);w.document.close();setTimeout(()=>{try{w.focus();w.print()}catch(_e){}},400)}catch(e){msg(e.message,'err')}}
async function loadExpenses(){try{expenses=await rpc('erp_list_expenses',{p_from:null,p_to:null})||[];$('expenseTable').innerHTML=expenses.length?`<table class="table"><thead><tr><th>رقم</th><th>التاريخ</th><th>التصنيف</th><th>المورد</th><th>الصافي</th><th>VAT</th><th>الإجمالي</th><th>طريقة الدفع</th></tr></thead><tbody>${expenses.map(e=>`<tr><td>${esc(e.expense_number)}</td><td>${e.expense_date}</td><td>${esc(e.category_name||'—')}</td><td>${esc(e.vendor_name||'—')}</td><td>${money(e.amount)}</td><td>${money(e.vat_amount)}</td><td><b>${money(e.total)}</b></td><td>${esc(e.payment_method)}</td></tr>`).join('')}</tbody></table>`:'<div style="padding:30px;text-align:center;color:#718096">لا توجد مصروفات.</div>'}catch(e){$('expenseTable').innerHTML='<div class="notice err">'+esc(e.message)+'</div>'}}
async function newExpense(){try{const {data,error}=await sb.from('erp_expense_categories').select('*').eq('is_active',true).order('name');if(error)throw error;$('eCategory').innerHTML='<option value="">بدون تصنيف</option>'+(data||[]).map(c=>`<option value="${c.id}">${esc(c.name)}</option>`).join('');$('eDate').value=today();$('eAmount').value='';$('eVat').value=settings.vat_rate??5;$('eVendor').value='';$('eRef').value='';$('eNotes').value='';openModal('expenseModal')}catch(e){msg(e.message,'err')}}
$('expenseForm').onsubmit=async e=>{e.preventDefault();try{const amount=Number($('eAmount').value);const vatRate=Number($('eVat').value);if(!Number.isFinite(amount)||amount<=0)throw new Error('يجب أن يكون مبلغ المصروف أكبر من صفر');if(!Number.isFinite(vatRate)||vatRate<0||vatRate>100)throw new Error('نسبة VAT يجب أن تكون بين 0 و100');await rpc('erp_add_expense',{p_expense:{category_id:$('eCategory').value,vendor_name:$('eVendor').value,expense_date:$('eDate').value,amount,vat_rate:vatRate,payment_method:$('eMethod').value,reference:$('eRef').value,notes:$('eNotes').value}});closeModal('expenseModal');msg('تم حفظ المصروف.');await loadExpenses();await loadDashboard();await loadVat();await loadFinancialAccounts();await loadReports()}catch(e){msg(e.message,'err')}};
async function loadVat(){try{const d=await rpc('erp_vat_summary',{p_from:$('vatFrom').value,p_to:$('vatTo').value});$('vatBoxes').innerHTML=`<div class="report-box"><small>المبيعات الخاضعة</small><strong>${money(d.sales_net)}</strong></div><div class="report-box"><small>VAT مخرجات</small><strong>${money(d.output_vat)}</strong></div><div class="report-box"><small>المشتريات/المصروفات</small><strong>${money(d.purchase_net)}</strong></div><div class="report-box"><small>VAT مدخلات</small><strong>${money(d.input_vat)}</strong></div><div class="report-box"><small>صافي VAT</small><strong>${money(d.net_vat)}</strong></div>`}catch(e){msg(e.message,'err')}}
let activeFinancialReport='pl';
function finVal(v){return money(Number(v||0))}
function finDate(id){return $(id)?.value||today()}
function finEsc(v){return esc(v==null?'':String(v))}
function finArr(v){if(Array.isArray(v))return v;if(v&&Array.isArray(v.rows))return v.rows;if(v&&Array.isArray(v.data))return v.data;if(v&&Array.isArray(v.accounts))return v.accounts;return []}
function financialStatus(text,type=''){const el=$('financialReportStatus');if(el)el.innerHTML=text?`<div class="notice ${type}">${esc(text)}</div>`:''}
function reportKpi(label,value,cls=''){return `<div class="fin-kpi"><small>${label}</small><strong class="${cls}">${finVal(value)}</strong></div>`}
async function loadFinancialAccounts(){try{const {data,error}=await sb.from('erp_accounts').select('id,code,name,account_type').eq('is_active',true).order('code');if(error)throw error;financialAccounts=data||[]}catch(e){financialAccounts=[];console.warn('Financial accounts:',e.message)}}
function renderPL(d){return `<div class="fin-kpis">${reportKpi('Revenue / الإيرادات',d.revenue)}${reportKpi('COGS / تكلفة المبيعات',d.cost_of_goods_sold)}${reportKpi('Gross Profit / الربح الإجمالي',d.gross_profit,d.gross_profit<0?'fin-bad':'fin-good')}${reportKpi('Operating Expenses / المصروفات',d.operating_expenses)}${reportKpi('Net Profit / صافي الربح',d.net_profit,d.net_profit<0?'fin-bad':'fin-good')}</div><div class="fin-section"><h3>Profit & Loss Statement</h3><table class="fin-table"><tbody><tr><td>Revenue / الإيرادات</td><td><b>${finVal(d.revenue)}</b></td></tr><tr><td>Cost of Goods Sold / تكلفة المبيعات</td><td>${finVal(d.cost_of_goods_sold)}</td></tr><tr class="fin-total"><td>Gross Profit / الربح الإجمالي</td><td>${finVal(d.gross_profit)}</td></tr><tr><td>Operating Expenses / مصروفات التشغيل</td><td>${finVal(d.operating_expenses)}</td></tr><tr class="fin-total"><td>Net Profit / صافي الربح</td><td>${finVal(d.net_profit)}</td></tr></tbody></table></div>`}
function renderBS(d){const balanced=d.balanced===true||d.balanced==='true';return `<div class="fin-kpis">${reportKpi('Assets / الأصول',d.assets)}${reportKpi('Liabilities / الالتزامات',d.liabilities)}${reportKpi('Equity / حقوق الملكية',d.equity)}${reportKpi('Retained Earnings / الأرباح المحتجزة',d.retained_earnings)}${reportKpi('Total L + E / إجمالي الخصوم والحقوق',d.total_liabilities_equity)}</div><div class="fin-section"><h3>Balance Sheet — As of ${finEsc(d.as_of_date||finDate('finTo'))}</h3><div class="notice ${balanced?'ok':'err'}">${balanced?'✓ الميزانية متوازنة':'⚠ الميزانية تحتاج إلى مراجعة'} — ${balanced?'Assets = Liabilities + Equity':'يوجد فرق في المعادلة المحاسبية'}</div><table class="fin-table"><tbody><tr><td>Assets / الأصول</td><td>${finVal(d.assets)}</td></tr><tr><td>Liabilities / الالتزامات</td><td>${finVal(d.liabilities)}</td></tr><tr><td>Equity / حقوق الملكية</td><td>${finVal(d.equity)}</td></tr><tr><td>Retained Earnings / الأرباح المحتجزة</td><td>${finVal(d.retained_earnings)}</td></tr><tr class="fin-total"><td>Total Liabilities + Equity</td><td>${finVal(d.total_liabilities_equity)}</td></tr></tbody></table></div>`}
function renderCF(d){return `<div class="fin-kpis">${reportKpi('Cash In / دخول نقدي',d.cash_in)}${reportKpi('Cash Out / خروج نقدي',d.cash_out)}${reportKpi('Cash Net / صافي النقد',d.cash_net,d.cash_net<0?'fin-bad':'fin-good')}${reportKpi('Bank Net / صافي البنك',d.bank_net,d.bank_net<0?'fin-bad':'fin-good')}${reportKpi('Total Net / صافي التدفق',d.total_net,d.total_net<0?'fin-bad':'fin-good')}</div><div class="fin-section"><h3>Cash & Bank Movement</h3><table class="fin-table"><thead><tr><th>الحساب</th><th>In</th><th>Out</th><th>Net</th></tr></thead><tbody><tr><td>Cash / النقد</td><td>${finVal(d.cash_in)}</td><td>${finVal(d.cash_out)}</td><td>${finVal(d.cash_net)}</td></tr><tr><td>Bank / البنك</td><td>${finVal(d.bank_in)}</td><td>${finVal(d.bank_out)}</td><td>${finVal(d.bank_net)}</td></tr><tr class="fin-total"><td>Total</td><td>${finVal(Number(d.cash_in||0)+Number(d.bank_in||0))}</td><td>${finVal(Number(d.cash_out||0)+Number(d.bank_out||0))}</td><td>${finVal(d.total_net)}</td></tr></tbody></table></div>`}
function renderRows(rows,headers){if(!rows.length)return '<div class="fin-muted" style="padding:25px;text-align:center">لا توجد بيانات لهذه الفترة.</div>';return `<div class="fin-table-wrap"><table class="fin-table"><thead><tr>${headers.map(h=>`<th>${h[0]}</th>`).join('')}</tr></thead><tbody>${rows.map(r=>`<tr>${headers.map(h=>`<td>${h[1](r)}</td>`).join('')}</tr>`).join('')}</tbody></table></div>`}
function renderTB(rows){const totalDebit=rows.reduce((a,r)=>a+Number(r.debit||0),0),totalCredit=rows.reduce((a,r)=>a+Number(r.credit||0),0);return `<div class="fin-kpis">${reportKpi('Total Debit / إجمالي المدين',totalDebit)}${reportKpi('Total Credit / إجمالي الدائن',totalCredit)}${reportKpi('Difference / الفرق',totalDebit-totalCredit,(Math.abs(totalDebit-totalCredit)<.001?'fin-good':'fin-bad'))}</div><div class="fin-section"><h3>Trial Balance</h3>${renderRows(rows,[['Code',r=>finEsc(r.code)],['Account',r=>finEsc(r.name)],['Type',r=>finEsc(r.account_type)],['Debit',r=>finVal(r.debit)],['Credit',r=>finVal(r.credit)],['Balance',r=>finVal(r.balance)]])}</div>`}
function renderGL(rows,meta={}){
  const selected=meta.account_id||$('glAccountId')?.value||'';
  const options=financialAccounts.map(a=>`<option value="${esc(a.id)}" ${a.id===selected?'selected':''}>${esc(a.code)} — ${esc(a.name)}</option>`).join('');
  const opening=Number(meta.opening_balance||0),closing=Number(meta.closing_balance||0);
  const headers=[['Date',r=>finEsc(r.entry_date||r.date)],['Entry',r=>finEsc(r.entry_number||r.journal_entry)],['Description',r=>finEsc(r.description)],['Debit',r=>finVal(r.debit)],['Credit',r=>finVal(r.credit)],['Balance',r=>finVal(r.balance)]];
  return `<div class="fin-kpis">${reportKpi('Opening Balance / الرصيد الافتتاحي',opening)}${reportKpi('Closing Balance / الرصيد الختامي',closing)}</div><div class="fin-section"><div class="toolbar"><h3>General Ledger / الأستاذ العام</h3><div class="filters"><select id="glAccountId" style="min-width:260px">${options||'<option value="">لا توجد حسابات</option>'}</select><button class="btnx primary" onclick="loadGeneralLedger()">عرض الحساب</button></div></div>${renderRows(rows,headers)}</div>`;
}
function renderVAT(d){const x=d||{};return `<div class="fin-kpis">${reportKpi('Output VAT / ضريبة المخرجات',x.output_vat)}${reportKpi('Input VAT / ضريبة المدخلات',x.input_vat)}${reportKpi('Net VAT / صافي الضريبة',x.net_vat,(Number(x.net_vat||0)>0?'fin-warn':'fin-good'))}</div><div class="fin-section"><h3>VAT Summary</h3><table class="fin-table"><tbody>${Object.entries(x).filter(([k])=>!['from_date','to_date'].includes(k)).map(([k,v])=>`<tr><td>${finEsc(k.replaceAll('_',' '))}</td><td>${typeof v==='number'?finVal(v):finEsc(v)}</td></tr>`).join('')}</tbody></table></div>`}
function renderControl(d){const x=d||{};const ok=x.ok===true||x.success===true||x.balanced===true||x.status==='ok'||x.status==='passed';return `<div class="fin-section"><h3>Accounting Control Check</h3><div class="notice ${ok?'ok':'warn'}">${ok?'✓ Accounting controls passed':'⚠ Review required'}</div><table class="fin-table"><tbody>${Object.entries(x).map(([k,v])=>`<tr><td>${finEsc(k.replaceAll('_',' '))}</td><td>${typeof v==='object'?`<pre style="margin:0;white-space:pre-wrap">${finEsc(JSON.stringify(v,null,2))}</pre>`:finEsc(v)}</td></tr>`).join('')}</tbody></table></div>`}
async function loadGeneralLedger(){try{if(!financialAccounts.length)await loadFinancialAccounts();const accountId=$('glAccountId')?.value||financialAccounts[0]?.id;if(!accountId)return financialStatus('لا توجد حسابات محاسبية.','err');const from=finDate('finFrom'),to=finDate('finTo');financialStatus('جاري تحميل الأستاذ العام...');const d=await rpc('erp_general_ledger',{p_from:from,p_to:to,p_account_id:accountId});$('financialReportContent').innerHTML=renderGL(finArr(d),d||{});financialStatus('تم تحميل الأستاذ العام.','ok')}catch(e){financialStatus(e.message||'تعذر تحميل الأستاذ العام.','err')}}
async function loadFinancialReports(){const from=finDate('finFrom'),to=finDate('finTo');if(!from||!to)return msg('حدد تاريخ البداية والنهاية.','err');if(from>to)return msg('تاريخ البداية يجب أن يكون قبل تاريخ النهاية.','err');try{financialStatus('جاري تحميل التقرير المحاسبي...');let html='';if(activeFinancialReport==='pl'){html=renderPL(await rpc('erp_profit_loss_accounting',{p_from:from,p_to:to}))}else if(activeFinancialReport==='bs'){html=renderBS(await rpc('erp_balance_sheet',{p_to:to}))}else if(activeFinancialReport==='cf'){html=renderCF(await rpc('erp_cash_flow',{p_from:from,p_to:to}))}else if(activeFinancialReport==='tb'){html=renderTB(finArr(await rpc('erp_trial_balance',{p_from:from,p_to:to})))}else if(activeFinancialReport==='gl'){if(!financialAccounts.length)await loadFinancialAccounts();const accountId=$('glAccountId')?.value||financialAccounts[0]?.id;if(!accountId)throw new Error('لا توجد حسابات محاسبية.');const d=await rpc('erp_general_ledger',{p_from:from,p_to:to,p_account_id:accountId});html=renderGL(finArr(d),d||{})}else if(activeFinancialReport==='vatf'){html=renderVAT(await rpc('erp_financial_vat_summary',{p_from:from,p_to:to}))}else if(activeFinancialReport==='control'){html=renderControl(await rpc('erp_accounting_control_check',{p_from:from,p_to:to}))}$('financialReportContent').innerHTML=html;financialStatus(`تم تحديث التقرير: ${from} → ${to}`,'ok')}catch(e){$('financialReportContent').innerHTML='';financialStatus(e.message||'تعذر تحميل التقرير.','err')}}
async function loadReports(){return loadFinancialReports()}

async function printInvoice(id){try{const i=invoices.find(x=>x.id===id);if(!i)return;const items=await rpc('erp_get_invoice_items',{p_invoice_id:id});const w=window.open('','_blank');w.document.write(`<html dir="rtl"><head><title>${esc(i.invoice_number)}</title><style>body{font-family:Arial;padding:40px;color:#111}h1{color:#092a82}.head{display:flex;justify-content:space-between}.box{border:1px solid #ddd;padding:15px;margin:15px 0;border-radius:8px}table{width:100%;border-collapse:collapse}th,td{border-bottom:1px solid #ddd;padding:10px;text-align:right}.total{font-size:20px;font-weight:bold;text-align:left;margin-top:20px}</style></head><body><div class="head"><div><h1>${esc(settings.company_name||'BINGO Oman')}</h1><div>${esc(settings.tax_number||'')}</div><div>${esc(settings.phone||'')}</div></div><div><h2>فاتورة ضريبية</h2><b>${esc(i.invoice_number)}</b><div>${esc(i.issue_date)}</div></div></div><div class="box"><b>العميل:</b> ${esc(i.customer_name||'—')} ${i.customer_company?'<br>'+esc(i.customer_company):''}</div><table><thead><tr><th>الوصف</th><th>الكمية</th><th>سعر الوحدة</th><th>الخصم</th><th>الإجمالي</th></tr></thead><tbody>${(items||[]).map(x=>`<tr><td>${esc(x.description)}</td><td>${x.quantity}</td><td>${Number(x.unit_price).toFixed(3)}</td><td>${Number(x.discount).toFixed(3)}</td><td>${Number(x.line_total).toFixed(3)}</td></tr>`).join('')}</tbody></table><div class="total">Subtotal: ${Number(i.subtotal).toFixed(3)} OMR<br>VAT ${Number(i.vat_rate).toFixed(2)}%: ${Number(i.vat_amount).toFixed(3)} OMR<br>Grand Total: ${Number(i.total).toFixed(3)} OMR</div></body></html>`);w.document.close();setTimeout(()=>{try{w.focus();w.print()}catch(_e){}},500)}catch(e){msg(e.message,'err')}}
document.querySelectorAll('.report-tab').forEach(b=>b.onclick=()=>{document.querySelectorAll('.report-tab').forEach(x=>x.classList.remove('active'));b.classList.add('active');activeFinancialReport=b.dataset.report;loadFinancialReports()});
document.querySelectorAll('[data-tab]').forEach(b=>b.onclick=()=>{document.querySelectorAll('[data-tab]').forEach(x=>x.classList.remove('active'));b.classList.add('active');document.querySelectorAll('.tab').forEach(x=>x.style.display='none');$('tab-'+b.dataset.tab).style.display='block';if(b.dataset.tab==='reports'){loadFinancialReports()}if(b.dataset.tab==='purchases'){loadSuppliers();loadPurchases()}if(b.dataset.tab==='suppliers'){loadSuppliers()}});
(function initFinancialDates(){const now=new Date();const t=localDateISO(now);const y=new Date(now);y.setDate(y.getDate()-1);const yesterday=localDateISO(y);$('finTo')&&($('finTo').value=t);$('finFrom')&&($('finFrom').value=yesterday);$('from')&&($('from').value=t);$('to')&&($('to').value=t);$('vatFrom')&&($('vatFrom').value=t);$('vatTo')&&($('vatTo').value=t)})();
init();