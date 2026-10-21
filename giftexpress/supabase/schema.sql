-- GiftExpress · Supabase/Postgres schema
-- Run first. Then run rls.sql and seed.sql.
create extension if not exists pgcrypto;

create or replace function public.set_updated_at() returns trigger language plpgsql as $$
begin new.updated_at = now(); return new; end $$;

create table if not exists public.roles (
  id uuid primary key default gen_random_uuid(),
  slug text unique not null check (slug in ('super_admin','admin','operations')),
  name text not null,
  created_at timestamptz not null default now()
);

create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  full_name text,
  role_id uuid references public.roles(id),
  active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.categories (
  id uuid primary key default gen_random_uuid(),
  parent_id uuid references public.categories(id) on delete set null,
  slug text unique not null,
  image_url text,
  sort_order integer not null default 0,
  active boolean not null default true,
  deleted_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index if not exists categories_parent_idx on public.categories(parent_id);
create index if not exists categories_active_sort_idx on public.categories(active,sort_order);

create table if not exists public.category_translations (
  id uuid primary key default gen_random_uuid(),
  category_id uuid not null references public.categories(id) on delete cascade,
  locale text not null check (locale in ('es','en','pt')),
  name text not null,
  description text,
  unique(category_id,locale)
);

create table if not exists public.products (
  id uuid primary key default gen_random_uuid(),
  sku text unique not null,
  slug text unique not null,
  category_id uuid references public.categories(id) on delete set null,
  brand text,
  tags text[] not null default '{}',
  price_ars numeric(14,2) not null check(price_ars >= 0),
  promo_price_ars numeric(14,2) check(promo_price_ars is null or promo_price_ars >= 0),
  internal_cost_ars numeric(14,2) check(internal_cost_ars is null or internal_cost_ars >= 0),
  stock integer not null default 0 check(stock >= 0),
  min_stock integer not null default 0 check(min_stock >= 0),
  weight_grams integer check(weight_grams is null or weight_grams >= 0),
  dimensions jsonb not null default '{}'::jsonb,
  origin text,
  ingredients text,
  warnings text,
  conservation text,
  published boolean not null default false,
  hidden boolean not null default false,
  featured boolean not null default false,
  is_new boolean not null default false,
  best_seller boolean not null default false,
  sort_order integer not null default 0,
  deleted_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check(promo_price_ars is null or promo_price_ars <= price_ars)
);
create index if not exists products_category_idx on public.products(category_id);
create index if not exists products_public_idx on public.products(published,hidden,deleted_at);
create index if not exists products_featured_idx on public.products(featured,sort_order);
create index if not exists products_tags_gin on public.products using gin(tags);

create table if not exists public.product_translations (
  id uuid primary key default gen_random_uuid(),
  product_id uuid not null references public.products(id) on delete cascade,
  locale text not null check(locale in ('es','en','pt')),
  name text not null,
  short_description text,
  description text,
  unique(product_id,locale)
);
create index if not exists product_translations_product_idx on public.product_translations(product_id);

create table if not exists public.product_images (
  id uuid primary key default gen_random_uuid(),
  product_id uuid not null references public.products(id) on delete cascade,
  storage_path text not null,
  public_url text not null,
  alt_text text,
  is_primary boolean not null default false,
  sort_order integer not null default 0,
  created_at timestamptz not null default now(),
  unique(product_id,storage_path)
);
create index if not exists product_images_product_sort_idx on public.product_images(product_id,sort_order);

create table if not exists public.product_variants (
  id uuid primary key default gen_random_uuid(),
  product_id uuid not null references public.products(id) on delete cascade,
  sku text unique not null,
  name text not null,
  attributes jsonb not null default '{}'::jsonb,
  price_delta_ars numeric(14,2) not null default 0,
  stock integer not null default 0 check(stock >= 0),
  active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index if not exists product_variants_product_idx on public.product_variants(product_id);

create table if not exists public.inventory (
  product_id uuid primary key references public.products(id) on delete cascade,
  available integer not null default 0 check(available >= 0),
  reserved integer not null default 0 check(reserved >= 0),
  updated_at timestamptz not null default now()
);

create table if not exists public.inventory_movements (
  id uuid primary key default gen_random_uuid(),
  product_id uuid not null references public.products(id) on delete cascade,
  variant_id uuid references public.product_variants(id) on delete set null,
  movement_type text not null check(movement_type in ('in','sale','manual_adjustment','return','reservation','release')),
  quantity integer not null,
  order_id uuid,
  note text,
  actor_id uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now()
);
create index if not exists inventory_movements_product_date_idx on public.inventory_movements(product_id,created_at desc);

create table if not exists public.customers (
  id uuid primary key default gen_random_uuid(),
  auth_user_id uuid references auth.users(id) on delete set null,
  first_name text not null,
  last_name text,
  email text,
  whatsapp text,
  country text,
  preferred_locale text check(preferred_locale is null or preferred_locale in ('es','en','pt')),
  preferred_currency text check(preferred_currency is null or preferred_currency in ('ARS','USD','EUR','BRL')),
  marketing_opt_in boolean not null default false,
  orders_count integer not null default 0,
  total_spent_ars numeric(16,2) not null default 0,
  avg_ticket_ars numeric(16,2) not null default 0,
  last_order_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index if not exists customers_email_idx on public.customers(lower(email));
create index if not exists customers_whatsapp_idx on public.customers(whatsapp);

create table if not exists public.hotels (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  address_line text,
  street_number text,
  district text,
  postal_code text,
  city text default 'Buenos Aires',
  active boolean not null default true,
  created_at timestamptz not null default now()
);

create table if not exists public.addresses (
  id uuid primary key default gen_random_uuid(),
  customer_id uuid references public.customers(id) on delete set null,
  accommodation_type text not null check(accommodation_type in ('Hotel','Airbnb','Departamento temporario','Hostel','Otro')),
  hotel_id uuid references public.hotels(id) on delete set null,
  hotel_name text,
  address_line text not null,
  street_number text,
  floor text,
  room text,
  district text not null,
  postal_code text,
  reference text,
  reservation_name text,
  deliver_reception boolean not null default false,
  room_unknown boolean not null default false,
  notes text,
  created_at timestamptz not null default now()
);
create index if not exists addresses_customer_idx on public.addresses(customer_id);

create table if not exists public.delivery_zones (
  id uuid primary key default gen_random_uuid(),
  name text unique not null,
  districts text[] not null default '{}',
  postal_codes text[] not null default '{}',
  price_ars numeric(14,2) not null default 0 check(price_ars >= 0),
  free_over_ars numeric(14,2) check(free_over_ars is null or free_over_ars >= 0),
  min_order_ars numeric(14,2) not null default 0 check(min_order_ars >= 0),
  cutoff time not null default '17:00',
  eta_text text not null default '2–4 h',
  delivery_days smallint[] not null default '{1,2,3,4,5,6}',
  active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.delivery_blackouts (
  id uuid primary key default gen_random_uuid(),
  blackout_date date not null,
  zone_id uuid references public.delivery_zones(id) on delete cascade,
  reason text,
  special_cutoff time,
  no_delivery boolean not null default true,
  unique(blackout_date,zone_id)
);

create table if not exists public.currencies (
  code text primary key check(code in ('ARS','USD','EUR','BRL')),
  name text not null,
  symbol text not null,
  enabled boolean not null default true,
  is_charge_currency boolean not null default false
);

create table if not exists public.exchange_rates (
  id uuid primary key default gen_random_uuid(),
  currency_code text not null references public.currencies(code),
  ars_per_unit numeric(18,6) not null check(ars_per_unit > 0),
  source text not null default 'manual',
  effective_at timestamptz not null default now(),
  created_at timestamptz not null default now()
);
create index if not exists exchange_rates_latest_idx on public.exchange_rates(currency_code,effective_at desc);

create table if not exists public.coupons (
  id uuid primary key default gen_random_uuid(),
  code text unique not null,
  discount_type text not null check(discount_type in ('percent','fixed')),
  discount_value numeric(14,2) not null check(discount_value > 0),
  starts_at timestamptz,
  ends_at timestamptz,
  min_order_ars numeric(14,2) not null default 0,
  max_uses integer check(max_uses is null or max_uses > 0),
  usage_count integer not null default 0,
  applicable_product_ids uuid[] not null default '{}',
  applicable_category_ids uuid[] not null default '{}',
  active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index if not exists coupons_code_active_idx on public.coupons(code,active);

create sequence if not exists public.gx_order_seq start 1000;
create or replace function public.next_order_code() returns text language sql volatile as $$
  select 'GX-' || lpad(nextval('public.gx_order_seq')::text,6,'0')
$$;

create table if not exists public.orders (
  id uuid primary key default gen_random_uuid(),
  code text unique not null default public.next_order_code(),
  customer_id uuid references public.customers(id) on delete set null,
  address_id uuid references public.addresses(id) on delete set null,
  delivery_zone_id uuid references public.delivery_zones(id) on delete set null,
  coupon_id uuid references public.coupons(id) on delete set null,
  status text not null default 'received' check(status in ('received','paid','preparing','on_the_way','delivered','canceled')),
  payment_status text not null default 'pending' check(payment_status in ('pending','approved','rejected','canceled','refunded')),
  display_currency text not null default 'ARS' check(display_currency in ('ARS','USD','EUR','BRL')),
  charge_currency text not null default 'ARS' check(charge_currency in ('ARS','USD','EUR','BRL')),
  subtotal_ars numeric(14,2) not null check(subtotal_ars >= 0),
  discount_ars numeric(14,2) not null default 0 check(discount_ars >= 0),
  delivery_ars numeric(14,2) not null default 0 check(delivery_ars >= 0),
  tax_ars numeric(14,2) not null default 0 check(tax_ars >= 0),
  total_ars numeric(14,2) not null check(total_ars >= 0),
  exchange_snapshot jsonb not null default '{}'::jsonb,
  delivery_date date,
  delivery_window text,
  delivery_message text,
  customer_note text,
  source text not null default 'web',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index if not exists orders_created_idx on public.orders(created_at desc);
create index if not exists orders_status_idx on public.orders(status,payment_status);
create index if not exists orders_customer_idx on public.orders(customer_id);

alter table public.inventory_movements drop constraint if exists inventory_movements_order_id_fkey;
alter table public.inventory_movements add constraint inventory_movements_order_id_fkey foreign key(order_id) references public.orders(id) on delete set null;

create table if not exists public.order_items (
  id uuid primary key default gen_random_uuid(),
  order_id uuid not null references public.orders(id) on delete cascade,
  product_id uuid references public.products(id) on delete set null,
  variant_id uuid references public.product_variants(id) on delete set null,
  sku text not null,
  product_name text not null,
  quantity integer not null check(quantity > 0),
  unit_price_ars numeric(14,2) not null check(unit_price_ars >= 0),
  line_total_ars numeric(14,2) generated always as (quantity * unit_price_ars) stored,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);
create index if not exists order_items_order_idx on public.order_items(order_id);

create table if not exists public.order_status_history (
  id uuid primary key default gen_random_uuid(),
  order_id uuid not null references public.orders(id) on delete cascade,
  status text not null,
  payment_status text,
  note text,
  actor_id uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now()
);
create index if not exists order_status_history_order_idx on public.order_status_history(order_id,created_at);

create table if not exists public.payments (
  id uuid primary key default gen_random_uuid(),
  order_id uuid not null references public.orders(id) on delete cascade,
  provider text not null default 'mercadopago',
  provider_order_id text,
  provider_payment_id text,
  status text not null default 'pending' check(status in ('pending','approved','rejected','canceled','refunded')),
  amount numeric(14,2) not null,
  currency text not null default 'ARS',
  payment_method text,
  raw_response jsonb not null default '{}'::jsonb,
  idempotency_key text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create unique index if not exists payments_provider_order_uidx on public.payments(provider,provider_order_id) where provider_order_id is not null;
create index if not exists payments_order_idx on public.payments(order_id);

create table if not exists public.coupon_usage (
  id uuid primary key default gen_random_uuid(),
  coupon_id uuid not null references public.coupons(id) on delete cascade,
  order_id uuid not null references public.orders(id) on delete cascade,
  customer_id uuid references public.customers(id) on delete set null,
  discount_ars numeric(14,2) not null,
  created_at timestamptz not null default now(),
  unique(coupon_id,order_id)
);

create table if not exists public.settings (
  id integer primary key default 1 check(id=1),
  business_name text not null default 'GiftExpress',
  logo_url text,
  favicon_url text,
  whatsapp text,
  email text,
  instagram text,
  fx_mode text not null default 'manual' check(fx_mode in ('manual','api')),
  fx_api_url text,
  charge_currency text not null default 'ARS' check(charge_currency in ('ARS','USD','EUR','BRL')),
  enabled_locales text[] not null default '{es,en,pt}',
  enabled_currencies text[] not null default '{ARS,USD,EUR,BRL}',
  taxes jsonb not null default '{}'::jsonb,
  delivery_text text,
  default_cutoff time not null default '17:00',
  business_data jsonb not null default '{}'::jsonb,
  payment_methods jsonb not null default '{"mercadopago":true}'::jsonb,
  banners jsonb not null default '[]'::jsonb,
  analytics jsonb not null default '{}'::jsonb,
  updated_at timestamptz not null default now()
);

create table if not exists public.webhook_events (
  id text primary key,
  provider text not null,
  event_type text,
  resource_id text,
  payload jsonb not null,
  processed_at timestamptz not null default now()
);

-- updated_at triggers
DO $$
DECLARE t text;
BEGIN
  FOREACH t IN ARRAY ARRAY['profiles','categories','products','product_variants','customers','delivery_zones','coupons','orders','payments'] LOOP
    EXECUTE format('drop trigger if exists %I_set_updated_at on public.%I',t,t);
    EXECUTE format('create trigger %I_set_updated_at before update on public.%I for each row execute function public.set_updated_at()',t,t);
  END LOOP;
END $$;

-- Create a profile when a Supabase Auth user is created.
create or replace function public.handle_new_user() returns trigger language plpgsql security definer set search_path=public as $$
begin
  insert into public.profiles(id,full_name)
  values(new.id,coalesce(new.raw_user_meta_data->>'full_name',new.email))
  on conflict(id) do nothing;
  return new;
end $$;
drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created after insert on auth.users for each row execute function public.handle_new_user();

-- Atomic public-checkout transaction. Call only from a trusted Edge Function with service_role.
create or replace function public.create_order_from_checkout(p_payload jsonb)
returns jsonb
language plpgsql
security definer
set search_path=public
as $$
declare
  v_customer jsonb := p_payload->'customer';
  v_address jsonb := p_payload->'address';
  v_items jsonb := p_payload->'items';
  v_item jsonb;
  v_product public.products%rowtype;
  v_zone public.delivery_zones%rowtype;
  v_coupon public.coupons%rowtype;
  v_customer_id uuid;
  v_address_id uuid;
  v_order_id uuid;
  v_order_code text;
  v_coupon_id uuid;
  v_subtotal numeric(14,2) := 0;
  v_eligible_subtotal numeric(14,2) := 0;
  v_discount numeric(14,2) := 0;
  v_delivery numeric(14,2) := 0;
  v_total numeric(14,2) := 0;
  v_qty integer;
  v_price numeric(14,2);
  v_today date := (now() at time zone 'America/Argentina/Buenos_Aires')::date;
  v_local_time time := (now() at time zone 'America/Argentina/Buenos_Aires')::time;
  v_delivery_date date;
  v_candidate date;
  v_allowed boolean;
  v_rates jsonb := '{}'::jsonb;
  i integer;
begin
  if jsonb_typeof(v_items) <> 'array' or jsonb_array_length(v_items)=0 then raise exception 'El carrito está vacío'; end if;
  if coalesce(v_customer->>'email','')='' or coalesce(v_customer->>'first_name','')='' then raise exception 'Datos de cliente incompletos'; end if;
  select * into v_zone from public.delivery_zones where id=(p_payload->>'delivery_zone_id')::uuid and active=true;
  if not found then raise exception 'Zona de entrega inválida'; end if;

  -- Lock each product and calculate server-authoritative total.
  for v_item in select * from jsonb_array_elements(v_items) loop
    v_qty := greatest(1,coalesce((v_item->>'quantity')::int,1));
    select * into v_product from public.products where id=(v_item->>'product_id')::uuid and published=true and hidden=false and deleted_at is null for update;
    if not found then raise exception 'Producto no disponible'; end if;
    if v_product.stock < v_qty then raise exception 'Stock insuficiente para %',v_product.sku; end if;
    v_price := coalesce(v_product.promo_price_ars,v_product.price_ars);
    v_subtotal := v_subtotal + (v_price*v_qty);
  end loop;
  if v_subtotal < v_zone.min_order_ars then raise exception 'El pedido no alcanza el mínimo de la zona'; end if;

  if nullif(trim(coalesce(p_payload->>'coupon_code','')),'') is not null then
    select * into v_coupon from public.coupons where upper(code)=upper(p_payload->>'coupon_code') and active=true and (starts_at is null or starts_at<=now()) and (ends_at is null or ends_at>=now()) for update;
    if found and v_subtotal>=v_coupon.min_order_ars and (v_coupon.max_uses is null or v_coupon.usage_count<v_coupon.max_uses) then
      v_coupon_id := v_coupon.id;
      if cardinality(v_coupon.applicable_product_ids)=0 and cardinality(v_coupon.applicable_category_ids)=0 then
        v_eligible_subtotal := v_subtotal;
      else
        for v_item in select * from jsonb_array_elements(v_items) loop
          v_qty := greatest(1,coalesce((v_item->>'quantity')::int,1));
          select * into v_product from public.products where id=(v_item->>'product_id')::uuid;
          if v_product.id=any(v_coupon.applicable_product_ids) or v_product.category_id=any(v_coupon.applicable_category_ids) then
            v_eligible_subtotal := v_eligible_subtotal + coalesce(v_product.promo_price_ars,v_product.price_ars)*v_qty;
          end if;
        end loop;
      end if;
      if v_coupon.discount_type='percent' then v_discount:=round(v_eligible_subtotal*(v_coupon.discount_value/100.0),2); else v_discount:=least(v_coupon.discount_value,v_eligible_subtotal); end if;
    end if;
  end if;

  v_delivery := case when v_zone.free_over_ars is not null and (v_subtotal-v_discount)>=v_zone.free_over_ars then 0 else v_zone.price_ars end;
  v_total := greatest(0,v_subtotal-v_discount+v_delivery);

  -- Next valid delivery date. ISO weekday 1=Mon..7=Sun.
  v_delivery_date := null;
  for i in 0..14 loop
    v_candidate := v_today+i;
    v_allowed := extract(isodow from v_candidate)::int = any(v_zone.delivery_days)
      and not exists(select 1 from public.delivery_blackouts b where b.blackout_date=v_candidate and (b.zone_id is null or b.zone_id=v_zone.id) and b.no_delivery=true);
    if i=0 and v_local_time>v_zone.cutoff then v_allowed:=false; end if;
    if v_allowed then v_delivery_date:=v_candidate; exit; end if;
  end loop;
  if v_delivery_date is null then raise exception 'No hay una fecha de entrega disponible'; end if;

  select coalesce(jsonb_object_agg(code,rate),'{}'::jsonb) into v_rates from (
    select c.code,coalesce((select er.ars_per_unit from public.exchange_rates er where er.currency_code=c.code order by er.effective_at desc limit 1),case when c.code='ARS' then 1 else null end) rate
    from public.currencies c where c.enabled=true
  ) x where rate is not null;

  select id into v_customer_id from public.customers where lower(email)=lower(v_customer->>'email') order by created_at limit 1 for update;
  if v_customer_id is null then
    insert into public.customers(first_name,last_name,email,whatsapp,country,preferred_locale,preferred_currency)
    values(v_customer->>'first_name',v_customer->>'last_name',lower(v_customer->>'email'),v_customer->>'whatsapp',v_customer->>'country',coalesce(v_customer->>'language','es'),coalesce(v_customer->>'currency','ARS')) returning id into v_customer_id;
  else
    update public.customers set first_name=v_customer->>'first_name',last_name=v_customer->>'last_name',whatsapp=v_customer->>'whatsapp',country=v_customer->>'country',preferred_locale=coalesce(v_customer->>'language',preferred_locale),preferred_currency=coalesce(v_customer->>'currency',preferred_currency) where id=v_customer_id;
  end if;

  insert into public.addresses(customer_id,accommodation_type,hotel_name,address_line,street_number,floor,room,district,postal_code,reference,reservation_name,deliver_reception,room_unknown,notes)
  values(v_customer_id,coalesce(v_address->>'accommodation_type','Otro'),v_address->>'hotel_name',v_address->>'address_line',v_address->>'number',v_address->>'floor',v_address->>'room',v_address->>'district',v_address->>'postal_code',v_address->>'reference',v_address->>'reservation_name',coalesce((v_address->>'deliver_reception')::boolean,false),coalesce((v_address->>'room_unknown')::boolean,false),v_address->>'notes')
  returning id into v_address_id;

  insert into public.orders(customer_id,address_id,delivery_zone_id,coupon_id,display_currency,charge_currency,subtotal_ars,discount_ars,delivery_ars,total_ars,exchange_snapshot,delivery_date,delivery_window,delivery_message,customer_note)
  values(v_customer_id,v_address_id,v_zone.id,v_coupon_id,coalesce(p_payload->>'display_currency','ARS'),'ARS',v_subtotal,v_discount,v_delivery,v_total,v_rates,v_delivery_date,v_zone.eta_text,case when v_delivery_date=v_today then 'Entrega hoy · '||v_zone.eta_text else 'Entrega '||to_char(v_delivery_date,'DD/MM/YYYY')||' · '||v_zone.eta_text end,v_address->>'notes')
  returning id,code into v_order_id,v_order_code;

  for v_item in select * from jsonb_array_elements(v_items) loop
    v_qty := greatest(1,coalesce((v_item->>'quantity')::int,1));
    select * into v_product from public.products where id=(v_item->>'product_id')::uuid for update;
    v_price := coalesce(v_product.promo_price_ars,v_product.price_ars);
    insert into public.order_items(order_id,product_id,variant_id,sku,product_name,quantity,unit_price_ars)
    values(v_order_id,v_product.id,nullif(v_item->>'variant_id','')::uuid,v_product.sku,coalesce((select name from public.product_translations where product_id=v_product.id and locale='es'),v_product.sku),v_qty,v_price);
    update public.products set stock=stock-v_qty where id=v_product.id;
    insert into public.inventory(product_id,available,reserved) values(v_product.id,v_product.stock-v_qty,0) on conflict(product_id) do update set available=excluded.available,updated_at=now();
    insert into public.inventory_movements(product_id,variant_id,movement_type,quantity,order_id,note) values(v_product.id,nullif(v_item->>'variant_id','')::uuid,'sale',-v_qty,v_order_id,'Venta '||v_order_code);
  end loop;

  if v_coupon_id is not null then
    insert into public.coupon_usage(coupon_id,order_id,customer_id,discount_ars) values(v_coupon_id,v_order_id,v_customer_id,v_discount);
    update public.coupons set usage_count=usage_count+1 where id=v_coupon_id;
  end if;
  insert into public.order_status_history(order_id,status,payment_status,note) values(v_order_id,'received','pending','Pedido creado');
  update public.customers set orders_count=orders_count+1,total_spent_ars=total_spent_ars+v_total,avg_ticket_ars=(total_spent_ars+v_total)/(orders_count+1),last_order_at=now() where id=v_customer_id;

  return jsonb_build_object('id',v_order_id,'code',v_order_code,'subtotal_ars',v_subtotal,'discount_ars',v_discount,'delivery_ars',v_delivery,'total_ars',v_total,'delivery_date',v_delivery_date,'delivery_message',case when v_delivery_date=v_today then 'Entrega hoy · '||v_zone.eta_text else 'Entrega '||to_char(v_delivery_date,'DD/MM/YYYY')||' · '||v_zone.eta_text end,'display_currency',coalesce(p_payload->>'display_currency','ARS'),'charge_currency','ARS','exchange_snapshot',v_rates);
end $$;
revoke all on function public.create_order_from_checkout(jsonb) from public,anon,authenticated;
grant execute on function public.create_order_from_checkout(jsonb) to service_role;

-- Public order code is deliberately non-sequential to reduce enumeration risk on tracking URLs.
create or replace function public.next_order_code() returns text language sql volatile as $$
  select 'GX-' || upper(substr(replace(gen_random_uuid()::text,'-',''),1,10))
$$;
