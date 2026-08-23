import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const enc=new TextEncoder()
const json=(body:unknown,status=200)=>new Response(JSON.stringify(body),{status,headers:{'Content-Type':'application/json'}})
const b64url=(input:Uint8Array|string)=>{const bytes=typeof input==='string'?enc.encode(input):input;let s='';for(const b of bytes)s+=String.fromCharCode(b);return btoa(s).replace(/\+/g,'-').replace(/\//g,'_').replace(/=+$/,'')}
const pemToBytes=(pem:string)=>{const clean=pem.replace(/-----BEGIN PRIVATE KEY-----|-----END PRIVATE KEY-----|\s/g,'');const bin=atob(clean);return Uint8Array.from(bin,c=>c.charCodeAt(0))}

async function googleAccessToken(){
  const raw=Deno.env.get('FIREBASE_SERVICE_ACCOUNT_JSON')
  if(!raw)throw new Error('FIREBASE_SERVICE_ACCOUNT_JSON is not configured')
  const sa=JSON.parse(raw)
  if(!sa.client_email||!sa.private_key||!sa.project_id)throw new Error('Invalid Firebase service account')
  const now=Math.floor(Date.now()/1000)
  const header=b64url(JSON.stringify({alg:'RS256',typ:'JWT'}))
  const claim=b64url(JSON.stringify({iss:sa.client_email,scope:'https://www.googleapis.com/auth/firebase.messaging',aud:'https://oauth2.googleapis.com/token',iat:now,exp:now+3600}))
  const key=await crypto.subtle.importKey('pkcs8',pemToBytes(sa.private_key),{name:'RSASSA-PKCS1-v1_5',hash:'SHA-256'},false,['sign'])
  const sig=new Uint8Array(await crypto.subtle.sign('RSASSA-PKCS1-v1_5',key,enc.encode(`${header}.${claim}`)))
  const assertion=`${header}.${claim}.${b64url(sig)}`
  const r=await fetch('https://oauth2.googleapis.com/token',{method:'POST',headers:{'Content-Type':'application/x-www-form-urlencoded'},body:new URLSearchParams({grant_type:'urn:ietf:params:oauth:grant-type:jwt-bearer',assertion})})
  const body=await r.json();if(!r.ok||!body.access_token)throw new Error(body.error_description||'Firebase OAuth failed')
  return {token:body.access_token,projectId:sa.project_id}
}

Deno.serve(async(req)=>{
  try{
    if(req.method!=='POST')return json({ok:false,error:'POST required'},405)
    const expected=Deno.env.get('PUSH_WEBHOOK_SECRET')||''
    const supplied=req.headers.get('x-bingo-push-secret')||''
    if(!expected||supplied!==expected)return json({ok:false,error:'Unauthorized'},401)

    const payload=await req.json().catch(()=>({}))
    const record=payload?.record||payload?.new||payload
    const notificationId=record?.id
    if(!notificationId)return json({ok:false,error:'Notification id required'},400)

    const admin=createClient(Deno.env.get('SUPABASE_URL')!,Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!)
    const {data:n,error:nErr}=await admin.from('user_notifications').select('id,user_id,type,title,body,href,order_id').eq('id',notificationId).single()
    if(nErr||!n)throw new Error('Notification not found')

    const {data:tokens,error:tErr}=await admin.from('mobile_push_tokens').select('token').eq('user_id',n.user_id).eq('is_active',true)
    if(tErr)throw tErr
    if(!tokens?.length)return json({ok:true,sent:0})

    const {token:accessToken,projectId}=await googleAccessToken()
    let sent=0
    for(const row of tokens){
      const data:Record<string,string>={type:String(n.type||'notification'),notification_id:String(n.id)}
      if(n.href)data.url=String(n.href)
      if(n.order_id)data.order_id=String(n.order_id)
      const r=await fetch(`https://fcm.googleapis.com/v1/projects/${encodeURIComponent(projectId)}/messages:send`,{
        method:'POST',headers:{Authorization:`Bearer ${accessToken}`,'Content-Type':'application/json'},
        body:JSON.stringify({message:{token:row.token,notification:{title:String(n.title||'BINGO Oman'),body:String(n.body||'لديك تحديث جديد')},data,android:{priority:'high'}}})
      })
      if(r.ok){sent++}else{
        const text=await r.text()
        if(/UNREGISTERED|registration-token-not-registered/i.test(text))await admin.from('mobile_push_tokens').update({is_active:false,updated_at:new Date().toISOString()}).eq('token',row.token)
        console.error('FCM failed',r.status,text)
      }
    }
    return json({ok:true,sent})
  }catch(e){return json({ok:false,error:e?.message||String(e)},400)}
})
