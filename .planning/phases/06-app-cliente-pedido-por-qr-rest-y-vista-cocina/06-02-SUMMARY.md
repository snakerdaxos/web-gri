---
phase: 06-app-cliente-pedido-por-qr-rest-y-vista-cocina
plan: 02
subsystem: app-cliente-flutter
tags: [flutter, mobile-scanner, qr, sesion-mesa, carrito, pedidos, polling, cuenta, riverpod-3]
requires:
  - "06-01 (backend 141/141): POST /cliente/sesiones (201/200/404/409), GET /cliente/sesiones/actual, POST /cliente/sesiones/actual/cuenta, POST /cliente/pedidos, GET /cliente/pedidos/actual"
  - "05-03 (app_cliente): GoRouter shell, core reutilizable, patrones de test con Fake ApiClient"
provides:
  - "features/sesion_qr: ScanScreen (mobile_scanner lazy + input manual GRI-MESA-XXX primera clase) + sesionProvider keepAlive + SesionController"
  - "features/pedidos: MenuMesaScreen (menú REUSADO de restauranteDetalleProvider + carrito), CarritoNotifier, pedidosSessionProvider (polling 10s), PedidoEstadoScreen (chips 5 estados + cuenta)"
  - "Home integrado: banner 'Estás en la Mesa X' + botón 📷 real (reemplaza 'Próximamente')"
  - "Env.pollSeconds=10 (base para Phase 7 swap a WS)"
affects:
  - "07-tiempo-real (pedidosSessionProvider pasa de Timer.periodic a WS sin tocar screens)"
  - "F9 pagos (pedido_estado_screen es donde el cliente espera la cuenta → pago)"
  - "06-03 (panel cocina avanza estados; el cliente los ve reflejados en <10s)"
tech-stack:
  added:
    - mobile_scanner 7.4.0 (QR: BarcodeDetector nativo / zxing-wasm fallback web)
  patterns:
    - "Cámara LAZY: MobileScanner se monta solo tras tap — input manual SIEMPRE en el árbol (tests + web sin secure context/CDN)"
    - "pedidosSessionProvider = clon exacto de mesas_provider del panel (primer yield + Timer.periodic + ref.onDispose), autoDispose para que el timer muera al salir"
    - "Modal bottom sheet que navega: el callback onEnviado usa el context de la SCREEN (el context del sheet muere con el pop; el sheet vive en el root navigator donde GoRouter.of no es confiable)"
    - "POST /cliente/pedidos SIN sesion_id en el body — el backend usa la sesión activa (contrato 06-01)"
    - "Cuenta idempotente UX: _cuentaYaPedida mirror local tras éxito + invalidate sesionProvider (banner home se entera)"
key-files:
  created:
    - app_cliente/lib/models/sesion_mesa.dart
    - app_cliente/lib/models/pedido.dart
    - app_cliente/lib/models/pedido_item.dart
    - app_cliente/lib/features/sesion_qr/scan_screen.dart
    - app_cliente/lib/features/sesion_qr/sesion_provider.dart
    - app_cliente/lib/features/pedidos/menu_mesa_screen.dart
    - app_cliente/lib/features/pedidos/carrito_controller.dart
    - app_cliente/lib/features/pedidos/pedidos_provider.dart
    - app_cliente/lib/features/pedidos/pedido_estado_screen.dart
    - app_cliente/test/sesion_qr/scan_test.dart
    - app_cliente/test/pedidos/carrito_test.dart
    - app_cliente/test/pedidos/estado_test.dart
    - app_cliente/test/pedidos/cuenta_test.dart
  modified:
    - app_cliente/pubspec.yaml (+mobile_scanner)
    - app_cliente/lib/core/api_client.dart (+abrirSesion/getSesionActual/pedirCuenta/getPedidosActuales/createPedido)
    - app_cliente/lib/core/env.dart (+pollSeconds=10)
    - app_cliente/lib/app.dart (+rutas /sesion/scan, /mesa, /mesa/pedidos)
    - app_cliente/lib/features/restaurantes/home_screen.dart (banner + 📷 real)
decisions:
  - "Input manual GRI-MESA-XXX es vía de primera clase (regex ^GRI-MESA-\\d{3}$ pre-red); la cámara es enhancement lazy —.MobileScanner JAMÁS en el árbol inicial"
  - "Anti doble-disparo triple: DetectionSpeed.noDuplicates + flag _navigating + controller.stop() tras primer hit (además del idempotente server-side)"
  - "sesionProvider keepAlive (sobrevive navegación como authState); pedidosSessionProvider autoDispose (timer muere al salir de la pantalla de estado)"
  - "El sheet del carrito envía items como records ({productoId, cantidad}) SIN precios — total siempre server-side"
  - "Chips de estado con extensión PedidoEstadoX: enviado azul/aceptado naranja/en_preparacion morado/servido verde/rechazado rojo"
requirements-completed: [MESA-05, MESA-06, PEDI-01, PEDI-02, PEDI-04, PAGO-01]
metrics:
  duration: 16min
  tasks: 3
  tests-new: 15 (4 scan + 5 carrito + 3 estado + 3 cuenta)
  tests-total: 34
  completed: 2026-08-14
---

# Phase 6 Plan 02: App Cliente — Pedido por QR (Scan → Menú → Carrito → Estado → Cuenta) Summary

**Journey completo del core value en la app cliente: escanear QR (o código manual GRI-MESA-XXX, vía de primera clase testeable) → sesión de mesa → menú con carrito (agotados deshabilitados, notas para cocina) → envío → chips de 5 estados con polling 10s → pedir la cuenta idempotente. mobile_scanner 7.4.0 lazy, menú REUSADO de restauranteDetalleProvider, suite 19→34 tests + analyze 0 + build web release.**

## Performance

- **Duration:** 16 min (09:01:20Z → 09:17:07Z)
- **Tasks:** 3 (commits atómicos por tarea)
- **Files:** 18 (13 creados + 5 modificados)
- **Tests:** 19 → **34** (+15, todos widget tests con Fakes — cero instancias de MobileScanner, cero timers reales)

## Accomplishments

- ✅ **T1 Sesión QR** (`eb7efb4`): `mobile_scanner: ^7.4.0` + `SesionMesa` freezed + `abrirSesion` (200 Y 201 idempotente) / `getSesionActual` (404→null) / `pedirCuenta` en ApiClient. `sesionProvider` keepAlive + `SesionController.abrir` (invalida tras abrir; 404/409 propagan detail a SnackBar). `ScanScreen`: cámara solo tras tap "Escanear con cámara" (errorBuilder → "usa el código manual"), input manual SIEMPRE visible con regex pre-red, botón disabled en vuelo, éxito → SnackBar verde "¡Sesión abierta en la Mesa N!" + pushReplacement /mesa. 4 tests.
- ✅ **T2 Feature pedidos** (`6f0e0c6`): `Pedido`/`PedidoItem` freezed + `PedidoEstadoX` (labels y colores de 5 estados). `Env.pollSeconds=10`. `getPedidosActuales` + `createPedido` (records sin sesion_id — backend usa la activa). `CarritoNotifier` (agregar/incrementar/decrementar→remover en 1/limpiar + total/itemCount). `pedidosSessionProvider` — clon exacto de mesas_provider (primer fetch + Timer.periodic + ref.onDispose, autoDispose mata el timer). `MenuMesaScreen` REUSA restauranteDetalleProvider: +/- por producto, "Agotado" deshabilitado desde render (Pitfall 7), bottom bar → sheet con notas(≤500)/total informativo/"Enviar pedido" disabled en vuelo (Pitfall 4) → invalidate + SnackBar + pushReplacement /mesa/pedidos. `PedidoEstadoScreen`: cards con chips coloreados + "Se actualiza automáticamente" + "Pedir la cuenta" → SnackBar + "Cuenta solicitada ✓" reemplaza el botón. 11 tests.
- ✅ **T3 Integración home** (`8569682`): rutas push fullscreen `/sesion/scan`, `/mesa`, `/mesa/pedidos` (branches del shell intactas). `_QrButton` y `_ActionCard` "Escanear mesa" → `context.push('/sesion/scan')` ("Próximamente" eliminado). Banner gradiente "Estás en la Mesa N · restaurante" con "Ver menú"/"Mis pedidos"/"Cuenta solicitada ✓". **Verificación global: analyze 0 issues · suite 34/34 · `flutter build web --release` ✓ (46.5s)**.

## Verification

| Check | Resultado |
|-------|-----------|
| flutter test (suite completa) | **34 passed, 0 failed** (19 previos + 15 nuevos, sin regresiones) |
| flutter analyze | No issues found |
| flutter build web --release | ✓ Built build\web (46.5s) |
| grep scan_screen | BarcodeFormat.qrCode ✓ · controller.stop() tras primer hit ✓ · TextField FUERA del condicional de cámara ✓ |
| grep pedidos_provider | Timer.periodic ✓ · ref.onDispose ✓ (Pitfall 8) |
| grep menu_mesa_screen | restauranteDetalleProvider (menú no re-implementado) ✓ · formatCOP ✓ |
| grep home_screen | "Próximamente" 0 matches ✓ · "Estás en la Mesa" ✓ · push /sesion/scan ×2 ✓ |
| grep app.dart | rutas /sesion/scan + /mesa + /mesa/pedidos ✓ |
| Tests sin cámara | `find.byType(MobileScanner)` findsNothing en render inicial (test explícito) |
| Enviar disabled en vuelo | flag _sending en sheet (Pitfall 4) ✓ |
| Chips 5 estados | test con scrollUntilVisible verifica label + color exacto por estado |

### UAT manual (NO bloqueante — para `/gsd-verify-work`)

```powershell
# 1. Backend (141/141): docker compose up -d
# 2. Desde la raíz:
cd app_cliente
$env:Path += ";C:\src\flutter\bin"
flutter run -d chrome --web-port=5174
# 3. http://localhost:5174 → login carlos@demo.gri.dev / Demo!1234
# 4. Home: botón 📷 (header) o action "Escanear mesa" → scanner
#    - Cámara web funciona en localhost:5174 (secure context)
#    - Input manual: GRI-MESA-003 → "¡Sesión abierta en la Mesa 3!" → menú
#    - 409 (mesa ocupada): mensaje del backend en SnackBar rojo
# 5. Home de vuelta: banner "Estás en la Mesa 3" con Ver menú / Mis pedidos
# 6. Menú: + en productos (agotados en gris "Agotado") → bar "Carrito (2) · $ ..."
#    → sheet → notas "Sin cebolla" → "Enviar pedido" → "¡Pedido enviado!"
# 7. Estado: card "Pedido #N" chip azul "Enviado", items, total, notas
#    - Avanzar estado (panel cocina o curl cocina@demo.gri.dev / Demo!1234):
#      PUT POST /staff/pedidos/{id}/estado {"estado":"aceptado"} → chip
#      cambia solo en ≤10s ("Se actualiza automáticamente")
# 8. "Pedir la cuenta" → SnackBar verde + "Cuenta solicitada ✓" + banner home
#    - Doble tap seguro (idempotente server-side)
# 9. Cámara real en dispositivo físico: UAT manual mobile_scanner (web OK)
```

## Task Commits

1. **T1 Sesión QR + scan con fallback manual** — `eb7efb4`
2. **T2 Menú/carrito/envío/estado/cuenta** — `6f0e0c6`
3. **T3 Integración home + rutas + suite global** — `8569682`

## Decisions Made

- Input manual primera clase y cámara lazy: única vía testeable en widget tests y fallback garantizado en web sin secure context/CDN (Pitfalls 5/9).
- `createPedido` envía `items` como records sin precios ni sesion_id — total y snapshot siempre server-side (contrato 06-01).
- El sheet del carrito navega vía callback `onEnviado` con el context de la screen: el context del sheet muere con el pop y el modal vive en el root navigator (GoRouter.of no confiable ahí).
- Cuenta: mirror local `_cuentaYaPedida` + `invalidate(sesionProvider)` — la UI confirma sin depender del round-trip del provider inválido.
- Chips: colores en extensión `PedidoEstadoX` (azul/naranja/morado/verde/rojo) — reutilizables y testeables unitariamente.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] SesionController autoDispose moría a mitad de `abrir`**
- **Found during:** Task 1 (primer run de scan_test: tests de éxito/409 fallaban sin SnackBar)
- **Issue:** `sesionControllerProvider` es autoDispose; la pantalla lo usaba con `ref.read(.notifier)` sin observarlo → Riverpod 3 dispone el provider tras el read → el `state = AsyncData` post-await en `abrir` lanzaba "Cannot use the Ref after it has been disposed" → caía al catch genérico ("Error de conexión")
- **Fix:** La pantalla hace `ref.watch(sesionControllerProvider)` en build (idénta razón por la que el wizard de reservas observa a ReservaController — mantiene el controller vivo mientras la pantalla existe)
- **Files modified:** app_cliente/lib/features/sesion_qr/scan_screen.dart
- **Verification:** 4/4 tests scan; suite 34/34
- **Committed in:** eb7efb4

**2. [Rule 3 - Blocking] Flag `--build-dir` no existe en build_runner 2.15**
- **Found during:** Task 1 (verify del plan imprimía el help y no corría)
- **Issue:** El comando `dart run build_runner build --build-dir .dart_tool` del plan no es un flag válido de esta versión
- **Fix:** `dart run build_runner build` estándar (sin --delete-conflicting-outputs, según lección 05-03)
- **Committed in:** n/a (solo comando de verificación)

**3. [Rule 1 - Bug/test] ListView lazy no construía los cards fuera del viewport**
- **Found during:** Task 2 (estado_test: 'Servido' no encontrado con 5 pedidos)
- **Issue:** Los 5 cards no caben en el viewport de 600px del test — los últimos no se construyen
- **Fix:** `tester.scrollUntilVisible` por chip antes de asertar label/color
- **Files modified:** app_cliente/test/pedidos/estado_test.dart
- **Committed in:** 6f0e0c6

---

**Total deviations:** 3 auto-fixed (2× Rule 1, 1× Rule 3 de verificación)
**Impact on plan:** Cero scope creep — todas puntuales para compilar/comportarse como el plan especificaba.

## Issues Encountered

- `documentos/` untracked (mockups del usuario, preexistente — fuera de alcance, no commiteado, idem 06-01).
- El agente paralelo de 06-03 trabaja en panel_admin/ — commits de este plan stagean SOLO app_cliente/ (sin interferencias).

## User Setup Required

None — mobile_scanner funciona en web sin configuración extra (auto-load del script desde 5.0.0). En dev web-first el permiso de cámara lo pide el browser en localhost:5174.

## Next Phase Readiness

- **06-03 (panel cocina)**: el contrato ya fluye end-to-end desde el cliente — enviar pedido en dev y avanzarlo desde el panel valida la matriz en vivo.
- **Phase 7 (WS)**: `pedidosSessionProvider` es el ÚNICO punto a reescribir (Timer.periodic → WebSocket); screens no se tocan. `Env.pollSeconds` queda obsoleto.
- **F9 (pagos)**: pedido_estado_screen ya muestra "Cuenta solicitada ✓" — ahí vive el CTA de pago.

## Self-Check: PASSED

13/13 archivos creados verificados en disco; 3/3 commits verificados en git log (eb7efb4, 6f0e0c6, 8569682); suite 34/34 y analyze 0 re-verificados post-commit.

---
*Phase: 06-app-cliente-pedido-por-qr-rest-y-vista-cocina*
*Plan: 02*
*Completed: 2026-08-14*
