import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const corsHeaders={
  'Access-Control-Allow-Origin':'*',
  'Access-Control-Allow-Headers':'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods':'POST, OPTIONS'
}

const enc=new TextEncoder()
const b64url=(input:Uint8Array|string)=>{
  const bytes=typeof input==='string'?enc.encode(input):input
  let s=''; for(const b of bytes)s+=String.fromCharCode(b)
  return btoa(s).replace(/\+/g,'-').replace(/\//g,'_').replace(/=+$/,'')
}
const pemToBytes=(pem:string)=>{
  const clean=pem.replace(/-----BEGIN PRIVATE KEY-----|-----END PRIVATE KEY-----|\s/g,'')
  const bin=atob(clean); return Uint8Array.from(bin,c=>c.charCodeAt(0))
}
async function googleAccessToken(){
  const raw=Deno.env.get('FIREBASE_SERVICE_ACCOUNT_JSON')
  if(!raw)throw new Error('FIREBASE_SERVICE_ACCOUNT_JSON is not configured')
  const sa=JSON.parse(raw)
  if(!sa.client_email||!sa.private_key)throw new Error('Invalid Firebase service account')
  const now=Math.floor(Date.now()/1000)
  const header=b64url(JSON.stringify({alg:'RS256',typ:'JWT'}))
  const claim=b64url(JSON.stringify({iss:sa.client_email,scope:'https://www.googleapis.com/auth/firebase.messaging',aud:'https://oauth2.googleapis.com/token',iat:now,exp:now+3600}))
  const key=await crypto.subtle.importKey('pkcs8',pemToBytes(sa.private_key),{name:'RSASSA-PKCS1-v1_5',hash:'SHA-256'},false,['sign'])
  const sig=new Uint8Array(await crypto.subtle.sign('RSASSA-PKCS1-v1_5',key,enc.encode(`${header}.${claim}`)))
  const assertion=`${header}.${claim}.${b64url(sig)}`
  const r=await fetch('https://oauth2.googleapis.com/token',{method:'POST',headers:{'Content-Type':'application/x-www-form-urlencoded'},body:new URLSearchParams({grant_type:'urn:ietf:params:oauth:grant-type:jwt-bearer',assertion})})
  const body=await r.json(); if(!r.ok||!body.access_token)throw new Error(body.error_description||'Firebase OAuth failed')
  return {token:body.access_token,projectId:sa.project_id}
}

Deno.serve(async(req)=>{
  if(req.method==='OPTIONS')return new Response('ok',{headers:corsHeaders})
  try{
    const auth=req.headers.get('Authorization')||''
    if(!auth.startsWith('Bearer '))throw new Error('Authentication required')
    const supabaseUrl=Deno.env.get('SUPABASE_URL')!
    const anon=Deno.env.get('SUPABASE_ANON_KEY')!
    const service=Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
    const userClient=createClient(supabaseUrl,anon,{global:{headers:{Authorization:auth}}})
    const admin=createClient(supabaseUrl,service)
    const {data:{user},error:userError}=await userClient.auth.getUser()
    if(userError||!user)throw new Error('Authentication required')

    const {message_id}=await req.json()
    if(!message_id)throw new Error('message_id required')
    const {data:msg,error:msgErr}=await admin.from('messages').select('id,conversation_id,sender_id,message,created_at').eq('id',message_id).single()
    if(msgErr||!msg)throw new Error('Message not found')
    if(msg.sender_id!==user.id)throw new Error('Not allowed')
    const {data:conv,error:convErr}=await admin.from('conversations').select('id,buyer_id,seller_id,listing_id,auction_id').eq('id',msg.conversation_id).single()
    if(convErr||!conv)throw new Error('Conversation not found')
    if(user.id!==conv.buyer_id&&user.id!==conv.seller_id)throw new Error('Not allowed')
    const recipient=user.id===conv.buyer_id?conv.seller_id:conv.buyer_id
    if(!recipient)return new Response(JSON.stringify({ok:true,sent:0}),{headers:{...corsHeaders,'Content-Type':'application/json'}})

    const [{data:tokens},{data:profile}]=await Promise.all([
      admin.from('mobile_push_tokens').select('token').eq('user_id',recipient).eq('is_active',true),
      admin.from('public_profiles').select('full_name,username').eq('id',user.id).maybeSingle()
    ])
    if(!tokens?.length)return new Response(JSON.stringify({ok:true,sent:0}),{headers:{...corsHeaders,'Content-Type':'application/json'}})
    const sender=profile?.full_name||profile?.username||'BINGO user'
    const preview=String(msg.message||'New message').replace(/^\[BINGO_STICKER:[^\]]+\]$/,'BINGO sticker').slice(0,180)
    const {token:accessToken,projectId}=await googleAccessToken()
    let sent=0
    for(const row of tokens){
      const r=await fetch(`https://fcm.googleapis.com/v1/projects/${encodeURIComponent(projectId)}/messages:send`,{
        method:'POST',headers:{Authorization:`Bearer ${accessToken}`,'Content-Type':'application/json'},
        body:JSON.stringify({message:{token:row.token,notification:{title:`Message from ${sender}`,body:preview},data:{url:`messages.html?conversation=${conv.id}`,type:'message',conversation_id:String(conv.id)}}})
      })
      if(r.ok){sent++}else{
        const t=await r.text()
        if(/UNREGISTERED|registration-token-not-registered/i.test(t))await admin.from('mobile_push_tokens').update({is_active:false,updated_at:new Date().toISOString()}).eq('token',row.token)
        console.error('FCM send failed',r.status,t)
      }
    }
    return new Response(JSON.stringify({ok:true,sent}),{headers:{...corsHeaders,'Content-Type':'application/json'}})
  }catch(e){
    return new Response(JSON.stringify({ok:false,error:e?.message||String(e)}),{status:400,headers:{...corsHeaders,'Content-Type':'application/json'}})
  }
})
