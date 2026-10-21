import { CONFIG } from '../config.js';import { storage } from '../utils/storage.js';import { getSupabase } from '../services/supabase.js';
const DEMO={email:'admin@giftexpress.demo',password:'demo1234'};
export async function login(email,password){if(CONFIG.demoMode){if(email===DEMO.email&&password===DEMO.password){storage.set('gx_admin_session',{email,role:'super_admin',at:Date.now()});return {email,role:'super_admin'}}throw new Error('Credenciales demo incorrectas.');}const sb=await getSupabase();const {data,error}=await sb.auth.signInWithPassword({email,password});if(error)throw error;return data.user}
export async function logout(){if(CONFIG.demoMode){storage.remove('gx_admin_session');return}const sb=await getSupabase();await sb.auth.signOut()}
export async function session(){if(CONFIG.demoMode)return storage.get('gx_admin_session',null);const sb=await getSupabase();const {data}=await sb.auth.getSession();return data.session}
export async function requireAdmin(){const s=await session();if(!s){location.href=window.GX_BASE+'admin/index.html';return null}if(!CONFIG.demoMode){const sb=await getSupabase();const {data:role,error}=await sb.rpc('current_role_slug');if(error||!['super_admin','admin','operations'].includes(role)){await sb.auth.signOut();location.href=window.GX_BASE+'admin/index.html?error=forbidden';return null}s.role=role;}return s}
export {DEMO};
