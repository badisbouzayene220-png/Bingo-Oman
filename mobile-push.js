(function(){'use strict';
let started=false,lastToken=null;
const allowedPage=/^[a-z0-9][a-z0-9._-]*\.html(?:[?#][^\s]*)?$/i;
function nativePlatform(){try{return !!window.Capacitor?.isNativePlatform?.()}catch{return false}}
function platform(){try{return String(window.Capacitor?.getPlatform?.()||'').toLowerCase()}catch{return ''}}
function plugin(){return window.Capacitor?.Plugins?.PushNotifications||null}
function safeHref(value){let href=String(value||'').trim();if(!href)return null;try{if(/^https?:\/\//i.test(href)){const u=new URL(href);if(u.origin!==location.origin)return null;href=(u.pathname.split('/').pop()||'index.html')+u.search+u.hash}}catch{return null}href=href.replace(/^\.\//,'').replace(/^\//,'');return allowedPage.test(href)?href:null}
async function user(){if(window.BingoAuth?.getUser)return BingoAuth.getUser();try{return (await window.sb?.auth?.getUser())?.data?.user||null}catch{return null}}
async function saveToken(token){const u=await user();if(!u||!window.sb||!token)return;lastToken=token;const p=platform();if(p!=='android'&&p!=='ios')return;const deviceName=[navigator.platform,navigator.userAgentData?.platform].filter(Boolean)[0]||null;const {error}=await sb.rpc('register_my_mobile_push_token',{p_token:token,p_platform:p,p_device_name:deviceName});if(error)console.warn('BINGO push token save:',error.message)}
async function disableCurrent(){if(!lastToken||!window.sb)return;try{await sb.rpc('disable_my_mobile_push_token',{p_token:lastToken})}catch{}lastToken=null}
async function start(){if(started||!nativePlatform())return;const Push=plugin();if(!Push)return;started=true;try{
  const perm=await Push.checkPermissions();let receive=perm.receive;
  if(receive==='prompt'||receive==='prompt-with-rationale'){const asked=await Push.requestPermissions();receive=asked.receive}
  if(receive!=='granted')return;
  await Push.addListener('registration',t=>saveToken(t?.value));
  await Push.addListener('registrationError',e=>console.warn('BINGO push registration:',e));
  await Push.addListener('pushNotificationReceived',n=>{document.dispatchEvent(new CustomEvent('bingo:native-push',{detail:n||{}}))});
  await Push.addListener('pushNotificationActionPerformed',ev=>{const href=safeHref(ev?.notification?.data?.href||ev?.notification?.data?.url);if(href)location.href=href});
  await Push.register();
}catch(e){console.warn('BINGO native push:',e)}}
function onAuth(ev){const event=ev?.detail?.event||ev?.detail?.type||'';if(String(event).toUpperCase().includes('SIGNED_OUT'))disableCurrent();else setTimeout(start,150)}
document.addEventListener('bingo-auth-changed',onAuth);
if(document.readyState==='loading')document.addEventListener('DOMContentLoaded',()=>setTimeout(start,350),{once:true});else setTimeout(start,350);
window.BingoMobilePush={start,disable:disableCurrent,isNative:nativePlatform};
})();
