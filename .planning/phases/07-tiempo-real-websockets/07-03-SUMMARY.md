---
phase: 07-tiempo-real-websockets
plan: "03"
subsystem: app-cliente-realtime
tags: [websockets, ws-client, reconexion, dedup-seq, kick-to-refetch, sesion-cerrada, riverpod]
requires:
  - "07-01 (/ws/cliente?token= room user:{id}; eventos {type, restaurante_id, seq, ts, data}; 4401)"
  - "Phase 4-6 app_cliente (ApiClient con _refreshOnce, AuthState, sesionProvider, pedidosSession polling)"
provides:
  - "app_cliente/lib/core/ws_client.dart — WsClient resiliente (token fresco por intento, backoff 1→30s ×2+jitter, dedup seq con reset al reconectar, resync signal, 4401→refreshTokens→retry inmediato, seams inyectables connect/backoffBuilder) + providers wsClient/wsConnection/wsEvents/wsResync"
  - "pedidosSession EN VIVO (PEDI-04): kick-to-refetch GET por evento WS + safety net 60s + sesion.cerrada → ref.invalidate(sesionProvider)"
  - "ApiClient.refreshTokens() público (wrapper del Completer anti refresh-storm del interceptor)"
affects:
  - "F9 deploy (derivación ws(s):// de Env.apiBaseUrl ya lista para nginx+TLS)"
tech-stack:
  added:
    - "web_socket_channel ^3.0.3 (direct dep)"
    - "stream_channel ^2.1.4 (dev-only — StreamChannelMixin para el FakeWebSocketChannel)"
  patterns:
    - "WebSocketChannel.connect es MÉTODO ESTÁTICO en 3.0.3 (no constructor); WebSocketChannel es abstract interface class → fakes via implements + StreamChannelMixin"
    - "TODO uso de ref (watch/read/onDispose) ANTES del primer await en generators — riverpod 3.4 lanza UnmountedRefException con ref post-await si hubo rebuild (identical(element.ref, this))"
    - "Guard isClosed en controller.add del refresh() — race dispose-vs-GET-en-vuelo al invalidar por sesion.cerrada"
key-files:
  created:
    - app_cliente/lib/core/ws_client.dart
    - app_cliente/test/ws_client_test.dart
    - app_cliente/test/pedidos_ws_test.dart
  modified:
    - app_cliente/pubspec.yaml (+web_socket_channel, +stream_channel dev)
    - app_cliente/lib/core/api_client.dart (refreshTokens() público; guarda referencia al AuthInterceptor)
    - app_cliente/lib/core/env.dart (pollSafetyNetSeconds, default 60 defensivo)
    - app_cliente/lib/features/pedidos/pedidos_provider.dart (polling 10s → WS push + safety net 60s)
decisions:
  - "WsClient copiado del Pattern 6 (research) — panel_admin aún no tenía ws_client.dart al iniciar (07-02 paralelo); NO se leyó ni tocó panel_admin/"
  - "Jitter dentro del backoffBuilder por defecto (no en _scheduleReconnect): el seam inyectado en 1ms da suite sin esperas reales"
  - "wsConnectionProvider: else-branch disconnect en logout (conexión vive CON la sesión, plan de vida keepAlive del Provider manual)"
  - "pubspec: caret ^3.0.3 explícito (pub add había fijado 3.0.3 exacto — criterio del plan)"
metrics:
  duration: "~35 min"
  tasks: 2
  tests-new: 7 (5 ws_client + 2 pedidos_ws; suite 34 → 41)
  tests-total: 41
  completed: 2026-08-14
---

# Phase 7 Plan 03: App Cliente en Vivo (WsClient + pedidosSession + sesion.cerrada) Summary

La app cliente pasa de polling 10s a push WebSocket: WsClient propio (token FRESCO por intento, backoff exponencial 1→30s ×2 + jitter, dedup por seq con reset al reconectar, señal de re-sync, y el flujo 4401→refresh→retry inmediato sin logout), pedidos de la sesión en vivo con kick-to-refetch idempotente + safety net 60s, y manejo de sesion.cerrada (anti-zombi/pago) que invalida la sesión y colapsa el banner — todo verificado con 7 tests nuevos (suite 41/41, analyze 0).

## Goal

RT-01 lado cliente (el dueño ve su pedido avanzar en vivo) + RT-03 completo (reconexión con re-sincronización, dedup, token fresco — el flujo más ejercitado en producción).

## Accomplished

- **Task 1 (80ea89b):** `web_socket_channel ^3.0.3` + `core/ws_client.dart` (WsEvent.fromJson del contrato 07-01; WsClient con seams `connect`/`backoffBuilder`; Uri ws(s):// derivado de Env; providers manuales wsClient/wsConnection/watchea SOLO authStateProvider/wsEvents/wsResync) + `ApiClient.refreshTokens()` público (reusa el Completer anti refresh-storm — la clase ahora guarda `_auth` al AuthInterceptor) + `Env.pollSafetyNetSeconds` (default 60 defensivo) + `pedidosSession` kick-to-refetch con `sesion.cerrada → ref.invalidate(sesionProvider)` Y refresh (por sesión vieja). Panel_admin no existía aún como fuente → implementado del Pattern 6 del research (copias core/ del proyecto).
- **Task 2 (cc7073e + 030b69e):** `test/ws_client_test.dart` (5 tests: dedup seq, reconexión+resync solo-tras-fallo, 4401→refresh→retry inmediato, refresh null→sin reconnect, token null→sin conexión) con FakeWebSocketChannel (StreamChannelMixin + implements — web_socket_channel 3.0.3 es abstract interface) y `test/pedidos_ws_test.dart` (2 tests: pedido.estado→GET extra; sesion.cerrada→invalidate observable vía contador de builds + colapso a Stream.empty sin más GETs) con ProviderContainer inline. Los tests ejercitaron el provider REAL y destaparon el hazard riverpod-3 (ver desviación 1).

## Verification

| Check | Resultado |
|---|---|
| `flutter test` (suite completa app_cliente) | **41 passed** (34 previos + 7 nuevos, 0 regresiones) |
| `flutter analyze` (app_cliente) | **0 issues** |
| Delays en tests | backoffBuilder inyectado 1ms; settles ≤50ms — nada >100ms |
| Acceptance grep: pubspec `web_socket_channel: ^3.0.3` / `refreshTokens(` público / pedidos_provider con wsEventsProvider+wsResyncProvider+pollSafetyNetNull→**pollSafetyNetSeconds** y SIN Env.pollSeconds | ✓ |
| `readAccess()` dentro de connect (no campo cacheado) / dedup seq / resync en reconnect / 4401→refresh→retry | ✓ (tests 1-5) |
| Scope: 0 archivos de panel_admin/ o backend/ en mis commits | ✓ (working tree de panel_admin pertenece al agente 07-02 paralelo) |

### Humo manual (NO bloqueante — documentado para UAT de fase)

1. `flutter run -d chrome --web-port 5174`, login cliente, abrir sesión (QR/manual), pedir.
2. Desde el panel, avanzar el pedido → la app del cliente refleja el avance sin refrescar.
3. `docker compose restart api` → la app reconecta sola (backoff) y re-sincroniza (GET + resync signal).
4. Panel: mesa → limpieza (anti-zombi) → el banner "Estás en la Mesa X" desaparece solo.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 2 - Hardening] pedidosSession reestructurado: uso de `ref` 100% antes del primer await**
- **Found during:** Task 2 (los tests 6-7 iban a ejercitar el provider real con riverpod 3.4.2)
- **Issue:** El plan esbozaba `ref.watch(wsEventsProvider)` DESPUÉS del `yield await getPedidosActuales()` (como el polling original). Verificado en fuente riverpod 3.4.2 (`ref.dart`): `mounted => !_element._disposed && identical(_element.ref, this)` — un rebuild del provider durante el await del GET inicial invalida el `ref` y el watch post-await lanza `UnmountedRefException`.
- **Fix:** Suscripciones (wsEvents/wsResync/timer) + onDispose registradas ANTES del primer await; eventos durante el GET inicial quedan bufferizados en el controller single-subscription. Añadido guard `isClosed` en `controller.add` (race dispose-vs-refresh-en-vuelo al invalidar por sesion.cerrada — destapado por el test 7).
- **Files:** app_cliente/lib/features/pedidos/pedidos_provider.dart
- **Commit:** cc7073e

**2. [Rule 3 - Blocking] stream_channel como dev-dependency**
- **Found during:** Task 2
- **Issue:** web_socket_channel 3.0.3 NO re-exporta `StreamChannelMixin`; el FakeWebSocketChannel necesita sus tipos → import de transitive dispara `depend_on_referenced_packages` (flutter_lints 6).
- **Fix:** `flutter pub add --dev stream_channel:^2.1.4` (misma versión que ya resolvía flutter_test — cero cambio de grafo).
- **Files:** app_cliente/pubspec.yaml
- **Commit:** 030b69e

**3. [Rule 1 - Lint] pubspec caret**
- **Issue:** `flutter pub add web_socket_channel:^3.0.3` escribió `3.0.3` exacto (sin caret) — el criterio pide `^3.0.3`.
- **Fix:** Editado a `^3.0.3` con comentario. **Commit:** 80ea89b

### Notas (no desviaciones)

- **TDD:** Task 2 marcó RED→GREEN, pero Task 1 ya contenía la implementación (orden del plan): los tests nacieron verdes; el ciclo RED/GREEN aplicó al hazard riverpod-3 destapado al escribirlos (desviación 1). Commits separados impl/tests como pedía el plan.
- **Pre-accept 403 (07-01 SUMMARY):** el rechazo pre-handshake llega como HTTP 403 → `ready` lanza → backoff normal; el 4401 close-code se maneja post-accept. La recuperación del 403-por-token-vencido la cierra el safety net 60s (cualquier GET dispara el refresh del interceptor) — comportamiento v1 aceptable, documentado para F9.
- **Paralelo 07-02:** sus archivos en working tree NO fueron tocados; los commits 5484707/cf28805 son del otro agente.

## Self-Check: PASSED

- Archivos: ws_client.dart (205 líneas ≥80), test/ws_client_test.dart (175 ≥60), test/pedidos_ws_test.dart (124), pedidos_provider.dart (contiene wsEventsProvider) — FOUND
- Commits: 80ea89b, cc7073e, 030b69e — FOUND (git log)
- Suite: 41 passed (34 + 7), analyze 0 issues
