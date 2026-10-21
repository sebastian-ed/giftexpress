## Abrir GiftExpress en Windows (importante)

**No abras `index.html` con doble clic**: las rutas `/assets/...` y los módulos ES6 requieren un servidor HTTP; con `file://` se ve sin estilos ni imágenes y no carga el catálogo.

1. Extraé el ZIP completo.
2. Entrá en la carpeta `giftexpress`.
3. Ejecutá **`INICIAR-GIFTEXPRESS.bat`** (requiere Python 3 instalado en Windows).
4. Abrí **http://localhost:8765/** si no se abre automáticamente.
5. Dejá la ventana del servidor abierta. Admin: **http://localhost:8765/admin/**.

Alternativa: desplegá el directorio completo en Netlify y accedé a la URL HTTPS. `file://` no es un modo de ejecución soportado.

# GiftExpress

GiftExpress es un e-commerce mobile-first orientado a turistas alojados en hoteles, Airbnb y residencias temporarias. El repositorio incluye storefront, catálogo, producto, carrito persistente, checkout invitado, cálculo de entrega, seguimiento de pedidos, administración, Supabase, RLS, Storage y una integración server-side con Mercado Pago.

## 1. Qué incluye

- Home comercial orientada a conversión.
- Catálogo con búsqueda, categoría, disponibilidad y ordenamiento.
- Ficha de producto con galería, stock, cantidad y productos relacionados.
- Carrito persistente en `localStorage`.
- Checkout sin registro obligatorio.
- Datos de alojamiento: hotel, habitación, recepción, referencias y observaciones.
- Zonas de entrega con costo, mínimo, envío gratis, cutoff y próximos días válidos.
- Selector de idioma ES / EN / PT con fallback español.
- Selector visual de ARS / USD / EUR / BRL, separado de la moneda real de cobro.
- Tracking de pedido.
- Admin con autenticación, dashboard, productos, preview responsive, imágenes, inventario, pedidos, clientes, categorías, cupones, zonas y configuración.
- SQL: `schema.sql`, `rls.sql`, `seed.sql`.
- Supabase Storage para `product-images`.
- Edge Functions para crear pedidos, iniciar Checkout Pro y procesar webhooks.
- Datos demo y assets locales para poder evaluar la UI sin depender de imágenes externas.

## 2. Arquitectura

```text
/
├── index.html
├── catalogo.html
├── producto.html
├── carrito.html
├── checkout.html
├── pedido.html
├── 404.html
├── admin/
│   ├── index.html
│   ├── dashboard.html
│   ├── productos.html
│   ├── producto-editar.html
│   ├── pedidos.html
│   ├── pedido.html
│   ├── inventario.html
│   ├── clientes.html
│   ├── categorias.html
│   ├── cupones.html
│   ├── entregas.html
│   └── configuracion.html
├── assets/
│   ├── css/
│   ├── img/
│   ├── icons/
│   └── js/
└── supabase/
    ├── schema.sql
    ├── rls.sql
    ├── seed.sql
    ├── config.toml
    └── functions/
```

La aplicación evita un framework SPA pesado. Usa HTML5, CSS, Bootstrap 5 y JavaScript ES modules. Supabase concentra Auth, Postgres, Storage y Edge Functions.

## 3. Modo demo inmediato

El ZIP se entrega con `demoMode: true` en `assets/js/config.js`.

1. Serví la carpeta con HTTP. Ejemplo:
   ```bash
   python -m http.server 8080
   ```
2. Abrí `http://localhost:8080`.
3. Los datos demo viven en `localStorage`.
4. Admin demo:
   - Email: `admin@giftexpress.demo`
   - Contraseña: `demo1234`

El modo demo no simula una pasarela real. El botón de checkout crea un pedido local y abre su tracking.

## 4. Crear el proyecto Supabase

1. Creá un proyecto en Supabase.
2. Abrí SQL Editor.
3. Ejecutá, en orden:
   1. `supabase/schema.sql`
   2. `supabase/rls.sql`
   3. `supabase/seed.sql`
4. Verificá que exista el bucket público `product-images`.
5. Verificá que RLS esté habilitado en las tablas públicas.

La documentación oficial de Supabase recomienda proteger las tablas expuestas al Data API mediante RLS y usar Edge Functions para lógica server-side y secretos. Referencias:
- https://supabase.com/docs/guides/database/secure-data
- https://supabase.com/docs/guides/functions
- https://supabase.com/docs/guides/auth

## 5. Pasar el frontend a producción

Copiá `assets/js/config.example.js` sobre `assets/js/config.js` y completá:

```js
export const CONFIG = {
  demoMode: false,
  supabaseUrl: 'https://TU_PROYECTO.supabase.co',
  supabaseAnonKey: 'TU_CLAVE_PUBLICA',
  edgeBaseUrl: 'https://TU_PROYECTO.supabase.co/functions/v1',
  // ...
};
```

La URL del proyecto y la clave pública/publishable pueden estar en el browser si las tablas están protegidas con RLS. **Nunca** pongas `service_role` ni secretos de Mercado Pago en el frontend.

## 6. Authentication y primer administrador

1. En Supabase Authentication creá el usuario administrador con email y contraseña.
2. Buscá el UUID del usuario en Authentication > Users.
3. Asignale rol con SQL:

```sql
update public.profiles
set role_id = (select id from public.roles where slug='super_admin')
where id = 'UUID_DEL_USUARIO';
```

El admin usa `signInWithPassword`. Los permisos efectivos los controla RLS mediante `profiles` + `roles`.

## 7. Storage

El bucket `product-images` se crea desde `rls.sql`.

Ruta usada por el uploader:

```text
products/{product_id}/{uuid}.{ext}
```

Política:
- lectura pública;
- escritura, reemplazo y borrado solo para usuarios con permisos de catálogo.

No se almacena una imagen remota como dependencia crítica en los datos demo; el ZIP incluye placeholders locales reemplazables.

## 8. Mercado Pago: arquitectura actual

La integración incluida usa **Checkout Pro vía Orders API**, el flujo recomendado actualmente por Mercado Pago para integraciones nuevas:

```text
Browser
  ↓
Supabase Edge Function: create-mercadopago-checkout
  ↓
POST https://api.mercadopago.com/v1/orders
  ↓
checkout_url
  ↓
Mercado Pago
  ↓
Webhook firmado
  ↓
Supabase Edge Function: mercadopago-webhook
  ↓
orders + payments + order_status_history
```

Referencias oficiales:
- Crear order: https://www.mercadopago.com.ar/developers/es/reference/online-payments/checkout-pro/create-order/post
- Checkout Pro Orders: https://www.mercadopago.com.ar/developers/es/docs/checkout-pro-orders/overview
- Webhooks: https://www.mercadopago.com.ar/developers/es/docs/checkout-pro-orders/notifications

La implementación incluye `X-Idempotency-Key`. El webhook valida `x-signature` mediante HMAC-SHA256 antes de consultar la order en Mercado Pago. No se despacha un pedido por el simple hecho de que el navegador vuelva a la URL de éxito: el estado definitivo llega por webhook y se verifica server-side.

### Variables privadas

Configurá secretos en Supabase:

```bash
supabase secrets set \
  MERCADOPAGO_ACCESS_TOKEN="..." \
  MERCADOPAGO_WEBHOOK_SECRET="..." \
  SITE_URL="https://tudominio.com"
```

`SUPABASE_URL` y `SUPABASE_SERVICE_ROLE_KEY` están disponibles para funciones desplegadas en Supabase. Si tu entorno exige declararlas manualmente, cargalas como secretos; nunca las envíes al browser.

### Desplegar funciones

```bash
supabase functions deploy create-order --no-verify-jwt
supabase functions deploy create-mercadopago-checkout --no-verify-jwt
supabase functions deploy mercadopago-webhook --no-verify-jwt
supabase functions deploy validate-coupon --no-verify-jwt
supabase functions deploy get-order-status --no-verify-jwt
```

Las funciones de checkout, cupón y tracking son públicas porque el checkout admite invitado; el tracking usa códigos públicos aleatorios de alta entropía.  la seguridad no depende de confiar precios enviados por el cliente. `create-order` llama a una función SQL transaccional que vuelve a leer precios, stock, cupón y zona desde la base.

### Configurar Webhook en Mercado Pago

En la aplicación de Mercado Pago configurá la URL productiva de la Edge Function `mercadopago-webhook` y el tópico de Orders/Checkout Pro indicado por el panel. Copiá el Webhook Secret a `MERCADOPAGO_WEBHOOK_SECRET`.

## 9. Checkout y stock

`public.create_order_from_checkout(payload)` es una función SQL transaccional y atómica. Hace lo siguiente en una única transacción:

- valida carrito;
- bloquea filas de producto con `FOR UPDATE`;
- revalida precios y stock desde la base;
- valida zona y mínimo;
- valida cupón;
- calcula envío;
- calcula próxima fecha válida de entrega;
- guarda snapshot de cotizaciones;
- crea cliente y dirección;
- crea pedido e ítems;
- descuenta stock;
- registra movimientos de inventario;
- registra uso de cupón;
- agrega historial del pedido.

Por esto no se confía en totales calculados por JavaScript del navegador.

## 10. Monedas

- El precio base se almacena en ARS.
- `exchange_rates` guarda cotizaciones históricas.
- El pedido conserva `exchange_snapshot` para trazabilidad.
- `display_currency` y `charge_currency` son campos distintos.
- La integración Mercado Pago incluida cobra ARS.

Si el usuario visualiza USD/EUR/BRL, la UI debe informar que el cobro real se procesará en ARS. No se finge soporte de moneda que la pasarela no tenga configurado.

## 11. Zonas y entrega

`delivery_zones` define:

- barrios;
- CP;
- costo;
- envío gratis desde cierto importe;
- pedido mínimo;
- cutoff;
- ETA;
- días habilitados.

`delivery_blackouts` agrega feriados, días sin entrega y horarios excepcionales. El checkout calcula la fecha efectiva dentro de la transacción server-side usando `America/Argentina/Buenos_Aires`.

## 12. Administración

Rutas principales:

- `/admin/dashboard.html`
- `/admin/productos.html`
- `/admin/producto-editar.html`
- `/admin/pedidos.html`
- `/admin/inventario.html`
- `/admin/clientes.html`
- `/admin/categorias.html`
- `/admin/cupones.html`
- `/admin/entregas.html`
- `/admin/configuracion.html`

La edición de productos incluye preview Desktop / Tablet / Mobile antes de publicar. Las imágenes pueden subirse a Storage y reordenarse por drag & drop en la interfaz.

## 13. SEO

El sitio incorpora:

- títulos y descriptions base;
- URLs legibles por slug mediante query en la versión HTML estática;
- canonical base;
- `robots.txt`;
- `sitemap.xml`;
- `alt` de imágenes;
- estructura preparada para JSON-LD Product/Organization.

### Decisión importante sobre URLs

En un hosting puramente estático, `producto.html?slug=...` funciona sin configuración de servidor. Para conseguir exactamente `/producto/alfajores-havanna-chocolate`, configurá rewrites del hosting o pasá la capa pública a funciones/SSR. No se implementó un router artificial que rompa compatibilidad con hosting HTML tradicional.

## 14. Analítica

`assets/js/services/analytics.js` deja una capa de eventos sin activar proveedores externos. Se pueden conectar GA4, Meta Pixel y Google Ads usando la misma taxonomía:

- `view_item`
- `add_to_cart`
- `begin_checkout`
- `purchase_intent`
- `search`

No se incluyen IDs falsos.

## 15. Deploy recomendado

**Recomendación: Netlify o Cloudflare Pages para el frontend + Supabase para backend.**

Motivos:
- despliegue estático simple;
- CDN global;
- HTTPS automático;
- headers configurables;
- no obliga a meter secretos de pago en el hosting estático;
- Supabase Edge Functions mantienen el backend separado.

Vercel también funciona correctamente. Un hosting HTML tradicional funciona para el storefront siempre que sirva ES modules por HTTP/HTTPS; las Edge Functions continúan viviendo en Supabase.

## 16. QA antes de publicar

Customer:
- idioma y fallback;
- moneda visual;
- catálogo y búsqueda;
- ficha y galería;
- carrito persistente;
- checkout invitado;
- barrio/CP fuera de cobertura;
- mínimo de compra;
- cutoff y fecha siguiente;
- cupón;
- pago aprobado/rechazado/pendiente;
- webhook;
- tracking.

Admin:
- login;
- roles;
- alta/edición/ocultamiento de producto;
- imágenes;
- preview responsive;
- stock;
- pedido y cambio de estado;
- categorías;
- cupones;
- zonas;
- settings.

Responsive mínimo:
- 375 px;
- 390 px;
- 768 px;
- 1024 px;
- 1440 px.

## 17. Decisiones profesionales tomadas

1. **No se obliga a registrarse.** El turista puede comprar como invitado.
2. **No se guardan tarjetas.** Los datos sensibles quedan en el proveedor PCI-compliant.
3. **El webhook manda.** El redirect del browser no confirma el pago.
4. **Los precios del browser no son confiables.** El servidor recalcula todo.
5. **El stock se valida dentro de la transacción.** Esto reduce sobreventa y manipulación.
6. **No se usa `service_role` en cliente.** Los secretos viven en Edge Functions.
7. **La UI no se fuerza a parecer una SPA SaaS.** La dirección visual es retail/editorial, con producto protagonista.
8. **La URL amigable exacta requiere rewrites.** Se priorizó compatibilidad real con hosting estático antes que simular un router inexistente.

## 18. Mantenimiento

- Actualizá las dependencias CDN de Bootstrap/Supabase con control de regresión visual.
- Rotá credenciales privadas si sospechás exposición.
- Revisá regularmente las políticas RLS.
- Nunca desactives RLS para “hacer que funcione”.
- Probá Webhooks de Mercado Pago en ambiente de prueba antes de producción.
- Hacé backups de Postgres y de Storage según el plan contratado.
- Para una operación creciente, agregá email transaccional y WhatsApp desde Edge Functions, no desde el browser.

## Ampliación multiproveedor (versión nueva)

- Módulos de admin: **Proveedores**, **Rentabilidad**, **Importar catálogo** (CSV/XLSX) y **Combos**. Estos módulos funcionan en modo demo; en Supabase requieren aplicar `supabase/upgrade_multiproveedor.sql` sobre la base original. Los productos nuevos del importador se crean como borradores.
- Cinco fichas premium de ejemplo usan datos **ficticios**, no se presentan como mercadería verificada de Arandú. El proveedor Arandú es una ficha de referencia, sin precios, inventario ni fotos importados automáticamente.
- El cálculo de rentabilidad utiliza **margen bruto estimado sobre venta**, incluyendo costo y logística, y distingue el precio sugerido de un porcentaje sobre costo.
- La ficha de producto permite elegir variantes guardadas; los combos del administrador calculan la disponibilidad teórica según existencias de componentes.
- **Limitaciones de esta entrega:** la importación XLSX necesita cargar SheetJS desde CDN; el módulo de compras/reposiciones no cuenta todavía con flujo transaccional completo; el checkout productivo no reserva existencias de componentes de combos y la gestión visual de todas las opciones/variantes requiere un editor adicional. Las métricas avanzadas por proveedor necesitan atribución de costos históricos por renglón de pedido. No considerar lista para comercializar esos flujos sin pruebas e integración.
- **Punto de seguridad bloqueante de producción:** en el esquema original, la tabla `products` contiene costos privados y su política de lectura anónima permite leer filas publicadas. No publicar con costos reales hasta reemplazar ese acceso con una vista/RPC de catálogo seguro y quitar acceso SELECT directo a la tabla base. Esto requiere migración y prueba end-to-end de los consumidores públicos y administradores.
- La promesa de entrega hoy debe depender de inventario confirmado y rutas operativas. Los nuevos productos premium quedan en modo consulta y no tienen stock confirmado.


## GitHub Pages y rediseño editorial (v3)

Esta versión admite publicación dentro de una subcarpeta de GitHub Pages (`https://usuario.github.io/repo/`). El HTML utiliza rutas relativas y el navegador ajusta los enlaces y recursos generados dinámicamente. Para publicarla: GitHub → repositorio → Settings → Pages → Deploy from a branch → main / (root); subir **el contenido de la carpeta `giftexpress` al nivel raíz** del repositorio. Si mantenés la carpeta `giftexpress` dentro del repositorio, la URL de entrada será `https://usuario.github.io/repo/giftexpress/`.

**Ingreso demo:** `/admin/index.html` relativo a la ruta publicada. `admin@giftexpress.demo` / `demo1234`, solamente con `demoMode:true`. No utilizar como autenticación real: el modo demo funciona en el navegador y NO protege datos comerciales. Para producción configurar Supabase Auth, roles y RLS y cambiar `demoMode:false`. GitHub Pages no ejecuta backend ni Edge Functions: éstas se despliegan por separado en Supabase.

**Fotografías:** imágenes editoriales de referencia cargadas desde `images.unsplash.com`, no son fotografías del producto real ni imágenes de Arandú. Requieren conexión y deben sustituirse por fotografías oficiales propias o autorizadas antes de publicar productos para venta. Si no cargan, el sistema usa un placeholder local. No se copiaron ni redistribuyeron imágenes de Arandú o Manifesto sin permiso.

El frontend está rediseñado sobre principios editoriales de diseño retail: tipografía serif de títulos, grillas fotográficas 3:4, fondo neutro, espaciado generoso y CTA monocromáticos, con identidad propia.


## Dirección de arte editorial (actualización octubre 2026)

Se renovó la página de inicio de acuerdo con el brief de composición editorial: barra informativa, cabecera minimalista, hero fotográfico, colecciones de imagen, grilla de selección, manifiesto de marca, servicio y footer. Inspiración conceptual en Manifesto Design Store, sin copiar su marca, fotos ni layout exacto. Paleta: #FFFFFF, #F5F4F1, #222222, #707070, #D8D5CF. Tipografía base Inter con sistema de fallback. Breakpoints 650 y 1020 px.

**Fotografías:** se utilizan imágenes públicas referenciales de Unsplash por URL, sin empaquetar fotografías de marcas proveedoras y con fallback SVG local. Para producción, sustituir por fotografías licenciadas y preferentemente autohospedadas. La tienda necesita red de datos para descargar imágenes remotas. La actualización se concentró en la propuesta de inicio y el sistema CSS global, preservando las funciones existentes.


## Edición negra y vista local

La portada contiene 8 tarjetas estáticas de respaldo, visibles incluso cuando se abre `index.html` con doble clic (`file://`). Esta vista **no habilita ventas ni acceso al administrador**: los módulos JavaScript de compras, filtros y autenticación necesitan HTTP. Usar `INICIAR-GIFTEXPRESS.bat` o GitHub Pages.

Las imágenes vectoriales incluidas de productos de cuero/mate/bolsos son **ilustraciones de referencia**, NO fotografías originales de Arandú. Se consultaron nombres de productos de Arandú solo a efectos de referencia comercial. Los precios de proveedores son variables y no deben presentarse como precios de venta propios. Para publicar fotografías oficiales, obtener autorización escrita y cargarlas desde el panel, junto con stock y condiciones de entrega confirmados.

La primera tarjeta de referencia incluye una fotografía enlazada externamente desde el servidor de Arandú (no se distribuye en el ZIP). Su uso público/comercial requiere autorización del proveedor; puede no cargar por restricciones de terceros y existe una ilustración local alternativa.


## GiftExpress — Argentina en productos (edición editorial)

El diseño público utiliza base negro/grafito y una grilla editorial unificada en `index.html`, `catalogo.html`, `producto.html`, `carrito.html` y `checkout.html`. Para la navegación interactiva, usar un servidor HTTP o GitHub Pages.

**Fotografía:** la portada contiene imágenes externas de referencia y recursos locales de respaldo. Las imágenes que pertenecen a proveedores externos no están licenciadas para su redistribución o uso comercial por el mero hecho de figurar aquí. Solicitar autorización y subir fotografías aprobadas a `assets/img/products/` o Supabase Storage antes del lanzamiento. Algunos productos demo llevan fotografía representativa, no la ficha exacta del proveedor.

**Precios y stock:** todos los importes/cantidades de demostración requieren validación. No activar cobros reales basándose en disponibilidad del sitio de terceros. Los registros públicos históricos de demo guardados en `localStorage` pueden prevalecer sobre el catálogo actualizado: para ver nuevos datos, usar otro perfil de navegador o limpiar solo las claves `gx_demo_products` y `gx_demo_categories` (esto afecta datos demo locales).

**GitHub Pages:** publicar el contenido de esta carpeta en la raíz del repositorio; usar el enlace `/admin/index.html` relativo a la ruta del proyecto. Mercado Pago real, webhooks y operaciones seguras requieren Supabase Edge Functions correctamente configuradas; GitHub Pages solo sirve el frontend estático.
