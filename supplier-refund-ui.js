// Supplier refund UI helper for ERP purchases.
(function(){
  const sb = window.supabaseClient || window.supabase;
  if (!sb) return;
  window.erpSupplierRefund = async function(purchaseId){
    if(!purchaseId) throw new Error('Purchase is required');
    const {data: status, error: statusError} = await sb.rpc('erp_get_supplier_refund_status',{p_purchase_id:purchaseId});
    if(statusError) throw statusError;
    const balance = Number(status?.refund_balance || 0);
    if(!(balance > 0)) { alert('لا يوجد مبلغ مستحق للاسترجاع.'); return null; }
    const amountRaw = prompt(`المبلغ القابل للاسترجاع: ${balance.toFixed(3)} OMR\nأدخل مبلغ الاسترجاع:`, balance.toFixed(3));
    if(amountRaw === null) return null;
    const amount = Number(amountRaw);
    if(!Number.isFinite(amount) || amount <= 0 || amount > balance + 1e-9){ alert('مبلغ الاسترجاع غير صالح.'); return null; }
    const methodRaw = prompt('طريقة الاسترجاع: cash أو bank','bank');
    if(methodRaw === null) return null;
    const method = String(methodRaw).trim().toLowerCase();
    if(!['cash','bank'].includes(method)){ alert('طريقة الاسترجاع يجب أن تكون cash أو bank.'); return null; }
    const reference = prompt('المرجع (اختياري):','');
    const {data, error} = await sb.rpc('erp_record_supplier_refund',{p_refund:{purchase_id:purchaseId,amount:Number(amount.toFixed(3)),method,reference:reference||null,notes:'Supplier refund after purchase cancellation'}});
    if(error) throw error;
    alert(`تم تسجيل الاسترجاع بقيمة ${Number(data?.amount || amount).toFixed(3)} OMR`);
    return data;
  };
})();
