(function(){'use strict';
const page=(location.pathname.split('/').pop()||'').toLowerCase();if(page!=='dashboard.html')return;

function listingIdFromCard(card){
  const link=card?.querySelector('a[href*="listing.html?id="]');
  if(!link)return'';
  try{return new URL(link.href,location.href).searchParams.get('id')||''}catch{return''}
}

async function deleteListing(id){
  if(!id){alert('Could not identify this listing.');return}
  if(!confirm('Delete this listing?\n\nThis action cannot be undone.'))return;
  try{
    const {data,error}=await sb.rpc('user_delete_listing',{p_listing_id:id});
    if(error)throw error;
    if(data!==true)throw new Error('The server did not confirm deletion.');
    document.querySelectorAll('.my-ad-card').forEach(card=>{if(listingIdFromCard(card)===id)card.remove()});
    alert('Listing deleted successfully.');
    if(typeof go==='function')await go();
  }catch(err){
    console.error('Delete listing failed:',err);
    alert('Could not delete the listing: '+(err?.message||String(err)));
  }
}

window.deleteMyListing=function(id){return deleteListing(id)};

document.addEventListener('click',function(e){
  const btn=e.target.closest('.my-ad-actions button');
  if(!btn)return;
  const text=(btn.textContent||'').toLowerCase();
  if(!text.includes('delete')&&!text.includes('حذف'))return;
  e.preventDefault();
  e.stopPropagation();
  if(e.stopImmediatePropagation)e.stopImmediatePropagation();
  const card=btn.closest('.my-ad-card');
  deleteListing(listingIdFromCard(card));
},true);
})();
