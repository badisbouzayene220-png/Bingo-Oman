(function(){
  async function getUser(){
    try{
      const {data:{session}}=await sb.auth.getSession();
      return session?.user || null;
    }catch(e){ console.warn('BINGO auth session:',e); return null; }
  }
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
    const actions=document.querySelector('.actions'); if(!actions) return;
    const user=await getUser();
    if(user){
      const menu=ensureActions();
      const avatar=menu.querySelector('#avatar'); avatar.textContent=nameOf(user).charAt(0).toUpperCase();
      avatar.onclick=()=>menu.querySelector('#menu').classList.toggle('open');
      const logout=menu.querySelector('#logout');
      logout.onclick=async()=>{ await sb.auth.signOut(); location.href='index.html'; };
    }else if(!actions.querySelector('#langSwitch')){
      actions.innerHTML='<a class="login" href="login.html">Login</a><a class="btn primary small" href="register.html">Register</a>';
      if(window.BingoLang?.addSwitch) window.BingoLang.addSwitch();
    }
  }
  window.BingoAuth={getUser,refresh};
  document.addEventListener('DOMContentLoaded',()=>{
    refresh();
    if(sb?.auth) sb.auth.onAuthStateChange(()=>setTimeout(refresh,0));
  });
})();
