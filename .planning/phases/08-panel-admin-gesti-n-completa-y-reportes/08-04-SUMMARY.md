---
phase: 08-panel-admin-gesti-n-completa-y-reportes
plan: "04"
subsystem: panel-admin
tags: [menu-ui, clientes-ui, data-table-2, soft-delete-ui, admn-03, flutter-web]
requires:
  - "Plan 08-01 completo (7 endpoints staff menú/clientes — backend 169/169)"
  - "Plan 08-03 (AppShell sidebar + TopBar dinámico con títulos de los 7 paths; data_table_2 2.8.0 ya instalada)"
  - "mesasProvider patrón rid/queryRid + mesas_screen_test patrón de overrides (fake ApiClient + AuthState class-based)"
provides:
  - "Pantalla /configuracion: tabs Menú (CRUD completo) + Restaurante (read-only v1; 3er tab reservado 08-05)"
  - "MenuScreen: categorías ExpansionTile + productos con badges Agotado/Inactivo — staff ve TODO (sin filtro client-side)"
  - "CategoriaFormDialog + ProductoFormDialog (validaciones, imagen_url + preview Image.network errorBuilder, toggles semánticos)"
  - "Pantalla /clientes: DataTable2 (minWidth 600) + historial dialog (pedidos con chip de estado + items '2× Patacón')"
  - "Models: CategoriaStaff/ProductoStaff/ClienteResumen freezed + 7 métodos ApiClient (queryRid solo super_admin)"
  - "staffMenuProvider + clientesProvider + clienteHistorial family (rid null → [])"
affects:
  - "Plan 08-05: sidebar solo quedan /reservas y /reportes por activar; el tab 'Restaurantes' de Configuración (PLAT-05) se agrega al DefaultTabController length 2→3"
tech-stack:
  added: []  # cero deps nuevas — data_table_2 ya estaba (08-03)
  patterns:
    - "Refresh on-demand sin WS: pop + SnackBar + ref.invalidate(provider) tras cada mutación exitosa (menú/clientes no tienen eventos — decisión research 08)"
    - "Override CON CONTADOR para asertar invalidates en tests: provider.overrideWith((ref) { builds++; return Future.value(fixtures); })"
    - "Switches de creación vs edición: el POST de categorías/productos NO acepta activo/disponible (server default true) — los toggles solo aparecen en edición, evitando prometer al usuario algo que el wire no puede enviar"
    - "Limpiar campo opcional en PATCH: '' viaja (null-aware omitiría la clave y no limpiaría) — descripcion/imagen_url envían '' al vaciarse si tenían valor"
    - "late final en campos mutados por switches explota al 2º toggle (LateError) — late mutable"
key-files:
  created:
    - panel_admin/lib/models/categoria_staff.dart
    - panel_admin/lib/models/producto_staff.dart
    - panel_admin/lib/models/cliente_resumen.dart
    - panel_admin/lib/features/menu/menu_provider.dart
    - panel_admin/lib/features/menu/menu_screen.dart
    - panel_admin/lib/features/menu/categoria_form_dialog.dart
    - panel_admin/lib/features/menu/producto_form_dialog.dart
    - panel_admin/lib/features/configuracion/configuracion_screen.dart
    - panel_admin/lib/features/clientes/clientes_screen.dart
    - panel_admin/lib/features/clientes/historial_dialog.dart
    - panel_admin/test/menu/menu_screen_test.dart
    - panel_admin/test/clientes/clientes_screen_test.dart
  modified:
    - panel_admin/lib/core/api_client.dart
    - panel_admin/lib/features/clientes/clientes_provider.dart
    - panel_admin/lib/app.dart
    - panel_admin/lib/features/shared/app_shell.dart
    - panel_admin/lib/features/cocina/pedidos_staff_provider.g.dart
    - panel_admin/lib/features/dashboard/mesas_provider.g.dart
    - panel_admin/lib/features/dashboard/stats_provider.g.dart
decisions:
  - "Toggles Agotado/Activo SOLO en edición: los POST del backend no aceptan disponible/activo (contrato 08-01) — mostrarlos al crear prometería un wire imposible"
  - "Switch 'Activa' añadido a CategoriaFormDialog (edición) aunque el paso 4 del plan no lo listaba: MENU-01 exige 'desactivar categorías' y no había otra superficie de toggle (Rule 2)"
  - "'Nuevo producto' en trailing del ExpansionTile SOLO expandido (stateful por tile) — sin chevron cuando hay trailing, el tile completo sigue siendo tappable"
  - "Historial: 404 (existence hiding) y vacío → mismo mensaje 'Sin pedidos en este restaurante' (indistinguibles por diseño 08-01)"
  - "Tests del historial alimentan el family vía fake getClienteHistorial del ApiClient en vez de override de instancia del family — ejercita la cadena dialog→provider→client completa"
metrics:
  duration: "~12 min (2026-08-14 14:14→14:26 UTC)"
  tests: "39 → 46 (+4 menu_screen, +3 clientes_screen), analyze 0, build web OK"
  completed: 2026-08-14
---

# Phase 8 Plan 04: Panel menú CRUD + clientes Summary

**One-liner:** Feature completa `features/menu/` (CRUD de categorías y productos desde el tab Menú de /configuracion, con badges Agotado/Inactivo semánticamente separados, preview de imagen_url con errorBuilder y refresh por invalidate) + `features/clientes/` (DataTable2 con historial dialog por fila) — 3 models freezed, 7 métodos ApiClient, rutas /clientes y /configuracion activas, suite panel 39 → 46.

## Tasks Completed

| # | Task | Commit | Verificación |
|---|------|--------|--------------|
| 1 | Models freezed + 7 métodos ApiClient + providers staffMenu/clientes | `22b9aa9` | build_runner OK (sin --delete-conflicting-outputs); analyze 0; suite 39 sin regresiones |
| 2 | Menú UI — /configuracion (tabs Menú+Restaurante) + MenuScreen + forms + tests | `e36c109` | menu_screen_test 4/4; analyze 0; suite 43 |
| 3 | Clientes UI — DataTable2 + historial dialog + ruta /clientes + tests | `9395a65` | clientes_screen_test 3/3; suite 46; analyze 0; build web --release OK |
| — | Catch-up codegen .g.dart stale de 07-02 | `424d9ea` | git tree limpio; cero cambios de comportamiento |

## What Was Built

### Capa de datos (Task 1)
- **3 models freezed** espejo EXACTO de las shapes de 08-01: `ProductoStaff` (categoriaId, precio double, disponible≠activo), `CategoriaStaff` (productos anidados — staff ve TODO), `ClienteResumen` (usuarioId, numPedidos, totalGastado double, ultimoPedidoAt nullable).
- **ApiClient ×7**: getStaffMenu/createCategoria/updateCategoria/createProducto/updateProducto/getClientes/getClienteHistorial — todos con queryRid solo super_admin (patrón getMesas) y null-aware elements en los PATCH (solo campos modificados viajan).
- **staffMenuProvider + clientesProvider**: rid null (super_admin sin selección) → `[]` sin explotar; refresh on-demand (sin WS — decisión research).

### Menú UI (Task 2, MENU-01/02)
- **ConfiguracionScreen**: DefaultTabController length 2 — tab 'Menú' (MenuScreen embebido) + tab 'Restaurante' (ficha read-only con Cards nombre/tipo_cocina/dirección/descripción + badge Activo; comentario reservando el 3er tab para 08-05).
- **MenuScreen**: header + 'Nueva categoría'; categorías como Card+ExpansionTile — título con badge naranja 'Inactiva' (!activo) + count de productos, IconButton editar, 'Nuevo producto' visible SOLO expandido; filas de producto con nombre + descripción + formatCOP(precio) + badges 'Agotado' (ámbar, !disponible) e 'Inactivo' (gris, !activo) — semánticas DISTINTAS siempre etiquetadas.
- **CategoriaFormDialog**: nombre (1-100) + orden (int ≥ 0) + switch 'Activa' solo en edición; 409 dup → 'Ya existe una categoría con ese nombre'; éxito → pop + SnackBar + invalidate.
- **ProductoFormDialog**: nombre (1-150), descripción multiline opcional, precio double > 0 (validador + teclado numérico), imagen_url TextField + preview Image.network 120×80 con errorBuilder (broken_image si falla — SIN upload), switches 'Agotado' (!disponible) y 'Activo' (soft-delete) solo en edición; 422 → mensaje de precio; Guardar deshabilitado sin cambios.

### Clientes UI (Task 3, ADMN-03)
- **ClientesScreen**: DataTable2 columnSpacing 12 + minWidth 600 (scroll horizontal) — columnas Cliente (L, nombre bold + email gris), Pedidos (numérico), Total gastado (formatCOP), Último pedido (dd/MM/yyyy); DataRow2 onSelectChanged → historial; dentro de Expanded (bounds finitos, README data_table_2). Empty state 'Aún no hay clientes con pedidos'.
- **historial_dialog**: AlertDialog 520px — pedidos como Cards con 'Mesa N' + chip de estado (color del enum EstadoPedidoUI) + formatCOP(total) + fecha dd/MM/yyyy · HH:mm + items resumidos '2× Patacón'; error/vacío → 'Sin pedidos en este restaurante'.
- **clienteHistorial family** (patrón rid/queryRid) — 404 existence hiding relacional traducido al mismo mensaje del vacío.

### Infra
- app.dart: GoRoute `/clientes` y `/configuracion` dentro del ShellRoute. app_shell: `_routes[4] = '/clientes'`, `_routes[6] = '/configuracion'` (TopBar ya tenía los títulos desde 08-03).

### Tests (39 → 46)
- `menu_screen_test` (4): (a) 2 categorías + expandida muestra productos con formatCOP y badge 'Agotado' solo en el agotado + 'Nuevo producto' solo expandido; (b) crear 'Bebidas' → espía `createCategoria('Bebidas', 0, null)` + SnackBar + invalidate observable (override CON contador: builds 1 → 2); (c) toggle 'Agotado' ON → espía `updateProducto(5, disponible: false)` con SOLO ese campo en el wire; (d) badge 'Inactiva' en categoría fixture !activo.
- `clientes_screen_test` (3): (a) tabla renderiza nombres/emails/conteos/formatCOP/fechas; (b) tap fila Ana → dialog 'Historial de Ana' con 'Mesa 2', 'Pagado', '$ 59.500', '2× Patacón' + Cerrar hace pop; (c) empty state.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] `late final` en switches del ProductoFormDialog explotaba al 2º toggle**
- **Found during:** Task 2 (test (c): LateError 'Field _agotado has already been initialized' al tocar el SwitchListTile)
- **Issue:** `_agotado`/`_activo` declarados `late final` pero reasignados por onChanged.
- **Fix:** `late` mutable con comentario del gotcha.
- **Files:** producto_form_dialog.dart
- **Commit:** e36c109

**2. [Rule 2 - Funcionalidad faltante] Switch 'Activa' añadido a CategoriaFormDialog**
- **Found during:** Task 2 (implementación)
- **Issue:** El paso 4 del plan solo listaba nombre+orden, pero MENU-01 exige "desactivar categorías" y no existía otra superficie de toggle — el badge 'Inactiva' no permitía cambiar el estado.
- **Fix:** SwitchListTile 'Activa' (solo edición — el POST no acepta activo) viajando en updateCategoria solo si cambió.
- **Files:** categoria_form_dialog.dart
- **Commit:** e36c109

**3. [Lint] use_null_aware_elements en _InfoCard + unused_import en clientes_screen**
- **Fix inline:** `?trailing` en vez de `if (trailing != null) trailing!`; import de cliente_resumen.dart eliminado (tipo inferido).
- **Commits:** e36c109, 9395a65

**4. [Nota - Codegen catch-up] .g.dart stale de 3 providers WS de 07-02**
- **Issue:** pedidos_staff/mesas/stats .g.dart estaban commiteados con la docstring vieja (era polling) mientras sus fuentes ya tenían el contenido WS — mi build_runner los regeneró.
- **Fix:** Commit chore separado (424d9ea) para no mezclar codegen ajeno con features.
- **Files:** 3 .g.dart — cero cambios de comportamiento.

**5. [Micro-decisión] Tests del historial alimentan el family vía fake getClienteHistorial**
- El plan sugería "family provider override"; el fake del ApiClient en `clientes_screen_test` ejercita la cadena completa dialog→clienteHistorialProvider(9)→client (verificado con 'Mesa 2' real del fixture).

## Auth Gates

None — no se requirió intervención humana de autenticación.

## Verification Results

| Check | Resultado |
|-------|-----------|
| `dart run build_runner build` (sin --delete-conflicting-outputs) | OK ×2 (Task 1 y Task 3 — family) |
| `flutter analyze` | **0 issues** (4 runs durante la ejecución) |
| `flutter test` (workdir panel_admin) | **46 passed** (39 previos + 7 nuevos), sin regresiones dashboard/cocina/mesas/ws |
| `flutter build web --release` | **OK** (27.8s, tree-shaking icons OK) |
| Rutas | /clientes (sidebar índice 4) y /configuracion (índice 6) navegan; TopBar dinámico muestra sus títulos |
| Regresiones | Ninguna — suite completa ×2 verde |

## Requirements Covered

- **MENU-01 (UI)** — CRUD de categorías desde Configuración → Menú: crear/editar (nombre/orden), desactivar (switch 'Activa'), 409 amigable, refresh inmediato por invalidate.
- **MENU-02 (UI)** — CRUD de productos: precio validado > 0 client y server (422), descripción, imagen_url con preview errorBuilder, toggles 'Agotado' (!disponible) y 'Activo' (soft-delete) diferenciados con badges y switches etiquetados.
- **ADMN-03 (UI)** — DataTable2 de clientes (nombre, pedidos, total gastado, último pedido) + historial de pedidos por fila (tenant-scoped, 404→mensaje amigable).

## Manual UAT (para verificación humana)

1. Login `admin@demo.gri.dev` (Demo!1234) → sidebar **Configuración** → TopBar 'Configuración / Menú y administración' → tab **Menú**.
2. **Nueva categoría** → 'Bebidas' → Guardar → SnackBar + aparece en la lista (invalidate).
3. Expandir 'Bebidas' → **Nuevo producto** → nombre 'Limonada', precio 8000 → Guardar → aparece con '$ 8.000'.
4. Tap el producto → pegar URL inválida en 'URL de imagen' → preview muestra broken_image sin crash; toggle **Agotado** → Guardar → badge ámbar 'Agotado' en la fila.
5. Editar la categoría → apagar **Activa** → badge naranja 'Inactiva' en el título; verificar en la app cliente que desaparece de /public.
6. Sidebar **Clientes** → tabla con clientes demo (Ana tiene pedidos) → tap fila → historial con Mesa N, chip de estado, total e items '2× Patacón'.

## Notes for Next Plans

- **08-05:** solo quedan /reservas y /reportes por activar en `_routes` (índices 3 y 5); el tab 'Restaurantes' (PLAT-05) se agrega a ConfiguracionScreen (length 2→3 + comentario ya reservado).
- Patrón de override con contador para asertar invalidates (menu_screen_test) reutilizable en 08-05 para reportes con filtros.
- DataTable2 standalone funciona en tests con viewport 800×1800 dpr 1.0 sin configuración extra (loggea 'DataTable2 built: Xms' — inofensivo).
- El pattern de switches solo-en-edición aplica a cualquier CRUD futuro cuyo POST no acepte los flags (p.ej. restaurantes PLAT-05 si el create no tuviera 'activo').

## Self-Check: PASSED

- Archivos verificados en disco: menu_screen.dart (254 líneas ≥ min 60), clientes_screen.dart (143 ≥ min 50), menu_screen_test.dart (261 ≥ min 50), categoria_staff.dart, cliente_resumen.dart, producto_staff.dart — FOUND.
- 4/4 commits verificados en `git log`: 22b9aa9, e36c109, 9395a65, 424d9ea — FOUND.
