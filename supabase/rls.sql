-- GiftExpress Row Level Security
create or replace function public.current_role_slug() returns text language sql stable security definer set search_path=public as $$
  select r.slug from public.profiles p join public.roles r on r.id=p.role_id where p.id=auth.uid() and p.active=true limit 1
$$;
create or replace function public.is_admin() returns boolean language sql stable security definer set search_path=public as $$
  select coalesce(public.current_role_slug() in ('super_admin','admin','operations'),false)
$$;
create or replace function public.can_manage_catalog() returns boolean language sql stable security definer set search_path=public as $$
  select coalesce(public.current_role_slug() in ('super_admin','admin'),false)
$$;

alter table public.roles enable row level security;
alter table public.profiles enable row level security;
alter table public.categories enable row level security;
alter table public.category_translations enable row level security;
alter table public.products enable row level security;
alter table public.product_translations enable row level security;
alter table public.product_images enable row level security;
alter table public.product_variants enable row level security;
alter table public.inventory enable row level security;
alter table public.inventory_movements enable row level security;
alter table public.customers enable row level security;
alter table public.addresses enable row level security;
alter table public.hotels enable row level security;
alter table public.delivery_zones enable row level security;
alter table public.delivery_blackouts enable row level security;
alter table public.currencies enable row level security;
alter table public.exchange_rates enable row level security;
alter table public.coupons enable row level security;
alter table public.orders enable row level security;
alter table public.order_items enable row level security;
alter table public.order_status_history enable row level security;
alter table public.payments enable row level security;
alter table public.coupon_usage enable row level security;
alter table public.settings enable row level security;
alter table public.webhook_events enable row level security;

-- Public storefront: read only published catalog/configuration needed to browse.
create policy "public categories" on public.categories for select to anon,authenticated using(active=true and deleted_at is null);
create policy "public category translations" on public.category_translations for select to anon,authenticated using(exists(select 1 from public.categories c where c.id=category_id and c.active=true and c.deleted_at is null));
create policy "public products" on public.products for select to anon,authenticated using(published=true and hidden=false and deleted_at is null);
create policy "public product translations" on public.product_translations for select to anon,authenticated using(exists(select 1 from public.products p where p.id=product_id and p.published=true and p.hidden=false and p.deleted_at is null));
create policy "public product images" on public.product_images for select to anon,authenticated using(exists(select 1 from public.products p where p.id=product_id and p.published=true and p.hidden=false and p.deleted_at is null));
create policy "public active variants" on public.product_variants for select to anon,authenticated using(active=true and exists(select 1 from public.products p where p.id=product_id and p.published=true and p.hidden=false and p.deleted_at is null));
create policy "public zones" on public.delivery_zones for select to anon,authenticated using(active=true);
create policy "public currencies" on public.currencies for select to anon,authenticated using(enabled=true);
create policy "public rates" on public.exchange_rates for select to anon,authenticated using(true);
create policy "public settings" on public.settings for select to anon,authenticated using(true);
create policy "public hotels" on public.hotels for select to anon,authenticated using(active=true);

-- Admin reads.
create policy "admin roles read" on public.roles for select to authenticated using(public.is_admin());
create policy "own profile" on public.profiles for select to authenticated using(id=auth.uid() or public.is_admin());
create policy "admin all categories" on public.categories for all to authenticated using(public.can_manage_catalog()) with check(public.can_manage_catalog());
create policy "admin all category translations" on public.category_translations for all to authenticated using(public.can_manage_catalog()) with check(public.can_manage_catalog());
create policy "admin all products" on public.products for all to authenticated using(public.can_manage_catalog()) with check(public.can_manage_catalog());
create policy "admin all product translations" on public.product_translations for all to authenticated using(public.can_manage_catalog()) with check(public.can_manage_catalog());
create policy "admin all product images" on public.product_images for all to authenticated using(public.can_manage_catalog()) with check(public.can_manage_catalog());
create policy "admin all variants" on public.product_variants for all to authenticated using(public.can_manage_catalog()) with check(public.can_manage_catalog());
create policy "admin inventory" on public.inventory for all to authenticated using(public.is_admin()) with check(public.is_admin());
create policy "admin inventory movements" on public.inventory_movements for all to authenticated using(public.is_admin()) with check(public.is_admin());
create policy "admin customers" on public.customers for all to authenticated using(public.is_admin()) with check(public.is_admin());
create policy "admin addresses" on public.addresses for all to authenticated using(public.is_admin()) with check(public.is_admin());
create policy "admin hotels" on public.hotels for all to authenticated using(public.is_admin()) with check(public.is_admin());
create policy "admin zones" on public.delivery_zones for all to authenticated using(public.is_admin()) with check(public.is_admin());
create policy "admin blackouts" on public.delivery_blackouts for all to authenticated using(public.is_admin()) with check(public.is_admin());
create policy "admin currencies" on public.currencies for all to authenticated using(public.can_manage_catalog()) with check(public.can_manage_catalog());
create policy "admin rates" on public.exchange_rates for all to authenticated using(public.can_manage_catalog()) with check(public.can_manage_catalog());
create policy "admin coupons" on public.coupons for all to authenticated using(public.can_manage_catalog()) with check(public.can_manage_catalog());
create policy "admin orders" on public.orders for all to authenticated using(public.is_admin()) with check(public.is_admin());
create policy "admin order items" on public.order_items for all to authenticated using(public.is_admin()) with check(public.is_admin());
create policy "admin status history" on public.order_status_history for all to authenticated using(public.is_admin()) with check(public.is_admin());
create policy "admin payments" on public.payments for all to authenticated using(public.is_admin()) with check(public.is_admin());
create policy "admin coupon usage" on public.coupon_usage for all to authenticated using(public.is_admin()) with check(public.is_admin());
create policy "admin settings" on public.settings for all to authenticated using(public.can_manage_catalog()) with check(public.can_manage_catalog());
create policy "admin webhook events" on public.webhook_events for select to authenticated using(public.current_role_slug()='super_admin');

-- Explicit privileges; RLS remains the authorization boundary.
grant usage on schema public to anon,authenticated;
grant select on public.categories,public.category_translations,public.products,public.product_translations,public.product_images,public.product_variants,public.delivery_zones,public.currencies,public.exchange_rates,public.settings,public.hotels to anon;
grant select on all tables in schema public to authenticated;
grant insert,update,delete on public.categories,public.category_translations,public.products,public.product_translations,public.product_images,public.product_variants,public.inventory,public.inventory_movements,public.customers,public.addresses,public.hotels,public.delivery_zones,public.delivery_blackouts,public.currencies,public.exchange_rates,public.coupons,public.orders,public.order_items,public.order_status_history,public.payments,public.coupon_usage,public.settings to authenticated;

-- Storage bucket and policies. Public read, admin write.
insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types)
values('product-images','product-images',true,8388608,array['image/jpeg','image/png','image/webp','image/avif','image/svg+xml'])
on conflict(id) do update set public=excluded.public,file_size_limit=excluded.file_size_limit,allowed_mime_types=excluded.allowed_mime_types;

create policy "product images public read" on storage.objects for select to public using(bucket_id='product-images');
create policy "product images admin insert" on storage.objects for insert to authenticated with check(bucket_id='product-images' and public.can_manage_catalog());
create policy "product images admin update" on storage.objects for update to authenticated using(bucket_id='product-images' and public.can_manage_catalog()) with check(bucket_id='product-images' and public.can_manage_catalog());
create policy "product images admin delete" on storage.objects for delete to authenticated using(bucket_id='product-images' and public.can_manage_catalog());
