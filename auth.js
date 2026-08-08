(function(){
  let refreshing = false;
  async function getSession(){
    try { const {data,error}=await sb.auth.getSession(); if(error) throw error; return data?.session || null; }
    catch(e){ console.warn('BINGO auth session:',e); return null; }
  }
  async function getUser(){ const session=await getSession(); return session?.user || null; }
  function nameOf(user){ return user?.user_metadata?.full_name || user?.email?.split('@')[0] || 'User'; }
  function ensureActions(){
    const actions=document.querySelector('.actions'); if(!actions) return null;
    let menu=actions.querySelector('.user-menu');
    if(!menu){
      actions.innerHTML='';
      menu=document.createElement('div'); menu.className='user-menu';
      menu.innerHTML='<button class="avatar" id="avatar" aria-label="Account">U</button><div class="menu" id="menu"><a href="dashboard.html">My Account</a><a href="dashboard.html">My Ads</a><a href="dashboard.html">My Favorites</a><a href="dashboard.html">My Messages</a><button id="logout" type="button">Logout</button></div>';
      actions.appendChild(menu);
    }
    return menu;
  }
  async function refresh(){
    if(refreshing) return; refreshing=true;
    try{
      const actions=document.querySelector('.actions'); if(!actions) return;
      const session=await getSession();
      const user=session?.user;
      if(user){
        const menu=ensureActions();
        const {data:profile}=await sb.from('profiles').select('role').eq('id',user.id).maybeSingle();
        const menuBox=menu.querySelector('#menu');
        if(menuBox && profile?.role==='admin' && !menuBox.querySelector('.admin-link')){
          const a=document.createElement('a'); a.className='admin-link'; a.href='admin.html'; a.textContent='Admin Center'; menuBox.insertBefore(a,menuBox.querySelector('#logout'));
        }
        const avatar=menu.querySelector('#avatar');
        avatar.textContent=nameOf(user).charAt(0).toUpperCase();
        avatar.onclick=()=>menu.querySelector('#menu').classList.toggle('open');
        const logout=menu.querySelector('#logout');
        logout.onclick=async()=>{ logout.disabled=true; const {error}=await sb.auth.signOut(); if(error) console.warn(error); location.href='index.html'; };
        if(window.BingoLang?.addSwitch) window.BingoLang.addSwitch();
      }else{
        actions.innerHTML='<a class="login" href="login.html">Login</a><a class="btn primary small" href="register.html">Register</a>';
        if(window.BingoLang?.addSwitch) window.BingoLang.addSwitch();
      }
    }finally{ refreshing=false; }
  }
  window.BingoAuth={getSession,getUser,refresh};
  document.addEventListener('DOMContentLoaded',()=>{
    refresh();
    sb.auth.onAuthStateChange((event)=>{ if(event==='SIGNED_IN'||event==='SIGNED_OUT'||event==='TOKEN_REFRESHED'||event==='USER_UPDATED') setTimeout(refresh,0); });
  });
})();
