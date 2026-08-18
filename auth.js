(function(){
  let refreshing = false;
  async function getSession(){try{const {data,error}=await sb.auth.getSession();if(error)throw error;return data?.session||null;}catch(e){console.warn('BINGO auth session:',e);return null;}}
  async function getUser(){const session=await getSession();return session?.user||null;}
  function nameOf(user){return user?.user_metadata?.full_name||user?.email?.split('@')[0]||'User';}
  let messageChannel=null,unreadTimer=null;
  function ensureActions(){const actions=document.querySelector('.actions');if(!actions)return null;let menu=actions.querySelector('.user-menu');if(!menu){actions.innerHTML='';const messageLink=document.createElement('a');messageLink.className='header-messages';messageLink.href='messages.html';messageLink.setAttribute('aria-label','Messages');messageLink.title='Messages';messageLink.innerHTML='<span class="header-message-icon" aria-hidden="true">💬</span><span class="header-message-badge" id="headerMessageBadge" style="display:none">0</span>';actions.appendChild(messageLink);menu=document.createElement('div');menu.className='user-menu';menu.innerHTML='<button class="avatar" id="avatar" aria-label="Account">U</button><div class="menu" id="menu"><a href="dashboard.html">My Account</a><a href="dashboard.html">My Ads</a><a href="dashboard.html">My Favorites</a><a href="messages.html">My Messages</a><button id="logout" type="button">Logout</button></div>';actions.appendChild(menu);}return menu;}
  async function updateMessageBadge(user){const badge=document.getElementById('headerMessageBadge');if(!badge||!user)return;try{const {data:conversations,error:cError}=await sb.from('conversations').select('id').or(`buyer_id.eq.${user.id},seller_id.eq.${user.id}`);if(cError)throw cError;const ids=(conversations||[]).map(c=>c.id);if(!ids.length){badge.style.display='none';badge.textContent='0';return;}const {count,error:mError}=await sb.from('messages').select('id',{count:'exact',head:true}).in('conversation_id',ids).eq('is_read',false).neq('sender_id',user.id);if(mError)throw mError;const n=count||0;badge.textContent=n>99?'99+':String(n);badge.style.display=n?'inline-flex':'none';}catch(e){console.warn('BINGO unread messages:',e);}}
  function setupMessageRealtime(user){if(messageChannel){try{sb.removeChannel(messageChannel);}catch(e){}messageChannel=null;}if(unreadTimer){clearInterval(unreadTimer);unreadTimer=null;}if(!user)return;updateMessageBadge(user);unreadTimer=setInterval(()=>updateMessageBadge(user),15000);try{messageChannel=sb.channel('bingo-header-messages-'+user.id).on('postgres_changes',{event:'*',schema:'public',table:'messages'},()=>updateMessageBadge(user)).subscribe();}catch(e){console.warn('BINGO message realtime:',e);}}
  function ensureDeliveryAdminLink(){
    if(!/admin\.html$/i.test(location.pathname))return;
    const side=document.querySelector('.admin-side');
    if(!side||side.querySelector('.bingo-delivery-admin-link'))return;
    const a=document.createElement('a');
    a.className='bingo-delivery-admin-link';
    a.href='bingo-delivery-admin.html';
    a.textContent='🚚 BINGO Delivery';
    a.style.cssText='display:block;text-align:left;text-decoration:none;padding:12px;border-radius:10px;font-weight:800;color:#fff;background:linear-gradient(135deg,#ff8a16,#ff5b00);margin:6px 0;box-shadow:0 8px 18px rgba(255,91,0,.18)';
    side.appendChild(a);
  }
  async function refresh(){if(refreshing)return;refreshing=true;try{const actions=document.querySelector('.actions');if(!actions)return;const session=await getSession();const user=session?.user;if(user){const menu=ensureActions();const {data:profile}=await sb.from('profiles').select('role').eq('id',user.id).maybeSingle();const menuBox=menu.querySelector('#menu');if(menuBox&&profile?.role==='admin'&&!menuBox.querySelector('.admin-link')){const a=document.createElement('a');a.className='admin-link';a.href='admin.html';a.textContent='Admin Center';menuBox.insertBefore(a,menuBox.querySelector('#logout'));}if(profile?.role==='admin')ensureDeliveryAdminLink();const avatar=menu.querySelector('#avatar');avatar.textContent=nameOf(user).charAt(0).toUpperCase();avatar.onclick=()=>menu.querySelector('#menu').classList.toggle('open');const logout=menu.querySelector('#logout');logout.onclick=async()=>{logout.disabled=true;const {error}=await sb.auth.signOut();if(error)console.warn(error);location.href='index.html';};setupMessageRealtime(user);if(window.BingoLang?.addSwitch)window.BingoLang.addSwitch();}else{if(messageChannel){try{sb.removeChannel(messageChannel);}catch(e){}messageChannel=null;}if(unreadTimer){clearInterval(unreadTimer);unreadTimer=null;}actions.innerHTML='<a class="login" href="login.html">Login</a><a class="btn primary small" href="register.html">Register</a>';if(window.BingoLang?.addSwitch)window.BingoLang.addSwitch();}}finally{refreshing=false;}}
  window.BingoAuth={getSession,getUser,refresh};
  document.addEventListener('DOMContentLoaded',()=>{refresh();setTimeout(refresh,500);setTimeout(refresh,1500);sb.auth.onAuthStateChange((event)=>{if(event==='SIGNED_IN'||event==='SIGNED_OUT'||event==='TOKEN_REFRESHED'||event==='USER_UPDATED'){setTimeout(refresh,0);setTimeout(refresh,300);}});document.addEventListener('visibilitychange',()=>{if(document.visibilityState==='visible')setTimeout(refresh,0);});window.addEventListener('pageshow',()=>setTimeout(refresh,0));});
  function loadScriptOnce(src){return new Promise((resolve)=>{if(document.querySelector('script[src="'+src+'"]'))return resolve();const s=document.createElement('script');s.src=src;s.async=false;s.onload=resolve;s.onerror=resolve;document.head.appendChild(s);});}
  function loadCssOnce(href){if(document.querySelector('link[href="'+href+'"]'))return;const l=document.createElement('link');l.rel='stylesheet';l.href=href;document.head.appendChild(l);}
  async function loadStableLanguage(){
    const scoped=/erp\.html$|hr\.html$/i.test(location.pathname);
    if(!scoped){await loadScriptOnce('language.js');return;}
    const NativeMO=window.MutationObserver;
    window.MutationObserver=class StableLanguageObserver{constructor(){}observe(){}disconnect(){}takeRecords(){return[];}};
    try{await loadScriptOnce('language.js');}finally{window.MutationObserver=NativeMO;}
  }
  async function loadGlobalUI(){loadCssOnce('bingo-ui.css');await loadStableLanguage();if(/erp\.html$|hr\.html$/i.test(location.pathname))await loadScriptOnce('erp-hr-static-i18n.js');}
  if(document.readyState==='loading')document.addEventListener('DOMContentLoaded',loadGlobalUI,{once:true});else loadGlobalUI();
})();