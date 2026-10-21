import { CONFIG } from '../config.js';
import { demoDB,initDemo } from './demo-db.js';
import { getSupabase } from './supabase.js';
initDemo();
const map={products:'products',categories:'categories',zones:'delivery_zones',coupons:'coupons',settings:'settings',orders:'orders',customers:'customers',inventory:'inventory_movements',rates:'exchange_rates',suppliers:'suppliers',supplier_products:'supplier_products',bundles:'product_bundles',variants:'product_variants',purchase_orders:'purchase_orders',import_jobs:'import_jobs'};
const LANGS=['es','en','pt'];
function flattenTranslations(row,kind){
  const translations=row?.[`${kind}_translations`]||[];
  const out={...row};
  for(const tr of translations){out[`name_${tr.locale}`]=tr.name;if('description' in tr)out[`description_${tr.locale}`]=tr.description;if('short_description' in tr)out[`short_description_${tr.locale}`]=tr.short_description;}
  if(kind==='product'&&row.product_images?.length){const imgs=[...row.product_images].sort((a,b)=>(a.sort_order||0)-(b.sort_order||0));out.images=imgs.map(x=>x.public_url);out.image=(imgs.find(x=>x.is_primary)||imgs[0])?.public_url||out.image;}
  return out;
}
export const data={
  async list(entity,opts={}){
    if(CONFIG.demoMode)return demoDB.list(entity);
    const sb=await getSupabase();
    let select=opts.select||'*';
    if(entity==='products')select='*,product_translations(*),product_images(*)';
    if(entity==='categories')select='*,category_translations(*)';
    let q=sb.from(map[entity]||entity).select(select);
    if(opts.eq)for(const [k,v] of Object.entries(opts.eq))q=q.eq(k,v);
    if(opts.order)q=q.order(opts.order.column,{ascending:opts.order.ascending??true});
    const {data,error}=await q;if(error)throw error;
    if(entity==='products')return (data||[]).map(r=>flattenTranslations(r,'product'));
    if(entity==='categories')return (data||[]).map(r=>flattenTranslations(r,'category'));
    if(entity==='zones')return (data||[]).map(z=>({...z,days:z.delivery_days||z.days||[],eta:z.eta_text||z.eta||''}));
    if(entity==='coupons')return (data||[]).map(c=>({...c,type:c.discount_type||c.type,value:Number(c.discount_value??c.value??0),min_ars:Number(c.min_order_ars??c.min_ars??0),uses:c.usage_count??c.uses??0}));
    if(entity==='settings')return (data||[]).map(x=>({...x,default_delivery_text:x.delivery_text||x.default_delivery_text||'',cutoff_default:x.default_cutoff||x.cutoff_default||''}));
    return data||[];
  },
  async get(entity,id,field='id'){
    if(CONFIG.demoMode)return demoDB.get(entity,id,field);
    const rows=await this.list(entity,{eq:{[field]:id}});return rows[0]||null;
  },
  async upsert(entity,row){
    if(CONFIG.demoMode)return demoDB.upsert(entity,row);
    const sb=await getSupabase();
    if(entity==='products'){
      const translated={};for(const l of LANGS)translated[l]={name:row[`name_${l}`]||'',description:row[`description_${l}`]||'',short_description:row[`short_description_${l}`]||''};
      const core={...row};for(const l of LANGS)for(const f of ['name','description','short_description'])delete core[`${f}_${l}`];const hasImageList=Array.isArray(core.images);const imageUrls=[...(core.images||[])];delete core.images;delete core.image;delete core.product_translations;delete core.product_images;
      const {data:p,error}=await sb.from('products').upsert(core).select().single();if(error)throw error;
      const trs=LANGS.filter(l=>translated[l].name||l==='es').map(l=>({product_id:p.id,locale:l,...translated[l]}));
      if(trs.length){const {error:te}=await sb.from('product_translations').upsert(trs,{onConflict:'product_id,locale'});if(te)throw te;}
      if(hasImageList){await sb.from('product_images').delete().eq('product_id',p.id);if(imageUrls.length){const imageRows=imageUrls.map((u,i)=>({product_id:p.id,storage_path:storagePathFromUrl(u)||`legacy/${p.id}/${i}`,public_url:u,alt_text:translated.es.name||p.sku,is_primary:i===0,sort_order:i}));const {error:ie}=await sb.from('product_images').insert(imageRows);if(ie)throw ie;}}
      return p;
    }
    if(entity==='categories'){
      const trans={};for(const l of LANGS)trans[l]={name:row[`name_${l}`]||'',description:row[`description_${l}`]||''};
      const core={...row};for(const l of LANGS)for(const f of ['name','description'])delete core[`${f}_${l}`];delete core.category_translations;
      const {data:c,error}=await sb.from('categories').upsert(core).select().single();if(error)throw error;
      const trs=LANGS.filter(l=>trans[l].name||l==='es').map(l=>({category_id:c.id,locale:l,...trans[l]}));const {error:te}=await sb.from('category_translations').upsert(trs,{onConflict:'category_id,locale'});if(te)throw te;return c;
    }
    let payload=row;if(entity==='zones')payload={...row,eta_text:row.eta_text||row.eta,delivery_days:row.delivery_days||row.days};if(entity==='zones'){delete payload.eta;delete payload.days;}if(entity==='coupons')payload={...row,discount_type:row.discount_type||row.type,discount_value:Number(row.discount_value??row.value),min_order_ars:Number(row.min_order_ars??row.min_ars??0),usage_count:Number(row.usage_count??row.uses??0)};if(entity==='coupons'){delete payload.type;delete payload.value;delete payload.min_ars;delete payload.uses;}if(entity==='settings'){payload={...row,delivery_text:row.delivery_text||row.default_delivery_text,default_cutoff:row.default_cutoff||row.cutoff_default};delete payload.default_delivery_text;delete payload.cutoff_default;}const {data,error}=await sb.from(map[entity]||entity).upsert(payload).select().single();if(error)throw error;return data;
  },
  async remove(entity,id){if(CONFIG.demoMode)return demoDB.remove(entity,id);const sb=await getSupabase();const {error}=await sb.from(map[entity]||entity).delete().eq('id',id);if(error)throw error;return true}
};

function storagePathFromUrl(url){const marker='/storage/v1/object/public/product-images/';const i=String(url||'').indexOf(marker);return i>=0?decodeURIComponent(String(url).slice(i+marker.length)):null}
