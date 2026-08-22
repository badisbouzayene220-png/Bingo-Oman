import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const corsHeaders={
  'Access-Control-Allow-Origin':'*',
  'Access-Control-Allow-Headers':'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods':'POST, OPTIONS'
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
    const {payment_id}=await req.json()
    if(!payment_id)throw new Error('payment_id is required')
    const {data:payment,error:pe}=await admin.from('listing_plan_payments').select('*,listing_plan_catalog(*)').eq('id',payment_id).eq('user_id',user.id).maybeSingle()
    if(pe)throw pe
    if(!payment)throw new Error('Payment not found')
    if(payment.status==='paid')return new Response(JSON.stringify({ok:true,status:'paid'}),{headers:{...corsHeaders,'Content-Type':'application/json'}})
    if(!payment.provider_session_id)throw new Error('Payment session missing')

    const base=(Deno.env.get('THAWANI_BASE_URL')||'https://uatcheckout.thawani.om/api/v1').replace(/\/$/,'')
    const secret=Deno.env.get('THAWANI_SECRET_KEY')
    if(!secret)throw new Error('Thawani is not configured')
    const r=await fetch(`${base}/checkout/session/${encodeURIComponent(payment.provider_session_id)}`,{headers:{'thawani-api-key':secret}})
    const body=await r.json().catch(()=>({}))
    if(!r.ok||!body?.success)throw new Error(body?.description||'Could not verify payment')
    const gatewayStatus=String(body?.data?.payment_status||body?.data?.status||'').toLowerCase()
    if(gatewayStatus!=='paid'){
      if(['cancelled','canceled','failed'].includes(gatewayStatus))await admin.from('listing_plan_payments').update({status:gatewayStatus.startsWith('cancel')?'cancelled':'failed',metadata:{gateway_response:body}}).eq('id',payment.id)
      return new Response(JSON.stringify({ok:true,status:gatewayStatus||'pending'}),{headers:{...corsHeaders,'Content-Type':'application/json'}})
    }

    const plan=payment.listing_plan_catalog
    const now=new Date();const end=new Date(now.getTime()+Number(plan.duration_days)*86400000)
    const {error:subError}=await admin.from('listing_republish_subscriptions').insert({
      user_id:user.id,plan_code:payment.plan_code,status:'active',starts_at:now.toISOString(),ends_at:end.toISOString(),payment_id:payment.id,provider:'thawani'
    })
    if(subError)throw subError
    await admin.from('listing_plan_payments').update({status:'paid',paid_at:now.toISOString(),metadata:{gateway_response:body}}).eq('id',payment.id)
    return new Response(JSON.stringify({ok:true,status:'paid',plan_code:payment.plan_code,ends_at:end.toISOString()}),{headers:{...corsHeaders,'Content-Type':'application/json'}})
  }catch(e){return new Response(JSON.stringify({ok:false,error:e?.message||String(e)}),{status:400,headers:{...corsHeaders,'Content-Type':'application/json'}})}
})
