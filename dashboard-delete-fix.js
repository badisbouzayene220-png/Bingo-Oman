(function(){'use strict';
const page=(location.pathname.split('/').pop()||'').toLowerCase();if(page!=='dashboard.html')return;
async function deleteListing(id,title){
  if(!confirm(`Delete "${title||'this listing'}"?\n\nThis action cannot be undone.`))return;
  try{
    const {data,error}=await sb.rpc('user_delete_listing',{p_listing_id:id});
    if(error)throw error;
    if(data!==true)throw new Error('The server did not confirm deletion.');
    document.querySelectorAll('.my-ad-card').forEach(card=>{
      const link=card.querySelector(`a[href*="${CSS.escape(id)}"]`);
      if(link)card.remove();
    });
    alert('Listing deleted successfully.');
    if(typeof go==='function')await go();
  }catch(err){
    console.error('Delete listing failed:',err);
    alert('Could not delete the listing: '+(err?.message||String(err)));
  }
}
window.deleteMyListing=deleteListing;
})();
