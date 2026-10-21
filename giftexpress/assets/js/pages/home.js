import { data } from '../services/data.js';
import { localize,t } from '../i18n/i18n.js';
import { formatMoney,loadRates } from '../services/currency.js';
import { cart } from '../services/cart.js';
import { track } from '../services/analytics.js';

const base = (window.GX_BASE || './');
const rel = (p='') => `${base}${String(p).replace(/^\//,'')}`;
const productHref = slug => rel(`producto.html?slug=${encodeURIComponent(slug)}`);
const catalogHref = slug => rel(`catalogo.html${slug ? `?categoria=${encodeURIComponent(slug)}` : ''}`);

function card(p){
  const img = p.image || rel('assets/img/products/caja.svg');
  return `<article class="product-card"><a class="product-image" href="${productHref(p.slug)}"><img loading="lazy" src="${img}" onerror="this.onerror=null;this.src='${rel('assets/img/products/caja.svg')}'" alt="${localize(p)}">${p.promo_price_ars?'<span class="badge-gx">Oferta</span>':p.is_new?'<span class="badge-gx">Nuevo</span>':''}</a><div class="product-body"><a class="product-name" href="${productHref(p.slug)}">${localize(p)}</a><div class="price">${formatMoney(p.promo_price_ars||p.price_ars)} ${p.promo_price_ars?`<span class="price-old">${formatMoney(p.price_ars)}</span>`:''}</div><div class="card-actions"><button class="btn-gx btn-primary-gx" data-add="${p.id}">${t('common.add')}</button><a class="btn-gx btn-outline-gx" href="${productHref(p.slug)}">${t('common.details')}</a></div></div></article>`
}

async function init(){
  await loadRates();
  const [products,categories]=await Promise.all([data.list('products'),data.list('categories')]);
  const featured = products.filter(p=>p.published!==false && p.featured).slice(0,8);
  const preferred = ['cuero','tradicion','sabores','indumentaria','artesania','regalospremium'];
  const catMap = new Map(categories.filter(c=>c.active!==false).map(c=>[c.slug,c]));
  const selected = preferred.map(slug=>catMap.get(slug)).filter(Boolean);
  const categoryImages = {
    cuero:'https://i0.wp.com/arandu.com.ar/wp-content/uploads/2020/06/16008P_web.jpg?fit=900%2C900&ssl=1',
    tradicion:'https://images.unsplash.com/photo-1518977676601-b53f82aba655?auto=format&fit=crop&w=850&q=82',
    sabores:'https://images.unsplash.com/photo-1606313564200-e75d5e30476c?auto=format&fit=crop&w=850&q=82',
    indumentaria:'./assets/img/arandu-hero.png',
    artesania:'https://images.unsplash.com/photo-1513519245088-0e12902e5a38?auto=format&fit=crop&w=850&q=82',
    regalospremium:'https://images.unsplash.com/photo-1549465220-1a8b9238cd48?auto=format&fit=crop&w=850&q=82'
  };
  const fallback = rel('assets/img/products/caja.svg');
  document.getElementById('homeCategories').innerHTML = selected.map(c=>`<a class="gx-photo-category" href="${catalogHref(c.slug)}"><span class="gx-cat-img"><img loading="lazy" src="${categoryImages[c.slug]||fallback}" alt="${localize(c)}" onerror="this.src='${fallback}'"></span><span class="gx-cat-footer"><strong>${localize(c)}</strong><span aria-hidden="true">↗</span></span></a>`).join('');
  document.getElementById('homeProducts').innerHTML = featured.map(card).join('');
  document.querySelectorAll('[data-add]').forEach(b=>b.onclick=()=>{const p=products.find(x=>x.id===b.dataset.add);cart.add(p);track('add_to_cart',{item_id:p.id,item_name:localize(p),value:p.price_ars,currency:'ARS'});b.textContent='Agregado';setTimeout(()=>b.textContent=t('common.add'),900)});
  track('view_home');
}

init().catch(console.error);
