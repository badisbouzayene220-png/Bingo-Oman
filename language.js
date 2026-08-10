(function () {
  "use strict";

  /*
   * BINGO Oman language engine
   * English <-> Arabic
   *
   * This file is intentionally self-contained.
   * It works with the old pages in this project and the new
   * data-i18n attributes used by index.html.
   */

  const KEYS = {
    en: {
      oman_marketplace: "🇴🇲 Oman's marketplace",
      business_tenders: "Business & Tenders",
      live_auctions: "Live Auctions",
      home: "Home",
      marketplace: "Marketplace",
      auctions: "Auctions",
      tenders: "Tenders",
      login: "Login",
      register: "Register",

      hero_eyebrow: "BUY • SELL • TRADE IN OMAN",
      hero_title_1: "Everything you need.",
      hero_title_2: "One place.",
      hero_description: "Discover products, services, auctions and tenders across Oman. Find great deals or put your own listing in front of buyers.",
      search_placeholder: "What are you looking for?",
      all_oman: "All Oman",
      muscat: "Muscat",
      seeb: "Seeb",
      salalah: "Salalah",
      sohar: "Sohar",
      nizwa: "Nizwa",
      sur: "Sur",
      search: "Search",
      popular: "Popular:",
      cars: "Cars",
      phones: "Phones",
      properties: "Properties",
      furniture: "Furniture",

      explore_bingo: "EXPLORE BINGO",
      what_are_you_looking_for: "What are you looking for?",
      view_marketplace: "View marketplace →",
      cars_vehicles: "Cars & Vehicles",
      find_next_ride: "Find your next ride",
      electronics: "Electronics",
      phones_laptops: "Phones, laptops & more",
      property: "Property",
      homes_land_offices: "Homes, land & offices",
      home_furniture: "Home & Furniture",
      make_space_better: "Make your space better",
      jobs_services: "Jobs & Services",
      work_opportunities: "Work and opportunities",
      everything_else: "Everything Else",
      discover_more: "Discover more",

      marketplace_kicker: "MARKETPLACE",
      buy_sell_easy: "Buy & sell with ease.",
      browse_local_listings: "Browse local listings and connect with buyers and sellers.",
      live_now: "LIVE NOW",
      bid_win_repeat: "Bid. Win. Repeat.",
      discover_auctions: "Discover exciting auctions and place your next winning bid.",
      business: "BUSINESS",
      opportunities_await: "Opportunities await.",
      find_tenders: "Find tenders and business opportunities across Oman.",
      got_something: "GOT SOMETHING TO SELL?",
      unused_items: "Turn unused items into opportunities.",
      create_listing: "Create a listing and reach buyers across Oman.",
      start_selling: "Start selling →",
      discover_oman_kicker: "DISCOVER OMAN",
      discover_oman_title: "Real places. Real photos. Oman as it is.",
      discover_oman_desc: "Explore the cities, governorates and landmarks that make every BINGO listing feel closer to your community.",
      explore_local: "Explore local marketplace ←",

      footer_description: "Oman's marketplace to buy, sell, bid and trade.",
      explore: "Explore",
      account: "Account",
      create_account: "Create account",
      dashboard: "Dashboard",
      buy_sell_trade: "Buy • Sell • Trade"
    },

    ar: {
      oman_marketplace: "🇴🇲 منصة عُمان للبيع والشراء",
      business_tenders: "الأعمال والمناقصات",
      live_auctions: "المزادات المباشرة",
      home: "الرئيسية",
      marketplace: "السوق",
      auctions: "المزادات",
      tenders: "المناقصات",
      login: "تسجيل الدخول",
      register: "إنشاء حساب",

      hero_eyebrow: "شراء • بيع • تداول في عُمان",
      hero_title_1: "كل ما تحتاجه.",
      hero_title_2: "في مكان واحد.",
      hero_description: "اكتشف المنتجات والخدمات والمزادات والمناقصات في جميع أنحاء عُمان. اعثر على أفضل العروض أو أضف إعلانك للوصول إلى المشترين.",
      search_placeholder: "ما الذي تبحث عنه؟",
      all_oman: "كل عُمان",
      muscat: "مسقط",
      seeb: "السيب",
      salalah: "صلالة",
      sohar: "صحار",
      nizwa: "نزوى",
      sur: "صور",
      search: "بحث",
      popular: "الأكثر بحثاً:",
      cars: "السيارات",
      phones: "الهواتف",
      properties: "العقارات",
      furniture: "الأثاث",

      explore_bingo: "استكشف BINGO",
      what_are_you_looking_for: "ما الذي تبحث عنه؟",
      view_marketplace: "عرض السوق ←",
      cars_vehicles: "السيارات والمركبات",
      find_next_ride: "اعثر على سيارتك القادمة",
      electronics: "الإلكترونيات",
      phones_laptops: "الهواتف والحواسيب والمزيد",
      property: "العقارات",
      homes_land_offices: "المنازل والأراضي والمكاتب",
      home_furniture: "المنزل والأثاث",
      make_space_better: "طوّر مساحتك",
      jobs_services: "الوظائف والخدمات",
      work_opportunities: "العمل والفرص",
      everything_else: "كل ما هو آخر",
      discover_more: "اكتشف المزيد",

      marketplace_kicker: "السوق",
      buy_sell_easy: "اشترِ وبِع بسهولة.",
      browse_local_listings: "تصفح الإعلانات المحلية وتواصل مباشرة مع المشترين والبائعين.",
      live_now: "مباشر الآن",
      bid_win_repeat: "زايد. اربح. كرر التجربة.",
      discover_auctions: "اكتشف المزادات وقدم عرضك الرابح القادم.",
      business: "أعمال",
      opportunities_await: "الفرص بانتظارك.",
      find_tenders: "اعثر على المناقصات والفرص التجارية في عُمان.",
      got_something: "هل لديك شيء للبيع؟",
      unused_items: "حوّل أغراضك غير المستخدمة إلى فرص.",
      create_listing: "أنشئ إعلانك ووصل إلى المشترين في جميع أنحاء عُمان.",
      start_selling: "ابدأ البيع ←",
      discover_oman_kicker: "اكتشف عُمان",
      discover_oman_title: "أماكن حقيقية. صور حقيقية. عُمان كما هي.",
      discover_oman_desc: "استكشف المدن والمحافظات والمعالم التي تجعل كل إعلان في BINGO أقرب إلى مجتمعك.",
      explore_local: "استكشف السوق المحلي ←",

      footer_description: "منصة عُمان للبيع والشراء والمزايدة والتداول.",
      explore: "استكشف",
      account: "الحساب",
      create_account: "إنشاء حساب",
      dashboard: "لوحة التحكم",
      buy_sell_trade: "شراء • بيع • تداول"
    }
  };

  /*
   * Legacy text map.
   * The original project has several pages without data-i18n attributes.
   * Keeping this map lets the new switch work on those pages too.
   */
  const LEGACY_EN_AR = {
    "Home": "الرئيسية",
    "Marketplace": "السوق",
    "Auctions": "المزادات",
    "Tenders": "المناقصات",
    "Login": "تسجيل الدخول",
    "Register": "إنشاء حساب",
    "Business & Tenders": "الأعمال والمناقصات",
    "Live Auctions": "المزادات المباشرة",
    "🇴🇲 Oman's marketplace": "🇴🇲 منصة عُمان للبيع والشراء",
    "🇴🇲 Oman’s marketplace": "🇴🇲 منصة عُمان للبيع والشراء",
    "BINGO Oman": "BINGO عُمان",
    "Oman": "عُمان",
    "Muscat": "مسقط",
    "Seeb": "السيب",
    "Salalah": "صلالة",
    "Sohar": "صحار",
    "Nizwa": "نزوى",
    "Sur": "صور",
    "BUY • SELL • BID": "شراء • بيع • مزايدة",
    "LIVE AUCTION": "مزاد مباشر",
    "Marketplace": "السوق",
    "Live bidding": "المزايدة المباشرة",
    "Find your next deal": "اعثر على عرضك القادم",
    "Bid in real time": "زايد في الوقت الحقيقي",
    "Made for Oman": "مصمم لعُمان",
    "Local opportunities": "فرص محلية",
    "BINGO Oman | Buy • Sell • Trade": "BINGO عُمان | شراء • بيع • تداول",
    "BINGO Oman | Auctions": "BINGO عُمان | المزادات",
    "BINGO Oman | Tenders": "BINGO عُمان | المناقصات",
    "BINGO Oman | Marketplace": "BINGO عُمان | السوق",
    "BINGO Dashboard": "لوحة تحكم BINGO",
    "BINGO Admin": "إدارة BINGO",

    "BUY • SELL • TRADE IN OMAN": "شراء • بيع • تداول في عُمان",
    "Everything you need.": "كل ما تحتاجه.",
    "One place.": "في مكان واحد.",
    "Discover products, services, auctions and tenders across Oman. Find great deals or put your own listing in front of buyers.": "اكتشف المنتجات والخدمات والمزادات والمناقصات في جميع أنحاء عُمان. اعثر على أفضل العروض أو أضف إعلانك للوصول إلى المشترين.",
    "What are you looking for?": "ما الذي تبحث عنه؟",
    "All Oman": "كل عُمان",
    "Search": "بحث",
    "Popular:": "الأكثر بحثاً:",
    "Cars": "السيارات",
    "Phones": "الهواتف",
    "Properties": "العقارات",
    "Furniture": "الأثاث",
    "EXPLORE BINGO": "استكشف BINGO",
    "View marketplace": "عرض السوق",
    "Cars & Vehicles": "السيارات والمركبات",
    "Find your next ride": "اعثر على سيارتك القادمة",
    "Electronics": "الإلكترونيات",
    "Phones, laptops & more": "الهواتف والحواسيب والمزيد",
    "Property": "العقارات",
    "Homes, land & offices": "المنازل والأراضي والمكاتب",
    "Home & Furniture": "المنزل والأثاث",
    "Make your space better": "طوّر مساحتك",
    "Jobs & Services": "الوظائف والخدمات",
    "Work and opportunities": "العمل والفرص",
    "Everything Else": "كل ما هو آخر",
    "Discover more": "اكتشف المزيد",

    "MARKETPLACE": "السوق",
    "Buy & sell with ease.": "اشترِ وبِع بسهولة.",
    "Browse local listings and connect with buyers and sellers.": "تصفح الإعلانات المحلية وتواصل مباشرة مع المشترين والبائعين.",
    "LIVE NOW": "مباشر الآن",
    "Bid. Win. Repeat.": "زايد. اربح. كرر التجربة.",
    "Discover exciting auctions and place your next winning bid.": "اكتشف المزادات وقدم عرضك الرابح القادم.",
    "BUSINESS": "أعمال",
    "Opportunities await.": "الفرص بانتظارك.",
    "Find tenders and business opportunities across Oman.": "اعثر على المناقصات والفرص التجارية في عُمان.",
    "GOT SOMETHING TO SELL?": "هل لديك شيء للبيع؟",
    "Turn unused items into opportunities.": "حوّل أغراضك غير المستخدمة إلى فرص.",
    "Create a listing and reach buyers across Oman.": "أنشئ إعلانك ووصل إلى المشترين في جميع أنحاء عُمان.",
    "Start selling →": "ابدأ البيع →",
    "Oman's marketplace to buy, sell, bid and trade.": "منصة عُمان للبيع والشراء والمزايدة والتداول.",
    "Oman’s marketplace to buy, sell, bid and trade.": "منصة عُمان للبيع والشراء والمزايدة والتداول.",
    "Explore": "استكشف",
    "Account": "الحساب",
    "Create account": "إنشاء حساب",
    "Dashboard": "لوحة التحكم",
    "Buy • Sell • Trade": "شراء • بيع • تداول",
    "© 2026 BINGO Oman": "© 2026 BINGO عُمان",

    "LIVE AUCTIONS": "المزادات المباشرة",
    "Bid. Win. Repeat.": "زايد. اربح. كرر التجربة.",
    "Discover active auctions and make your next winning bid.": "اكتشف المزادات النشطة وقدم مزايدتك الرابحة القادمة.",
    "LIVE": "مباشر",
    "STARTING SOON": "يبدأ قريباً",
    "Current bid:": "المزايدة الحالية:",
    "Starting:": "يبدأ من:",
    "12 bids": "12 مزايدة",
    "8 bids": "8 مزايدات",
    "0 bids": "0 مزايدات",
    "Place a bid": "تقديم مزايدة",
    "View auction": "عرض المزاد",
    "Tomorrow": "غداً",

    "BUSINESS OPPORTUNITIES": "فرص الأعمال",
    "Discover tenders.": "اكتشف المناقصات.",
    "Find procurement and business opportunities across Oman.": "اعثر على فرص المشتريات والأعمال في جميع أنحاء عُمان.",
    "OPEN": "مفتوحة",
    "Closing:": "الإغلاق:",
    "View tender": "عرض المناقصة",
    "Ref:": "المرجع:",

    "BINGO MARKETPLACE": "سوق BINGO",
    "Find your next deal.": "اعثر على عرضك القادم.",
    "Browse published listings from across Oman.": "تصفح الإعلانات المنشورة من جميع أنحاء عُمان.",
    "+ Sell": "+ بيع",
    "All categories": "كل التصنيفات",
    "Loading listings…": "جارٍ تحميل الإعلانات…",
    "No listings found.": "لم يتم العثور على إعلانات.",

    "Welcome back": "مرحباً بعودتك",
    "Email": "البريد الإلكتروني",
    "Password": "كلمة المرور",
    "New to BINGO?": "جديد في BINGO؟",
    "Create an account": "إنشاء حساب",
    "Logging in…": "جارٍ تسجيل الدخول…",
    "Login error:": "خطأ في تسجيل الدخول:",
    "Create your BINGO account": "أنشئ حساب BINGO الخاص بك",
    "Full name": "الاسم الكامل",
    "Username": "اسم المستخدم",
    "Oman phone": "رقم الهاتف في عُمان",
    "Individual": "فرد",
    "Company": "شركة",
    "City": "المدينة",
    "Password (8+ characters)": "كلمة المرور (8 أحرف على الأقل)",
    "Confirm password": "تأكيد كلمة المرور",
    "Already have an account?": "لديك حساب بالفعل؟",
    "Creating…": "جارٍ إنشاء الحساب…",
    "Registration error:": "خطأ في التسجيل:",
    "Passwords do not match.": "كلمتا المرور غير متطابقتين.",
    "Account created. Check your email for verification.": "تم إنشاء الحساب. تحقق من بريدك الإلكتروني للتفعيل.",

    "Overview": "نظرة عامة",
    "My Ads": "إعلاناتي",
    "Favorites": "المفضلة",
    "Messages": "الرسائل",
    "Logout": "تسجيل الخروج",
    "Loading…": "جارٍ التحميل…",
    "Loading profile…": "جارٍ تحميل الملف الشخصي…",
    "Welcome,": "مرحباً،",
    "Account profile": "الملف الشخصي",
    "My listings": "إعلاناتي",
    "Browse marketplace": "تصفح السوق",
    "+ Create listing": "+ إنشاء إعلان",
    "Published": "منشورة",
    "Pending": "قيد المراجعة",
    "Pending review": "قيد المراجعة",
    "Could not load your ads": "تعذر تحميل إعلاناتك",
    "You have no ads yet": "لا توجد لديك إعلانات بعد",
    "Create your first ad": "أنشئ إعلانك الأول",

    "SELL ON BINGO": "البيع على BINGO",
    "Create your listing.": "أنشئ إعلانك.",
    "Add your item, photos and details. Your listing will be reviewed before it goes live.": "أضف منتجك وصورك وتفاصيله. ستتم مراجعة الإعلان قبل نشره.",
    "Listing details": "تفاصيل الإعلان",
    "Title": "العنوان",
    "Category": "التصنيف",
    "Price (OMR)": "السعر (ر.ع)",
    "Select category": "اختر التصنيف",
    "Select city": "اختر الولاية أو المدينة",
    "Condition": "الحالة",
    "Select condition": "اختر الحالة",
    "New": "جديد",
    "Like new": "شبه جديد",
    "Good": "جيد",
    "Used": "مستعمل",
    "For parts": "للقطع",
    "Description": "الوصف",
    "Upload photos": "رفع الصور",
    "Choose photos": "اختيار الصور",
    "Publish listing": "نشر الإعلان",
    "Cancel": "إلغاء",
    "Tips for a better ad": "نصائح لإعلان أفضل",
    "Use a clear, specific title.": "استخدم عنواناً واضحاً ومحدداً.",
    "Add several bright photos from different angles.": "أضف عدة صور واضحة من زوايا مختلفة.",
    "Describe the condition honestly.": "اذكر حالة المنتج بوضوح.",
    "Choose the correct city and category.": "اختر المدينة والتصنيف الصحيحين.",
    "Set a realistic OMR price.": "ضع سعراً مناسباً بالريال العُماني.",
    "Choose up to 8 images. JPG, PNG or WEBP, max 5 MB each.": "اختر حتى 8 صور. JPG أو PNG أو WEBP، بحد أقصى 5 ميجابايت للصورة.",
    "Other": "أخرى",
    "Description": "الوصف",

    "ADMIN CENTER": "مركز الإدارة",
    "Admin": "الإدارة",
    "Admin access required": "يتطلب الوصول إلى الإدارة",
    "All": "الكل",
    "BINGO Control Center": "مركز تحكم BINGO",
    "Back to account": "العودة إلى الحساب",
    "Review listings, manage users and publish approved products.": "راجع الإعلانات وأدر المستخدمين وانشر المنتجات المعتمدة.",
    "Total listings": "إجمالي الإعلانات",
    "Users": "المستخدمون",
    "Loading listings…": "جارٍ تحميل الإعلانات…",
    "This area is restricted to BINGO administrators.": "هذه المنطقة مخصصة لمسؤولي BINGO.",
    "← Dashboard": "← لوحة التحكم",
    "↻ Refresh": "↻ تحديث",

    "Home": "الرئيسية",
    "New to BINGO?": "جديد في BINGO؟"
  };

  const TITLE_MAP = {
    "BINGO Oman | Buy • Sell • Trade": "BINGO عُمان | شراء • بيع • تداول",
    "BINGO Oman | Auctions": "BINGO عُمان | المزادات",
    "BINGO Oman | Tenders": "BINGO عُمان | المناقصات",
    "BINGO Oman | Marketplace": "BINGO عُمان | السوق",
    "BINGO Oman - Login": "BINGO عُمان - تسجيل الدخول",
    "BINGO Oman - Register": "BINGO عُمان - إنشاء حساب",
    "BINGO Dashboard": "لوحة تحكم BINGO",
    "Create Listing | BINGO Oman": "إنشاء إعلان | BINGO عُمان",
    "BINGO Admin": "إدارة BINGO"
  };

  const AR_TO_EN = {};
  Object.keys(LEGACY_EN_AR).forEach(function (en) {
    const ar = LEGACY_EN_AR[en];
    if (ar && !AR_TO_EN[ar]) AR_TO_EN[ar] = en;
  });

  function currentLanguage() {
    const params = new URLSearchParams(window.location.search);
    const queryLang = params.get("lang");

    if (queryLang === "ar" || queryLang === "en") {
      localStorage.setItem("bingo-language", queryLang);
      localStorage.setItem("bingo-lang", queryLang);
      return queryLang;
    }

    const saved =
      localStorage.getItem("bingo-language") ||
      localStorage.getItem("bingo-lang");

    return saved === "ar" ? "ar" : "en";
  }

  function translateDataAttributes(lang) {
    const dict = KEYS[lang];

    document.querySelectorAll("[data-i18n]").forEach(function (el) {
      const key = el.getAttribute("data-i18n");
      if (Object.prototype.hasOwnProperty.call(dict, key)) {
        el.textContent = dict[key];
      }
    });

    document.querySelectorAll("[data-i18n-placeholder]").forEach(function (el) {
      const key = el.getAttribute("data-i18n-placeholder");
      if (Object.prototype.hasOwnProperty.call(dict, key)) {
        el.placeholder = dict[key];
      }
    });
  }

  function translateLegacyText(lang) {
    const map = lang === "ar" ? LEGACY_EN_AR : AR_TO_EN;
    const walker = document.createTreeWalker(
      document.body,
      NodeFilter.SHOW_TEXT,
      {
        acceptNode: function (node) {
          const parent = node.parentElement;
          if (!parent) return NodeFilter.FILTER_REJECT;

          const tag = parent.tagName;
          if (
            tag === "SCRIPT" ||
            tag === "STYLE" ||
            tag === "NOSCRIPT" ||
            tag === "TEMPLATE"
          ) {
            return NodeFilter.FILTER_REJECT;
          }

          return NodeFilter.FILTER_ACCEPT;
        }
      }
    );

    const nodes = [];
    while (walker.nextNode()) nodes.push(walker.currentNode);

    nodes.forEach(function (node) {
      const raw = node.nodeValue;
      const trimmed = raw.trim();

      if (!trimmed || !Object.prototype.hasOwnProperty.call(map, trimmed)) {
        return;
      }

      const replacement = map[trimmed];
      node.nodeValue =
        raw.replace(trimmed, replacement);
    });

    document.querySelectorAll("input, textarea").forEach(function (el) {
      if (!el.placeholder) return;
      const mapValue =
        Object.prototype.hasOwnProperty.call(map, el.placeholder)
          ? map[el.placeholder]
          : null;
      if (mapValue) el.placeholder = mapValue;
    });

    document.querySelectorAll("option").forEach(function (el) {
      const text = el.textContent.trim();
      if (Object.prototype.hasOwnProperty.call(map, text)) {
        el.textContent = map[text];
      }
    });
  }

  function changeLogos(lang) {
    const file = lang === "ar" ? "logo-ar.png" : "logo-en.png";
    const alt = lang === "ar" ? "بينجو عُمان" : "BINGO Oman";

    const selector = [
      "#headerLogo",
      "#footerLogo",
      ".header .logo img",
      ".header .main-logo img",
      ".footer-logo img",
      ".footergrid img",
      ".authbrand img"
    ].join(",");

    const seen = new Set();

    document.querySelectorAll(selector).forEach(function (img) {
      if (seen.has(img)) return;
      seen.add(img);
      if (!img.src.endsWith(file)) img.src = file;
      if (img.alt !== alt) img.alt = alt;
      img.removeAttribute("data-original-logo");
    });
  }

  function updateButton(lang) {
    document.querySelectorAll("#langSwitch, #bingoLanguageButton, .lang-switch, .bingo-language").forEach(function (button) {
      const label = lang === "ar" ? "EN" : "العربية";
      if (button.textContent !== label) button.textContent = label;
      const aria = lang === "ar"
        ? "Switch to English"
        : "التبديل إلى العربية";
      if (button.getAttribute("aria-label") !== aria) {
        button.setAttribute("aria-label", aria);
      }
      if (button.title !== aria) {
        button.title = aria;
      }
    });
  }

  function addSwitch() {
    let existing = document.querySelector("#langSwitch, #bingoLanguageButton");

    if (!existing) {
      const actions = document.querySelector(".actions");

      if (actions) {
        existing = document.createElement("button");
        existing.id = "langSwitch";
        existing.type = "button";
        existing.className = "lang-switch";
        actions.insertBefore(existing, actions.firstChild);
      }
    }

    if (!existing && document.querySelector(".auth")) {
      existing = document.createElement("button");
      existing.id = "langSwitch";
      existing.type = "button";
      existing.className = "lang-switch floating-language";
      document.body.appendChild(existing);
    }

    if (!existing) return;

    if (!existing.dataset.bingoLanguageBound) {
      existing.addEventListener("click", function (event) {
        event.preventDefault();
        event.stopPropagation();
        toggle();
      });
      existing.dataset.bingoLanguageBound = "1";
    }

    updateButton(currentLanguage());
  }

  function setLanguage(lang) {
    lang = lang === "ar" ? "ar" : "en";

    localStorage.setItem("bingo-language", lang);
    localStorage.setItem("bingo-lang", lang);

    document.documentElement.lang = lang;
    document.documentElement.dir = lang === "ar" ? "rtl" : "ltr";

    document.body.classList.toggle("rtl", lang === "ar");
    document.body.classList.toggle("arabic", lang === "ar");
    document.body.classList.toggle("language-ar", lang === "ar");
    document.body.classList.toggle("language-en", lang === "en");

    translateDataAttributes(lang);
    translateLegacyText(lang);

    if (lang === "ar") {
      document.title = TITLE_MAP[document.title] || document.title;
    } else {
      document.title = AR_TO_EN[document.title] || document.title;
    }

    changeLogos(lang);
    addSwitch();
    updateButton(lang);
  }

  function toggle() {
    setLanguage(currentLanguage() === "ar" ? "en" : "ar");
  }

  function init() {
    addSwitch();
    setLanguage(currentLanguage());

    /*
     * auth.js can replace .actions after authentication.
     * A small observer re-adds the language button without
     * interfering with the authentication code.
     */
    const observer = new MutationObserver(function () {
      addSwitch();
      updateButton(currentLanguage());
      changeLogos(currentLanguage());
    });

    observer.observe(document.body, {
      childList: true,
      subtree: true
    });

    window.setTimeout(function () {
      addSwitch();
      updateButton(currentLanguage());
      changeLogos(currentLanguage());
    }, 150);
  }

  window.BingoLang = {
    apply: setLanguage,
    toggle: toggle,
    get: currentLanguage,
    addSwitch: addSwitch
  };

  window.BingoLanguage = {
    set: setLanguage,
    toggle: toggle,
    get: currentLanguage
  };

  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", init);
  } else {
    init();
  }
})();
