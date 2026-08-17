/* Bingo Delivery — Supabase integration + stable i18n + login */
(function () {
  'use strict';
  const KEY = 'bingo_delivery_lang';
  const dict = {
    en: {delivery:'Delivery',admin:'Delivery Admin',seller:'Seller',driver:'Driver',customer:'Customer',orders:'Orders',drivers:'Drivers',stores:'Stores',zones:'Zones',complaints:'Complaints',fees:'Delivery Fees',commissions:'Commissions',earnings:'Earnings',online:'Online',offline:'Offline',available:'Available',busy:'Busy',accept:'Accept',reject:'Reject',pickup:'Pickup',delivered:'Delivered',onDelivery:'On Delivery',preparing:'Preparing',pending:'Pending',confirmed:'Confirmed',cancelled:'Cancelled',ready:'Ready',assigned:'Assigned',picked_up:'Picked up',offered:'Offered',liveMap:'Live Map',activeDeliveries:'Active Deliveries',today:'Today',thisWeek:'This Week',totalOrders:'Total Orders',deliveryRevenue:'Delivery Revenue',onlineDrivers:'Online Drivers',requestDriver:'Request Driver',assignDriver:'Assign driver',navigate:'Navigate',rateDriver:'Rate Driver',save:'Save',search:'Search',status:'Status',distance:'Distance',earning:'Earning',actions:'Actions',customerName:'Customer',storeName:'Store',driverName:'Driver',deliveryFee:'Delivery Fee',bingoShare:'Bingo Share',driverShare:'Driver Share',total:'Total',newOrder:'New Order',noOrders:'No orders yet',noActive:'No active deliveries',noDrivers:'No drivers',noPricing:'No active pricing rules',checkout:'Checkout',deliveryAddress:'Delivery Address',location:'Location',deliveryOption:'Delivery Option',orderItems:'Order Items',confirmOrder:'Confirm Order',myOrders:'My Orders',orderCreated:'Order created successfully',loginRequired:'Please sign in before placing an order',invalidItems:'Enter valid order items JSON',storeRequired:'Select a store before placing the order',useLocation:'Use my current location',login:'Login',logout:'Logout',email:'Email',password:'Password',signIn:'Sign in',close:'Close',loginSuccess:'Signed in successfully',loginFailed:'Login failed'},
    ar: {delivery:'التوصيل',admin:'إدارة التوصيل',seller:'البائع',driver:'المندوب',customer:'العميل',orders:'الطلبات',drivers:'المندوبون',stores:'المتاجر',zones:'المناطق',complaints:'الشكاوى',fees:'رسوم التوصيل',commissions:'العمولات',earnings:'الأرباح',online:'متصل',offline:'غير متصل',available:'متاح',busy:'مشغول',accept:'قبول',reject:'رفض',pickup:'استلام',delivered:'تم التسليم',onDelivery:'قيد التوصيل',preparing:'قيد التجهيز',pending:'معلق',confirmed:'مؤكد',cancelled:'ملغي',ready:'جاهز',assigned:'تم التعيين',picked_up:'تم الاستلام',offered:'معروض',liveMap:'الخريطة المباشرة',activeDeliveries:'التوصيلات النشطة',today:'اليوم',thisWeek:'هذا الأسبوع',totalOrders:'إجمالي الطلبات',deliveryRevenue:'إيرادات التوصيل',onlineDrivers:'المندوبون المتصلون',requestDriver:'طلب مندوب',assignDriver:'تعيين مندوب',navigate:'الملاحة',rateDriver:'تقييم المندوب',save:'حفظ',search:'بحث',status:'الحالة',distance:'المسافة',earning:'الأرباح',actions:'الإجراءات',customerName:'العميل',storeName:'المتجر',driverName:'المندوب',deliveryFee:'رسوم التوصيل',bingoShare:'حصة Bingo',driverShare:'حصة المندوب',total:'الإجمالي',newOrder:'طلب جديد',noOrders:'لا توجد طلبات',noActive:'لا توجد توصيلات نشطة',noDrivers:'لا يوجد مندوبون',noPricing:'لا توجد قواعد تسعير فعالة',checkout:'إتمام الطلب',deliveryAddress:'عنوان التوصيل',location:'الموقع',deliveryOption:'خيار التوصيل',orderItems:'المنتجات',confirmOrder:'تأكيد الطلب',myOrders:'طلباتي',orderCreated:'تم إنشاء الطلب بنجاح',loginRequired:'يرجى تسجيل الدخول قبل إنشاء الطلب',invalidItems:'أدخل منتجات الطلب بصيغة JSON صحيحة',storeRequired:'اختر المتجر قبل إنشاء الطلب',useLocation:'استخدام موقعي الحالي',login:'تسجيل الدخول',logout:'تسجيل الخروج',email:'البريد الإلكتروني',password:'كلمة المرور',signIn:'دخول',close:'إغلاق',loginSuccess:'تم تسجيل الدخول بنجاح',loginFailed:'فشل تسجيل الدخول'}
  };

  const sb = window.supabaseClient || window.sb || window.supabase;
  const rpc = async (name, args = {}) => {
    if (!sb || typeof sb.rpc !== 'function') throw new Error('Supabase is not initialized');
    const { data, error } = await sb.rpc(name, args);
    if (error) throw error;
    return data;
  };

  function t(key) {
    const lang = localStorage.getItem(KEY) === 'en' ? 'en' : 'ar';
    return dict[lang]?.[key] || dict.en[key] || key;
  }

  function setLanguage(lang) {
    lang = lang === 'en' ? 'en' : 'ar';
    localStorage.setItem(KEY, lang);
    document.documentElement.lang = lang;
    document.documentElement.dir = lang === 'ar' ? 'rtl' : 'ltr';
    renderTranslations();
    window.dispatchEvent(new CustomEvent('bingo:language', { detail: { lang } }));
  }

  function ensureLoginUI() {
    const nav = document.querySelector('.bd-nav');
    if (!nav) return;

    let box = document.querySelector('#bd-auth-box');
    if (!box) {
      box = document.createElement('span');
      box.id = 'bd-auth-box';
      box.style.marginInlineStart = '10px';
      nav.appendChild(box);
    }

    if (!document.querySelector('#bd-login-modal')) {
      const modal = document.createElement('div');
      modal.id = 'bd-login-modal';
      modal.style.cssText = 'display:none;position:fixed;inset:0;background:rgba(0,0,0,.55);z-index:9999;align-items:center;justify-content:center;padding:20px';
      modal.innerHTML = '<form id="bd-login-form" style="background:#fff;color:#111;padding:24px;border-radius:16px;max-width:380px;width:100%;display:grid;gap:12px"><h2 data-bd-i18n="login">تسجيل الدخول</h2><input id="bd-login-email" type="email" required data-bd-placeholder="email" placeholder="البريد الإلكتروني"><input id="bd-login-password" type="password" required data-bd-placeholder="password" placeholder="كلمة المرور"><div style="display:flex;gap:8px"><button class="bd-btn orange" type="submit" data-bd-i18n="signIn">دخول</button><button class="bd-btn ghost" type="button" id="bd-login-close" data-bd-i18n="close">إغلاق</button></div><p id="bd-login-message" role="status"></p></form>';
      document.body.appendChild(modal);
      document.querySelector('#bd-login-close').onclick = () => { modal.style.display = 'none'; };
      document.querySelector('#bd-login-form').onsubmit = async (event) => {
        event.preventDefault();
        const msg = document.querySelector('#bd-login-message');
        try {
          msg.textContent = '';
          const { error } = await sb.auth.signInWithPassword({
            email: document.querySelector('#bd-login-email').value.trim(),
            password: document.querySelector('#bd-login-password').value
          });
          if (error) throw error;
          modal.style.display = 'none';
          msg.textContent = t('loginSuccess');
          await renderAuth();
        } catch (err) {
          msg.textContent = err.message || t('loginFailed');
        }
      };
    }
  }

  async function renderAuth() {
    ensureLoginUI();
    const box = document.querySelector('#bd-auth-box');
    if (!box || !sb?.auth) return;
    const { data } = await sb.auth.getSession();
    if (data?.session) {
      box.innerHTML = '<button type="button" class="bd-btn ghost" id="bd-logout" data-bd-i18n="logout">تسجيل الخروج</button>';
      document.querySelector('#bd-logout').onclick = async () => {
        await sb.auth.signOut();
        await renderAuth();
      };
    } else {
      box.innerHTML = '<button type="button" class="bd-btn orange" id="bd-login" data-bd-i18n="login">تسجيل الدخول</button>';
      document.querySelector('#bd-login').onclick = () => {
        const modal = document.querySelector('#bd-login-modal');
        if (modal) modal.style.display = 'flex';
      };
    }
    renderTranslations();
  }

  function renderTranslations() {
    const lang = localStorage.getItem(KEY) === 'en' ? 'en' : 'ar';
    document.documentElement.lang = lang;
    document.documentElement.dir = lang === 'ar' ? 'rtl' : 'ltr';
    document.querySelectorAll('[data-bd-i18n]').forEach(el => { el.textContent = t(el.dataset.bdI18n); });
    document.querySelectorAll('[data-bd-placeholder]').forEach(el => { el.placeholder = t(el.dataset.bdPlaceholder); });
    document.querySelectorAll('[data-bd-title]').forEach(el => { el.title = t(el.dataset.bdTitle); });
    const sw = document.querySelector('[data-bd-language]');
    if (sw) sw.textContent = lang === 'ar' ? 'EN' : 'العربية';
  }

  window.BingoDelivery = {
    getLang: () => localStorage.getItem(KEY) === 'en' ? 'en' : 'ar',
    setLang: setLanguage,
    t,
    render: renderTranslations,
    renderAuth,
    rpc,
    createOrder: a => rpc('delivery_create_order', a),
    setDriverStatus: online => rpc('delivery_set_driver_status', { p_online: online }),
    updateLocation: (lat,lng,accuracy=null,heading=null,speed=null) => rpc('delivery_update_location', { p_latitude:lat,p_longitude:lng,p_accuracy_m:accuracy,p_heading:heading,p_speed_kmh:speed }),
    decideAssignment: (id,accept) => rpc('delivery_driver_decide', { p_assignment_id:id,p_accept:accept }),
    setAssignmentStatus: (id,status) => rpc('delivery_set_assignment_status', { p_assignment_id:id,p_status:status }),
    assignDriver: (orderId,driverId) => rpc('delivery_assign_driver', { p_order_id:orderId,p_driver_id:driverId }),
    setSellerOrderStatus: (orderId,status) => rpc('delivery_store_set_order_status', { p_order_id:orderId,p_status:status })
  };

  function getStoreId() {
    return document.querySelector('#delivery-store-id')?.value || new URLSearchParams(location.search).get('store') || '';
  }

  function syncTotals() {
    const fee = Number(document.querySelector('#delivery-option')?.value || 1.5);
    let items = [];
    try { items = JSON.parse(document.querySelector('#delivery-items')?.value || '[]'); } catch { return; }
    const subtotal = Array.isArray(items) ? items.reduce((sum,i) => sum + Number(i.quantity||0) * Number(i.unit_price||0), 0) : 0;
    const feeEl = document.querySelector('#delivery-fee');
    const totalEl = document.querySelector('#delivery-total');
    if (feeEl) feeEl.textContent = fee.toFixed(3) + ' OMR';
    if (totalEl) totalEl.textContent = (subtotal + fee).toFixed(3) + ' OMR';
  }

  async function createCustomerOrder() {
    const msg = document.querySelector('#checkout-message');
    try {
      if (msg) msg.textContent = '';
      const session = await sb.auth.getSession();
      if (!session.data?.session) throw new Error(t('loginRequired'));
      const storeId = getStoreId();
      if (!storeId) throw new Error(t('storeRequired'));
      let items;
      try { items = JSON.parse(document.querySelector('#delivery-items')?.value || '[]'); } catch { throw new Error(t('invalidItems')); }
      if (!Array.isArray(items) || !items.length) throw new Error(t('invalidItems'));
      const fee = Number(document.querySelector('#delivery-option')?.value || 1.5);
      const lat = Number(document.querySelector('#delivery-lat')?.value || 0);
      const lng = Number(document.querySelector('#delivery-lng')?.value || 0);
      const address = document.querySelector('#delivery-address')?.value?.trim() || '';
      const id = await BingoDelivery.createOrder({
        p_store_id: storeId,p_address:address,p_latitude:lat,p_longitude:lng,
        p_distance_km:Number(document.querySelector('#delivery-distance')?.value||0),p_items:items,
        p_delivery_fee:fee,p_driver_share:fee*0.733333,p_bingo_share:fee*0.266667,
        p_store_commission:0,p_payment_status:'pending',p_notes:null
      });
      if (msg) msg.textContent = t('orderCreated') + ' — ' + id;
      await loadOrders();
    } catch (err) { if (msg) msg.textContent = err.message || 'Order creation failed'; }
  }

  async function loadOrders() {
    if (!sb?.from) return;
    const { data, error } = await sb.from('delivery_orders').select('id,order_number,status,total,delivery_fee,delivery_address,created_at').order('created_at',{ascending:false}).limit(50);
    if (error) return;
    const hosts = [document.querySelector('#delivery-orders'),document.querySelector('#orders-list'),document.querySelector('#seller-orders'),document.querySelector('#orders-table-body')].filter(Boolean);
    hosts.forEach(host => { host.innerHTML = data?.length ? data.map(o => `<article class="delivery-order-card"><strong>${o.order_number}</strong><span>${t(o.status)||o.status}</span><span>${Number(o.total||0).toFixed(3)} OMR</span><small>${o.delivery_address||''}</small></article>`).join('') : `<p>${t('noOrders')}</p>`; });
  }

  async function loadAssignments() {
    if (!sb?.from) return;
    const { data, error } = await sb.from('delivery_assignments').select('id,status,order_id,delivery_orders(order_number,total,delivery_address)').in('status',['offered','accepted','picked_up','on_delivery']).order('offered_at',{ascending:false});
    if (error) return;
    const host = document.querySelector('#driver-orders') || document.querySelector('#active-deliveries');
    if (!host) return;
    host.innerHTML = data?.length ? data.map(a => `<article class="delivery-order-card" data-assignment="${a.id}"><strong>${a.delivery_orders?.order_number||a.order_id}</strong><span>${t(a.status)||a.status}</span><span>${Number(a.delivery_orders?.total||0).toFixed(3)} OMR</span><small>${a.delivery_orders?.delivery_address||''}</small></article>`).join('') : `<p>${t('noActive')}</p>`;
  }

  function startLocation() {
    if (!navigator.geolocation) return;
    navigator.geolocation.watchPosition(
      p => BingoDelivery.updateLocation(p.coords.latitude,p.coords.longitude,p.coords.accuracy,p.coords.heading,p.coords.speed ? p.coords.speed*3.6 : null).catch(()=>{}),
      ()=>{},
      {enableHighAccuracy:true,maximumAge:5000,timeout:15000}
    );
  }

  document.addEventListener('click', async event => {
    const button = event.target.closest('[data-delivery-action]');
    if (!button) return;
    const action = button.dataset.deliveryAction;
    try {
      if (action === 'online') { await BingoDelivery.setDriverStatus(true); startLocation(); }
      else if (action === 'offline') await BingoDelivery.setDriverStatus(false);
      else if (action === 'accept' || action === 'reject') { await BingoDelivery.decideAssignment(button.dataset.id,action==='accept'); await loadAssignments(); }
      else if (['picked_up','on_delivery','delivered','cancelled'].includes(action)) { await BingoDelivery.setAssignmentStatus(button.dataset.id,action); await loadAssignments(); }
      else if (action === 'language') setLanguage(BingoDelivery.getLang()==='ar'?'en':'ar');
      else if (action === 'create-order') await createCustomerOrder();
      else if (action === 'seller-status') { await BingoDelivery.setSellerOrderStatus(button.dataset.orderId,button.dataset.status); await loadOrders(); }
      else if (action === 'use-location' && navigator.geolocation) navigator.geolocation.getCurrentPosition(p => { const lat=document.querySelector('#delivery-lat'); const lng=document.querySelector('#delivery-lng'); if(lat)lat.value=p.coords.latitude; if(lng)lng.value=p.coords.longitude; });
    } catch (err) { console.error(err); alert(err.message || 'Delivery action failed'); }
  });

  document.addEventListener('DOMContentLoaded', async () => {
    renderTranslations();
    ensureLoginUI();
    renderTranslations();
    await renderAuth();
    syncTotals();
    loadOrders();
    loadAssignments();
    document.querySelector('#delivery-option')?.addEventListener('change',syncTotals);
    document.querySelector('#delivery-items')?.addEventListener('input',syncTotals);
    if (sb?.auth) sb.auth.onAuthStateChange(() => renderAuth());
    if (sb?.channel) sb.channel('bingo-delivery-live').on('postgres_changes',{event:'*',schema:'public',table:'delivery_orders'},loadOrders).on('postgres_changes',{event:'*',schema:'public',table:'delivery_assignments'},loadAssignments).subscribe();
  });
})();