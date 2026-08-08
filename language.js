(function () {

  "use strict";


  /* ==========================================
     TRANSLATIONS
  ========================================== */

  const LANG = {

    en: {

      oman_marketplace:
        "🇴🇲 Oman's marketplace",

      business_tenders:
        "Business & Tenders",

      live_auctions:
        "Live Auctions",

      home:
        "Home",

      marketplace:
        "Marketplace",

      auctions:
        "Auctions",

      tenders:
        "Tenders",

      login:
        "Login",

      register:
        "Register",

      hero_eyebrow:
        "BUY • SELL • TRADE IN OMAN",

      hero_title_1:
        "Everything you need.",

      hero_title_2:
        "One place.",

      hero_description:
        "Discover products, services, auctions and tenders across Oman. Find great deals or put your own listing in front of buyers.",

      search_placeholder:
        "What are you looking for?",

      all_oman:
        "All Oman",

      muscat:
        "Muscat",

      seeb:
        "Seeb",

      salalah:
        "Salalah",

      sohar:
        "Sohar",

      nizwa:
        "Nizwa",

      sur:
        "Sur",

      search:
        "Search",

      popular:
        "Popular:",

      cars:
        "Cars",

      phones:
        "Phones",

      properties:
        "Properties",

      furniture:
        "Furniture",

      explore_bingo:
        "EXPLORE BINGO",

      what_are_you_looking_for:
        "What are you looking for?",

      view_marketplace:
        "View marketplace →",

      cars_vehicles:
        "Cars & Vehicles",

      find_next_ride:
        "Find your next ride",

      electronics:
        "Electronics",

      phones_laptops:
        "Phones, laptops & more",

      property:
        "Property",

      homes_land_offices:
        "Homes, land & offices",

      home_furniture:
        "Home & Furniture",

      make_space_better:
        "Make your space better",

      jobs_services:
        "Jobs & Services",

      work_opportunities:
        "Work and opportunities",

      everything_else:
        "Everything Else",

      discover_more:
        "Discover more",

      marketplace_kicker:
        "MARKETPLACE",

      buy_sell_easy:
        "Buy & sell with ease.",

      browse_local_listings:
        "Browse local listings and connect with buyers and sellers.",

      live_now:
        "LIVE NOW",

      bid_win_repeat:
        "Bid. Win. Repeat.",

      discover_auctions:
        "Discover exciting auctions and place your next winning bid.",

      business:
        "BUSINESS",

      opportunities_await:
        "Opportunities await.",

      find_tenders:
        "Find tenders and business opportunities across Oman.",

      got_something:
        "GOT SOMETHING TO SELL?",

      unused_items:
        "Turn unused items into opportunities.",

      create_listing:
        "Create a listing and reach buyers across Oman.",

      start_selling:
        "Start selling →",

      footer_description:
        "Oman's marketplace to buy, sell, bid and trade.",

      explore:
        "Explore",

      account:
        "Account",

      create_account:
        "Create account",

      dashboard:
        "Dashboard",

      buy_sell_trade:
        "Buy • Sell • Trade"

    },


    /* ==========================================
       ARABIC
    ========================================== */

    ar: {

      oman_marketplace:
        "🇴🇲 منصة عُمان للبيع والشراء",

      business_tenders:
        "الأعمال والمناقصات",

      live_auctions:
        "المزادات المباشرة",

      home:
        "الرئيسية",

      marketplace:
        "السوق",

      auctions:
        "المزادات",

      tenders:
        "المناقصات",

      login:
        "تسجيل الدخول",

      register:
        "إنشاء حساب",

      hero_eyebrow:
        "شراء • بيع • تداول في عُمان",

      hero_title_1:
        "كل ما تحتاجه.",

      hero_title_2:
        "في مكان واحد.",

      hero_description:
        "اكتشف المنتجات والخدمات والمزادات والمناقصات في جميع أنحاء عُمان. اعثر على أفضل العروض أو أضف إعلانك للوصول إلى المشترين.",

      search_placeholder:
        "ما الذي تبحث عنه؟",

      all_oman:
        "كل عُمان",

      muscat:
        "مسقط",

      seeb:
        "السيب",

      salalah:
        "صلالة",

      sohar:
        "صحار",

      nizwa:
        "نزوى",

      sur:
        "صور",

      search:
        "بحث",

      popular:
        "الأكثر بحثاً:",

      cars:
        "السيارات",

      phones:
        "الهواتف",

      properties:
        "العقارات",

      furniture:
        "الأثاث",

      explore_bingo:
        "استكشف BINGO",

      what_are_you_looking_for:
        "ما الذي تبحث عنه؟",

      view_marketplace:
        "عرض السوق ←",

      cars_vehicles:
        "السيارات والمركبات",

      find_next_ride:
        "اعثر على سيارتك القادمة",

      electronics:
        "الإلكترونيات",

      phones_laptops:
        "الهواتف والحواسيب والمزيد",

      property:
        "العقارات",

      homes_land_offices:
        "المنازل والأراضي والمكاتب",

      home_furniture:
        "المنزل والأثاث",

      make_space_better:
        "طوّر مساحتك",

      jobs_services:
        "الوظائف والخدمات",

      work_opportunities:
        "العمل والفرص",

      everything_else:
        "كل ما هو آخر",

      discover_more:
        "اكتشف المزيد",

      marketplace_kicker:
        "السوق",

      buy_sell_easy:
        "اشترِ وبِع بسهولة.",

      browse_local_listings:
        "تصفح الإعلانات المحلية وتواصل مباشرة مع المشترين والبائعين.",

      live_now:
        "مباشر الآن",

      bid_win_repeat:
        "زايد. اربح. كرر التجربة.",

      discover_auctions:
        "اكتشف المزادات وقدم عرضك الرابح القادم.",

      business:
        "أعمال",

      opportunities_await:
        "الفرص بانتظارك.",

      find_tenders:
        "اعثر على المناقصات والفرص التجارية في عُمان.",

      got_something:
        "هل لديك شيء للبيع؟",

      unused_items:
        "حوّل أغراضك غير المستخدمة إلى فرص.",

      create_listing:
        "أنشئ إعلانك ووصل إلى المشترين في جميع أنحاء عُمان.",

      start_selling:
        "ابدأ البيع ←",

      footer_description:
        "منصة عُمان للبيع والشراء والمزايدة والتداول.",

      explore:
        "استكشف",

      account:
        "الحساب",

      create_account:
        "إنشاء حساب",

      dashboard:
        "لوحة التحكم",

      buy_sell_trade:
        "شراء • بيع • تداول"

    }

  };


  /* ==========================================
     LOGO CONFIG
  ========================================== */

  const LOGOS = {

    en: {
      header: "logo-en.png",
      footer: "logo-en.png",
      alt: "BINGO Oman"
    },

    ar: {
      header: "logo-ar.png",
      footer: "logo-ar.png",
      alt: "بينجو عُمان"
    }

  };


  /* ==========================================
     GET LANGUAGE
  ========================================== */

  function getLanguage() {

    const params =
      new URLSearchParams(window.location.search);

    const urlLang =
      params.get("lang");

    if (urlLang === "ar" || urlLang === "en") {

      localStorage.setItem(
        "bingo-lang",
        urlLang
      );

      return urlLang;

    }


    const saved =
      localStorage.getItem("bingo-lang");

    if (saved === "ar" || saved === "en") {
      return saved;
    }


    return "en";

  }


  /* ==========================================
     TRANSLATE TEXT
  ========================================== */

  function translatePage(lang) {

    const dictionary =
      LANG[lang];

    if (!dictionary) return;


    /* Normal text */

    document
      .querySelectorAll("[data-i18n]")
      .forEach(function (element) {

        const key =
          element.getAttribute("data-i18n");

        if (
          dictionary[key] !== undefined
        ) {

          element.textContent =
            dictionary[key];

        }

      });


    /* Placeholders */

    document
      .querySelectorAll("[data-i18n-placeholder]")
      .forEach(function (element) {

        const key =
          element.getAttribute(
            "data-i18n-placeholder"
          );

        if (
          dictionary[key] !== undefined
        ) {

          element.placeholder =
            dictionary[key];

        }

      });

  }


  /* ==========================================
     CHANGE LOGO
  ========================================== */

  function changeLogo(lang) {

    const logo =
      LOGOS[lang];

    if (!logo) return;


    const headerLogo =
      document.getElementById("headerLogo");

    const footerLogo =
      document.getElementById("footerLogo");


    if (headerLogo) {

      headerLogo.src =
        logo.header;

      headerLogo.alt =
        logo.alt;

    }


    if (footerLogo) {

      footerLogo.src =
        logo.footer;

      footerLogo.alt =
        logo.alt;

    }

  }


  /* ==========================================
     APPLY LANGUAGE
  ========================================== */

  function applyLanguage(lang) {

    if (
      lang !== "ar" &&
      lang !== "en"
    ) {

      lang = "en";

    }


    /* HTML direction */

    document.documentElement.lang =
      lang;

    document.documentElement.dir =
      lang === "ar"
        ? "rtl"
        : "ltr";


    /* Body class */

    document.body.classList.toggle(
      "rtl",
      lang === "ar"
    );


    document.body.classList.toggle(
      "arabic",
      lang === "ar"
    );


    /* Translate */

    translatePage(lang);


    /* Logo */

    changeLogo(lang);


    /* Language button */

    const switchButton =
      document.getElementById(
        "langSwitch"
      );

    if (switchButton) {

      switchButton.textContent =
        lang === "ar"
          ? "EN"
          : "العربية";

      switchButton.setAttribute(
        "aria-label",
        lang === "ar"
          ? "Switch to English"
          : "التبديل إلى العربية"
      );

    }


    /* Save */

    localStorage.setItem(
      "bingo-lang",
      lang
    );

  }


  /* ==========================================
     SWITCH LANGUAGE
  ========================================== */

  function toggleLanguage() {

    const current =
      localStorage.getItem(
        "bingo-lang"
      ) || "en";


    const next =
      current === "ar"
        ? "en"
        : "ar";


    applyLanguage(next);

  }


  /* ==========================================
     INIT
  ========================================== */

  function init() {

    const current =
      getLanguage();


    applyLanguage(current);


    const switchButton =
      document.getElementById(
        "langSwitch"
      );


    if (switchButton) {

      switchButton.addEventListener(
        "click",
        toggleLanguage
      );

    }

  }


  /* ==========================================
     PUBLIC API
  ========================================== */

  window.BingoLang = {

    apply: applyLanguage,

    toggle: toggleLanguage,

    get: getLanguage

  };


  /* ==========================================
     START
  ========================================== */

  if (
    document.readyState === "loading"
  ) {

    document.addEventListener(
      "DOMContentLoaded",
      init
    );

  } else {

    init();

  }
  /* ==========================================
   LANGUAGE BUTTON
========================================== */

function setupLanguageButton() {

    const actions = document.querySelector(".actions");

    if (!actions) {
        return;
    }

    let button = document.getElementById("langSwitch");

    /*
     * إذا لم يكن الزر موجوداً في HTML
     * يتم إنشاؤه تلقائياً
     */

    if (!button) {

        button = document.createElement("button");

        button.id = "langSwitch";

        button.type = "button";

        button.className = "lang-switch";

        actions.insertBefore(
            button,
            actions.firstChild
        );

    }

    /*
     * منع إضافة Event Listener أكثر من مرة
     */

    if (!button.dataset.languageReady) {

        button.addEventListener("click", function () {

            const current =
                localStorage.getItem("bingo-lang") || "en";

            const next =
                current === "ar" ? "en" : "ar";

            applyLanguage(next);

        });

        button.dataset.languageReady = "true";

    }

}


/* ==========================================
   UPDATE LANGUAGE BUTTON
========================================== */

function updateLanguageButton(lang) {

    const button =
        document.getElementById("langSwitch");

    if (!button) {
        return;
    }

    if (lang === "ar") {

        button.textContent = "EN";

        button.setAttribute(
            "aria-label",
            "Switch to English"
        );

        button.setAttribute(
            "title",
            "Switch to English"
        );

    } else {

        button.textContent = "العربية";

        button.setAttribute(
            "aria-label",
            "التبديل إلى العربية"
        );

        button.setAttribute(
            "title",
            "التبديل إلى العربية"
        );

    }

}


/* ==========================================
   APPLY LANGUAGE
========================================== */

function applyLanguage(lang) {

    if (lang !== "ar" && lang !== "en") {

        lang = "en";

    }

    /*
     * HTML direction
     */

    document.documentElement.lang = lang;

    document.documentElement.dir =
        lang === "ar" ? "rtl" : "ltr";


    /*
     * Body
     */

    document.body.classList.toggle(
        "rtl",
        lang === "ar"
    );

    document.body.classList.toggle(
        "arabic",
        lang === "ar"
    );


    /*
     * Translate text
     */

    translatePage(lang);


    /*
     * Change logo
     */

    changeLogo(lang);


    /*
     * Change language button
     */

    updateLanguageButton(lang);


    /*
     * Save language
     */

    localStorage.setItem(
        "bingo-lang",
        lang
    );

}


/* ==========================================
   INIT
========================================== */

function init() {

    /*
     * Create language button
     * if it doesn't exist
     */

    setupLanguageButton();


    /*
     * Get saved language
     */

    const current =
        getLanguage();


    /*
     * Apply language
     */

    applyLanguage(current);

}

})();
