---
phase: 09-pagos-calificaciones-y-deploy
plan: 03
subsystem: app-cliente-pagos-ui
tags: [pago-ui, url-launcher, calificacion, rating, flutter, polling]
requires:
  - "09-01: POST /cliente/pagos/intencion + GET /cliente/pagos/{id} + sandbox checkout"
  - "09-02: POST /cliente/calificaciones + calificacion/total_calificaciones en public"
  - "fases 5-7 app cliente: go_router, Riverpod 3.4 codegen, freezed pin 4.0.0-dev.3"
provides:
  - "features/pagos/ completa: PagoController (iniciar/pagar/poll) + PagoScreen + CalificacionSheet"
  - "models/pago.dart (PagoIntencion/PagoEstado freezed) + ApiClient.crearIntencionPago/getPagoEstado/crearCalificacion"
  - "Botón 'Pagar en línea 💳' en _cuentaSection (cuenta pedida) → /mesa/pago"
  - "pagoLauncherProvider (launcher inyectable — patrón backoffBuilder de ws_client)"
  - "Restaurante/RestauranteDetalle.totalCalificaciones (@Default(0)) + ratingLabel ('4.8 (245)' | '—')"
  - "Rating real en lista + detalle + home (CALI-02 discover completo)"
affects:
  - "app_cliente/pubspec.yaml (url_launcher ^6.3.2 — ÚNICA dep nueva)"
  - "test/pedidos/cuenta_test.dart (botón Pagar en línea)"
key-files:
  created:
    - app_cliente/lib/models/pago.dart
    - app_cliente/lib/features/pagos/pago_controller.dart
    - app_cliente/lib/features/pagos/pago_screen.dart
    - app_cliente/lib/features/pagos/calificacion_sheet.dart
    - app_cliente/test/pagos/pago_screen_test.dart
    - app_cliente/test/pagos/calificacion_sheet_test.dart
  modified:
    - app_cliente/pubspec.yaml
    - app_cliente/pubspec.lock
    - app_cliente/lib/core/api_client.dart
    - app_cliente/lib/models/restaurante.dart
    - app_cliente/lib/models/restaurante_detalle.dart
    - app_cliente/lib/features/pedidos/pedido_estado_screen.dart
    - app_cliente/lib/features/restaurantes/restaurantes_list_screen.dart
    - app_cliente/lib/features/restaurantes/restaurante_detalle_screen.dart
    - app_cliente/lib/features/restaurantes/home_screen.dart
    - app_cliente/lib/app.dart
    - app_cliente/test/pedidos/cuenta_test.dart
    - app_cliente/test/restaurantes/list_test.dart
tech-stack:
  added:
    - "url_launcher ^6.3.2 (+web/windows platform impls) — launch SOLO en user action (Pitfall 8)"
  patterns:
    - "Launcher inyectable via Provider (pagoLauncherProvider) override-able en tests — spy registra la URI"
    - "Intención auto-creada al ABRIR la screen (iniciar()) → monto visible ANTES del tap; launch separado en pagar()"
    - "Timer.periodic 2.5s + WidgetsBindingObserver resumed → poll inmediato; poll() no muta en 'pendiente' (cero rebuilds por tick)"
    - "Estado de flujo hand-rolled (PagoFlowState + copyWith) — controller @riverpod codegen como reserva_controller"
    - "409 del server → SnackBar con detail (ref.listen) + vista de error persistente"
decisions:
  - "La intención se crea al abrir la PagoScreen (idempotente server-side) y el botón Pagar solo lanza el checkout — el monto server-side es visible antes del gesto (UX del must_have) y el launch queda 100% en onPressed (Pitfall 8)"
  - "La UI jamás muta el estado del pago: transiciones solo con la palabra de GET /cliente/pagos/{id} (threat 1 — testeado explícito)"
  - "CalificacionSheet usa el ÚLTIMO de PagoEstado.pedidoIds (sesión ya cerrada — Pitfall 6); messenger se captura ANTES del pop para el SnackBar de gracias"
  - "ratingLabel como getter NUEVO (calificacionLabel se conserva): home_screen reusa ratingLabel sin tocar su widget card"
  - "Rechazado → 'Intentar de nuevo' llama iniciar(): el backend crea pago nuevo porque el anterior quedó terminal"
metrics:
  duration: 21 min
  completed: 2026-08-14
  tests-before: 41
  tests-after: 51
  commits: 4
---

# Phase 9 Plan 03: App Cliente — Pago UI + Calificación + Rating Real Summary

Cierre del ciclo en la app cliente: pagar la cuenta en línea (intención server-side → checkout sandbox en el navegador → polling 2.5s → éxito/rechazo), calificar con 5 estrellas custom post-pago, y rating real "⭐ 4.8 (245)" en lista/detalle/home — 51 tests (baseline 41 + 10 nuevos) + e2e curl completo contra el stack dev real.

## What Was Built

### Task 1 — Feature pago completa + wiring (TDD: 2d21ac7 → 44aff54)

- **models/pago.dart**: `PagoIntencion` {pago_id, referencia, monto double, estado, checkout_url} + `PagoEstado` {…, pedido_ids List<int>} — freezed 4.0.0-dev.3 regen sin conflictos.
- **ApiClient**: `crearIntencionPago()` (POST body vacío — monto SIEMPRE server-side) + `getPagoEstado(id)` — mismo patrón parseo que pedirCuenta.
- **pago_controller.dart** (@riverpod, autoDispose): `iniciar()` crea/reusa intención SIN lanzar → monto visible pre-tap; `pagar()` garantiza intención y lanza (launcher inyectable `pagoLauncherProvider`); `poll()` transiciona SOLO con GET (aprobado/rechazado; 'pendiente' no muta estado — cero rebuilds); `abrirCheckout()` re-apertura desde user tap. Estados idle/creando/pendiente/aprobado/rechazado/error + lanzado/launchFallido/urlAbsoluta/errorDetail. URL absoluta: relativa sandbox → `Env.apiBaseUrl + url`.
- **pago_screen.dart**: ConsumerStatefulWidget + Timer.periodic 2.5s (poll auto-guardado, cancel en dispose) + WidgetsBindingObserver (resumed → poll inmediato). Vistas: resumen (Total a pagar + formatCOP + ref + Pagar 💳), esperando (Consultar ahora + Abrir checkout), éxito (✅ + monto + CTA Califica tu experiencia ⭐), rechazado (❌ + Intentar de nuevo = intención nueva), error (detail persistente + Reintentar). SnackBars via ref.listen: 409 con detail del server; launch fallido con la URL (fallback Pitfall 8).
- **Wiring**: GoRoute `/mesa/pago` (push fullscreen) + `_cuentaSection` con yaPedida → columna "Cuenta solicitada ✓" + botón **Pagar en línea 💳** (mirror `_cuentaYaPedida` intacto).
- **Tests (5)**: monto renderizado · tap Pagar → spy con URL absoluta (startsWith Env.apiBaseUrl) y SIN mutación local a aprobado · poll→aprobado (éxito + CTA) · poll→rechazado (reintento = intención #2) · 409 → SnackBar con detail. Sin timers reales: `ProviderScope.containerOf(ctx).read(pagoControllerProvider.notifier).poll()` directo (patrón estado_test).

### Task 2 — CalificacionSheet + rating real (TDD: 7151b1e → 99a813f)

- **calificacion_sheet.dart**: Row de 5 IconButtons (star/star_border, ámbar 0xFFF5A623 — cero deps), TextField multiline opcional, Enviar deshabilitado sin estrellas → `crearCalificacion(pedidoId, estrellas, comentario: trim→null)` → pop + SnackBar "¡Gracias por calificar! 🙌" (messenger capturado pre-pop). 409 → "Este pedido ya fue calificado" (sheet NO cierra); otros DioException → detail.
- **pago_screen**: CTA éxito → showModalBottomSheet con `pedidoIds.last`; el CTA permanece si se descarta (calificar opcional).
- **models**: `totalCalificaciones` @JsonKey('total_calificaciones') @Default(0) en Restaurante + RestauranteDetalle (constructores existentes siguen compilando) + getter `ratingLabel` = "4.8 (245)" | "—" (sin lógica local de promedio — el número que llega ES el promedio).
- **Screens**: lista + detalle + **home** pasan a ratingLabel (home: 1 palabra, fuera del files_modified del plan pero mismo espíritu CALI-02).
- **Tests (5 nuevos)**: 3 del sheet (estrellas/deshabilitado→enviar+gracias/409) + 1 lista ("4.8 (245)" vs "—") + 1 cuenta_test (botón Pagar en línea visible al pedir la cuenta).

### Task 3 — Checkpoint e2e sandbox (automatizado vía curl + pasos manuales documentados)

**E2E ejecutado contra el stack dev real** (14 pasos, `E2E-OK`) — equivalente automatizado del how-to-verify del plan, autorizado por el orchestrator (sin browser en el entorno):

1. BEFORE rating: null/0 → login admin@demo + cocina@demo
2. Mesa nueva vía POST /staff/mesas (GRI-MESA-R1-093 — las 8 demo intactas)
3. Cliente e2e registrado + sesión QR abierta (201)
4. Pedido 2× Arepa Rellena ($22.000) avanzado por staff: aceptado → en_preparacion → servido
5. Pedir la cuenta → **POST /cliente/pagos/intencion → monto 22000.0 server-side** + checkout_url relativa
6. GET checkout HTML: contiene referencia + "$ 22.000" ✓
7. POST /pagos/sandbox/{ref}/aprobar → **303** (mismo pipeline del webhook)
8. GET /cliente/pagos/{id} → **aprobado, pedido_ids=[2450]** ✓
9. POST /cliente/calificaciones 5★ + comentario → **201** ✓
10. GET /public/restaurantes → **calificacion 5.0, total_calificaciones 0→1→2** (2 corridas) ✓
11. Efecto: **mesa → limpieza** ✓

Cleanup posterior por SQL (orden FK 09-02): calificacion → pago_event → pago → pedido_item → pedido → sesion_mesa → mesa → usuario — verificado 0 residuo; restaurante demo vuelve a rating null/0 (pristine para el pase visual humano).

**Pase visual humano (PENDIENTE — no bloqueante, suite 51/51 ×2 + e2e curl verde):** pasos en `how-to-verify` del plan: `flutter run -d chrome --web-port 5174` → login → Escanear QR de mesa disponible (panel http://localhost:5173, cocina@demo.gri.dev / Demo!1234) → 2 productos → enviar → avanzar a servido en panel → "Pedir la cuenta" → **"Pagar en línea 💳"** → aprobar en sandbox → ✅ en ≤3s → calificar 5★ → "⭐ X.X (1)" en tab Restaurantes.

## Commits

| Task | Commit | Tipo |
| ---- | ------ | ---- |
| T1 RED | 2d21ac7 | test: failing tests del flujo de pago (monto, launcher, poll, 409) |
| T1 GREEN | 44aff54 | feat: pago en línea UI — intención, checkout externo, polling 2.5s (PAGO-02) |
| T2 RED | 7151b1e | test: failing tests calificación sheet + rating real lista (CALI-01/02) |
| T2 GREEN | 99a813f | feat: calificación post-pago + rating real en discover (CALI-01/02) |

## Deviations from Plan

### Auto-fixed Issues

**1. [Regla 3 - Bloqueo] PS 5.1 quirks en el script e2e (3 iteraciones)**
- **Found during:** Task 3 (verificación automatizada)
- **Issue:** (a) member enumeration de PS 5.1 sobre arrays de Invoke-RestMethod/ConvertFrom-Json producía `System.Object[]` en los asserts de rating; (b) Invoke-WebRequest NullReferenceException sin `-UseBasicParsing`; (c) `-MaximumRedirection 0` no exponía el 303 del sandbox.
- **Fix:** parseo por índice `[0]` con assert de id + `-UseBasicParsing` + curl.exe para el POST de aprobar (no sigue redirects → "303" literal). Solo afectó el script de verificación (temp), cero cambios en producto.
- **Files modified:** (script temporal — sin archivos del repo)

**2. [Regla 3 - Bloqueo] Rol cocina no puede crear mesas**
- **Found during:** Task 3 (paso 2 del e2e)
- **Issue:** `POST /staff/mesas` con token de cocina@demo → 403 "Rol no autorizado" (correcto: mesa-create es admin).
- **Fix:** login admin@demo.gri.dev para creación de mesa; cocina mantiene el avance de pedidos (como el plan). Números 90-99 con verificación de libres.
- **Files modified:** (script temporal)

### Notas de implementación (dentro del espíritu del plan)

- **La intención se crea al ABRIR la PagoScreen** (`iniciar()` en postFrameCallback) y `pagar()` solo lanza: así "Total a pagar" muestra el monto REAL server-side antes del tap y el launch queda íntegramente en el onPressed (Pitfall 8). La idempotencia server-side (09-01) hace el POST-inicial seguro; `pagar()` mantiene el fallback create-then-launch si la intención no existiera.
- **home_screen.dart** añadido a files_modified (1 palabra: `ratingLabel`) — la fila ⭐ del home es parte de discover (CALI-02); sin este cambio el home mostraría el promedio SIN count, inconsistente con lista/detalle.
- **cuenta_test extendido** con un test nuevo (botón Pagar en línea visible solo con cuenta pedida) — exigido por acceptance criteria del Task 1.
- **Aserción del test 409 ajustada** a `find.descendant(of: SnackBar)`: el detail aparece 2 veces (SnackBar transitorio + vista de error persistente) y el findsOneWidget global era sobre-estricto; el behavior ("SnackBar con el detail") se cumple exactamente.

## Test Evidence

- **flutter test suite completa: 51/51 × 2 corridas consecutivas** (baseline 41 + 10 nuevos: 5 pago_screen + 3 calificacion_sheet + 1 list + 1 cuenta) · **flutter analyze: 0 issues**
- Spy del launcher: URL absoluta (`Env.apiBaseUrl` + relativa sandbox) — assert explícito startsWith + endsWith
- Threat 1 testeado: "sin mutación local a aprobado" (la vista sigue 'Esperando' tras el launch hasta que poll() lee el backend)
- e2e curl contra stack dev: 14/14 pasos E2E-OK (incluye efectos: mesa→limpieza; rating público +1 con avg 5.0); residuo limpio y verificado (0 calis/pagos/mesas-R1-09x/usuarios-e2e)

## Verification of Plan Success Criteria

- **PAGO-02 (UI)** ✓ botón Pagar abre checkout (launcher externalApplication en onPressed) y el éxito se refleja por polling 2.5s + lifecycle resumed (tests + e2e)
- **CALI-01 (UI)** ✓ sheet 5 estrellas + comentario tras pago aprobado, con pedido_id de pago.pedido_ids (tests: args exactos al FakeApi)
- **CALI-02 (UI)** ✓ lista Y detalle (Y home) muestran "⭐ X.X (N)"; "—" con total 0 (test)
- **Cero regresiones** ✓ 41 preexistentes verdes; cuenta_test actualizado sin romper los 3 tests originales
- **Checkpoint humano** ⏳ pase visual PENDIENTE (no bloqueante según orchestrator: suite verde + e2e curl automatizado aprobado; pasos documentados arriba)

## Self-Check: PASSED

8/8 archivos creados verificados en disco · 4/4 commits verificados en `git log` · pago_screen.dart = 426 líneas (min 60 del must_have) · suite 51/51 ×2 · analyze 0 issues.
