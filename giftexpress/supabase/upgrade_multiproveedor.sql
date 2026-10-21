-- Ejecutar DESPUÉS de schema.sql / rls.sql existentes.
-- GiftExpress: migración incremental y no destructiva
create table if not exists public.suppliers (
 id uuid primary key default gen_random_uuid(), name text not null, contact text,
 email text, phone text, website text, notes text, lead_days integer not null default 2 check(lead_days>=0),
 active boolean not null default true, created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);
create table if not exists public.supplier_products (
 id uuid primary key default gen_random_uuid(), supplier_id uuid not null references public.suppliers(id) on delete cascade,
 product_id uuid not null references public.products(id) on delete cascade,
 supplier_sku text, cost_ars numeric(14,2) check(cost_ars>=0), available_qty integer check(available_qty>=0),
 confirmed_at timestamptz, lead_days integer check(lead_days>=0), preferred boolean default false,
 notes text, unique(supplier_id,product_id)
);
create table if not exists public.supplier_cost_history (
 id uuid primary key default gen_random_uuid(), supplier_product_id uuid not null references public.supplier_products(id) on delete cascade,
 previous_cost_ars numeric(14,2), new_cost_ars numeric(14,2) not null check(new_cost_ars>=0),
 changed_by uuid references auth.users(id), changed_at timestamptz not null default now()
);
alter table public.products add column if not exists supplier_id uuid references public.suppliers(id) on delete set null;
alter table public.products add column if not exists logistics_cost_ars numeric(14,2) default 0 check(logistics_cost_ars>=0);
alter table public.products add column if not exists margin_target_pct numeric(6,2) check(margin_target_pct>=0 and margin_target_pct<100);
alter table public.products add column if not exists availability_mode text not null default 'own_stock' check(availability_mode in ('own_stock','supplier_confirmed','preorder','on_request','out_of_stock'));
alter table public.products add column if not exists fulfillment_status text not null default 'unconfirmed' check(fulfillment_status in ('ready','tomorrow','scheduled','inquiry','unconfirmed','out'));
alter table public.products add column if not exists lead_time_days integer default 0 check(lead_time_days>=0);
alter table public.products add column if not exists attributes jsonb not null default '{}'::jsonb;
alter table public.products add column if not exists story_es text;
alter table public.products add column if not exists travel_warning_es text;
alter table public.products add column if not exists fragile boolean default false;
alter table public.products add column if not exists contains_liquids boolean default false;
alter table public.products add column if not exists contains_food boolean default false;
create table if not exists public.product_options (id uuid primary key default gen_random_uuid(),product_id uuid not null references public.products(id) on delete cascade,name text not null,sort_order int not null default 0,unique(product_id,name));
create table if not exists public.product_option_values (id uuid primary key default gen_random_uuid(),option_id uuid not null references public.product_options(id) on delete cascade,value text not null,sort_order int not null default 0,unique(option_id,value));
alter table public.product_variants add column if not exists price_ars numeric(14,2) check(price_ars>=0);
alter table public.product_variants add column if not exists image_url text;
alter table public.product_variants add column if not exists supplier_sku text;
alter table public.product_variants add column if not exists availability_mode text default 'own_stock';
create table if not exists public.variant_inventory (variant_id uuid primary key references public.product_variants(id) on delete cascade,own_stock int not null default 0 check(own_stock>=0),supplier_confirmed int not null default 0 check(supplier_confirmed>=0),updated_at timestamptz default now());
create table if not exists public.purchase_orders (id uuid primary key default gen_random_uuid(),supplier_id uuid not null references public.suppliers(id),status text not null default 'draft',notes text,created_at timestamptz default now(),received_at timestamptz);
create table if not exists public.purchase_order_items (id uuid primary key default gen_random_uuid(),purchase_order_id uuid not null references public.purchase_orders(id) on delete cascade,product_id uuid not null references public.products(id),variant_id uuid references public.product_variants(id),quantity integer not null check(quantity>0),unit_cost_ars numeric(14,2) not null check(unit_cost_ars>=0));
create table if not exists public.product_bundles (id uuid primary key default gen_random_uuid(),name text not null,sku text unique not null,price_ars numeric(14,2) not null check(price_ars>=0),components jsonb not null default '[]',active boolean not null default true,created_at timestamptz default now());
create table if not exists public.bundle_items (id uuid primary key default gen_random_uuid(),bundle_id uuid not null references public.product_bundles(id) on delete cascade,product_id uuid not null references public.products(id),variant_id uuid references public.product_variants(id),quantity integer not null check(quantity>0));
create table if not exists public.product_attributes (id uuid primary key default gen_random_uuid(),product_id uuid not null references public.products(id) on delete cascade,name text not null,value text not null);
create table if not exists public.product_story_translations (id uuid primary key default gen_random_uuid(),product_id uuid not null references public.products(id) on delete cascade,locale text not null check(locale in ('es','en','pt')),story text,materials text,craft text,care text,travel_warning text,unique(product_id,locale));
create table if not exists public.import_jobs (id uuid primary key default gen_random_uuid(),file_name text,processed integer default 0,successful integer default 0,failed integer default 0,created_at timestamptz default now(),created_by uuid references auth.users(id));
create table if not exists public.import_job_rows (id uuid primary key default gen_random_uuid(),job_id uuid not null references public.import_jobs(id) on delete cascade,row_number integer not null,sku text,status text,message text,raw_data jsonb);
create index if not exists supplier_products_product_idx on public.supplier_products(product_id);
create index if not exists suppliers_name_idx on public.suppliers(name);
create index if not exists product_bundles_sku_idx on public.product_bundles(sku);
-- Datos comerciales y costos no deben tener políticas públicas.
do $$ declare t text; begin foreach t in array array['suppliers','supplier_products','supplier_cost_history','product_options','product_option_values','variant_inventory','purchase_orders','purchase_order_items','product_bundles','bundle_items','product_attributes','product_story_translations','import_jobs','import_job_rows'] loop
 execute format('alter table public.%I enable row level security',t);
 execute format('create policy %I on public.%I for all to authenticated using(public.can_manage_catalog()) with check(public.can_manage_catalog())','gx_admin_'||t,t);
 execute format('grant select,insert,update,delete on public.%I to authenticated',t);
 end loop; end $$;
-- Los atributos públicos deben consultarse desde el catálogo de productos publicado, no los costos.
create policy "gx public stories" on public.product_story_translations for select to anon,authenticated using(exists(select 1 from public.products p where p.id=product_id and p.published and not p.hidden and p.deleted_at is null));
create policy "gx public options" on public.product_options for select to anon,authenticated using(exists(select 1 from public.products p where p.id=product_id and p.published and not p.hidden and p.deleted_at is null));
create policy "gx public option values" on public.product_option_values for select to anon,authenticated using(exists(select 1 from public.product_options o join public.products p on p.id=o.product_id where o.id=option_id and p.published and not p.hidden and p.deleted_at is null));
grant select on public.product_options,public.product_option_values,public.product_story_translations to anon;
-- NOTE: original products table grants SELECT to anon, including internal_cost_ars.
-- For production, replace public products read with a sanitized API/view and restrict the base table grants.
