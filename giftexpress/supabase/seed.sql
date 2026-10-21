-- GiftExpress demo seed. Safe to run after schema.sql + rls.sql.
insert into public.roles(slug,name) values
('super_admin','Super Admin'),('admin','Administrador'),('operations','Operaciones')
on conflict(slug) do update set name=excluded.name;

insert into public.currencies(code,name,symbol,enabled,is_charge_currency) values
('ARS','Peso argentino','$',true,true),('USD','Dólar estadounidense','US$',true,false),('EUR','Euro','€',true,false),('BRL','Real brasileño','R$',true,false)
on conflict(code) do update set enabled=excluded.enabled,is_charge_currency=excluded.is_charge_currency;
insert into public.exchange_rates(currency_code,ars_per_unit,source) values
('ARS',1,'manual'),('USD',1200,'manual'),('EUR',1390,'manual'),('BRL',225,'manual');

insert into public.settings(id,business_name,whatsapp,email,instagram,fx_mode,charge_currency,delivery_text)
values(1,'GiftExpress','+5491100000000','hola@giftexpress.com','@giftexpress.ar','manual','ARS','Pedidos dentro de zona y antes del horario límite se entregan el mismo día.')
on conflict(id) do update set business_name=excluded.business_name;

with c(slug,sort_order) as (values
('alfajores',1),('mate-y-yerba',2),('gourmet',3),('vinos',4),('regalos',5),('regionales',6),('chocolates',7),('combos',8))
insert into public.categories(slug,sort_order,active) select slug,sort_order,true from c on conflict(slug) do nothing;

insert into public.category_translations(category_id,locale,name)
select id,'es',case slug when 'alfajores' then 'Alfajores' when 'mate-y-yerba' then 'Mate y yerba' when 'gourmet' then 'Gourmet' when 'vinos' then 'Vinos' when 'regalos' then 'Regalos' when 'regionales' then 'Regionales' when 'chocolates' then 'Chocolates' else 'Combos' end from public.categories
on conflict(category_id,locale) do update set name=excluded.name;
insert into public.category_translations(category_id,locale,name)
select id,'en',case slug when 'alfajores' then 'Alfajores' when 'mate-y-yerba' then 'Mate & yerba' when 'gourmet' then 'Gourmet' when 'vinos' then 'Wine' when 'regalos' then 'Gifts' when 'regionales' then 'Regional' when 'chocolates' then 'Chocolate' else 'Bundles' end from public.categories
on conflict(category_id,locale) do update set name=excluded.name;
insert into public.category_translations(category_id,locale,name)
select id,'pt',case slug when 'alfajores' then 'Alfajores' when 'mate-y-yerba' then 'Mate e erva' when 'gourmet' then 'Gourmet' when 'vinos' then 'Vinhos' when 'regalos' then 'Presentes' when 'regionales' then 'Regionais' when 'chocolates' then 'Chocolates' else 'Combos' end from public.categories
on conflict(category_id,locale) do update set name=excluded.name;

create temporary table if not exists _gx_seed_products(sku text,slug text,category_slug text,price numeric,promo numeric,stock int,min_stock int,brand text,featured boolean,is_new boolean,best boolean,img text,name_es text,name_en text,name_pt text,desc_es text,desc_en text,desc_pt text) on commit drop;
truncate _gx_seed_products;
insert into _gx_seed_products values
('GX-ALF-001','alfajores-cacao-pack-6','alfajores',18500,null,18,5,'Pampa Select',true,false,true,'/assets/img/products/alfajores.svg','Alfajores de cacao · caja x6','Cocoa alfajores · box of 6','Alfajores de cacau · caixa x6','Seis alfajores premium con cobertura de cacao y relleno de dulce de leche.','Six premium alfajores with cocoa coating and dulce de leche filling.','Seis alfajores premium com cobertura de cacau e doce de leite.'),
('GX-DUL-001','dulce-de-leche-clasico-450','gourmet',12800,10900,28,8,'Sur',true,false,true,'/assets/img/products/dulce.svg','Dulce de leche clásico · 450 g','Classic dulce de leche · 450 g','Doce de leite clássico · 450 g','Textura cremosa, perfil clásico y frasco fácil de transportar.','Creamy texture, classic flavor and travel-friendly jar.','Textura cremosa, sabor clássico e pote fácil de transportar.'),
('GX-YER-001','yerba-mate-suave-500','mate-y-yerba',9800,null,34,10,'Campo Claro',true,false,false,'/assets/img/products/yerba.svg','Yerba mate suave · 500 g','Smooth yerba mate · 500 g','Erva-mate suave · 500 g','Blend suave pensado para viajeros.','Smooth blend for travelers.','Blend suave para viajantes.'),
('GX-MAT-001','mate-calabaza-cuero','mate-y-yerba',39500,null,11,4,'Criollo',true,true,false,'/assets/img/products/mate.svg','Mate de calabaza y cuero','Gourd & leather mate cup','Cuia de cabaça e couro','Mate natural revestido en cuero, preparado para regalo.','Natural gourd mate cup wrapped in leather.','Cuia natural revestida em couro.'),
('GX-BOM-001','bombilla-acero-clasica','mate-y-yerba',14500,null,22,6,'Criollo',false,false,false,'/assets/img/products/bombilla.svg','Bombilla de acero clásica','Classic steel bombilla','Bomba clássica de aço','Acero inoxidable, simple y durable.','Simple and durable stainless steel.','Aço inoxidável, simples e durável.'),
('GX-VIN-001','malbec-mendoza-reserva','vinos',28900,null,9,5,'Altos del Oeste',true,false,true,'/assets/img/products/malbec.svg','Malbec Mendoza · Reserva','Mendoza Malbec · Reserve','Malbec Mendoza · Reserva','Malbec de Mendoza, perfil frutado y elegante.','Mendoza Malbec with a fruit-forward profile.','Malbec de Mendoza, frutado e elegante.'),
('GX-CHO-001','chocolate-patagonico-70','chocolates',15400,null,24,7,'Sur Cacao',false,true,false,'/assets/img/products/chocolate.svg','Chocolate patagónico 70%','Patagonian 70% chocolate','Chocolate patagônico 70%','Tableta intensa elaborada en Patagonia.','Intense cocoa bar made in Patagonia.','Barra intensa feita na Patagônia.'),
('GX-CAJ-001','caja-argentina-esencial','regalos',62900,57900,15,4,'GiftExpress',true,false,true,'/assets/img/products/caja.svg','Caja Argentina Esencial','Essential Argentina Gift Box','Caixa Argentina Essencial','Alfajores, dulce de leche, chocolate y postal ilustrada.','Alfajores, dulce de leche, chocolate and postcard.','Alfajores, doce de leite, chocolate e cartão.'),
('GX-COM-001','combo-mate-viajero','combos',59800,null,12,4,'GiftExpress',true,true,false,'/assets/img/products/combo-mate.svg','Combo Mate Viajero','Traveler Mate Bundle','Combo Mate Viajante','Mate, bombilla y yerba en caja compacta.','Mate cup, bombilla and yerba in a compact box.','Cuia, bomba e erva em caixa compacta.'),
('GX-REG-001','sal-marina-patagonica','regionales',8700,null,31,8,'Costa Sur',false,false,false,'/assets/img/products/sal.svg','Sal marina patagónica','Patagonian sea salt','Sal marinho patagônico','Sal marina fina en envase compacto.','Fine sea salt in compact packaging.','Sal marinho fino em embalagem compacta.'),
('GX-GOU-002','mermelada-frutos-rojos','gourmet',11900,null,17,5,'Bosque',false,false,false,'/assets/img/products/mermelada.svg','Mermelada de frutos rojos','Red berry preserve','Geleia de frutas vermelhas','Mermelada artesanal patagónica.','Artisanal Patagonian berry preserve.','Geleia artesanal patagônica.'),
('GX-REG-002','postal-buenos-aires-set','regalos',7900,null,40,10,'Río Papel',false,true,false,'/assets/img/products/postales.svg','Set de postales Buenos Aires','Buenos Aires postcard set','Kit de cartões-postais de Buenos Aires','Seis postales ilustradas de Buenos Aires.','Six illustrated Buenos Aires postcards.','Seis cartões ilustrados de Buenos Aires.');

insert into public.products(sku,slug,category_id,price_ars,promo_price_ars,stock,min_stock,brand,published,featured,is_new,best_seller,origin)
select s.sku,s.slug,c.id,s.price,s.promo,s.stock,s.min_stock,s.brand,true,s.featured,s.is_new,s.best,'Argentina' from _gx_seed_products s join public.categories c on c.slug=s.category_slug
on conflict(sku) do update set price_ars=excluded.price_ars,promo_price_ars=excluded.promo_price_ars,stock=excluded.stock,published=true;

insert into public.product_translations(product_id,locale,name,description)
select p.id,'es',s.name_es,s.desc_es from _gx_seed_products s join public.products p on p.sku=s.sku
on conflict(product_id,locale) do update set name=excluded.name,description=excluded.description;
insert into public.product_translations(product_id,locale,name,description)
select p.id,'en',s.name_en,s.desc_en from _gx_seed_products s join public.products p on p.sku=s.sku
on conflict(product_id,locale) do update set name=excluded.name,description=excluded.description;
insert into public.product_translations(product_id,locale,name,description)
select p.id,'pt',s.name_pt,s.desc_pt from _gx_seed_products s join public.products p on p.sku=s.sku
on conflict(product_id,locale) do update set name=excluded.name,description=excluded.description;

insert into public.product_images(product_id,storage_path,public_url,alt_text,is_primary,sort_order)
select p.id,'demo/'||p.slug||'.svg',s.img,s.name_es,true,0 from _gx_seed_products s join public.products p on p.sku=s.sku
on conflict(product_id,storage_path) do update set public_url=excluded.public_url,alt_text=excluded.alt_text,is_primary=true;

insert into public.inventory(product_id,available,reserved)
select id,stock,0 from public.products on conflict(product_id) do update set available=excluded.available;

insert into public.delivery_zones(name,districts,postal_codes,price_ars,free_over_ars,min_order_ars,cutoff,eta_text,delivery_days,active) values
('CABA',array['Palermo','Recoleta','Belgrano','San Telmo','Microcentro','Puerto Madero','Caballito'],array['1000','1001','1002','1425','1426','1428'],7500,90000,25000,'17:00','2–4 h',array[1,2,3,4,5,6],true),
('Vicente López / San Isidro',array['Olivos','Vicente López','Martínez','San Isidro'],array['1636','1638','1640','1642'],11000,120000,35000,'16:00','3–5 h',array[1,2,3,4,5,6],true)
on conflict(name) do update set districts=excluded.districts,postal_codes=excluded.postal_codes,price_ars=excluded.price_ars;

insert into public.coupons(code,discount_type,discount_value,starts_at,ends_at,min_order_ars,max_uses,active)
values('HOTEL10','percent',10,'2026-01-01','2027-12-31',50000,200,true)
on conflict(code) do update set active=true;
