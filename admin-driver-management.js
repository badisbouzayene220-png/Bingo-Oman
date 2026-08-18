/* Legacy driver manager intentionally disabled.
   bingo-delivery-admin.html is the single source of truth and uses
   admin_delivery_drivers_all() + admin_update_delivery_driver(). */
(() => {
  window.BingoDeliveryAdminDrivers = { load: async () => {} };
})();
