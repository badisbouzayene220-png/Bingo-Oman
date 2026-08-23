(function(){
  if(!/(?:^|\/)messages\.html$/i.test(location.pathname)) return;
  const sent=new Set();
  let channel=null;
  async function start(){
    try{
      if(!window.sb || !window.BingoAuth) return setTimeout(start,300);
      const user=await BingoAuth.getUser();
      if(!user?.id) return;
      channel=sb.channel('bingo-push-dispatch-'+user.id)
        .on('postgres_changes',{event:'INSERT',schema:'public',table:'messages'},async payload=>{
          const row=payload?.new;
          if(!row?.id || row.sender_id!==user.id || sent.has(row.id)) return;
          sent.add(row.id);
          try{
            const {error}=await sb.functions.invoke('push-message-notification',{body:{message_id:row.id}});
            if(error) console.warn('BINGO push dispatch failed:',error.message||error);
          }catch(err){
            console.warn('BINGO push dispatch failed:',err?.message||err);
          }
          setTimeout(()=>sent.delete(row.id),60000);
        }).subscribe();
    }catch(err){
      console.warn('BINGO push dispatcher start failed:',err?.message||err);
    }
  }
  addEventListener('beforeunload',()=>{try{if(channel&&window.sb)sb.removeChannel(channel)}catch(_){}});
  document.readyState==='loading'?document.addEventListener('DOMContentLoaded',start,{once:true}):start();
})();
