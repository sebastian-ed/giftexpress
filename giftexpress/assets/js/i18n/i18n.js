import { CONFIG } from '../config.js';import { messages } from './translations.js';import { storage } from '../utils/storage.js';
export function getLocale(){return storage.get('gx_locale',null)||detectLocale()||CONFIG.defaultLocale}
export function detectLocale(){const l=(navigator.language||'es').slice(0,2);return CONFIG.supportedLocales.includes(l)?l:CONFIG.defaultLocale}
export function setLocale(l){if(CONFIG.supportedLocales.includes(l)){storage.set('gx_locale',l);document.documentElement.lang=l;location.reload()}}
export function t(path,vars={}){const l=getLocale();let v=path.split('.').reduce((a,k)=>a?.[k],messages[l]);if(v==null)v=path.split('.').reduce((a,k)=>a?.[k],messages.es)||path;return Object.entries(vars).reduce((s,[k,val])=>s.replaceAll(`{${k}}`,val),v)}
export function localize(obj,field='name'){const l=getLocale();return obj?.[`${field}_${l}`]||obj?.[`${field}_es`]||obj?.[field]||''}
