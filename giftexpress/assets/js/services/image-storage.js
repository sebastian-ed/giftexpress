import { CONFIG } from '../config.js';import { getSupabase } from './supabase.js';
export async function uploadProductImage(productId,file){
  if(CONFIG.demoMode){const dataUrl=await new Promise((res,rej)=>{const r=new FileReader();r.onload=()=>res(r.result);r.onerror=rej;r.readAsDataURL(file)});return {path:`demo/${file.name}`,publicUrl:dataUrl};}
  const sb=await getSupabase();const ext=(file.name.split('.').pop()||'jpg').toLowerCase();const path=`products/${productId}/${crypto.randomUUID()}.${ext}`;const {error}=await sb.storage.from('product-images').upload(path,file,{cacheControl:'3600',upsert:false});if(error)throw error;const {data}=sb.storage.from('product-images').getPublicUrl(path);return {path,publicUrl:data.publicUrl};
}
export async function deleteProductImage(path){if(CONFIG.demoMode)return true;const sb=await getSupabase();const {error}=await sb.storage.from('product-images').remove([path]);if(error)throw error;return true}
