(function(){
  'use strict';
  const EN_AR={
    'ERP • BUSINESS MANAGEMENT':'ERP • إدارة الأعمال',
    'ERP • Business Management':'ERP • إدارة الأعمال',
    'Human Resources':'الموارد البشرية',
    'HR • HUMAN RESOURCES':'الموارد البشرية • الموارد البشرية',
    'Employees • Attendance • Payroll • Salary payments':'الموظفون • الحضور والانصراف • الرواتب • مدفوعات الرواتب',
    'Employees':'الموظفون','Attendance':'الحضور والانصراف','Payroll':'الرواتب','SQL Editor':'محرر SQL',
    'Manage employee records and employment status.':'إدارة بيانات الموظفين وحالة التوظيف.',
    'Track work hours, overtime and late minutes.':'تتبع ساعات العمل والعمل الإضافي ودقائق التأخير.',
    'Generate, approve and pay employee payroll.':'إنشاء واعتماد ودفع رواتب الموظفين.',
    'Employees':'الموظفون','Active':'نشط','Monthly payroll':'إجمالي الرواتب الشهرية','Unpaid payroll':'الرواتب غير المدفوعة',
    'New employee':'موظف جديد','Record attendance':'تسجيل الحضور','Generate payroll':'إنشاء كشف راتب','Generate draft payroll':'إنشاء مسودة راتب',
    'Employee number':'رقم الموظف','Full name':'الاسم الكامل','Phone':'الهاتف','Email':'البريد الإلكتروني','Job title':'المسمى الوظيفي','Department':'القسم','Hire date':'تاريخ التعيين','Basic monthly salary (OMR)':'الراتب الأساسي الشهري (ر.ع)','Status':'الحالة','Notes':'ملاحظات','Work date':'تاريخ العمل','Check in':'وقت الدخول','Check out':'وقت الخروج','Work hours':'ساعات العمل','Overtime hours':'الساعات الإضافية','Late minutes':'دقائق التأخير','Payroll month':'شهر الراتب','Allowances':'البدلات','Deductions':'الخصومات','Overtime amount':'قيمة العمل الإضافي','Net salary':'صافي الراتب',
    'Admin access required':'مطلوب دخول المسؤول','This area is restricted to BINGO administrators.':'هذه المنطقة مخصصة لمسؤولي BINGO.','Back to account':'العودة إلى الحساب','Back to Admin Center':'العودة إلى مركز الإدارة','Back to Admin Center':'العودة إلى مركز الإدارة',
    'New employee':'موظف جديد','Edit employee':'تعديل الموظف','Save employee':'حفظ الموظف','Save attendance':'حفظ الحضور','Approve':'اعتماد','Mark paid':'تسجيل كمدفوع','Paid':'مدفوع','Approved':'معتمد','Draft':'مسودة','Inactive':'غير نشط',
    'Product':'المنتج','Products':'المنتجات','Supplier':'المورد','Suppliers':'الموردون','Customer':'العميل','Customers':'العملاء','Invoice':'الفاتورة','Invoices':'الفواتير','Payment':'الدفع','Payments':'المدفوعات','Expense':'المصروف','Expenses':'المصروفات','VAT':'ضريبة القيمة المضافة','Reports':'التقارير','Accounting':'المحاسبة','Inventory':'المخزون','Purchases':'المشتريات','Sales':'المبيعات','Finance':'المالية',
    'Financial Dashboard':'لوحة المالية','Financial control panel':'لوحة التحكم المالية','Company and accounting management':'إدارة الشركة والحسابات','Customers database':'قاعدة بيانات العملاء','Products and inventory':'المنتجات والمخزون','Purchase invoices':'فواتير الشراء','Supplier payments':'دفعات الموردين','Company settings':'إعدادات الشركة',
    'Sales':'المبيعات','Collected amounts':'المبالغ المحصلة','Expenses':'المصروفات','Receivables':'المستحقات','VAT on sales':'ضريبة القيمة المضافة على المبيعات','VAT on expenses':'ضريبة القيمة المضافة على المصروفات','Number of customers':'عدد العملاء',
    'Choose the period to display company indicators.':'اختر الفترة لعرض مؤشرات الشركة.','Refresh':'تحديث','New customer':'عميل جديد','New product':'منتج جديد','New purchase':'شراء جديد','New invoice':'فاتورة جديدة','New payment':'دفعة جديدة','New expense':'مصروف جديد',
    'Search by name, phone, email...':'بحث بالاسم أو الهاتف أو البريد...','Search by name, SKU or category...':'بحث بالاسم أو SKU أو التصنيف...','Search by title, reference or city…':'بحث بالعنوان أو المرجع أو المدينة…',
    'Excel':'Excel','Export Excel':'تصدير Excel','Download':'تنزيل','Print':'طباعة','Save':'حفظ','Cancel':'إلغاء','Close':'إغلاق','Edit':'تعديل','Delete':'حذف','View':'عرض','Details':'التفاصيل','Add':'إضافة','Create':'إنشاء','Update':'تحديث','Total':'الإجمالي','Subtotal':'المجموع الفرعي','Discount':'الخصم','Tax':'الضريبة','Grand Total':'الإجمالي النهائي','Paid Amount':'المبلغ المدفوع','Balance':'الرصيد','Quantity':'الكمية','Unit Cost':'تكلفة الوحدة','Line Discount':'خصم السطر','Line Total':'إجمالي السطر','Purchase Number':'رقم الشراء','Purchase Invoice':'فاتورة شراء','Supplier Payment':'دفعة للمورد','Inventory Value':'قيمة المخزون','Stock Quantity':'كمية المخزون','Cost Price':'سعر التكلفة',
    '← Admin Center':'← مركز الإدارة','Admin Center':'مركز الإدارة','Home':'الرئيسية','Account':'الحساب','My Account':'حسابي','My Ads':'إعلاناتي','My Favorites':'مفضلتي','My Messages':'رسائلي','Logout':'تسجيل الخروج',
    'BINGO Oman | HR':'BINGO عُمان | الموارد البشرية','BINGO Oman | ERP & Business Management':'BINGO عُمان | ERP وإدارة الأعمال'
  };
  const AR_EN=Object.fromEntries(Object.entries(EN_AR).map(([e,a])=>[a,e]));
  const getLang=()=>localStorage.getItem('bingo-language')||localStorage.getItem('bingo-lang')||'en';
  const skip=n=>!n.parentElement||/^(SCRIPT|STYLE|TEXTAREA|INPUT|OPTION)$/i.test(n.parentElement.tagName)||n.parentElement.closest('[data-no-translate]');
  function translate(root){
    const map=getLang()==='ar'?EN_AR:AR_EN;
    const w=document.createTreeWalker(root,NodeFilter.SHOW_TEXT);const nodes=[];let n;while((n=w.nextNode()))nodes.push(n);
    nodes.forEach(t=>{if(skip(t))return;const raw=t.nodeValue.trim();if(!raw)return;const key=raw.replace(/\s+/g,' ');if(map[key])t.nodeValue=t.nodeValue.replace(raw,map[key]);});
    root.querySelectorAll?.('[placeholder],[title],[aria-label]').forEach(el=>['placeholder','title','aria-label'].forEach(a=>{const v=el.getAttribute(a);if(v&&map[v])el.setAttribute(a,map[v]);}));
  }
  function apply(){const l=getLang();document.documentElement.lang=l;document.documentElement.dir=l==='ar'?'rtl':'ltr';document.body?.classList.toggle('rtl',l==='ar');if(document.body)translate(document.body);}
  function init(){apply();const obs=new MutationObserver(()=>apply());obs.observe(document.body,{childList:true,subtree:true});window.BingoPageLang={apply};}
  if(document.readyState==='loading')document.addEventListener('DOMContentLoaded',init,{once:true});else init();
})();
