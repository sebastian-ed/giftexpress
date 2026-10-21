import { CONFIG } from '../config.js';
import { demoDB } from './demo-db.js';
export async function validateCoupon(code,subtotal){
  const clean=String(code||'').trim().toUpperCase();if(!clean)return null;
  if(CONFIG.demoMode){const rows=await demoDB.list('coupons');return rows.find(c=>c.active!==false&&String(c.code).toUpperCase()===clean&&subtotal>=(c.min_ars||0))||null;}
  const base=CONFIG.edgeBaseUrl||`${CONFIG.supabaseUrl}/functions/v1`;
  const res=await fetch(`${base}/validate-coupon`,{method:'POST',headers:{'Content-Type':'application/json','apikey':CONFIG.supabaseAnonKey,'Authorization':`Bearer ${CONFIG.supabaseAnonKey}`},body:JSON.stringify({code:clean,subtotal_ars:subtotal})});
  if(!res.ok)return null;const out=await res.json();return out.valid?out.coupon:null;
}
