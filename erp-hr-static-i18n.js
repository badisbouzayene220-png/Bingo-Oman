(function () {
  'use strict';

  // Stable ERP/HR translator. No MutationObserver and no polling.
  // Text is snapshotted once per DOM text node; translation runs only on
  // initial load and explicit user actions.
  const PAIRS = {
    'ERP • BUSINESS MANAGEMENT':'ERP • BUSINESS MANAGEMENT','إدارة الشركة والحسابات':'Business & Accounting Management','العملاء • الفواتير • المدفوعات • المصروفات • ضريبة القيمة المضافة • التقارير':'Customers • Invoices • Payments • Expenses • VAT • Reports','← مركز الإدارة':'← Admin Center','مركز الإدارة':'Admin Center','هذه الصفحة للمشرف فقط':'Admin access required','العودة للحساب':'Back to account','لوحة المالية':'Financial Dashboard','العملاء':'Customers','المنتجات والمخزون':'Products & Inventory','الموردون':'Suppliers','المشتريات':'Purchases','الفواتير':'Invoices','المدفوعات':'Payments','المصروفات':'Expenses','VAT / الضريبة':'VAT / Tax','التقارير':'Reports','إعدادات الشركة':'Company Settings','المبيعات':'Sales','المبالغ المحصلة':'Collected Amount','المستحقات':'Receivables','لوحة التحكم المالية':'Financial Dashboard','اختر الفترة لعرض مؤشرات الشركة.':'Choose a period to view company indicators.','تحديث':'Refresh','VAT على المبيعات':'Sales VAT','VAT على المصروفات':'Expense VAT','عدد العملاء':'Customers Count','قاعدة بيانات العملاء':'Customer Database','CRM بسيط مرتبط بالفواتير والمدفوعات.':'Simple CRM linked to invoices and payments.','عميل جديد':'New Customer','بحث بالاسم، الهاتف، البريد...':'Search by name, phone, email...','منتج جديد':'New Product','إدارة المنتجات، الأسعار، الكميات وحركات المخزون.':'Manage products, prices, quantities and stock movements.','بحث بالاسم أو SKU أو التصنيف...':'Search by name, SKU or category...','كل المنتجات':'All products','مخزون منخفض':'Low stock','نفد المخزون':'Out of stock','مورد جديد':'New Supplier','إدارة الموردين والمشتريات والمدفوعات.':'Manage suppliers, purchases and payments.','فاتورة شراء جديدة':'New Purchase Invoice','إدارة المشتريات والاستلام وتكلفة المخزون.':'Manage purchases, receiving and inventory cost.','فاتورة جديدة':'New Invoice','إدارة فواتير المبيعات والمدفوعات.':'Manage sales invoices and payments.','مصروف جديد':'New Expense','إدارة المصروفات والضرائب.':'Manage expenses and taxes.','المحاسبة':'Accounting','الحسابات':'Accounts','دليل الحسابات':'Chart of Accounts','قيود اليومية':'Journal Entries','ميزان المراجعة':'Trial Balance','الأستاذ العام':'General Ledger','الميزانية العمومية':'Balance Sheet','قائمة الدخل':'Income Statement','تكلفة البضاعة المباعة':'Cost of Goods Sold','إجمالي الربح':'Gross Profit','المصروفات التشغيلية':'Operating Expenses','صافي الربح':'Net Profit','ضريبة القيمة المضافة':'Value Added Tax','المبلغ الخاضع للضريبة':'Taxable Amount','مبلغ الضريبة':'VAT Amount','المبلغ المدفوع':'Paid Amount','المتبقي':'Remaining','بحث':'Search','حفظ':'Save','إلغاء':'Cancel','إغلاق':'Close','تعديل':'Edit','حذف':'Delete','عرض':'View','تفاصيل':'Details','إضافة':'Add','إنشاء':'Create','تأكيد':'Confirm','نعم':'Yes','لا':'No','حالة':'Status','التاريخ':'Date','المبلغ':'Amount','الإجمالي':'Total','الكمية':'Quantity','السعر':'Price','التكلفة':'Cost','الخصم':'Discount','الوصف':'Description','الاسم':'Name','الهاتف':'Phone','البريد الإلكتروني':'Email','العنوان':'Address','الملاحظات':'Notes','التصنيف':'Category','الوحدة':'Unit','رمز المنتج':'SKU','المورد':'Supplier','العميل':'Customer','الحساب':'Account','الحساب البنكي':'Bank Account','رقم الفاتورة':'Invoice Number','رقم الشراء':'Purchase Number',
    'HR • HUMAN RESOURCES':'HR • HUMAN RESOURCES','الموارد البشرية':'Human Resources','الموظفون • الحضور والانصراف • الرواتب • مدفوعات الرواتب':'Employees • Attendance • Payroll • Salary Payments','الموظفون':'Employees','الحضور والانصراف':'Attendance','الرواتب':'Payroll','محرر SQL':'SQL Editor','النشطون':'Active','الرواتب الشهرية':'Monthly Payroll','الرواتب غير المدفوعة':'Unpaid Payroll','إدارة سجلات الموظفين وحالة التوظيف.':'Manage employee records and employment status.','تتبع ساعات العمل والعمل الإضافي ودقائق التأخير.':'Track work hours, overtime and late minutes.','إنشاء واعتماد ودفع رواتب الموظفين.':'Generate, approve and pay employee payroll.','موظف':'Employee','حضور':'Attendance','إنشاء الرواتب':'Generate Payroll','تشغيل الاستعلام':'Run query','مسح':'Clear','لأسباب أمنية، لا ينفذ هذا المحرر INSERT أو UPDATE أو DELETE أو DROP أو ALTER أو CREATE.':'For security, this editor does not execute INSERT, UPDATE, DELETE, DROP, ALTER or CREATE.','رقم الموظف':'Employee Number','الاسم الكامل':'Full Name','المسمى الوظيفي':'Job Title','القسم':'Department','تاريخ التوظيف':'Hire Date','الراتب الأساسي الشهري':'Basic Monthly Salary','نشط':'Active','غير نشط':'Inactive','حفظ الموظف':'Save Employee','موظف جديد':'New Employee','تسجيل الحضور':'Record Attendance','تاريخ العمل':'Work Date','دخول':'Check In','خروج':'Check Out','ساعات العمل':'Work Hours','ساعات إضافية':'Overtime Hours','دقائق التأخير':'Late Minutes','حفظ الحضور':'Save Attendance','إنشاء مسودة راتب':'Generate Draft Payroll','شهر الراتب':'Payroll Month','البدلات':'Allowances','الخصومات':'Deductions','مبلغ العمل الإضافي':'Overtime Amount','اعتماد':'Approve','دفع':'Pay','مدفوع':'Paid','مسودة':'Draft','ملغى':'Cancelled','معتمد':'Approved','غير مدفوع':'Unpaid',
    'SQL Editor':'SQL Editor','SELECT / WITH / EXPLAIN only.':'SELECT / WITH / EXPLAIN only.','العودة':'Back','الرئيسية':'Home','حسابي':'My Account','الإدارة':'Admin','ERP / Finance':'ERP / Finance','Admin Center':'Admin Center','Human Resources':'Human Resources','Home':'Home','Employees':'Employees','Attendance':'Attendance','Payroll':'Payroll','Salary payments':'Salary Payments','Generate payroll':'Generate Payroll','Save employee':'Save Employee','Record attendance':'Record Attendance','Save attendance':'Save Attendance','Admin access required':'Admin access required','This area is restricted to BINGO administrators.':'This area is restricted to BINGO administrators.','Back to account':'Back to account'
  };

  const AR_TO_EN = Object.assign({}, PAIRS);
  const EN_TO_AR = {};
  Object.keys(PAIRS).forEach(k => { const v=PAIRS[k]; if(k!==v) EN_TO_AR[v]=k; });
  const originals = new WeakMap();
  const attrOriginals = new WeakMap();
  let applying=false;

  function currentLang(){
    const stored=localStorage.getItem('bingo_language')||localStorage.getItem('language')||localStorage.getItem('lang');
    if(/^ar/i.test(stored||''))return'ar';
    if(/^en/i.test(stored||''))return'en';
    return /^ar/i.test(document.documentElement.lang||'')?'ar':'en';
  }

  function remember(root=document){
    const walker=document.createTreeWalker(root,NodeFilter.SHOW_TEXT);
    let n;
    while(n=walker.nextNode()){
      const p=n.parentElement;
      if(!p||/^(SCRIPT|STYLE|NOSCRIPT|TEXTAREA)$/i.test(p.tagName))continue;
      if(n.nodeValue.trim()&&!originals.has(n))originals.set(n,n.nodeValue);
    }
    root.querySelectorAll('*').forEach(el=>{
      ['placeholder','title','aria-label'].forEach(a=>{
        if(!el.hasAttribute(a))return;
        let m=attrOriginals.get(el);if(!m){m={};attrOriginals.set(el,m);}if(m[a]===undefined)m[a]=el.getAttribute(a);
      });
    });
  }

  function translateString(s,toAr){
    const dict=toAr?EN_TO_AR:AR_TO_EN;const t=String(s).trim();if(!t)return s;
    if(dict[t])return s.replace(t,dict[t]);
    let out=s;Object.keys(dict).sort((a,b)=>b.length-a.length).forEach(k=>{if(k&&out.includes(k))out=out.split(k).join(dict[k]);});return out;
  }

  function apply(){
    if(applying)return;applying=true;
    try{
      const toAr=currentLang()==='ar';
      document.documentElement.lang=toAr?'ar':'en';document.documentElement.dir=toAr?'rtl':'ltr';document.body.dir=toAr?'rtl':'ltr';
      const titleMap=toAr?EN_TO_AR:AR_TO_EN;document.title=translateString(document.title,toAr);
      const walker=document.createTreeWalker(document.body,NodeFilter.SHOW_TEXT);let n;
      while(n=walker.nextNode()){
        if(originals.has(n))n.nodeValue=translateString(originals.get(n),toAr);
      }
      document.querySelectorAll('*').forEach(el=>{const m=attrOriginals.get(el);if(!m)return;Object.keys(m).forEach(a=>el.setAttribute(a,translateString(m[a],toAr)));});
    }finally{applying=false;}
  }

  function refresh(){remember(document);apply();}

  document.addEventListener('click',function(e){
    const b=e.target.closest('button,a,[role="button"]');if(!b)return;
    const txt=(b.textContent||'').trim().toLowerCase();
    if(/^(ar|en|عربي|english|العربية|english \| العربية|العربية \| english)$/.test(txt)||b.dataset.lang||b.dataset.language){setTimeout(refresh,100);setTimeout(refresh,400);return;}
    if(/erp\.html$|hr\.html$/i.test(location.pathname))setTimeout(refresh,60);
  },true);

  document.addEventListener('DOMContentLoaded',()=>setTimeout(refresh,100),{once:true});
  window.BingoERPTranslator={apply:refresh};
})();
