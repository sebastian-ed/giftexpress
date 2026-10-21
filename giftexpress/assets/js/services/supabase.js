import { CONFIG } from '../config.js';
let client=null;
export async function getSupabase(){
  if(CONFIG.demoMode||!CONFIG.supabaseUrl||!CONFIG.supabaseAnonKey)return null;
  if(client)return client;
  if(!window.supabase)throw new Error('Supabase SDK no disponible');
  client=window.supabase.createClient(CONFIG.supabaseUrl,CONFIG.supabaseAnonKey,{auth:{persistSession:true,autoRefreshToken:true,detectSessionInUrl:true}});
  return client;
}
