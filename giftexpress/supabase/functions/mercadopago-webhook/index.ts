import { createClient } from 'npm:@supabase/supabase-js@2';
Deno.serve(async(req)=>{
  if(req.method!=='POST')return new Response('ok',{status:200});
  try{
    const secret=Deno.env.get('MERCADOPAGO_WEBHOOK_SECRET');const token=Deno.env.get('MERCADOPAGO_ACCESS_TOKEN');const sbUrl=Deno.env.get('SUPABASE_URL');const serviceKey=Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');
    if(!secret||!token||!sbUrl||!serviceKey)throw new Error('Webhook secrets missing');
    const url=new URL(req.url);const rawDataId=(url.searchParams.get('data.id')||url.searchParams.get('data_id')||'');const signatureDataId=rawDataId.toLowerCase();const xSig=req.headers.get('x-signature')||'';const xReq=req.headers.get('x-request-id')||'';
    if(!(await validSignature(xSig,xReq,signatureDataId,secret)))return new Response('invalid signature',{status:401});
    const body=await req.json().catch(()=>({}));const eventId=String(body?.id||`${rawDataId}:${body?.action||'event'}`);
    const sb=createClient(sbUrl,serviceKey,{auth:{persistSession:false}});
    const {error:eventError}=await sb.from('webhook_events').insert({id:eventId,provider:'mercadopago',event_type:body?.type||body?.action||'order',resource_id:rawDataId,payload:body});
    if(eventError&&eventError.code==='23505')return new Response('ok',{status:200});
    if(eventError)throw eventError;
    const mpRes=await fetch(`https://api.mercadopago.com/v1/orders/${encodeURIComponent(rawDataId)}`,{headers:{'Authorization':`Bearer ${token}`}});const mp=await mpRes.json();if(!mpRes.ok)throw new Error(mp?.message||'No se pudo consultar la order de Mercado Pago');
    const localCode=mp.external_reference;if(!localCode)return new Response('ok',{status:200});
    const paymentStatus=mapPayment(mp.status,mp.status_detail);
    const {data:local,error:localErr}=await sb.from('orders').select('id,status,payment_status').eq('code',localCode).single();if(localErr)throw localErr;
    let orderStatus=local.status;if(paymentStatus==='approved'&&['received','paid'].includes(local.status))orderStatus='paid';
    if(['rejected','canceled'].includes(paymentStatus)&&local.status==='received')orderStatus='received';
    await sb.from('orders').update({payment_status:paymentStatus,status:orderStatus}).eq('id',local.id);
    await sb.from('payments').upsert({order_id:local.id,provider:'mercadopago',provider_order_id:mp.id,status:paymentStatus,amount:Number(mp.total_amount||0),currency:mp.currency||'ARS',raw_response:mp},{onConflict:'provider,provider_order_id'});
    await sb.from('order_status_history').insert({order_id:local.id,status:orderStatus,payment_status:paymentStatus,note:`Mercado Pago: ${mp.status}/${mp.status_detail||''}`});
    return new Response('ok',{status:200});
  }catch(e){console.error(e);return new Response('error',{status:500})}
});
function mapPayment(status:string,detail:string){if(status==='processed'&&['accredited','partially_refunded'].includes(detail))return detail==='partially_refunded'?'refunded':'approved';if(status==='refunded')return 'refunded';if(status==='failed')return 'rejected';if(status==='canceled')return 'canceled';return 'pending'}
async function validSignature(header:string,requestId:string,dataId:string,secret:string){
  if(!header||!requestId||!dataId)return false;let ts='',v1='';for(const part of header.split(',')){const [k,v]=part.split('=',2).map(x=>x?.trim());if(k==='ts')ts=v||'';if(k==='v1')v1=v||''}if(!ts||!v1)return false;
  const manifest=`id:${dataId};request-id:${requestId};ts:${ts};`;const key=await crypto.subtle.importKey('raw',new TextEncoder().encode(secret),{name:'HMAC',hash:'SHA-256'},false,['sign']);const sig=await crypto.subtle.sign('HMAC',key,new TextEncoder().encode(manifest));const expected=[...new Uint8Array(sig)].map(b=>b.toString(16).padStart(2,'0')).join('');return constantTimeEqual(expected,v1);
}
function constantTimeEqual(a:string,b:string){if(a.length!==b.length)return false;let d=0;for(let i=0;i<a.length;i++)d|=a.charCodeAt(i)^b.charCodeAt(i);return d===0}
