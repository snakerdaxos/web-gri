---
phase: 10-migracion-a-firebase-opcion-b-apps-flutter-movil-y-panel-web
plan: "04"
subsystem: app_cliente
tags: [firebase, firestore, sesion-qr, pedidos, realtime, calificacion, purge, big-bang]
requires:
  - "10-01 (rules/indexes/seed — índice pedidos sesionId+createdAt ASC, doc shapes)"
  - "10-02 (firestoreProvider override point, state_machines, firebase_fakes)"
  - "10-03 (models fromDoc pattern, tx_mutex patrón, discover + reservas migrados)"
provides:
  - "abrirSesion: runTransaction sobre sesiones/{mesaId} determinista (UNA activa por mesa, MIGRA-06) + validarTransicion mesa→ocupada"
  - "sesionProvider(mesaId) doc stream (banner vivo) + sesionActual(keepAlive) sesión más reciente del usuario sin filtrar estado (calificación post-cierre alcanzable)"
  - "crearPedido: runTransaction con sesión propia activa (anti-spoofing P6) + items snapshot nombre/precio + total int COP + sesionId == mesaId"
  - "pedidosSessionProvider: where sesionId + orderBy createdAt (índice ASC 10-01) + reverse client-side — snapshots() nativo (MIGRA-05, WS+polling retirados)"
  - "solicitarCuenta: guard dueño + update cuentaSolicitada/cuentaPedidaAt (idempotente)"
  - "calificar: runTransaction con pedido servido propio + sesión cerrada + calificaciones/{pedidoId} 1:1 + recompute califProm/califCount EN LA MISMA tx"
  - "PURGE completo: sin dio/web_socket_channel/flutter_dotenv/flutter_secure_storage/url_launcher, sin api_client/token_provider/ws_client/auth_storage/env/token_pair/pago, sin ruta /mesa/pago ni assets/.env"
affects:
  - "app_cliente íntegro (sesión/pedidos/cuenta/calificación/home/app/main/pubspec) — big-bang MIGRA-01 completado"
tech-stack:
  added: []
  patterns:
    - "Doc ID determinista sesiones/{mesaId} + tx.get dentro de runTransaction = unicidad sin autoId"
    - "Agregado atómico leído-recomputado en la misma tx (califProm/califCount)"
    - "Stream con orden server-side solo sobre índices existentes + reverse client-side (extensión del patrón 10-03)"
    - "Bridge de auth en streams: yield currentUser antes de authStateChanges() (SDK real ya lo emite; mocks broadcast sin replay)"
    - "tx_mutex blindado contra throws sincrónicos de la acción (token release en catch)"
key-files:
  created:
    - app_cliente/lib/core/tx_mutex.dart
  modified:
    - app_cliente/lib/models/sesion_mesa.dart
    - app_cliente/lib/models/pedido.dart
    - app_cliente/lib/models/pedido_item.dart
    - app_cliente/lib/features/sesion_qr/sesion_provider.dart
    - app_cliente/lib/features/sesion_qr/scan_screen.dart
    - app_cliente/lib/features/pedidos/pedidos_provider.dart
    - app_cliente/lib/features/pedidos/carrito_controller.dart
    - app_cliente/lib/features/pedidos/menu_mesa_screen.dart
    - app_cliente/lib/features/pedidos/pedido_estado_screen.dart
    - app_cliente/lib/features/pagos/calificacion_sheet.dart
    - app_cliente/lib/features/restaurantes/home_screen.dart
    - app_cliente/lib/features/reservas/reserva_controller.dart
    - app_cliente/pubspec.yaml
    - app_cliente/lib/main.dart
    - app_cliente/lib/app.dart
  deleted:
    - app_cliente/lib/core/{api_client,auth_storage,token_provider,token_provider.g,ws_client,env}.dart
    - app_cliente/lib/models/{token_pair,token_pair.g,token_pair.freezed,pago,pago.g,pago.freezed}.dart
    - app_cliente/lib/features/pagos/{pago_screen,pago_controller,pago_controller.g}.dart
    - app_cliente/assets/.env
    - app_cliente/test/{ws_client_test,pedidos_ws_test,pagos/pago_screen_test}.dart
decisions:
  - "pedidosSessionProvider (nombre existente en screens) en vez de pedidosSesionProvider del plan — misma query/pattern del key_link; cero ripple en screens/tests"
  - "orderBy('createdAt') ASC server-side (índice 10-01) + .reversed.toList() client-side — el índice DESC no existe (mismo criterio 10-03)"
  - "sesionActual NO filtra por estado: emite la sesión más reciente del usuario; la UI discrimina (banner/menú exigen activa, calificación exige cerrada) — hace alcanzable el must_have 'calificar tras cierre'"
  - "Sin campo de notas en el carrito/pedido: el doc shape del research no las incluye y las rules validan estructura estricta"
  - "fromJson de los models sobrevive como herencia inerte de la era REST (sin callers) — no se eliminó para no amplizar el ripple del purge"
metrics:
  duration: "80m"
  completed: "2026-08-16"
  tests: "91/91 (83 baseline 10-03 + netos: 11 sesión QR, 11 carrito/pedidos, 5 cuenta, 4 estado, 9 calificación − 12 legacy ws/pagos eliminados)"
  analyze: "0 issues"
---

# Phase 10 Plan 04: app_cliente — sesión QR tx + pedidos + cuenta + calificación + realtime + PURGE Summary

**One-liner:** El core value completo (sentarse por QR → pedir con snapshot de precios → seguir los pedidos EN VIVO por onSnapshot → pedir la cuenta → calificar tras cierre con agregado atómico) corriendo 100% sobre Firestore con unicidad de sesión por tx determinista `sesiones/{mesaId}`, y el PURGE final que deja app_cliente sin rastro de la capa HTTP propia (dio/ws/token/env/pagos fuera de pubspec y disco).

## What Was Built

### Task 1 — sesión QR: models + abrirSesion tx + stream del banner (b814992 RED → dfad7d5 GREEN)

- Models `sesion_mesa`/`pedido`/`pedido_item` con `fromDoc` ids String: estado `activa|cerrada|expirada`, `cuentaSolicitada`/`cuentaPedidaAt?`, items snapshot `{productoId, nombre, precio int, cantidad int}`, `sesionId == mesaId`, `total` int COP.
- `abrirSesion` (runTransaction): tx.get `mesas/{codigoQR}` (no existe → 'Código de mesa inválido') → tx.get `sesiones/{mesaId}` (activa → 'Mesa ocupada') → `validarTransicion('mesa', actual→ocupada)` (limpieza lanza) → tx.set sesión limpia + tx.update mesa ocupada. Retorno ya enriquecido con mesaNumero leído en la tx.
- `sesionProvider(mesaId)`: stream del doc (banner vivo, refleja cuentaSolicitada y cierre). `sesionActual` (keepAlive): sesión más reciente del usuario.
- `scan_screen`: input manual de primera clase con regex `^GRI-MESA-[a-z0-9-]+-\d{3}$` (hint GRI-MESA-demo-001) + cámara bajo demanda (errorBuilder → fallback manual).
- `core/tx_mutex.dart`: el mutex en-proceso de 10-03 promovido a core (reserva_controller ahora lo importa).

### Task 2 — pedidos + cuenta + calificación + realtime (b58f9d0 RED → 69b8cc7 GREEN)

- `crearPedido` (runTransaction): sesión existe + `usuarioId == uid` + estado activa (errores controlados SIN doc creado); restauranteId de la mesa; items congelados del carrito (`CarritoLine.toPedidoItem()`); `total = Σ precio×cantidad` int; autoId para pedidos.
- `pedidosSessionProvider`: `where('sesionId').orderBy('createdAt').snapshots()` + reverse client-side — REALTIME MIGRA-05 (WS + polling 10s + refetch eliminados).
- `solicitarCuenta`: guard dueño/activa → update `cuentaSolicitada + cuentaPedidaAt` (idempotente).
- `calificar` (runTransaction): pedido servido propio → sesión cerrada → `calificaciones/{pedidoId}` no existe (1:1) → lee y recompute `califProm/califCount` EN LA MISMA tx (ej. 0,0→5; 5×1 →(5+3)/2=4).
- Screens: menu_mesa sin notas por tx (controller enviar + carrito limpio); pedido_estado sin "Pagar en línea 💳" (pagos diferidos) + botón "Calificar" en cards servidas con sesión cerrada; home banner solo si estado activa.

### Task 3 — purge legacy (d1f8092)

- DELETE 19 archivos: core/{api_client, auth_storage, token_provider*, ws_client, env}, models/{token_pair*, pago*}, features/pagos/{pago_screen, pago_controller*}, assets/.env, tests {ws_client_test, pedidos_ws_test, pago_screen_test}.
- pubspec sin dio/web_socket_channel/flutter_dotenv/flutter_secure_storage/url_launcher ni assets. main.dart sin dotenv.load. app.dart sin /mesa/pago.
- Comentarios de models/providers reformulados (0 matches del grep legacy en lib/ y test/). `web_socket_channel` queda SOLO como transitivo de build_runner/test (tooling, no app).

## Verification Results

| Check | Resultado |
|---|---|
| `flutter analyze` | ✅ **0 issues** |
| Suite completa `flutter test` | ✅ **91/91** |
| Concurrencia doble apertura (MIGRA-06) | ✅ Future.wait → 1 gana, perdedor 'Mesa ocupada' |
| Regresión 10-03 doble reserva slot | ✅ (mis_reservas/wizard tests verdes) |
| crearPedido sesión ajena/inactiva/vacío → sin doc | ✅ tests con asertos de colección vacía |
| REALTIME: create + estado servido sin refetch | ✅ container.listen sobre pedidosSessionProvider |
| solicitarCuenta → doc flag + cuentaPedidaAt | ✅ (unit + widget con stream vivo) |
| calificar agregado atómico + 1:1 + 3 negativos | ✅ (prom 4.0 exacto en (5+3)/2) |
| rg "api_client\|token_provider\|ws_client\|auth_storage\|dotenv\|url_launcher\|TokenPair" lib test | ✅ **0 matches** |
| Test-Path negativo por archivo purgado (19) | ✅ ninguno existe |
| pubspec sin capa HTTP propia | ✅ (solo transitivos de tooling) |

## Deviations from Plan

### Desvíos Rule 1/2/3 (auto-aplicados)

**1. [Rule 1 - Bug] tx_mutex blindado contra throws sincrónicos**
- **Found during:** Task 2 RED — los tests colgaban sin output.
- **Issue:** un `throw` SINCRÓNICO dentro de la acción saltaba la liberación del token; el mutex quedaba tomado y el siguiente test encadenaba sobre un future de una zona muerta (el gotcha documentado en el propio archivo, por una vía no prevista).
- **Fix:** try/catch alrededor de `accion()` en el camino libre: libera el token y devuelve `Future.error` (preserva el contrato async).
- **Files:** lib/core/tx_mutex.dart — **Commit:** b58f9d0

**2. [Rule 1 - Bug] sesionActual no emitía bajo mocks (2 fixes)**
- **Issue:** (a) `MockFirebaseAuth.authStateChanges()` es broadcast SIN replay — el evento de sign-in del constructor nunca llega a listeners tardíos; (b) `snap.docs.reduce(...)` explota por varianza de tipos con los fakes (`MockQueryDocumentSnapshot` vs `QueryDocumentSnapshot`).
- **Fix:** (a) bridge `yield auth.currentUser` antes de `yield* authStateChanges()` (el SDK real ya emite el usuario vigente a cada listener — paridad, no cambio semántico); (b) loop manual con upcast en vez de reduce.
- **Files:** lib/features/sesion_qr/sesion_provider.dart — **Commit:** 69b8cc7

**3. [Rule 3 - Blocking] Tests híbridos del executor muerto reescritos**
- **Issue:** cuenta_test/calificacion_sheet_test sobrescribían `apiClientProvider` (legacy) contra models nuevos; el test de cuenta asserteaba el botón "Pagar en línea" (UI retirada por pagos diferidos).
- **Fix:** reescritos con fakes Firestore (sesión real vía abrirSesion) + asertos anti-regresión `find.textContaining('Pagar') → findsNothing`.
- **Files:** test/pedidos/{cuenta,estado,carrito}_test.dart, test/pagos/calificacion_sheet_test.dart — **Commits:** b58f9d0, 69b8cc7

**4. [Rule 1 - Self-inflicted] Encoding mojibake de scan_test.dart**
- **Issue:** un rename vía PowerShell `Set-Content` (sin -Encoding UTF8) doble-codificó el test; un intento de reversión mal dirigido lo agravó (nivel 3).
- **Fix:** round-trips binarios correctos (UTF8-decode → 1252-encode → bytes) hasta limpiar; verificado con Read tool. Los tests quedaron con los literales correctos.
- **Commit:** dfad7d5 — *lección: nunca tocar archivos UTF-8 con contenido no-ASCII vía cmdlets de texto de PowerShell 5.1.*

### Decisiones técnicas menores

- **Nombre del provider**: se mantuvo `pedidosSessionProvider` (existente en screens/tests) en vez de `pedidosSesionProvider` — misma query del key_link (`where sesionId + snapshots`), cero ripple.
- **Orden DESC client-side**: índice 10-01 es sesionId+createdAt ASC; `.reversed.toList()` materializa el DESC (criterio 10-03: server-side solo lo indexado).
- **sesionActual sin filtro de estado**: la sesión cerrada sigue emitida para que la calificación post-cierre sea alcanzable desde la pantalla de pedidos; banner/menú discriminan por `estado`.
- **Notas del pedido eliminadas**: el doc shape del research no las incluye; rules validan estructura estricta.

## Auth Gates

Ninguno (todo contra fakes, por diseño del plan).

## Notes for Continuation (10-05 panel)

- app_cliente queda como referencia de big-bang completado: purge verificado por grep — misma receta para el panel.
- `califProm` double / `califCount` int en `restaurantes/{rid}` — el panel que muestra ratings lee esos campos (actualizados por la tx del cliente).
- El staff cierra sesión (mesa → limpieza→disponible) — el re-abrir mesa exige ese ciclo; documentado en los tests.
- `documentos/google-services.json` (untracked) es el config real de Firebase — NO commitear.

## Self-Check: PASSED

- Archivos clave en disco: sesion_provider.dart ✅ pedidos_provider.dart ✅ calificacion_sheet.dart ✅ tx_mutex.dart ✅ scan_screen.dart ✅
- Purge Test-Path negativo (19 archivos) ✅ — pubspec sin deps legacy ✅
- Commits verificados en git log: b814992 ✅ dfad7d5 ✅ b58f9d0 ✅ 69b8cc7 ✅ d1f8092 ✅
- flutter analyze 0 issues + flutter test 91/91 ✅ (corrida final post-purge)
