// BINGO Oman ERP — supplier refund integration.
// Adds the Refund action after a cancelled purchase when the existing SQL RPC says a refund is due.
(function(){
  const boot = () => {
    if (typeof window.loadPurchases !== 'function' || typeof window.sb === 'undefined') {
      setTimeout(boot, 250);
      return;
    }
    if (window.__supplierRefundIntegrationInstalled) return;
    window.__supplierRefundIntegrationInstalled = true;

    const rpc = async (name, args) => {
      const { data, error } = await window.sb.rpc(name, args);
      if (error) throw error;
      return data;
    };

    window.refundSupplierPurchase = async function(id){
      try {
        const s = await rpc('erp_get_supplier_refund_status', {p_purchase_id:id});
        const balance = Number(s?.refund_balance || 0);
        if (!(balance > 0)) {
          if (typeof window.msg === 'function') window.msg('لا يوجد مبلغ مستحق للاسترجاع.','err');
          else alert('لا يوجد مبلغ مستحق للاسترجاع.');
          return;
        }
        const raw = prompt(`المبلغ القابل للاسترجاع: ${balance.toFixed(3)} OMR\nأدخل مبلغ الاسترجاع:`, balance.toFixed(3));
        if (raw === null) return;
        const amount = Number(raw);
        if (!Number.isFinite(amount) || amount <= 0 || amount > balance + 1e-9) {
          if (typeof window.msg === 'function') window.msg('مبلغ الاسترجاع غير صحيح.','err');
          return;
        }
        const methodRaw = prompt('طريقة الاسترجاع: cash أو bank','bank');
        if (methodRaw === null) return;
        const method = String(methodRaw).trim().toLowerCase();
        if (!['cash','bank'].includes(method)) {
          if (typeof window.msg === 'function') window.msg('طريقة الاسترجاع يجب أن تكون cash أو bank.','err');
          return;
        }
        const reference = prompt('المرجع (اختياري):','');
        const result = await rpc('erp_record_supplier_refund', {
          p_refund: {
            purchase_id:id,
            amount:Number(amount.toFixed(3)),
            method,
            reference:reference || null,
            notes:'Supplier refund after purchase cancellation'
          }
        });
        if (typeof window.msg === 'function') window.msg(`تم تسجيل استرجاع المورد بقيمة ${Number(result?.amount || amount).toFixed(3)} OMR.`);
        else alert(`تم تسجيل الاسترجاع بقيمة ${Number(result?.amount || amount).toFixed(3)} OMR.`);
        await window.loadPurchases();
        if (window.loadSuppliers) await window.loadSuppliers();
        if (window.loadDashboard) await window.loadDashboard();
      } catch(e) {
        const text = e?.message || 'تعذر تسجيل استرجاع المورد.';
        if (typeof window.msg === 'function') window.msg(text,'err'); else alert(text);
      }
    };

    const originalLoadPurchases = window.loadPurchases;
    window.loadPurchases = async function(){
      await originalLoadPurchases.apply(this, arguments);
      const table = document.getElementById('purchaseTable');
      if (!table) return;
      const purchases = window.purchases || [];
      const rows = Array.from(table.querySelectorAll('tbody tr'));
      for (const tr of rows) {
        const p = purchases.find(x => tr.children[0]?.textContent?.trim() === String(x.purchase_number || '').trim());
        if (!p || p.status !== 'cancelled') continue;
        const actions = tr.lastElementChild;
        if (!actions || actions.querySelector('[data-supplier-refund]')) continue;
        try {
          const s = await rpc('erp_get_supplier_refund_status', {p_purchase_id:p.id});
          if (!s?.refundable || Number(s.refund_balance || 0) <= 0) continue;
          const btn = document.createElement('button');
          btn.type = 'button';
          btn.className = 'btnx primary';
          btn.dataset.supplierRefund = p.id;
          btn.textContent = '↩ استرجاع';
          btn.style.cssText = 'background:#137a4a!important;border-color:#137a4a!important;color:#fff!important;font-weight:900!important;cursor:pointer!important;margin-right:4px';
          btn.addEventListener('click', () => window.refundSupplierPurchase(p.id));
          actions.appendChild(btn);
        } catch(e) {
          console.warn('supplier refund status unavailable', p.id, e);
        }
      }
    };
  };
  boot();
})();
