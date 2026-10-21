import { storage } from '../utils/storage.js';
import { demoProducts,demoCategories,demoDeliveryZones,demoRates,demoCoupons,demoSettings,demoSuppliers,demoSupplierProducts,demoBundles } from './demo-data.js';
const K={products:'gx_demo_products',categories:'gx_demo_categories',zones:'gx_demo_zones',rates:'gx_demo_rates',coupons:'gx_demo_coupons',settings:'gx_demo_settings',orders:'gx_demo_orders',customers:'gx_demo_customers',inventory:'gx_demo_inventory',suppliers:'gx_demo_suppliers',supplier_products:'gx_demo_supplier_products',bundles:'gx_demo_bundles',variants:'gx_demo_variants',purchase_orders:'gx_demo_purchase_orders',import_jobs:'gx_demo_import_jobs'};
const seed=(k,v)=>{if(storage.get(k)===null)storage.set(k,v)};
export function initDemo(){seed(K.products,demoProducts);seed(K.categories,demoCategories);seed(K.zones,demoDeliveryZones);seed(K.rates,demoRates);seed(K.coupons,demoCoupons);seed(K.settings,demoSettings);seed(K.orders,[]);seed(K.customers,[]);seed(K.inventory,[]);seed(K.suppliers,demoSuppliers);seed(K.supplier_products,demoSupplierProducts);seed(K.bundles,demoBundles);seed(K.variants,[]);seed(K.purchase_orders,[]);seed(K.import_jobs,[])}
export const demoDB={
  async list(entity){initDemo();return storage.get(K[entity],[])},
  async get(entity,id,field='id'){return (await this.list(entity)).find(x=>String(x[field])===String(id))||null},
  async upsert(entity,row){const rows=await this.list(entity);const id=row.id||crypto.randomUUID();const next={...row,id};const i=rows.findIndex(x=>x.id===id);if(i>=0)rows[i]=next;else rows.unshift(next);storage.set(K[entity],rows);return next},
  async remove(entity,id){const rows=(await this.list(entity)).filter(x=>x.id!==id);storage.set(K[entity],rows);return true},
  async createOrder(order){const orders=await this.list('orders');orders.unshift(order);storage.set(K.orders,orders);return order},
  async updateOrder(code,patch){const orders=await this.list('orders');const i=orders.findIndex(o=>o.code===code);if(i<0)return null;orders[i]={...orders[i],...patch,updated_at:new Date().toISOString()};storage.set(K.orders,orders);return orders[i]}
};
