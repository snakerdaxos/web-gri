---
phase: 10-migracion-a-firebase-opcion-b-apps-flutter-movil-y-panel-web
plan: "05"
subsystem: panel_admin
tags: [firebase, firestore, panel-admin, claims, dashboard, mapa-mesas, cocina, realtime, matriz-rol]
requires:
  - "10-01 (rules/indexes/seed — índice pedidos restauranteId+estado+createdAt, doc shapes)"
  - "10-02 (patrón firebase_bootstrap/providers/fakes verificado en app_cliente)"
  - "10-04 (app_cliente 100% Firebase — locked app primero; shapes pedidos/sesiones)"
provides:
  - "Bootstrap Firebase del panel (web-only options p-gri-b5b40) + gate USE_EMULATORS + firebaseAuthProvider/firestoreProvider/claimsProvider (idTokenResult forceRefresh)"
  - "Login por claims {role, rid}: staff → dashboard de SU restaurante, super_admin → selector, cliente/sin role → rechazo + signOut"
  - "ridActivoProvider: única fuente del rid para TODAS las queries staff (claims del staff / selección del super — nunca input libre)"
  - "mesasProvider: mapa EN VIVO where restauranteId==rid orderBy numero → snapshots() (MIGRA-05) + cambiarEstadoMesa SOLO {estado, updatedAt} tras validarTransicion"
  - "statsProvider: DashboardStats DERIVADA de 3 streams combineLatest (mesas/reservas-hoy TZ local/pedidos activos whereIn) — sin endpoint"
  - "pedidosStaffProvider: cola cocina where estado in [enviado, aceptado, en_preparacion] orderBy createdAt ASC → snapshots() + avanzarPedidoStaff (validarTransicion + matriz rol ANTES del update)"
  - "avisoCuentaProvider: sesiones activas con cuentaSolicitada → badge EN VIVO en cocina (sustituye WS)"
affects:
  - "panel_admin (auth/dashboard/mapa/cocina/restaurante activo migrados a Firestore; legacy mesas-CRUD/menú/clientes/reportes/reservas/config intactos sobre api_client hasta 10-06)"
tech-stack:
  added:
    - firebase_core 4.13.0, firebase_auth 6.5.7, cloud_firestore 6.8.0 (deps LOCKED del plan)
    - dev: fake_cloud_firestore 4.2.0, firebase_auth_mocks 0.15.2
  patterns:
    - "ridActivoProvider como único origen del where restauranteId (aislamiento tenant Pitfall 4 — super selecciona, staff hereda claims)"
    - "Matriz rol×transición client-side (matrizRolPedido) espejo de las rules — doble barrera: validarTransicion → matriz → update mínimo"
    - "combineLatest de 3 streams manual (StreamController sync:true, sin rxdart) para stats derivadas"
    - "Watches de ref ANTES del primer await en generators async* (lección 07-03, riverpod-3-safe)"
key-files:
  created:
    - panel_admin/lib/firebase_options.dart
    - panel_admin/lib/core/firebase_bootstrap.dart
    - panel_admin/lib/core/firebase_providers.dart
    - panel_admin/lib/core/state_machines.dart
    - panel_admin/lib/features/dashboard/restaurantes_list_provider.dart
    - panel_admin/test/state_machines_test.dart
    - panel_admin/test/helpers/firebase_fakes.dart
    - panel_admin/test/auth/login_form_test.dart
    - panel_admin/test/cocina/cola_test.dart
    - panel_admin/test/dashboard/mesa_actions_test.dart
    - panel_admin/test/dashboard/mesa_tile_color_test.dart
    - panel_admin/test/dashboard/stats_render_test.dart
  modified:
    - panel_admin/pubspec.yaml
    - panel_admin/lib/main.dart
    - panel_admin/lib/app.dart
    - panel_admin/lib/features/auth/login_controller.dart
    - panel_admin/lib/features/dashboard/restaurante_provider.dart
    - panel_admin/lib/features/dashboard/mesas_provider.dart
    - panel_admin/lib/features/dashboard/stats_provider.dart
    - panel_admin/lib/features/dashboard/dashboard_screen.dart
    - panel_admin/lib/features/cocina/cocina_screen.dart
    - panel_admin/lib/features/cocina/pedidos_staff_provider.dart
    - panel_admin/lib/features/mesas/mesa_actions_sheet.dart
    - panel_admin/lib/features/reservas/reservas_screen.dart
    - panel_admin/lib/core/api_client.dart
    - panel_admin/lib/core/format.dart
    - panel_admin/lib/models/mesa.dart
    - panel_admin/lib/models/pedido_staff.dart
  deleted:
    - panel_admin/test/mesas_ws_test.dart
    - panel_admin/test/pedidos_ws_test.dart
decisions:
  - "Providers de Task 3 consumen ridActivoProvider (no claims directo): soporta super_admin con selección de restaurante además del staff con claims — mismo override en tests (claimsProvider)"
  - "Firmas de los 3 providers idénticas a los stubs del RED: cero regeneración de .g.dart necesaria"
  - "combineLatest manual con StreamController sync:true (sin rxdart — dep nueva no justificada): la re-emisión entrega EN el evento del snapshot, paridad con yield* directo (un read posterior a la escritura ya ve el valor nuevo)"
  - "Reservas hoy sin filtro de estado (count de todas las del día — bloque interfaces del plan); ventana computada en TZ local truncada a día"
  - "api_client.setMesaEstado/updateMesa cambian mesaId a String (doc ID = código QR): compile-compat del CRUD legacy que aún vive hasta 10-06; el mapa operacional YA escribe directo a Firestore"
metrics:
  duration: "45m (reanudación final; Tasks 1-2 ejecutadas en sesión previa — c29c039/acc4f7c)"
  completed: "2026-08-16"
  tests: "82/82 (62 pasando + 20 migrados/alineados; ws tests retirados)"
  analyze: "0 issues"
---

# Phase 10 Plan 05: panel_admin — bootstrap + login claims + dashboard/mapa/cocina realtime Summary

**One-liner:** El panel web arranca sobre Firebase con login por claims `{role, rid}` (staff → su restaurante, super → selector, cliente → rechazo), dashboard con mapa de mesas y stats DERIVADAS de 3 streams combineLatest, y cocina con cola de pedidos EN VIVO + matriz rol×transición validada antes de cada update + aviso de cuenta por stream de sesiones — todo por onSnapshot nativo (WS/polling retirados de estas vistas), con el core legacy intacto hasta 10-06.

## What Was Built

### Task 1 — infra panel (c29c039)

- pubspec: firebase_core 4.13.0 / firebase_auth 6.5.7 / cloud_firestore 6.8.0 + dev fakes (deps LOCKED, sin quitar nada — purge en 10-06).
- `firebase_options.dart` SOLO web (projectId p-gri-b5b40, appId de grip.web); `firebase_bootstrap.dart` con el mismo gate `USE_EMULATORS` de app_cliente (auth 9099 / firestore 8080 antes de runApp); `main.dart` ensureInitialized + await bootstrap, dotenv vivo hasta 10-06.
- `core/firebase_providers.dart`: firebaseAuthProvider, firestoreProvider, authStateChangesProvider + claimsProvider (`idTokenResult(true)` — claims frescos al instante tras login).
- `state_machines.dart` port 1:1 + `test/helpers/firebase_fakes.dart` (seed demo/norte/sur para el selector del super).

### Task 2 — login por claims + routing (acc4f7c)

- `login_controller`: signInWithEmailAndPassword + `getIdTokenResult(true)`; `super_admin` → selector, staff → dashboard con rid de claims, cliente/sin role → 'Esta aplicación es solo para personal del restaurante' + signOut. Sin dio/api_client/token_provider.
- `app.dart` rewired al authState nuevo; `restaurante_provider`: restauranteActivoProvider (doc stream para TopBar) + seleccionRestauranteProvider (super) + ridActivoProvider; `restaurantes_list_provider` (solo super, `activo == true`).
- 4 casos de login verdes (staff/super/cliente-rechazado/credenciales inválidas).

### Task 3 — dashboard/mapa/stats/cocina realtime (2a534ed GREEN + 07b560a tests)

- `mesasProvider`: `where restauranteId == rid orderBy numero → snapshots()`; `cambiarEstadoMesa`: validarTransicion('mesa') → update SOLO `{estado, updatedAt}` (sheet ofrece solo destinos válidos por kMesaTransitions).
- `statsProvider`: DashboardStats derivada combinando mesas (count por estado) + reservas de hoy (ventana TZ local `>= inicioHoy < inicioMañana`) + pedidos activos (`whereIn [enviado, aceptado, en_preparacion]`) — combineLatest manual sin rxdart.
- `pedidosStaffProvider`: cola FIFO `orderBy createdAt ASC` (índice 10-01) — un `servido` desaparece del stream SOLO; `avanzarPedidoStaff`: validarTransicion → matrizRolPedido (`StateError('Tu rol no puede hacer esta acción')` si el rol no puede) → update mínimo; `avisoCuentaProvider`: sesiones `cuentaSolicitada == true && estado == 'activa'` → badge vivo en cocina (Flexible + ellipsis).
- Models `Mesa`/`PedidoStaff` con `fromDoc` (id = QR/autoId, items snapshot, total int COP, mesaNumero derivado del QR).

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Task 3 quedó en RED: los 3 providers eran stubs `UnimplementedError`**
- **Found during:** Reanudación (suite 62+20)
- **Issue:** El executor original murió tras escribir los tests TDD; mesas/stats/pedidos_staff eran stubs y 16 tests fallaban (pumpAndSettle timeouts + UnimplementedError)
- **Fix:** GREEN completo con las queries del bloque interfaces, consumiendo ridActivoProvider; firmas idénticas a los stubs (sin regeneración de .g.dart)
- **Files:** mesas_provider.dart, stats_provider.dart, pedidos_staff_provider.dart
- **Commit:** 2a534ed

**2. [Rule 1 - Bug] RenderFlex overflow del header de cocina con el badge de cuenta**
- **Issue:** Row título + badge desbordaba 88px con el aviso visible en viewport angosto
- **Fix:** `Flexible` en el badge del header + `Flexible`+`TextOverflow.ellipsis` en el Text interno del badge
- **Files:** cocina_screen.dart · **Commit:** 2a534ed

**3. [Rule 1 - Bug] Tests legacy de reservas esperaban el wire viejo (mesaId int)**
- **Issue:** `setMesaEstado` pasó mesaId a String (doc ID = QR); los espías registran `('2', 'ocupada')` y los tests asertaban `(2, 'ocupada')` — imposible tras el cambio de superficie
- **Fix:** Expectations alineadas al wire nuevo (misma fuerza: mesaId 2 → '2' + estado)
- **Files:** test/reservas/reservas_screen_test.dart · **Commit:** 07b560a

**4. [Rule 1 - Bug] Test stats 'derivadas' se contradecía con su propio setup**
- **Issue:** Comentaba "4ª mesa ocupada (001-003 disponibles)" pero hacía update de la 001 → disponibles 2 ≠ 3 esperado
- **Fix:** Doc nuevo mesas/GRI-MESA-demo-004 ocupada (3+1=4 mesas, como define el caso)
- **Files:** test/dashboard/stats_render_test.dart · **Commit:** 07b560a

**5. [Rule 1 - Bug] Test tenant-filter asertaba widgets que nunca renderizaba**
- **Issue:** El test renderiza `Text('Mesa N')` pero asertaba `find.byType(MesaTile) findsNWidgets(3)` — siempre 0
- **Fix:** Conteo de filas por regex `^Mesa \d+$` = 3 (la Mesa 1 del norte no debe duplicar la fila — mismo aislamiento, aserción posible)
- **Files:** test/dashboard/mesa_tile_color_test.dart · **Commit:** 07b560a

**6. [Rule 1 - Flake] Reservas "hoy" con `now() + 2h` cruzaba medianoche**
- **Issue:** Corriendo de noche, la reserva +2h caía en "mañana" → reservasHoy 1 ≠ 2
- **Fix:** Horas fijas 12:00/14:00 de hoy (misma aserción: 2 dentro de hoy, 1 ayer)
- **Files:** test/dashboard/stats_render_test.dart · **Commit:** 07b560a

**7. [Rule 3 - Blocking] Stats stale tras escritura con combineLatest no-sync**
- **Issue:** El StreamController async entregaba la re-emisión en microtask posterior al `read(future)` del test → valor viejo
- **Fix:** `sync: true` en el controller (entrega EN el evento del snapshot, paridad con `yield*` directo — la cola pasa el mismo patrón de test sin controller)
- **Files:** stats_provider.dart · **Commit:** 2a534ed

## Testing

- **82/82 verdes** (62 baseline + 20 migrados: 11 cocina/cola, 3 mesa_actions, 2 mesa_tile en vivo, 2 stats, 2 reservas wire). `flutter analyze` 0 issues.
- Patrón fakes replicado de app_cliente: FakeFirebaseFirestore + claimsProvider override por rol (mesero/cocina/admin) — nada de mocks del api_client en features migradas.
- Tests WS (mesas/pedidos) eliminados junto al ws_client de esas vistas (MIGRA-05).
- Verificación rg del plan: las 6 queries a colecciones staff (mesas/pedidos/reservas/sesiones) llevan `where restauranteId == rid`.

## Self-Check: PASSED

Archivos clave y 4 commits del plan (c29c039, acc4f7c, 2a534ed, 07b560a) verificados en disco/git.
