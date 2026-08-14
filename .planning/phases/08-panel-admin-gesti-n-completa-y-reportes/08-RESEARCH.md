# Phase 8: Panel Admin — Gestión Completa y Reportes - Research

**Researched:** 2026-08-14
**Domain:** CRUD staff endpoints (FastAPI/SQLAlchemy async) + pantallas de gestión Flutter Web (Riverpod 3 + go_router) + agregaciones SQL para reportes + QR rendering
**Confidence:** HIGH (todo el backend/panel se apoya en patrones ya probados en F2-F7 del propio codebase; versiones pub.dev verificadas hoy)

## Summary

La Fase 8 es predominantemente **repetición de patrones existentes a nueva escala**: los 6 endpoints de escritura nuevos (mesas CRUD, menú CRUD, PLAT-05) copian el contrato probado de `/staff` (`_resolve_rid` + existence hiding + `require_roles`), los reportes son 2 queries de agregación sobre tablas ya indexadas (`ix_pedido_restaurante_estado`, `ix_pedido_item_restaurante_producto`), y el panel activa 5 rutas ya reservadas en `app.dart` (comentario literal "Phase 8: /mesas, /reservas, /clientes, /reportes, /configuracion"). **Casi nada del backend de esta fase es verde**: `GET /staff/reservas`, `POST /staff/mesas/{id}/estado`, `GET /staff/mesas` y todo el stack WS (mesa.estado kick-to-refetch) ya existen y están testeados (suite 155).

Los tres puntos de diseño que el plan debe cerrar: **(1)** generación de `codigo_qr` para mesas nuevas — el código es `String(32)` UNIQUE GLOBAL; recomendamos esquema determinista `GRI-MESA-R{rid}-{numero:03d}` que es collision-free POR CONSTRAINT (la unique compuesta `(restaurant_id, numero)` lo garantiza — sin loops de retry ni secuencias); **(2)** "desactivar" categorías/productos NO tiene columna hoy — requiere **migración 0005** adding `activo` boolean a `categoria` y `producto` (soft-delete; `disponible` queda como el toggle "agotado" transitorio, semántica distinta) + filtro `activo=true` en `public_service`; **(3)** definición de "venta" para REPO-01 — decision: `estado IN (servido, pagado)` (servido cubre v1; pagado entra solo en F9, el filtro ya lo incluye y no hay que tocarlo).

**Primary recommendation:** Un plan backend (endpoints + migración 0005 + tests) seguido de un plan panel (5 features + sidebar + QR dialog), reutilizando `mesa.estado` como evento de invalidación post-commit para creates/edits de mesa (los listeners del panel ya refrescan la lista completa por tipo de evento — kick gratis, cero tipos nuevos).

<phase_requirements>

## Phase Requirements

| ID | Description | Research Support |
|----|-------------|-----------------|
| PLAT-05 | Super-admin ve lista de restaurantes y los desactiva | `GET /admin/restaurantes` existe (solo activos — el propio `admin_service.list_restaurantes` tiene comentario "managing inactive ones is Phase 8"); NUEVO `PATCH /admin/restaurantes/{id}` body `{activo: bool}` + param `?incluir_inactivos=true`. Desactivar ya oculta el restaurante de `/public` (filtro `activo` existente) |
| MENU-01 | CRUD categorías del menú | Migración 0005 (`categoria.activo`); `POST/PATCH /staff/categorias` con 409 por `uq_categoria_restaurante_nombre` (constraint ya existe en el modelo) |
| MENU-02 | CRUD productos (precio, descripción, imagen, agotado) | `POST/PATCH /staff/productos`; toggle agotado = PATCH `disponible`; imagen = `imagen_url` opcional STRING (sin upload en v1); precio Decimal→float con `@field_serializer` (patrón Pitfall 3 ya implementado en `schemas/menu.py`) |
| MESA-01 | Crear/editar mesas (número, capacidad) | `POST /staff/mesas` + `PATCH /staff/mesas/{id}`; `codigo_qr` derivado determinista (ver Patterns); 409 por `uq_mesa_restaurante_numero` |
| MESA-03 | Ver/imprimir QR de una mesa | `qr_flutter 4.1.0` (verificado pub.dev hoy — publisher verificado, web OK): `QrImageView(data: mesa.codigo_qr)` en dialog + botón imprimir vía `package:web` `window.print()` (web 1.1.1, oficial dart.dev) |
| ADMN-03 | Gestión de clientes (lista e historial) | `GET /staff/clientes` (JOIN pedido→usuario, GROUP BY usuario, count+SUM(total)) + `GET /staff/clientes/{id}/historial` (pedidos del usuario EN el tenant); usuario es tabla global → "cliente del restaurante" = usuario con pedidos ahí |
| ADMN-04 | Cambiar estado de mesa desde el mapa | `POST /staff/mesas/{id}/estado` YA EXISTE (F5, 409 inválidas); solo UI: popup/bottom-sheet en `MesaTile` con transiciones válidas derivadas de un mirror client-side de `MESA_TRANSITIONS` |
| REPO-01 | Ventas por día/rango (total, num pedidos) | `GET /staff/reportes/ventas?desde&hasta`: `func.date(created_at)` GROUP BY; venta = `estado IN (servido, pagado)`; usa índice existente |
| REPO-02 | Platos más vendidos | `GET /staff/reportes/top-platos`: `pedido_item` JOIN `pedido` (rango) GROUP BY `producto_id`, `SUM(cantidad)` DESC LIMIT 10; `restaurant_id` denormalizado en `pedido_item` (índice compuesto existente) |

</phase_requirements>

## Standard Stack

### Core — NUEVAS dependencias del panel (backend NO agrega nada)

| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| **qr_flutter** | ^4.1.0 | RENDER del QR de cada mesa (MESA-03) | Verificado pub.dev hoy: publisher verificado theyakka.com, 2.34k likes, 1.66M desc/sem, soporta Web. Widget `QrImageView(data:, version: QrVersions.auto, size:)`. Es la librería del STACK.md para GENERAR (mobile_scanner es para escanear) |
| **data_table_2** | ^2.8.0 | Tablas sticky-header para Clientes y Ventas por día | Verificado pub.dev hoy: 2.8.0 publicado hace 24h (mantenimiento activo), 981 likes, solo depende de `async`+`flutter` (cero riesgo de conflicto). API = drop-in de `DataTable` (`DataTable2`/`DataColumn2`). Recomendado por STACK.md para el admin |
| **web** (package:web) | ^1.1.1 | `window.print()` en el QR dialog (web-only) | Oficial dart.dev (9M desc/sem). Reemplazo de `dart:html`. 3 líneas: `import 'package:web/web.dart' as web; web.window.print()` |

### Explicitmente EXCLUIDAS de v1 (decisiones prescriptivas)

| Library | Decision | Reason |
|---------|----------|--------|
| **fl_chart** (1.2.0, verificado) | NO en v1 | REPO-01/02 piden totales y ranking — cards + tabla + lista los satisfacen 100%. Un gráfico suma complejidad de widget-tests sin requisito. Dejar como polish post-v1 si se desea |
| **cached_network_image** | NO en el panel v1 | El panel muestra thumbnails del menú en edición: `Image.network` + `errorBuilder` (icono placeholder) basta y evita una dependencia. La app cliente (donde las imágenes sí son centrales) es otra pubspec/decisión |
| **Upload de imágenes** | NO en v1 | `imagen_url` es STRING opcional (el admin pega una URL). python-multipart/UploadFile queda para post-v1. Documentar en el form: "URL de imagen (opcional)" |

**Installation (panel_admin/):**
```bash
flutter pub add qr_flutter:^4.1.0 data_table_2:^2.8.0 web:^1.1.1
```

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| data_table_2 | DataTable nativo | DataTable nativo no tiene sticky headers ni `minWidth` scroll horizontal; con 5 columnas de clientes en pantallas chicas se rompe. data_table_2 es drop-in — mismo esfuerzo |
| package:web window.print() | Solo instrucción "Ctrl+P" | El botón imprimir es mejor UX y 3 líneas; si en implementación hay fricción, el fallback (texto "usa Ctrl+P") es aceptable — no bloquear |
| Dialog con QR | Generar PDF (pdf/printing pkgs) | NO — pdf+printing en web agrega complejidad real (js interop, fonts). El dialog con QR grande es imprimible tal cual por el browser |

## Architecture Patterns

### Inventario de endpoints: existentes vs nuevos

**YA EXISTEN (consumir, NO re-crear):** `GET /staff/mesas`, `GET /staff/stats`, `GET /staff/pedidos?activos=true`, `POST /staff/pedidos/{id}/estado`, `GET /staff/reservas?fecha=`, `POST /staff/mesas/{id}/estado` (todo con tests), `GET /admin/restaurantes`, `GET /admin/restaurantes/{id}`, WS `/ws/staff` con eventos `pedido.*`, `mesa.estado`, `sesion.*`.

**NUEVOS backend (11 endpoints + 1 migración):**

| Endpoint | Body/Query | Respuesta | Errores |
|----------|-----------|-----------|---------|
| `POST /staff/mesas` | `{numero>0, capacidad>0}` (+`?restaurante_id=` super_admin) | 201 `MesaRead` | 409 dup (rid,numero), 400 super_admin sin param |
| `PATCH /staff/mesas/{id}` | `{numero?, capacidad?}` | `MesaRead` | 404 existence hiding, 409 dup |
| `GET /staff/menu` | — | `list[CategoriaStaff]` nested (INCLUYE agotados+inactivos con flags) | 400/403 contrato usual |
| `POST /staff/categorias` | `{nombre, orden?}` | 201 | 409 dup nombre |
| `PATCH /staff/categorias/{id}` | `{nombre?, orden?, activo?}` | `CategoriaStaff` | 404 |
| `POST /staff/productos` | `{categoria_id, nombre, descripcion?, precio>0, imagen_url?}` | 201 | 404 categoria ajena/inexistente, 422 precio |
| `PATCH /staff/productos/{id}` | `{nombre?, descripcion?, precio?, imagen_url?, disponible?, activo?}` | `ProductoStaff` | 404 |
| `GET /staff/clientes` | — | `list[ClienteResumen{usuario_id,nombre,email,num_pedidos,total_gastado,ultimo_pedido_at}]` | — |
| `GET /staff/clientes/{usuario_id}/historial` | — | `list[PedidoStaffRead]` (reusar schema F6) | 404 si el usuario no tiene pedidos en el tenant |
| `GET /staff/reportes/ventas` | `?desde&hasta` (date, default últimos 7 días DB-side) | `{desde,hasta,total,num_pedidos,por_dia:[{fecha,total,num_pedidos}]}` | 422 desde>hasta |
| `GET /staff/reportes/top-platos` | `?desde&hasta&limit=10` | `list[{producto_id,nombre,cantidad,total}]` | 422 |
| `PATCH /admin/restaurantes/{id}` | `{activo: bool}` | `RestauranteRead` | 404, 403 no-super_admin |
| `GET /admin/restaurantes` | `?incluir_inactivos=true` (nuevo param) | incluye inactivos | — |

**Migración 0005** (la ÚNICA del phase): `categoria.activo Boolean NOT NULL server_default true` + `producto.activo` idéntico. Luego `public_service.get_public_restaurante_detalle` filtra `Categoria.activo.is_(True)` / `Producto.activo.is_(True)` (los inactivos desaparecen del menú cliente sin borrar historia — `pedido_item` FK sigue válida).

### Matriz de roles (writes nuevos)

| Endpoint | Roles | Mecanismo |
|----------|-------|-----------|
| POST/PATCH mesas, categorías, productos | `admin_restaurante` + `super_admin` | `Depends(require_roles(RolUsuario.admin_restaurante, RolUsuario.super_admin))` — `require_roles(*allowed)` ya existe en deps/auth.py:79 |
| GET /staff/menu, clientes, reportes; PATCH /admin/restaurantes | staff (any) / super_admin-only respectivamente | `get_tenant_scope` / `require_roles(super_admin)` como hoy |

Los reads quedan abiertos a todo staff (un mesero ver el menú/clientes es correcto); los writes de configuración son del admin. Precedente: F6 ya restringe transiciones por rol.

### Pattern 1: codigo_qr determinista (MESA-01)

**What:** el QR NO se elige — se DERIVA. `codigo_qr = f"GRI-MESA-R{rid}-{numero:03d}"`.
**Why:** `codigo_qr` es UNIQUE GLOBAL (`uq_mesa_codigo_qr`) pero la unique compuesta `(restaurant_id, numero)` ya impide que dos mesas del mismo restaurante compartan numero → el esquema derivado es collision-free por construcción (rid distinto ⇒ prefijo distinto). Sin secuencias, sin SELECT MAX, sin retry loops. Formato consistente con el seed (`GRI-MESA-001..008` del demo queda como está — convive sin colisión porque el demo es rid=1 y el formato nuevo lleva `R1-`).
**On PATCH numero:** regenerar el codigo_qr en el mismo UPDATE (documentar en la UI: cambiar el numero invalida el QR impreso anterior — warning en el form).
**Length check:** `GRI-MESA-R` = 10 chars + rid (≤8 dígitos) + `-` + numero (≥3 dígitos) ≈ 22 chars máx realista — cabe en `String(32)`. Validar longitud igualmente en el schema.

```python
def _codigo_qr(rid: int, numero: int) -> str:
    return f"GRI-MESA-R{rid}-{numero:03d}"
```

### Pattern 2: contrato /staff replicate (todos los endpoints nuevos)

Copiar exactamente el esqueleto probado de F4/F5:

```python
rid = await _resolve_rid(session, scope, restaurante_id)   # 400 super_admin sin param / 404 inactivo
# existence hiding: mesa/categoria/producto ajena == inexistente → 404 (NUNCA 403)
obj = await session.get(Model, obj_id)
if obj is None or obj.restaurant_id != rid:
    raise HTTPException(404, "..." )
# pre-check unique legible → 409 (patrón create_staff email; la DB constraint es red de seguridad)
# commit → refresh → (mesa create/patch only) emit_event post-commit
```

### Pattern 3: invalidación en vivo reutilizando `mesa.estado`

Las pantallas de gestión NO necesitan tipos de evento nuevos. Dos vías ya resueltas:
- **Mapa del dashboard** (mesas nuevas/editadas aparecen en vivo): emitir `mesa.estado` post-commit también en `create_mesa`/`update_mesa` (data `{mesa_id, estado}` — el payload es mínimo por diseño kick-to-refetch; el listener del panel filtra por `type` y re-GETea la lista completa, así que un create aparece solo). Cero cambios en el panel.
- **Menu/clientes/reportes**: sin WS — refresh local tras cada mutación exitosa (la respuesta del POST/PATCH dispara el refetch del provider) + carga al navegar. Son datos de baja frecuencia de cambio.

### Pattern 4: agregaciones de reportes (SQL, no Python)

```python
# REPO-01 — ventas por día (venta = servido|pagado)
_VENTAS = [EstadoPedido.servido, EstadoPedido.pagado]
stmt = (
    select(func.date(Pedido.created_at).label("fecha"),
           func.count().label("num"),
           func.sum(Pedido.total).label("total"))
    .where(Pedido.restaurant_id == rid,
           Pedido.estado.in_(_VENTAS),
           Pedido.created_at >= desde_dt,               # desde 00:00 inclusive
           Pedido.created_at < hasta_dt + timedelta(days=1))  # hasta inclusive
    .group_by("fecha").order_by("fecha")
)
# REPO-02 — top platos (restaurant_id denormalizado en pedido_item; join pedido por el rango)
stmt = (
    select(PedidoItem.producto_id, Producto.nombre,
           func.sum(PedidoItem.cantidad).label("cantidad"),
           func.sum(PedidoItem.subtotal).label("total"))
    .join(Pedido, Pedido.id == PedidoItem.pedido_id)
    .join(Producto, Producto.id == PedidoItem.producto_id)
    .where(PedidoItem.restaurant_id == rid,
           Pedido.estado.in_(_VENTAS),
           Pedido.created_at >= desde_dt, Pedido.created_at < hasta_dt_plus_1)
    .group_by(PedidoItem.producto_id, Producto.nombre)
    .order_by(func.sum(PedidoItem.cantidad).desc())
    .limit(10)
)
```

Notas: `SUM(total)` devuelve Decimal → serializar como float en el schema (mismo `field_serializer` que ProductoRead). Default del rango: `desde = curdate() - 6 días, hasta = curdate()` computado **DB-side** (`func.curdate()`), nunca `date.today()` Python (lección Pitfall 6 de F4/F5). `precio_unitario` snapshot ya garantiza exactitud histórica (locked decision del modelo pedido.py).

### Pattern 5: clientes = JOIN, no tabla global

```python
# GET /staff/clientes — usuarios con pedidos EN el tenant
select(Usuario.id, Usuario.nombre, Usuario.email,
       func.count(Pedido.id), func.sum(Pedido.total), func.max(Pedido.created_at)) \
  .join(Pedido, Pedido.usuario_id == Usuario.id) \
  .where(Pedido.restaurant_id == rid) \
  .group_by(Usuario.id).order_by(func.sum(Pedido.total).desc())
```

Historial reusa `PedidoStaffRead` (F6: items+total+usuario_nombre+mesa). Si el usuario no tiene pedidos en el tenant → 404 (no revelar que el usuario_id existe globalmente — existence hiding aplicado a la relación, no a la fila).

### Estructura del panel (features nuevas)

```
panel_admin/lib/
├── app.dart                        # +5 GoRoutes dentro del ShellRoute (comentario ya los reserva)
├── features/
│   ├── mesas/
│   │   ├── mesas_screen.dart       # grid gestión (reuse MesaTile visual) + FAB "Nueva mesa" + edit
│   │   ├── mesa_form_dialog.dart   # numero/capacidad + warning "cambiar numero regenera el QR"
│   │   ├── qr_dialog.dart          # QrImageView grande + codigo_qr texto + btn imprimir (package:web)
│   │   └── mesas_admin_provider.dart
│   ├── menu/
│   │   ├── menu_screen.dart        # categorías (ExpansionTile/reorder) + productos
│   │   ├── categoria_form_dialog.dart
│   │   ├── producto_form_dialog.dart  # precio/desc/URL imagen + Switch agotado
│   │   └── menu_provider.dart
│   ├── clientes/
│   │   ├── clientes_screen.dart    # DataTable2: nombre/email/pedidos/total/último
│   │   ├── historial_screen.dart   # (o dialog) pedidos del cliente
│   │   └── clientes_provider.dart
│   ├── reportes/
│   │   ├── reportes_screen.dart    # rango pickers + cards total/pedidos + DataTable2 por día + top 10
│   │   └── reportes_provider.dart
│   ├── reservas/
│   │   ├── reservas_screen.dart    # date picker + lista del día + btn "Marcar ocupada"
│   │   └── reservas_provider.dart
│   └── configuracion/
│       ├── restaurantes_screen.dart # super-admin: lista + switch activo (PLAT-05); staff: msg "solo super-admin"
│       └── restaurantes_admin_provider.dart
└── models/                          # +categoria.dart, producto.dart, cliente_resumen.dart, reportes.dart (freezed)
```

Sidebar (`app_shell.dart`): llenar `_routes` — `['/', '/mesas', '/cocina', '/reservas', '/clientes', '/reportes', '/configuracion']` (orden de `_items` actual: Dashboard, Mesas, Pedidos, Reservas, Clientes, Reportes, Configuración). **Refactor menor necesario:** `_TopBar` tiene el título `'Dashboard'` hardcodeado — derivarlo de `location` (map path→título+subtítulo) al agregar 5 rutas.

ADMN-04 en el mapa: `MesaTile` hoy es no-interactivo (comentario en el archivo: "onTap real llega en Phase 8"). Añadir onTap → bottom sheet con las transiciones válidas según estado (mirror client-side de `MESA_TRANSITIONS`):

```dart
const kMesaTransitions = <String, Set<String>>{
  'disponible': {'reservada', 'ocupada'},
  'reservada': {'ocupada', 'disponible'},
  'ocupada': {'limpieza'},
  'limpieza': {'disponible'},
};
// La UI ofrece SOLO las válidas; el 409 del server sigue siendo la autoridad
// (cubre la carrera entre dos staff tocando a la vez — mostrar SnackBar y refrescar).
```

Labels de negocio para las acciones: ocupada→limpieza = "Marcar en limpieza", limpieza→disponible = "Liberar", disponible/reservada→ocupada = "Marcar ocupada".

### Anti-Patterns to Avoid

- **No crear `/admin/menu` o endpoints paralelos**: el menú/mesas/clientes son del tenant → viven en `/staff` con `_resolve_rid` (el router docstring de staff.py ya establece la separación /staff=operación vs /admin=plataforma).
- **No hacer soft-delete con la columna `disponible`**: agotado (temporal, vuelve solo) ≠ desactivado (fuera del menú). Semánticas distintas, columnas distintas (`disponible` existe; `activo` llega en 0005).
- **No filtrar reportes por `estado == pagado`**: en v1 casi ningún pedido llega a pagado (F9) — los reportes saldrían vacíos. `servido|pagado` es la definición.
- **No mutar estado local del mapa en el panel ante el propio POST**: el POST devuelve `MesaRead` pero el refresh autoritativo es el evento `mesa.estado` que el backend YA emite post-commit (evita dobles renders y drift).

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Render QR desde texto | Custom painter / API externa | `qr_flutter` `QrImageView` | QR tiene Reed-Solomon, máscaras, versiones 1-40 — hand-roll es bug garantizado |
| Imprimir en web | JS custom / screenshot | `package:web` `window.print()` | El browser ya tiene el pipeline de impresión |
| Sticky data tables | SingleChildScrollView + Table | `data_table_2` | Fixed headers, `minWidth` horizontal scroll, `DataRow2` onTap — gratis |
| Sesión/tenant en endpoints nuevos | Filtros manuales con query param | `_resolve_rid` + `get_tenant_scope` | Ya probado con tests de acceso cruzado; el param crudo NUNCA filtra para staff |
| Validación de transiciones de mesa | `if estado == ...` inline | `MESA_TRANSITIONS` via `validar_transicion` | Única fuente de verdad (decision locked F3/F5) |
| Formato COP en reportes | `'$' + total.toString()` | `core/format.dart` (ya existe en el panel) | Consistencia con dashboard/cocina |

**Key insight:** el riesgo de esta fase NO es tecnología nueva — es **consistencia de contrato** (status codes, super_admin param, existence hiding) con las 12 rutas /staff existentes. Cada endpoint nuevo debe pasar el mismo test de aislamiento que las viejas.

## Common Pitfalls

### Pitfall 1: Decimal → JSON string rompe el cliente Dart
**What:** asyncmy devuelve `Decimal` de `Numeric(10,2)`; Pydantic v2 lo serializa como STRING en JSON y `double.parse` del Dart explota.
**How to avoid:** en TODO schema nuevo con dinero (`total_gastado`, `total` de reportes, `precio` writes): declarar `float` + `@field_serializer` coercion — copiar literal de `schemas/menu.py:ProductoRead._coerce_precio`.
**Warning signs:** test de panel con `FormatException` al parsear reportes.

### Pitfall 2: identity map stale en tests (lección 05-02, YA ocurrió)
**What:** tras el commit del API, un assert que lee el objeto por `session.get()` puede leer el valor del identity map de la sesión de TEST, no el de la BD.
**How to avoid:** en tests de CRUD nuevo, `db_session.expire_all()` antes de todo verify-read post-commit; los fixtures de mesa restauran SIEMPRE a un estado determinista (auto-reparación de residuo).
**Warning signs:** el API responde 200 correcto pero el assert falla "aleatoriamente" en el segundo run.

### Pitfall 3: "hoy"/rangos calculados Python-side
**What:** el TZ del contenedor Python puede divergir de America/Bogota (TZ de MySQL) → un pedido de las 23:50 cae en el día equivocado del reporte.
**How to avoid:** defaults con `func.curdate()` DB-side; el rango desde/hasta se convierte a `datetime` BOUNDARIES inclusive (`desde 00:00:00` hasta `hasta+1d 00:00:00` exclusive) en el service.
**Warning signs:** ventas del día con 24h de desfase.

### Pitfall 4: emitir WS pre-commit
**What:** evento emitido antes del commit → listeners refetchean y no ven el cambio (o ven el anterior).
**How to avoid:** `emit_event` SIEMPRE después de `commit()+refresh()` (patrón locked F7 — revisar diff en code review).

### Pitfall 5: super_admin sin `?restaurante_id=` debe ser 400 — en TODOS los endpoints nuevos
**What:** olvidar el param handling en un endpoint nuevo rompe el contrato uniforme (400 sin param / 200 con / 404 inválido) que todos los tests de super_admin repiten.
**How to avoid:** `_resolve_rid` primera línea de cada service function nueva; test parametrizado del contrato por endpoint.

### Pitfall 6: PATCH numero de mesa invalida QR impresos silenciosamente
**What:** regenerar `codigo_qr` al cambiar numero deja obsoleto el cartel impreso en la mesa física.
**How to avoid:** es la decisión correcta igualmente (numero y QR deben corresponder), pero el FORM debe advertirlo ("Este cambio regenera el código QR de la mesa") y el SUMMARY documentarlo.

### Pitfall 7: race en unique (rid, numero) entre check y INSERT
**What:** el pre-check SELECT+409 tiene una ventana de carrera con otro admin creando la misma mesa.
**How to avoid:** el pre-check da el 409 amigable; envolver el commit con `except IntegrityError → 409` como red de seguridad (la constraint `uq_mesa_restaurante_numero` ya existe — es la autoridad). Mismo tratamiento para `uq_categoria_restaurante_nombre`.

### Pitfall 8: restaurante desactivado — definir el alcance EXACTO
**What:** "desactivar" puede significar solo ocultar de /public o también bloquear staff.
**Decision v1 (documentar en plan/SUMMARY):** desactivar = desaparece de `/public/*` (ya funciona por el filtro `activo` existente) y del listado activo del super-admin; el staff con token vigente SIGUE operando (no se bloquea login/operaciones en v1). `_resolve_rid` del super_admin ya 404-ea restaurantes inactivos — comportamiento existente, no tocar. PLAT-05 no pide más.

## Code Examples

### QR dialog (MESA-03) — el patrón completo

```dart
// Source: qr_flutter 4.1.0 docs (pub.dev/packages/qr_flutter) + package:web 1.1.1
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:web/web.dart' as web;

Future<void> showQrDialog(BuildContext context, Mesa mesa) {
  return showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: Text('Mesa ${mesa.numero} — QR'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          QrImageView(
            data: mesa.codigoQr,
            version: QrVersions.auto,
            size: 280,
            gapless: false,
            backgroundColor: Colors.white, // contraste para escáner/impresión
          ),
          const SizedBox(height: 12),
          SelectableText(mesa.codigoQr), // fallback: el staff puede tipearlo
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => web.window.print(), // imprime la página con el dialog abierto
          child: const Text('Imprimir'),
        ),
      ],
    ),
  );
}
```

### DataTable2 para clientes (ADMN-03)

```dart
// Source: data_table_2 2.8.0 README (pub.dev/packages/data_table_2)
DataTable2(
  columnSpacing: 12,
  minWidth: 600, // scroll horizontal si el viewport es más angosto
  columns: const [
    DataColumn2(label: Text('Cliente'), size: ColumnSize.L),
    DataColumn(label: Text('Pedidos'), numeric: true),
    DataColumn(label: Text('Total gastado'), numeric: true),
    DataColumn(label: Text('Último pedido')),
  ],
  rows: [
    for (final c in clientes)
      DataRow2(
        onSelectChanged: (_) => abrirHistorial(context, c), // onTap fila → historial
        cells: [
          DataCell(Text('${c.nombre}\n${c.email}')),
          DataCell(Text('${c.numPedidos}')),
          DataCell(Text(formatCop(c.totalGastado))),
          DataCell(Text(formatFecha(c.ultimoPedido))),
        ],
      ),
  ],
)
// OJO (README data_table_2): NUNCA poner DataTable2 dentro de SingleChildScrollView/
// Column sin Expanded — necesita bounds finitos.
```

### Servicio staff: create_mesa (combo de todos los patterns)

```python
# backend/app/services/staff_service.py (extensión)
async def create_mesa(session, scope, body: MesaCreate, restaurante_id) -> Mesa:
    rid = await _resolve_rid(session, scope, restaurante_id)
    dup = await session.execute(
        select(func.count()).select_from(Mesa)
        .where(Mesa.restaurant_id == rid, Mesa.numero == body.numero))
    if dup.scalar_one():
        raise HTTPException(409, f"La mesa {body.numero} ya existe")
    mesa = Mesa(
        restaurant_id=rid, numero=body.numero, capacidad=body.capacidad,
        codigo_qr=_codigo_qr(rid, body.numero),  # determinista — Pattern 1
        estado=EstadoMesa.disponible,
    )
    session.add(mesa)
    try:
        await session.commit()
    except IntegrityError as exc:  # red de seguridad de la carrera
        await session.rollback()
        raise HTTPException(409, "La mesa ya existe") from exc
    await session.refresh(mesa)
    # kick gratis: el listener del panel (type=='mesa.estado') re-GETea la lista
    await emit_event("mesa.estado", restaurante_id=rid, usuario_id=None,
                     data={"mesa_id": mesa.id, "estado": mesa.estado.value})
    return mesa
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| `dart:html` para browser APIs | `package:web` (JS interop, WASM-ready) | Dart 3.3+ / Flutter 3.19+ | Usar `package:web` para `window.print()`; `dart:html` está en freeze |
| Polling 10s del dashboard (F4) | WS kick-to-refetch + safety net 60s (F7-02) | F7 | Las screens nuevas NUNCA agregan polling propio — heredan WS o refrescan on-demand |
| DataTable nativo | data_table_2 drop-in | — (siempre disponible) | Sticky headers + minWidth gratis |

**Deprecated/outdated a evitar:** `qr_code_scanner` (deprecated desde 2023 — irrelevante aquí, solo no confundir); Provider para estado (usar Riverpod 3 como todo el panel).

## Open Questions

1. **¿Restaurante desactivado bloquea al staff?**
   - What we know: PLAT-05 solo pide "ver lista y desactivar"; `/public` ya oculta inactivos.
   - Recommendation (cerrada para el plan): v1 NO bloquea staff — solo ocultamiento público + listado. Documentar como decisión en el SUMMARY; bloqueo operacional sería PLT2 si algún día se pide.
2. **¿Clientes incluyen huéspedes de reservas sin pedidos?**
   - Recommendation: v1 = solo pedidos (JOIN pedido). Un cliente que solo reservó no aparece — documentar. Ampliar a OR reservas es un cambio de query pequeño post-v1 si el usuario lo pide en UAT.
3. **¿Top platos con nombre snapshot o nombre actual?**
   - `pedido_item` NO tiene snapshot de nombre (solo precio). El JOIN a `producto` da el nombre ACTUAL — si el admin renombra un plato, el reporte histórico muestra el nombre nuevo. Aceptable v1 (el precio sí es exacto por snapshot); documentar.
4. **Orden de `categorias` al crearse sin `orden`** — default 0 (server_default existente); la UI muestra el orden del listado (`ORDER BY orden, id` como public_service). Si el admin necesita reordenar, el PATCH de `orden` lo cubre manualmente — sin drag&drop en v1.

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Backend | pytest + pytest-asyncio (uv), suite actual **155 passed** — corre contra stack Docker VIVO (`docker compose up -d --build api` + `$env:DB_PASSWORD=<MYSQL_APP_PASSWORD>`) |
| Panel | flutter_test, suite actual **28 tests** |
| Config | `backend/pyproject.toml` (pytest) / `panel_admin/pubspec.yaml` |
| Quick run backend | `uv run pytest tests/test_staff_menu.py -q` (workdir backend) |
| Quick run panel | `flutter test test/menu/menu_screen_test.dart` (workdir panel_admin) |
| Full suite | `uv run pytest -q` / `flutter test` |

### Phase Requirements → Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| MESA-01 | POST/PATCH mesas: 201+QR autogen determinista, 409 dup numero, 404 cross-tenant, 400 super_admin sin param, PATCH regenera QR | integration (HTTP vs stack vivo) | `uv run pytest tests/test_staff_mesas_crud.py -q` | ❌ Wave 0 |
| MESA-03 | QR dialog renderiza `QrImageView` con el `codigo_qr` correcto + botón imprimir | widget | `flutter test test/mesas/qr_dialog_test.dart` | ❌ Wave 0 |
| MENU-01 | CRUD categorías: 201/200, 409 nombre dup, toggle activo, cross-tenant 404 | integration | `uv run pytest tests/test_staff_menu.py -q` | ❌ Wave 0 |
| MENU-02 | CRUD productos: 422 precio<=0, 404 categoría ajena, toggle disponible, public filtra activos tras 0005 | integration | `uv run pytest tests/test_staff_menu.py -q` | ❌ Wave 0 |
| ADMN-03 | Clientes: solo los del tenant (JOIN), count/total correctos con fixture, historial 404 usuario sin pedidos en tenant | integration | `uv run pytest tests/test_staff_clientes.py -q` | ❌ Wave 0 |
| ADMN-04 | UI del mapa ofrece SOLO transiciones válidas por estado; POST inválido (race) → SnackBar + refresh | widget + integration existente (`test_mesa_estado.py` ya cubre el 409) | `flutter test test/dashboard/mesa_actions_test.dart` | ❌ Wave 0 |
| REPO-01 | Ventas: fixture pedidos servidos/rechazados → solo servidos cuentan; agrrupación por día correcta; rango inclusive; 422 desde>hasta | integration | `uv run pytest tests/test_staff_reportes.py -q` | ❌ Wave 0 |
| REPO-02 | Top platos: SUM(cantidad) DESC, top 10, pedidos de otros tenants excluidos | integration | `uv run pytest tests/test_staff_reportes.py -q` | ❌ Wave 0 |
| PLAT-05 | PATCH desactiva: desaparece de /public, aparece con `incluir_inactivos`, staff de admin no puede (403), reactivar funciona | integration | `uv run pytest tests/test_admin_platform.py -q` (extender archivo existente) | ✅ (extender) |

Screens del panel (form validations, render con fixture, tabla clientes, rango reportes, reservas del día): widget tests bajo `test/{mesas,menu,clientes,reportes,reservas,configuracion}/` — `flutter test` por archivo (<30s c/u).

### Sampling Rate
- **Per task commit:** test file(s) del requisito del task + `flutter analyze` (panel) / `uv run ruff check` (backend)
- **Per wave merge:** `uv run pytest -q` (155+new) Y `flutter test` (28+new)
- **Phase gate:** ambas suites full verdes + `flutter build web` OK antes de `/gsd-verify-work`

### Wave 0 Gaps
- [ ] `backend/tests/test_staff_mesas_crud.py` — MESA-01 (copiar harness de `test_mesa_estado.py`: tokens staff/super_admin + `expire_all()` en verify-reads)
- [ ] `backend/tests/test_staff_menu.py` — MENU-01/02 (+ assert public filtra activos)
- [ ] `backend/tests/test_staff_clientes.py` — ADMN-03
- [ ] `backend/tests/test_staff_reportes.py` — REPO-01/02 (fixture: crear pedidos con items vía API F6 y transicionarlos a servido)
- [ ] `panel_admin/test/mesas/`, `test/menu/`, `test/clientes/`, `test/reportes/`, `test/reservas/`, `test/configuracion/`, `test/dashboard/mesa_actions_test.dart` — screens
- [ ] `flutter pub add qr_flutter data_table_2 web` + `dart run build_runner build --delete-conflicting-outputs` tras crear models freezed nuevos

## Sources

### Primary (HIGH confidence)
- **Codebase GRI (verificación directa hoy)**: `backend/app/api/staff.py` (12 endpoints, contrato documentado en docstrings), `backend/app/services/staff_service.py` (`_resolve_rid`, existence hiding, emit post-commit), `admin_service.py:42` ("managing inactive ones is Phase 8"), `schemas/menu.py` (field_serializer Decimal→float), `models/mesa.py` (uq globales/compuestas, String(32)), `models/pedido.py` (snapshot precio + denormalización restaurant_id en pedido_item), `core/state_machines.py` (MESA_TRANSITIONS), `seed_service.py` (formato GRI-MESA-{idx:03d})
- **Panel**: `app.dart` (rutas Phase 8 reservadas en comentario), `app_shell.dart` (`_routes` con nulls + TopBar hardcodeado), `mesas_provider.dart` (patrón kick-to-refetch completo), `api_client.dart` (patrón de métodos + query param super_admin), `pubspec.yaml` (riverpod 3.4/freezed 4.0.0-dev.3 pins)
- **pub.dev verificado hoy (2026-08-14)**: qr_flutter **4.1.0** (verified publisher, 2.34k likes, web ✓), data_table_2 **2.8.0** (publicado hace 24h, deps solo async+flutter), fl_chart 1.2.0 (evaluado y excluido v1), web **1.1.1** (dart.dev, 9.04M desc/sem)
- **Summaries F5-02 / F7-01**: contrato `/staff/reservas` + `POST mesas/{id}/estado` (existente); lección `expire_all()` identity map; contrato evento WS `{type, restaurante_id, seq, ts, data}` kick-to-refetch

### Secondary (MEDIUM confidence)
- Ninguno necesario — el dominio está íntegramente cubierto por codebase + pub.dev.

### Tertiary (LOW confidence)
- `window.print()` con dialog abierto imprime la página completa (no solo el dialog) — comportamiento browser estándar pero conviene confirmar en implementación; si el resultado es feo, fallback a texto "usa Ctrl+P" no bloquea MESA-03.

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — 3 paquetes verificados en pub.dev hoy con versiones exactas; backend sin deps nuevas
- Architecture (backend): HIGH — 100% replicación de patrones existentes con tests de referencia; migración 0005 es trivial (2 columnas)
- Architecture (panel): HIGH — rutas/provider/sidebar ya estructurados para esta fase (comentarios F4 reservan el espacio)
- Pitfalls: HIGH — 7 de 8 pitfalls ya ocurrieron y fueron resueltos en fases previas (documentados en SUMMARYs)

**Research date:** 2026-08-14
**Valid until:** 2026-09-14 (estable — solo pub.dev pins podrían moverse marginalmente)
