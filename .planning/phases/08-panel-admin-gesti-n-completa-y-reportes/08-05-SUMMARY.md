---
phase: 08-panel-admin-gesti-n-completa-y-reportes
plan: "05"
subsystem: panel-admin
tags: [reportes-ui, reservas-ui, marcar-ocupada, platform-toggle-ui, sidebar-7-7, data-table-2, repo-01, repo-02, plat-05, flutter-web]
requires:
  - "Plan 08-04 completo (panel 46/46, AppShell con _routes nullable, ConfiguracionScreen 2 tabs)"
  - "Endpoints 08-02: GET /staff/reportes/ventas, GET /staff/reportes/top-platos, PATCH /admin/restaurantes/{id}, GET /admin/restaurantes?incluir_inactivos"
  - "Endpoints F5 existentes: GET /staff/reservas?fecha, POST /staff/mesas/{id}/estado (setMesaEstado del ApiClient desde 08-03)"
  - "RestaurantesListProvider/token_provider (authState.isSuperAdmin) + patrón rid/queryRid"
provides:
  - "Pantalla /reportes: rango opcional (default server últimos 7 días), cards Total vendido/Pedidos, DataTable2 por día, top 10 platos numerado"
  - "Pantalla /reservas: selector de fecha + Hoy, cards con chips de estado, 'Marcar ocupada' en confirmadas (409 → SnackBar + refresh)"
  - "Configuración 3er tab 'Restaurantes' (solo super_admin): lista incluir_inactivos con switches activo (PLAT-05)"
  - "Sidebar 7/7 ítems navegables — flujo 'Próximamente' eliminado (grep negativo)"
  - "Models: VentaDia/VentasReporte/TopPlato + Reserva freezed; ApiClient ×4 métodos + listRestaurantes(incluirInactivos)"
affects:
  - "Cierre de la fase 08 — el panel queda operativo de punta a punta (gate para /gsd-verify-work)"
  - "Un dev-UX futuro: reemplazar la tabla por día por fl_chart (prohibido en esta fase por decisión de plan)"
tech-stack:
  added: []  # cero deps nuevas — data_table_2/intl ya estaban
  patterns:
    - "Estado LOCAL en screens de consultas one-shot (reportes): queries por rango no son datos vivos — sin provider intermedio (desviación menor del research documentada en el plan)"
    - "Validador estático visibleForTesting + debugSetFechas: alternativa del plan al manejo frágil de showDatePicker en widget tests"
    - "Bounds finitos computados para DataTable2 en contexto scrollable: SizedBox(48 + 48×filas + 8) con headingRowHeight/dataRowHeight explícitos (data_table_2 2.8.0 NO tiene shrinkWrap)"
    - "Tab condicional length 2/3: computar isSuperAdmin ANTES del DefaultTabController — el tab no existe para staff ni en el TabBar (defense in depth + test de ausencia)"
    - "Chips de estado con paleta de mesas del theme (confirmada=disponible verde, cancelada=ocupada rojo TACHADA, pendiente=reservada ámbar)"
key-files:
  created:
    - panel_admin/lib/models/reporte.dart
    - panel_admin/lib/models/reserva.dart
    - panel_admin/lib/features/reportes/reportes_screen.dart
    - panel_admin/lib/features/reservas/reservas_provider.dart
    - panel_admin/lib/features/reservas/reservas_screen.dart
    - panel_admin/lib/features/configuracion/restaurantes_admin_provider.dart
    - panel_admin/test/reportes/reportes_screen_test.dart
    - panel_admin/test/reservas/reservas_screen_test.dart
    - panel_admin/test/configuracion/restaurantes_test.dart
  modified:
    - panel_admin/lib/core/api_client.dart
    - panel_admin/lib/features/configuracion/configuracion_screen.dart
    - panel_admin/lib/app.dart
    - panel_admin/lib/features/shared/app_shell.dart
decisions:
  - "Reportes SIN provider: estado local del screen para queries one-shot por rango (decisión del plan — desviación menor del research que proponía reportes_provider.dart)"
  - "Sin rango NO viajan params: el server aplica su default DB-side (semana móvil); la respuesta SIEMPRE trae el rango efectivo que la UI muestra en el título de la tabla"
  - "Header de columna 'Nº pedidos' en vez de 'Pedidos': el label del card resumen y el header colisionaban en find.text de los tests (y era ambiguo para usuarios)"
  - "debugSetFechas @visibleForTesting en vez de manejar pickers en tests: el plan habilita explícitamente la vía de 'validador testeable'; ejercita el _consultar REAL (SnackBar + no-llamada)"
  - "Test del tab Restaurantes navega el TabBarView con tap (lazy): el TabBar renderiza los 3 labels, pero el contenido (switches) solo se construye al activar el tab"
  - "restaurantesAdmin con guard StateError como restaurantesListProvider (defense in depth): staff jamás lo construye — verificado por test (c)"
metrics:
  duration: "~19 min (2026-08-14 14:28→14:47 UTC)"
  tests: "46 → 61 (+7 reportes, +5 reservas, +3 restaurantes), analyze 0, build web OK"
  completed: 2026-08-14
---

# Phase 8 Plan 05: Panel reportes + reservas + super-admin restaurantes Summary

**One-liner:** Cierre del panel operativo 7/7: /reportes (rango opcional con default server de 7 días, cards + DataTable2 por día + top 10 platos con formato COP), /reservas (selector de fecha + 'Marcar ocupada' en confirmadas con manejo de 409) y tab 'Restaurantes' del super-admin (switches activo con incluir_inactivos, PLAT-05) — 2 models freezed, 4 métodos ApiClient, suite panel 46 → 61.

## Tasks Completed

| # | Task | Commit | Verificación |
|---|------|--------|--------------|
| 1 | Models + 4 métodos ApiClient + providers + rutas + sidebar 7/7 | `7ee91f0` | build_runner OK (sin --delete-conflicting-outputs); analyze 0; suite 46 sin regresiones; grep 'Próximamente' = 0 |
| 2 | Reportes screen (rango + cards + por día + top 10) + tests | `be12281` | reportes_screen_test 7/7 (a-f + validador unit); analyze 0 |
| 3 | Reservas marcar-ocupada + tab Restaurantes super-admin + tests | `98bc2ab` | reservas 5/5 + restaurantes 3/3; suite 61/61; analyze 0; build web --release OK (26.4s) |

## What Was Built

### Capa de datos (Task 1)
- **2 models freezed** espejo de las shapes 08-02/F5: `VentaDia/VentasReporte/TopPlato` (money double, num_pedidos/por_dia con JsonKey) y `Reserva` (joins display restauranteNombre/mesaNumero, sin restaurante_id/created_at — solo lo que la UI pinta).
- **ApiClient ×4 + extensión**: `getReporteVentas/getTopPlatos` (desde/hasta/limit solo no-null viajan — sin rango el server aplica su default), `getReservas` (fecha + restauranteId), `patchRestauranteActivo` (PATCH {activo}), `listRestaurantes({incluirInactivos})` retrocompatible (query solo cuando true).
- **Providers**: `reservasDelDia` family por fecha YYYY-MM-DD (patrón rid/queryRid; rid null → []) y `restaurantesAdmin` (guard super_admin + incluir_inactivos: true, watch authState).
- **Sidebar 7/7**: `_routes` definitivo `['/', '/mesas', '/cocina', '/reservas', '/clientes', '/reportes', '/configuracion']` — `_showProximamente`, `onProximamente` y el flujo placeholder ELIMINADOS; GoRoutes /reservas y /reportes en el ShellRoute.

### Reportes (Task 2, REPO-01/02)
- Consultas one-shot con **estado local** (decisión del plan): 'Consultar' dispara `getReporteVentas + getTopPlatos` en paralelo (`Future.wait`) con queryRid derivado como en cocina.
- **Rango**: pickers Desde/Hasta con label dd/MM/yyyy o hints 'Inicio'/'Fin'; 'Limpiar' vuelve al default. Sin rango NO viajan params (el título de la tabla muestra el rango efectivo que respondió el server).
- **Validación client-side** `validarRango` (estático, unit-testeado): desde > hasta → SnackBar SIN llamada API; el 422 del server (`detail` string de `_rango_reportes`) también se pinta.
- **Resultados**: cards 'Total vendido' (formatCOP) + 'Pedidos'; DataTable2 minWidth 500 (Fecha | Nº pedidos | Total) en SizedBox de alto computado `48 + 48×filas + 8` (data_table_2 2.8.0 no tiene shrinkWrap — bounds finitos garantizados); 'Platos más vendidos' numerado 1..N con CircleAvatar, '×cantidad' y formatCOP; vacío → 'Sin ventas en el rango'.

### Reservas (Task 3, RESV-05 UI)
- Header '📅 dd/MM/yyyy' (showDatePicker → invalidate del family por la fecha-key) + botón 'Hoy'.
- Cards por reserva: hora HH:MM (substring del HH:MM:SS), 'Mesa N', 'N personas', chip de estado (confirmada verde / cancelada rojo **tachada** / pendiente ámbar — paleta de mesas del theme).
- **'Marcar ocupada' SOLO en confirmadas** → `setMesaEstado(mesaId, 'ocupada', restauranteId: queryRid)` → SnackBar 'Mesa N marcada ocupada' + invalidate; **409** (carrera: la mesa cambió por otra vía) → 'La mesa ya cambió de estado' + refresh; vacío → 'Sin reservas para este día'.

### Super-admin Restaurantes (Task 3, PLAT-05)
- ConfiguracionScreen → **3 tabs para super_admin / 2 para staff** (length computado antes del DefaultTabController): tab 'Restaurantes' con lista `?incluir_inactivos=true` — Card por restaurante (nombre + Activo/Inactivo coloreado) y **Switch** activo.
- Toggle → `patchRestauranteActivo(id, v)` → SnackBar semántico (desactivar: 'Restaurante desactivado — desaparece de la app de clientes'; reactivar: 'Restaurante reactivado') + invalidate; DioException → SnackBar del detail. El alcance v1 (staff sigue operando; el restaurante seleccionado NO se desmonta) documentado en el docstring.

### Tests (46 → 61)
- `reportes_screen_test` (7): validador unit (invertido/parcial/null) + (a) espías reciben params null sin tocar pickers (default server); (b) cards COP + filas de 2 días (descendant para no chocar con numerales de avatares); (c) top 1..3 con '×12' y orden por cantidad; (d) desde>hasta vía debugSetFechas → SnackBar Y espías vacíos; (e) vacío; (f) 422 → SnackBar con detail.
- `reservas_screen_test` (5): (a) 2 reservas con chips y cancelada tachada + fetch con fecha de HOY; (b) botón solo en confirmada; (c) espía wire exacto `(2, 'ocupada')` + SnackBar; (d) 409 → 'La mesa ya cambió de estado' + re-fetch; (e) vacío.
- `restaurantes_test` (3): (a) super_admin ve 3 tabs, 2 restaurantes, switch OFF en el inactivo + espía incluir_inactivos=[true]; (b) toggle → espía `patchRestauranteActivo(2, true)` + 'Restaurante reactivado'; (c) staff: find.text('Restaurantes') findsNothing + provider jamás construido.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Bloqueo] app.dart importaba pantallas que se crean en Tasks 2/3**
- **Found during:** Task 1 (rutas agregadas antes que las screens)
- **Issue:** El plan pone las GoRoutes en Task 1 pero ReportesScreen/ReservasScreen recién existen en Tasks 2/3 — el commit de Task 1 no compilaría.
- **Fix:** Esqueletos mínimos (Center Text) commiteados en Task 1 y reemplazados íntegramente en su task — cada commit queda verde y navegable.
- **Files:** panel_admin/lib/features/reportes/reportes_screen.dart, panel_admin/lib/features/reservas/reservas_screen.dart
- **Commit:** 7ee91f0

**2. [Lint] Tres issues de compilación/analyze en los primeros runs de tests**
- unnecessary_import de foundation.dart (visibleForTesting ya viene de material); parámetros no-nulables con default null implícito en 2 fakes; validarRango referenciado como ReportesScreen.* (vive en el State).
- **Fix inline** en el mismo task; analyze 0 antes de cada commit.
- **Commits:** be12281, 98bc2ab

**3. [Nota — Fuera de alcance] Sanity backend 165/181: residuo de datos demo + .env invisible desde backend/**
- **Found during:** verification (pytest sanity del plan)
- **Issue:** (1) `Settings` lee `.env` del CWD → desde `backend/` sin `$env:DB_PASSWORD` da Access denied (103 fallos); (2) con la conexión OK, 16 tests fallan por datos ACUMULADOS post-08-02 en el demo (7 mesas extra de UAT manual, pedidos/categorías que rompen asserts de conteo). Cero archivos backend tocados por este plan (`git status backend/` limpio).
- **Acción:** documentado en `deferred-items.md` con sugerencias (purge demo, .env del project root, re-seed determinista). NO tocado (SCOPE BOUNDARY).
- **Commit:** 98bc2ab

## Auth Gates

None — no se requirió intervención humana de autenticación.

## Verification Results

| Check | Resultado |
|-------|-----------|
| `dart run build_runner build` (sin --delete-conflicting-outputs) | OK — reporte/reserva freezed+json, providers .g.dart |
| `flutter analyze` | **0 issues** (5 runs durante la ejecución) |
| `flutter test` (workdir panel_admin) | **61 passed** (46 previos + 15 nuevos), sin regresiones dashboard/cocina/mesas/ws/menu/clientes |
| `flutter build web --release` | **OK** (26.4s, tree-shaking icons OK — phase gate) |
| Grep 'Próximamente' en panel_admin | **0 referencias** (lib + test) |
| Sidebar | 7/7 ítems navegan a pantallas reales (_routes sin nulls) |
| `uv run pytest -q` (backend, sanity) | 165/181 — 16 fallos por residuo de datos demo pre-existente (deferred-items.md; este plan no toca backend) |

## Requirements Covered

- **REPO-01 (UI)** — Reporte de ventas por día/rango con total y número de pedidos; default últimos 7 días del server; validación client-side + 422 manejados.
- **REPO-02 (UI)** — Top 10 platos más vendidos por cantidad, numerado, con montos exactos formatCOP.
- **PLAT-05 (UI)** — Tab Restaurantes (solo super_admin) con inactivos visibles y switch desactivar/reactivar; staff no ve el tab (test de ausencia).

## Manual UAT (para verificación humana)

1. Login `admin@demo.gri.dev` (Demo!1234) → sidebar **Reportes** → 'Consultar' sin tocar nada → cards + tabla de los últimos 7 días (título muestra el rango efectivo) + top 10.
2. Fijar Desde > Hasta → SnackBar sin consulta; fijar 2020 → 'Sin ventas en el rango'.
3. Sidebar **Reservas** → reservas del día con chips; en una confirmada → 'Marcar ocupada' → SnackBar + la mesa pasa a ocupada en el mapa (WS).
4. (Opcional 409) Abrir la misma mesa en el mapa y cambiarla manualmente, luego 'Marcar ocupada' en la reserva → 'La mesa ya cambió de estado'.
5. Login super_admin → **Configuración → Restaurantes** → desactivar un restaurante NO seleccionado → 'Restaurante desactivado — desaparece de la app de clientes' → verificar en /public (app cliente) que ya no lista; reactivar → vuelve.
6. Verificar los 7 ítems del sidebar navegan a pantallas reales (ningún placeholder).

## Notes for Next Plans

- La fase 08 queda completa (5/5 planes) — sigue el gate de fase: `/gsd-verify-work` con el UAT de arriba.
- Si F9 (pagos) necesita reportes con venta=pagado únicamente, la constante `_VENTAS_ESTADOS` del backend es el punto único de cambio (decisión locked 08-02).
- El pattern de alto computado para DataTable2 en scrollables (48+48×N+8) es reutilizable; data_table_2 2.8.0 NO tiene shrinkWrap.
- Backend sanity: resolver el deferred-item del residuo demo antes de correr pytest como gate de fase (o ejecutar el purge sugerido).

## Self-Check: PASSED

- Archivos verificados en disco: reportes_screen.dart (410 ≥ min 60), reservas_screen.dart (257 ≥ min 50), models/reporte.dart (56), configuracion_screen.dart (314, 3er tab) — FOUND.
- 3/3 commits verificados en `git log`: 7ee91f0, be12281, 98bc2ab — FOUND.
