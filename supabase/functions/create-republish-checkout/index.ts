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

    const {plan_code}=await req.json()
    if(!['monthly','yearly'].includes(plan_code))throw new Error('Invalid plan')
    const {data:plan,error:planError}=await admin.from('listing_plan_catalog').select('*').eq('plan_code',plan_code).maybeSingle()
    if(planError)throw planError
    if(!plan||!plan.is_active||!Number(plan.amount_baisa))throw new Error('This plan is not available for purchase yet')

    const {data:payment,error:payError}=await admin.from('listing_plan_payments').insert({
      user_id:user.id,plan_code,amount_baisa:plan.amount_baisa,currency:plan.currency,status:'created',provider:'thawani'
    }).select('id').single()
    if(payError)throw payError

    const base=(Deno.env.get('THAWANI_BASE_URL')||'https://uatcheckout.thawani.om/api/v1').replace(/\/$/,'')
    const secret=Deno.env.get('THAWANI_SECRET_KEY')
    const publishable=Deno.env.get('THAWANI_PUBLISHABLE_KEY')
    const site=(Deno.env.get('BINGO_SITE_URL')||'https://badisbouzayene220-png.github.io/Bingo-Oman').replace(/\/$/,'')
    if(!secret||!publishable)throw new Error('Thawani is not configured')

    const payload={
      client_reference_id:payment.id,
      mode:'payment',
      products:[{name:`BINGO Oman - ${plan.name_en}`,quantity:1,unit_amount:Number(plan.amount_baisa)}],
      success_url:`${site}/listing-plan-success.html?payment_id=${payment.id}`,
      cancel_url:`${site}/listing-plans.html?payment=cancelled`,
      metadata:{payment_id:payment.id,user_id:user.id,plan_code}
    }
    const r=await fetch(`${base}/checkout/session`,{
      method:'POST',headers:{'Content-Type':'application/json','thawani-api-key':secret},body:JSON.stringify(payload)
    })
    const body=await r.json().catch(()=>({}))
    const sessionId=body?.data?.session_id
    if(!r.ok||!body?.success||!sessionId){
      await admin.from('listing_plan_payments').update({status:'failed',metadata:{gateway_response:body}}).eq('id',payment.id)
      throw new Error(body?.description||'Could not create payment session')
    }
    await admin.from('listing_plan_payments').update({status:'pending',provider_session_id:sessionId,provider_reference:payment.id}).eq('id',payment.id)
    const payHost=base.includes('uatcheckout')?'https://uatcheckout.thawani.om':'https://checkout.thawani.om'
    const checkout_url=`${payHost}/pay/${encodeURIComponent(sessionId)}?key=${encodeURIComponent(publishable)}`
    return new Response(JSON.stringify({ok:true,checkout_url,payment_id:payment.id}),{status:200,headers:{...corsHeaders,'Content-Type':'application/json'}})
  }catch(e){
    return new Response(JSON.stringify({ok:false,error:e?.message||String(e)}),{status:400,headers:{...corsHeaders,'Content-Type':'application/json'}})
  }
})
