import { createClient } from 'npm:@supabase/supabase-js@2';
const cors={'Access-Control-Allow-Origin':'*','Access-Control-Allow-Headers':'authorization, x-client-info, apikey, content-type'};
Deno.serve(async(req)=>{
  if(req.method==='OPTIONS')return new Response('ok',{headers:cors});
  if(req.method!=='POST')return json({error:'Method not allowed'},405);
  try{
    const accessToken=Deno.env.get('MERCADOPAGO_ACCESS_TOKEN');
    const siteUrl=(Deno.env.get('SITE_URL')||'').replace(/\/$/,'');
    const supabaseUrl=Deno.env.get('SUPABASE_URL');const serviceKey=Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');
    if(!accessToken||!siteUrl||!supabaseUrl||!serviceKey)throw new Error('Faltan secretos de producción');
    const {order_id}=await req.json();if(!order_id) return json({error:'order_id requerido'},400);
    const sb=createClient(supabaseUrl,serviceKey,{auth:{persistSession:false}});
    const {data:order,error}=await sb.from('orders').select('id,code,total_ars,payment_status,customer_id').eq('id',order_id).single();if(error||!order)throw error||new Error('Pedido inexistente');
    if(order.payment_status==='approved')return json({checkout_url:`${siteUrl}/pedido.html?codigo=${encodeURIComponent(order.code)}`});
    const {data:customer}=await sb.from('customers').select('first_name,last_name,email,whatsapp').eq('id',order.customer_id).maybeSingle();
    const idempotency=crypto.randomUUID();
    const mpPayload={
      type:'online',processing_mode:'manual',capture_mode:'automatic_async',
      total_amount:Number(order.total_ars).toFixed(2),external_reference:order.code,
      description:`GiftExpress ${order.code}`,
      payer:{email:customer?.email||undefined,first_name:customer?.first_name||undefined,last_name:customer?.last_name||undefined},
      config:{statement_descriptor:'GIFTEXPRESS',online:{success_url:`${siteUrl}/pedido.html?codigo=${encodeURIComponent(order.code)}`,failure_url:`${siteUrl}/pedido.html?codigo=${encodeURIComponent(order.code)}&pago=fallido`,pending_url:`${siteUrl}/pedido.html?codigo=${encodeURIComponent(order.code)}&pago=pendiente`,auto_return:'all'}},
      items:[{external_code:order.code,title:`Pedido GiftExpress ${order.code}`,description:'Productos argentinos + entrega',quantity:1,unit_price:Number(order.total_ars).toFixed(2)}]
    };
    const mp=await fetch('https://api.mercadopago.com/v1/orders',{method:'POST',headers:{'Content-Type':'application/json','Authorization':`Bearer ${accessToken}`,'X-Idempotency-Key':idempotency},body:JSON.stringify(mpPayload)});
    const body=await mp.json();if(!mp.ok)throw new Error(body?.message||body?.error||'Mercado Pago rechazó la creación de la order');
    await sb.from('payments').upsert({order_id:order.id,provider:'mercadopago',provider_order_id:body.id,status:'pending',amount:order.total_ars,currency:body.currency||'ARS',idempotency_key:idempotency,raw_response:body},{onConflict:'provider,provider_order_id'});
    return json({checkout_url:body.checkout_url,provider_order_id:body.id});
  }catch(e){console.error(e);return json({error:e instanceof Error?e.message:'No se pudo iniciar Mercado Pago'},500)}
});
function json(body:unknown,status=200){return new Response(JSON.stringify(body),{status,headers:{...cors,'Content-Type':'application/json'}})}
