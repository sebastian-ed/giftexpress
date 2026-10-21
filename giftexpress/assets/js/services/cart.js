import { storage } from '../utils/storage.js';
const KEY='gx_cart';
export const cart={
  all(){return storage.get(KEY,[])},save(items){storage.set(KEY,items);window.dispatchEvent(new CustomEvent('gx:cart'));return items},
  add(product,qty=1,variant=null){const items=this.all();const key=`${product.id}:${variant?.id||''}`;const i=items.findIndex(x=>x.key===key);if(i>=0)items[i].qty+=qty;else items.push({key,product_id:product.id,slug:product.slug,sku:product.sku,name_es:product.name_es,name_en:product.name_en,name_pt:product.name_pt,image:product.image,unit_price_ars:product.promo_price_ars||product.price_ars,qty,variant});this.save(items);return items},
  update(key,qty){const items=this.all().map(x=>x.key===key?{...x,qty:Math.max(1,qty)}:x);return this.save(items)},remove(key){return this.save(this.all().filter(x=>x.key!==key))},clear(){return this.save([])},count(){return this.all().reduce((a,x)=>a+x.qty,0)},subtotal(){return this.all().reduce((a,x)=>a+x.unit_price_ars*x.qty,0)}
};
