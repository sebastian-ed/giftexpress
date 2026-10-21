import { createClient } from 'npm:@supabase/supabase-js@2';
const cors={'Access-Control-Allow-Origin':'*','Access-Control-Allow-Headers':'authorization, x-client-info, apikey, content-type'};
Deno.serve(async(req)=>{
  if(req.method==='OPTIONS')return new Response('ok',{headers:cors});
  if(req.method!=='POST')return json({error:'Method not allowed'},405);
  try{
    const url=Deno.env.get('SUPABASE_URL');const key=Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');
    if(!url||!key)throw new Error('Supabase server secrets are not configured');
    const payload=await req.json();
    if(!payload?.customer?.email||!Array.isArray(payload?.items)||!payload.items.length) return json({error:'Checkout incompleto'},400);
    const sb=createClient(url,key,{auth:{persistSession:false}});
    const {data,error}=await sb.rpc('create_order_from_checkout',{p_payload:payload});
    if(error)throw error;
    return json(data,201);
  }catch(e){console.error(e);return json({error:e instanceof Error?e.message:'No se pudo crear el pedido'},400)}
});
function json(body:unknown,status=200){return new Response(JSON.stringify(body),{status,headers:{...cors,'Content-Type':'application/json'}})}
