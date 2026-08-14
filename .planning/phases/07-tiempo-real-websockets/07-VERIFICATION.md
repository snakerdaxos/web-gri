---
phase: 07-tiempo-real-websockets
verified: 2026-08-14T20:05:00Z
status: passed
score: 3/3 must-haves verified
re_verification: false
human_verification:
  - test: "Humo visual panel en browser (login cocina@demo.gri.dev :5173, pedir desde otra pestaña como cliente)"
    expected: "La cola de cocina y el mapa de mesas cambian solos, sin refrescar"
    why_human: "Verificación visual del render en browser (los tests ya cubren evento→refetch→stream)"
  - test: "Reconexión visual: docker compose restart api con el panel/app abiertos en browser"
    expected: "UI se reconecta sola (backoff) y re-sincroniza; sin duplicados ni estado viejo"
    why_human: "Comportamiento de red real en browser — la lógica está cubierta por tests unitarios"
  - test: "App cliente: banner 'Estás en la Mesa X' colapsa al pasar la mesa a limpieza desde el panel"
    expected: "El banner desaparece solo (sesion.cerrada → invalidate)"
    why_human: "Confirmación visual del flujo anti-zombi end-to-end en la UI móvil"
---

# Phase 7: Tiempo Real — WebSockets Verification Report

**Phase Goal:** Pedidos y estados de mesa llegan en vivo a cocina, mesero, cliente y panel sin refrescar, con recuperación ante desconexiones
**Verified:** 2026-08-14T20:05:00Z
**Status:** PASSED
**Re-verification:** No — verificación inicial

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | Cambio de estado de pedido llega en vivo a cocina/mesero/admin y cliente sin refrescar (WS post-commit, kick-to-refetch) | ✓ VERIFIED | 7 emisiones post-commit en 3 services (tras `await session.commit()`); 14/14 tests WS vivos (incl. `test_staff_recibe_pedido_creado`, `test_cliente_recibe_pedido_estado`); **e2e runtime contra stack vivo: `pedido.creado` recibido por WS staff en 0.008s con seq**; pedidosStaff/pedidosSession kick-to-refetch con tests (41/41 app, 28/28 panel) |
| 2 | Mapa de mesas del panel se actualiza en vivo (mesa.estado) | ✓ VERIFIED | `mesa.estado` emitida en `abrir_sesion` (solo created=True) y `set_mesa_estado` (staff); `mesasProvider` + `statsProvider` kick-to-refetch + tests `mesas_ws_test`; e2e runtime: eventos limpieza y disponible recibidos con seq creciente |
| 3 | Reconexión: backoff+jitter, token fresco por intento, 4401→refresh→retry, dedup seq, re-sync GET al reconectar, safety net 60s | ✓ VERIFIED | Ambos `ws_client.dart`: backoff `min(30000, 1000*2^(n-1))` + jitter 0-500ms, `readAccess()` DENTRO de connect (sin cache), closeCode 4401 → `refreshTokens()` → retry inmediato (panel además handshake 401/403), dedup `seq <= lastSeq` + reset al reconectar, `resync` stream solo tras fallos, `Timer.periodic(Env.pollSafetyNetSeconds=60)` en los 4 providers; tests: dedup/reconnect/4401/resync en ambas apps + `test_seq_monotonico` backend |

**Score:** 3/3 truths verified

### Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `backend/app/core/broadcaster.py` | Broadcaster Protocol + InMemoryBroadcaster (rooms, seq/room, dead-cleanup) + emit_event | ✓ VERIFIED (existe, sustantivo, cableado) | 119 líneas; singleton usado por ws.py y 3 services; advertencia 1-worker documentada + replicada en docker-compose.yml L45-46 |
| `backend/app/api/ws.py` | /ws/staff + /ws/cliente, auth JWT manual, SIN Depends(get_session) | ✓ VERIFIED | 113 líneas; `async_session_maker()` corto en `_ws_user`; 4401/4400; rooms por token (cliente jamás en rooms staff); grep `Depends(get_session)` = 0 |
| `backend/tests/test_ws.py` | 14 tests contra stack vivo | ✓ VERIFIED | 14 passed en 12.18s (6 auth/conexión + 8 eventos e2e incl. cross-tenant y seq) |
| `panel_admin/lib/core/ws_client.dart` | WsClient resiliente + 4 providers | ✓ VERIFIED (WIRED) | 258 líneas; consumido por mesas/stats/pedidosStaff vía wsEvents/wsResync |
| `app_cliente/lib/core/ws_client.dart` | WsClient resiliente + 4 providers | ✓ VERIFIED (WIRED) | 236 líneas; consumido por pedidosSession |
| `panel_admin` 3 providers + `app_cliente` pedidos_provider | kick-to-refetch + safety net 60s | ✓ VERIFIED (WIRED) | grep: wsEventsProvider + wsResyncProvider + pollSafetyNetSeconds en los 4; `Env.pollSeconds` residual = 0; consumers UI intactos (dashboard_screen, cocina_screen, pedido_estado_screen) |
| `ApiClient.refreshTokens()` público | wrapper anti refresh-storm | ✓ VERIFIED | panel L70 / app L61: `Future<String?> refreshTokens() => _auth._refreshOnce()` |

### Key Link Verification

| From | To | Via | Status | Details |
|------|----|----|--------|---------|
| services (3) | broadcaster | `await emit_event(...)` post-commit ×7 | ✓ WIRED | 2 pedido + 3 sesion + 2 staff, todas tras `session.commit()` (lectura directa de código) |
| main.py | ws.router | `include_router(ws.router)` | ✓ WIRED | L58 |
| WS staff/cliente | broadcaster rooms | `_listen` connect/disconnect | ✓ WIRED | e2e runtime recibió 4 eventos en vivo |
| UI panel | providers en vivo | `ref.watch` en dashboard/cocina screens | ✓ WIRED | Sin cambios de contrato — consumers intactos |
| UI app | pedidosSession | `ref.watch` en pedido_estado_screen L77 | ✓ WIRED | sesion.cerrada → `ref.invalidate(sesionProvider)` |
| pubspecs | web_socket_channel ^3.0.3 | ambas apps + stream_channel dev | ✓ WIRED | grep verificado |

### Runtime E2E (stack Docker vivo, usuarios demo reales)

Script Python con httpx-ws dentro del contenedor api — flujo completo con carlos@demo.gri.dev y cocina@demo.gri.dev: **16/16 PASS**

1. login carlos + cocina → 200/200
2. POST /cliente/sesiones GRI-MESA-006 → **201**
3. WS staff conectado → POST /cliente/pedidos → evento `pedido.creado` **en 0.008s** con `seq=258`
4. POST cuenta → evento `sesion.cuenta` (seq=259)
5. mesa→limpieza → evento `mesa.estado` (seq=260); sesión de carlos cerrada (GET actual → 404, anti-zombi OK)
6. mesa→disponible → evento `mesa.estado` (seq=261)
7. **seq monótonos en room staff** [258,259,260,261] ✓
8. Cleanup: pedido e2e → rechazado; BD quedó limpia (0 sesiones abiertas, 0 pedidos enviados)

### Test Suites

| Suite | Resultado | Esperado |
|-------|-----------|----------|
| `docker compose exec api uv run pytest tests/ -q` | **155 passed** (58.71s) | 155/155 ✓ |
| `pytest tests/test_ws.py -v` | **14 passed** — todos los nombrados PASSED | 14/14 ✓ |
| `app_cliente: flutter test` | **41 passed** | 41/41 ✓ |
| `panel_admin: flutter test` | **28 passed** | 28/28 ✓ |
| `flutter analyze` ambas apps | **No issues found** | 0 ✓ |

### Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
|-------------|------------|-------------|--------|----------|
| RT-01 | 07-01, 07-02, 07-03 | Cambios de estado de pedidos llegan a cocina, mesero y cliente sin refrescar | ✓ SATISFIED | Emisiones post-commit + kick-to-refetch panel/cliente + tests en 3 capas + e2e runtime 0.008s |
| RT-02 | 07-01, 07-02 | Cambios de mesa se reflejan en el mapa del panel sin refrescar | ✓ SATISFIED | `mesa.estado` + mesasProvider/statsProvider kick + mesas_ws_test + e2e runtime (2 transiciones en vivo) |
| RT-03 | 07-01, 07-02, 07-03 | Reconexión + re-sincronización al reconectar | ✓ SATISFIED | WsClient ambas apps (backoff/jitter/token fresco/4401→refresh/dedup seq/resync GET/safety net 60s) + ws_client_test en ambas + test_seq_monotonico backend |

Requisitos huérfanos mapeados a Fase 7: ninguno (solo RT-01/02/03).

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
|------|------|---------|----------|--------|
| app_cliente/lib/core/ws_client.dart | 117-123 | Fallo de handshake auth NO dispara refresh inmediato (cae a backoff; recuperación vía safety net 60s) — a diferencia del panel que sí lo trata (`_isAuthHandshakeError`) | ℹ️ Info | Decisión v1 documentada en 07-03 SUMMARY ("comportamiento v1 aceptable, documentado para F9"); ventana ≤60s, sin logout |
| BD demo (gri.categoria/producto) | — | 24+24 filas de residuo de tests (`cat-*`/`prod-*`) en el menú demo | ℹ️ Info | Cosmético, solo DEMO_MODE; sesiones/mesas/pedidos quedaron limpios tras las suites |
| panel_admin/lib/core/ws_client.dart | 8 | Import core→feature (`restaurante_provider.dart`) | ℹ️ Info | Documentado en 07-02 SUMMARY; Dart no impone layering, sin ciclo |

Sin TODO/FIXME/placeholder reales (los matches fueron "TODO el uso..." en comentarios en español). Sin blockers.

### Human Verification Required (no bloqueante — UAT de fase)

### 1. Panel en vivo — humo visual

**Test:** Login cocina@demo.gri.dev en :5173; en otra pestaña (app cliente :5174) abrir sesión QR y pedir
**Expected:** La cola de cocina y el mapa cambian solos, sin refrescar
**Why human:** Render visual en browser; la cadena evento→refetch→stream ya está testeada

### 2. Reconexión visual

**Test:** Con panel/app abiertos en browser → `docker compose restart api`
**Expected:** Reconexión sola (backoff) + re-sincronización sin duplicados ni pantallas desactualizadas
**Why human:** Comportamiento de red real en browser; la lógica está cubierta por tests unitarios

### 3. Banner anti-zombi en la app

**Test:** App cliente con sesión activa → panel pasa la mesa a limpieza
**Expected:** El banner "Estás en la Mesa X" desaparece solo (sesion.cerrada → invalidate)
**Why human:** Confirmación visual del flujo en UI móvil

### Gaps Summary

Sin gaps. Los 3 must-haves verificados con evidencia en 4 capas: código (lectura directa de las 7 emisiones post-commit, WsClient completos, 4 providers kick-to-refetch), tests (155 backend + 41 app + 28 panel, 0 fallos), e2e runtime contra el stack Docker vivo con usuarios demo reales (16/16, evento en 8ms, seq monótonos, sesión cerrada anti-zombi, BD limpia al final) y analyze limpio. Los ítems de verificación humana son humo visual no bloqueante (marcados como UAT de fase por los SUMMARY).

---

_Verified: 2026-08-14T20:05:00Z_
_Verifier: Claude (gsd-verifier)_
