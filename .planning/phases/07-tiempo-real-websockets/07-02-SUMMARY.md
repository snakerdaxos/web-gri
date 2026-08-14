---
phase: 07-tiempo-real-websockets
plan: "02"
subsystem: panel-admin-realtime
tags: [websockets, ws-client, reconexion, backoff-jitter, dedup-seq, kick-to-refetch, safety-net, riverpod, flutter-web]
requires:
  - "07-01 (backend WS vivo: /ws/staff?token=, room restaurant:{id}, contrato {type, restaurante_id, seq, ts, data})"
  - "Phase 4 (panel_admin: ApiClient con _refreshOnce, AuthStorage, los 3 providers con polling 10s)"
provides:
  - "WsClient del panel (token FRESCO por intento, backoff 1→30s ×2+jitter, 4401/handshake-401→refreshTokens→retry inmediato, dedup seq por room con reset al reconectar, resync stream, seams inyectables connect/backoffBuilder)"
  - "wsClientProvider/wsConnectionProvider (ciclo de vida sesión+dropdown super_admin) + wsEventsProvider/wsResyncProvider broadcast"
  - "mesas/stats/pedidosStaff en vivo: kick-to-refetch (evento=señal, GET existente) + safety net 60s (pollSafetyNetSeconds)"
  - "ApiClient.refreshTokens() público (delega en el Completer anti refresh-storm del interceptor)"
affects:
  - "F9 deploy (derivación wss:// ya sale de Env.apiBaseUrl — Pitfall 8 respetado)"
  - "UAT de fase (humo manual end-to-end para cerrar RT-01/RT-03)"
tech-stack:
  added:
    - "web_socket_channel ^3.0.3 (directa; WebSocketChannel.connect cross-platform)"
    - "stream_channel ^2.1.0 (dev-only — fakes de canal en tests vía StreamChannelMixin)"
  patterns:
    - "Kick-to-refetch estructural: el evento WS SOLO invalida → GET existente; JAMÁS muta estado local (cero drift)"
    - "Seams inyectables (channel factory + backoffBuilder) → WsClient testeable sin sockets"
    - "Gen counter en WsClient descarta reconexiones de ciclos obsoletos (cambio de room durante backoff)"
    - "Riverpod dedupe AsyncValues idénticos → los fakes de ApiClient en tests deben distinguir snapshots por llamada"
key-files:
  created:
    - panel_admin/lib/core/ws_client.dart
    - panel_admin/test/mesas_ws_test.dart
    - panel_admin/test/pedidos_ws_test.dart
    - panel_admin/test/ws_client_test.dart
  modified:
    - panel_admin/pubspec.yaml (+web_socket_channel, +stream_channel dev)
    - panel_admin/pubspec.lock
    - panel_admin/lib/core/api_client.dart (refreshTokens() público + ref al interceptor)
    - panel_admin/lib/core/env.dart (pollSafetyNetSeconds 60)
    - panel_admin/lib/features/dashboard/mesas_provider.dart
    - panel_admin/lib/features/dashboard/stats_provider.dart
    - panel_admin/lib/features/cocina/pedidos_staff_provider.dart
decisions:
  - "mesa.estado SÍ refresca la cola de cocina (acción del plan + research P6) pese al ejemplo del bloque behavior — Test 5 usa sesion.abierta como irrelevante"
  - "Handshake 401/403 (forma observada del rechazo pre-accept en 07-01) se trata igual que close 4401: refresh+retry inmediato; en web (status opaco) el safety net 60s auto-cura el loop (GET 401→interceptor→token fresco→próximo intento)"
  - "RT-02 marcado completo (panel-only, cerrado por este plan); RT-01/RT-03 siguen Pending para el UAT end-to-end de fase — convención 07-01/07-03"
  - "Env.pollSeconds queda en env.dart para referencias pero NINGÚN provider lo usa (grep verificado)"
metrics:
  duration: "~20 min"
  tasks: 2
  tests-new: 11 (5 kick-to-refetch + 6 ws_client unit; suite 17 → 28)
  tests-total: 28
  completed: 2026-08-14
---

# Phase 7 Plan 02: Panel Admin en Vivo (WsClient + kick-to-refetch) Summary

El panel pasa de polling 10s a push WebSocket: WsClient propio con reconexión resiliente (token FRESCO del AuthStorage por intento, backoff 1→30s ×2 + jitter, close 4401 o handshake 401/403 → refreshTokens → retry inmediato, dedup por seq con reset al reconectar y señal de re-sync) y los 3 providers (mesas/stats/pedidosStaff) adoptan kick-to-refetch — el evento SOLO dispara el GET existente, jamás muta estado local — con safety net de 60s. Suite 17 → 28, analyze 0.

## Goal

RT-01/RT-02 del lado panel + RT-03 (reconexión con re-sincronización). Convierte la cola de cocina, el mapa de mesas y las stat cards en vivo — sin tocar consumers ni backend.

## Accomplished

- **Task 1 (5484707):** `web_socket_channel ^3.0.3` al pubspec; `ApiClient.refreshTokens()` público (delega en `_refreshOnce` del interceptor vía referencia `_auth` — reusa el Completer anti refresh-storm: N 401s + 4401s concurrentes → 1 solo POST /auth/refresh); `Env.pollSafetyNetSeconds` (60, mismo patrón dotenv defensivo); `core/ws_client.dart` (258 líneas): WsEvent.fromJson (num→int defensivo), WsClient con seams `connect`/`backoffBuilder`, `_wsUri` derivando ws(s):// de Env.apiBaseUrl con MERGE de query (conserva restaurante_id + token — `Uri.replace(queryParameters:)` a secas lo borraría), connect idempotente por path, gen-counter que descarta reconexiones de ciclos obsoletos (cambio de room durante backoff), dedup `seq <= lastSeq` con reset al reconectar, resync solo cuando `_failures > 0`, y los 4 providers de conexión/eventos cableados al ciclo de sesión (authState + dropdown super_admin → disconnect + connect al room nuevo).
- **Task 2 (RED cf28805 → GREEN ff497c9):** los 3 providers reemplazan `Timer.periodic(Env.pollSeconds)` por el patrón kick-to-refetch: `refresh()` local (try add GET / catch addError — no rompe el stream), sub1 = eventos relevantes (`mesa.estado` | `mesa.estado,pedido.creado,pedido.estado` | `pedido.creado,pedido.estado,sesion.cuenta,mesa.estado`), sub2 = wsResync → re-sync total, timer 60s safety net, onDispose cancela los 4. GET inicial EXACTO conservado (re-sync de RT-03). Contrato `Stream<T>` intacto — consumers sin cambios. Tests: mesas_ws (evento→refetch, irrelevante→nada, resync→refetch) y pedidos_ws (3 eventos→3 GETs, sesion.abierta→nada).
- **Plan-checker FIX (3ae9209):** `test/ws_client_test.dart` (6 tests): URI ws+token+query mergeado por intento, idempotencia por path + token null no conecta, dedup seq, 4401→refresh→retry inmediato con token fresco, 4401+refresh null→no reconecta, caída→backoff→reconexión→resync. Fakes: `_FakeChannel extends StreamChannelMixin implements WebSocketChannel` + `_FakeSink` + storage/api fake — cero sockets reales.

## Verification

| Check | Resultado |
|---|---|
| `flutter test` suite completa panel_admin | **28 passed** (17 baseline + 11 nuevos, 0 regresiones) |
| `flutter analyze` | **0 issues** |
| grep 3 providers: wsEventsProvider + wsResyncProvider + Env.pollSafetyNetSeconds | ✓ los tres |
| grep 3 providers: `Env.pollSeconds` (debe ser 0) | ✓ ausente |
| GET inicial (getMesas/getStats/getPedidosActivos) como primer yield | ✓ intacto en los 3 |
| ws_client.dart: readAccess() DENTRO de connect (sin campo _token) | ✓ (grep _token vacío) |
| ws_client.dart: `replaceFirst('http', 'ws')` (sin ws:// hardcodeado) | ✓ línea 105 |
| backoff cap 30s + jitter 0-500ms | ✓ `_defaultBackoff` |
| api_client.dart: refreshTokens público | ✓ línea 70 |
| Humo manual (login cocina@demo.gri.dev :5173, pedido QR en otra pestaña, docker stop/start api 5s) | **PENDIENTE — UAT de fase** (no bloqueante según plan) |

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] `Uri.replace(queryParameters:)` del esqueleto borraba el `restaurante_id` del path super_admin**
- **Found during:** Task 1
- **Issue:** el esqueleto del research hacía `_wsUri(path).replace(queryParameters: {'token': token})` — replace SOBREESCRIBE todo el query, así el super_admin habría conectado sin `restaurante_id` (backend responde 4400).
- **Fix:** merge explícito `{...uri.queryParameters, 'token': token}` — cubierto por el test 1 de ws_client_test.dart.
- **Files:** lib/core/ws_client.dart — **Commit:** 5484707

**2. [Rule 2 - Hardening] Handshake 401/403 tratado como 4401 (refresh + retry inmediato)**
- **Found during:** Task 1 (análisis del contrato real de 07-01)
- **Issue:** 07-01 documentó que el rechazo pre-accept llega como handshake HTTP 403 — el close code 4401 NO cruza el handshake. Con solo el manejo onDone==4401 del plan, un token expirado con handshake rechazado entraría en loop de backoff en IO y dependería 100% del safety net en web.
- **Fix:** `_isAuthHandshakeError` (toString contiene 403/401 — detectable en IO; en web el status es opaco) → `_onAuthClosed` (refresh + retry inmediato). En web, el safety net de 60s auto-cura: GET 401 → interceptor refresh → próximo intento WS lee token fresco (≤~90s, sin logout).
- **Files:** lib/core/ws_client.dart — **Commit:** 5484707

**3. [Rule 1 - Test bug] Fakes con `const [...]` ⇒ Riverpod dedupe AsyncValues idénticos y no notifica listeners**
- **Found during:** Task 2 (GREEN no llegaba)
- **Issue:** el fake de ApiClient retornaba la misma lista const canónica cada GET → `AsyncData(a) == AsyncData(a)` → Riverpod no notifica → los completers de los tests jamás se completaban (el evento SÍ llegaba y el GET SÍ ocurría — verificado con prints temporales).
- **Fix:** snapshots distinguibles por llamada (mesas: id/estado por nº de GET; pedidos: lista fresca `[]` no-const). Nota bene para futuros tests de StreamProvider.
- **Files:** test/mesas_ws_test.dart, test/pedidos_ws_test.dart — **Commit:** ff497c9

**4. [Rule 3 - Blocking] `await container.dispose()` no compila (Riverpod 3.4: dispose es void) + read sin listener no mantiene vivo autoDispose**
- **Found during:** Task 2 RED
- **Issue:** scaffolding de tests: (a) `ProviderContainer.dispose()` retorna void; (b) `read(provider.future)` sin `listen` deja morir el autoDispose provider en loading ("disposed during loading state").
- **Fix:** teardown sin await + listener dummy en los tests de "evento irrelevante".
- **Files:** test/mesas_ws_test.dart, test/pedidos_ws_test.dart — **Commit:** cf28805/ff497c9

**5. [Rule 3 - Test infra] `pub add` duplicó la clave web_socket_channel en pubspec.yaml**
- **Found during:** Task 1
- **Issue:** el pubspec quedó con `web_socket_channel: 3.0.3` (añadido por pub add) + `web_socket_channel: ^3.0.3` (añadido por mí) → "Duplicate mapping key" al pub get.
- **Fix:** eliminada la línea duplicada; constraint explícito `^3.0.3` con comentario.
- **Files:** pubspec.yaml — **Commit:** 5484707

### Notas (no desviaciones)

- **Contradicción interna del plan resuelta:** el bloque `<behavior>` Test 5 sugería `mesa.estado` como irrelevante para pedidosStaff, pero `<action>` paso 2 (y research Pattern 6) lo INCLUYE ("la cola re-ordena si la mesa cambia"). Prevaleció `<action>`; el test usa `sesion.abierta` (llega al room staff, no afecta la cola).
- **`_refreshOnce()` vive en AuthInterceptor**, no en ApiClient: el wrapper público `refreshTokens()` delega vía referencia `late final _auth` (mismo archivo, acceso privado válido).
- **ws_client.dart importa features/dashboard/restaurante_provider.dart** (core→feature) porque el plan prescribe wsConnectionProvider en el mismo archivo — Dart no impone layering y no crea ciclo.
- **Requisitos:** RT-02 marcado completo (requerimiento panel-only, cerrado aquí: backend 07-01 + panel 07-02 + tests en ambas capas). RT-01/RT-03 siguen Pending para el UAT end-to-end de fase — convención dejada por 07-01/07-03 en STATE.md.

## Self-Check: PASSED

- Archivos: ws_client.dart (258 líneas ≥80), mesas_ws_test.dart (192 ≥40), pedidos_ws_test.dart (154 ≥40), ws_client_test.dart (236) — FOUND
- Contiene `class WsClient` ✓, `wsEventsProvider` en pedidos_staff_provider.dart ✓
- Commits: 5484707, cf28805, ff497c9, 3ae9209 — FOUND (git log)
- Suite: 28 passed (17 + 11), analyze 0 issues, 0 regresiones
