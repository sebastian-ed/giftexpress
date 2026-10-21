import { CONFIG } from '../config.js';
const providers={
  mercadopago: async order=>{
    if(CONFIG.demoMode)return `/pedido.html?codigo=${encodeURIComponent(order.code)}&demo=1`;
    const base=CONFIG.edgeBaseUrl||`${CONFIG.supabaseUrl}/functions/v1`;
    const res=await fetch(`${base}/create-mercadopago-checkout`,{method:'POST',headers:{'Content-Type':'application/json','apikey':CONFIG.supabaseAnonKey,'Authorization':`Bearer ${CONFIG.supabaseAnonKey}`},body:JSON.stringify({order_id:order.id})});
    const out=await res.json();if(!res.ok)throw new Error(out.error||'No se pudo iniciar Mercado Pago');return out.checkout_url;
  }
};
export async function startPayment(order,provider='mercadopago'){const fn=providers[provider];if(!fn)throw new Error(`El medio de pago ${provider} no está configurado.`);return fn(order)}
export function availablePaymentProviders(){return Object.keys(providers)}
