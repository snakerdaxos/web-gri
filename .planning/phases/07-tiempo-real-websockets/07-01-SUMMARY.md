---
phase: 07-tiempo-real-websockets
plan: "01"
subsystem: backend-realtime
tags: [websockets, broadcaster, rooms, seq, realtime, post-commit-events, jwt-ws]
requires:
  - "Phase 2 (decode_token, RolUsuario, async_session_maker)"
  - "Phase 6 (pedido_service, sesion_service, staff_service con commits mapeados)"
provides:
  - "Broadcaster Protocol + InMemoryBroadcaster (rooms restaurant:{id}/user:{id}, seq por room, dead-socket cleanup) + helper emit_event"
  - "/ws/staff?token= (room restaurant:{id} del claim; super_admin requiere ?restaurante_id=) y /ws/cliente?token= (room user:{id})"
  - "6 emisiones post-commit desde services: pedido.creado, pedido.estado, mesa.estado, sesion.abierta, sesion.cuenta, sesion.cerrada"
  - "Contrato de evento {type, restaurante_id, seq, ts, data} para 07-02 (panel) y 07-03 (app cliente)"
affects:
  - "07-02 (panel_admin consume /ws/staff + kick-to-refetch)"
  - "07-03 (app_cliente consume /ws/cliente + WsClient reconexión)"
tech-stack:
  added:
    - "httpx-ws>=0.9.0 (dev-only — tests WS contra stack vivo)"
  patterns:
    - "Auth WS manual con async_session_maker() corto — PROHIBIDO Depends(get_session) en WS (pool exhaustion threat)"
    - "Emisión SIEMPRE post-commit desde services (una sola fuente), await directo secuencial (sin create_task)"
    - "Seq monotónico POR ROOM adjunto por broadcaster.publish; reset al reiniciar (re-sync HTTP cubre)"
    - "Rechazo pre-accept llega como handshake HTTP 403 (el close code no viaja pre-handshake) — cliente trata 4401/403 igual"
key-files:
  created:
    - backend/app/core/broadcaster.py
    - backend/app/api/ws.py
    - backend/tests/test_ws.py
  modified:
    - backend/pyproject.toml (+httpx-ws dev group)
    - backend/app/main.py (include_router(ws.router))
    - backend/app/services/pedido_service.py (2 emisiones)
    - backend/app/services/sesion_service.py (3 emisiones)
    - backend/app/services/staff_service.py (captura zombi pre-UPDATE + 2 emisiones)
    - docker-compose.yml (comentario 1-worker)
decisions:
  - ".value en payloads de evento (str() de enum mixin da 'EstadoPedido.enviado' — verificado) "
  - "Rechazo WS pre-accept documentado como handshake 403 observado; helper acepta ambas formas (Wave 0 resuelta)"
  - "Re-emisiones idempotentes: re-escaneo QR (created=False) y segunda solicitud de cuenta NO emiten"
  - "sesion.cerrada captura usuario_id ANTES del UPDATE anti-zombi (MySQL sin RETURNING, int plano anti-MissingGreenlet)"
  - "RT-01/02/03 NO se marcan completos aún: son end-to-end, 07-02/07-03 cierran el lado cliente"
metrics:
  duration: "~55 min"
  tasks: 2
  tests-new: 14 (6 auth/conexión + 8 eventos end-to-end; suite 141 -> 155)
  tests-total: 155
  completed: 2026-08-14
---

# Phase 7 Plan 01: Backend Tiempo Real (Broadcaster + /ws + 6 emisiones) Summary

Infraestructura WS del backend: abstracción Broadcaster (in-memory v1, Redis-ready para PLT2-02) con rooms `restaurant:{id}` (staff) y `user:{id}` (cliente) + seq monotónico por room, dos endpoints WebSocket con auth JWT manual por query param (sesión de BD corta — nunca `Depends(get_session)`), y las 6 emisiones de negocio estrictamente post-commit en los 3 services existentes — todo verificado end-to-end contra el stack Docker vivo con httpx-ws (POST HTTP → evento <1s).

## Goal

Base de tiempo real que consumen 07-02 (panel) y 07-03 (app cliente): sin esto no hay eventos que escuchar (RT-01/02/03 lado backend).

## Accomplished

- Task 1 (RED a3cd75d → GREEN 323a588): `core/broadcaster.py` (Protocol + InMemoryBroadcaster con rooms/seq/lock/copia list()/dead-cleanup + `emit_event` dual-room) + `api/ws.py` (`/ws/staff` + `/ws/cliente`, `_ws_user` con decode completo + type=access + usuario activo, 4401/4400, receive loop que descarta entrante) + `main.py` wiring + advertencia 1-worker en docker-compose + test_ws.py (6 tests conexión/auth). Wave 0 resuelta: rechazo observado como **handshake HTTP 403** (el close code no viaja pre-accept); documentado en `_assert_ws_rejected`, diseño intacto.
- Task 2 (RED 09d62f7 → GREEN 6e66e00): 6 emisiones post-commit — `pedido.creado`/`pedido.estado` (pedido_service, rooms staff+dueño), `mesa.estado`+`sesion.abierta` (abrir_sesion SOLO created=True), `sesion.cuenta` (dentro del if idempotente), `mesa.estado`+`sesion.cerrada` (set_mesa_estado con captura de zombi_usuario_id ANTES del UPDATE anti-zombi) + 8 tests end-to-end (incl. cross-tenant, seq monotónico, 409-no-emite, idempotencia de emisión).

## Verification

| Check | Resultado |
|---|---|
| `uv run pytest tests/test_ws.py -q` (stack vivo, post `docker compose up -d --build api`) | 14/14 passed |
| Full suite `uv run pytest -q` | **155 passed** (141 baseline + 14, 0 regresiones) |
| 2º run consecutivo suite WS | 14/14 passed (QRs uuid + cleanup finally → sin residuo) |
| Residuo BD tras runs (mesas/restaurantes/sesiones de test) | 0 filas |
| grep `Depends(get_session)` en `app/api/ws.py` | 0 ocurrencias (threat pool) |
| grep `include_router(ws.router)` en `main.py` / `pool_recycle=3600` en `core/db.py` | presentes (W01 ya aplicada — NO tocada, verificado) |
| grep `await emit_event(` pedido=2 / sesion=3 / staff=2 | ✓ (criterio del plan) |
| emisiones SIEMPRE tras commit/refresh (revisión de diff) | ✓ |
| ruff en archivos nuevos/tocados | limpio (B904 pre-existente en sesion_service es de Phase 6 — deferred) |

## Event contract (para 07-02/07-03)

`{"type": "pedido.creado|pedido.estado|mesa.estado|sesion.abierta|sesion.cuenta|sesion.cerrada", "restaurante_id": int|null, "seq": int, "ts": ISO-UTC, "data": {...}}`

- `restaurante_id`: int en eventos del room `restaurant:{id}`; **null** en eventos del room `user:{id}` (contrato).
- `seq` monotónico POR ROOM (independiente por room); reset al reiniciar server → el reconnect client-side resetea lastSeq y re-sincroniza por GET.
- `data` mínimo (ids + estado): estrategia client-side kick-to-refetch, no requiere joins display.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] `.value` en payloads de evento en lugar de `str(enum)`**
- **Found during:** Task 2 (verificado ya en Task 1 con `uv run python -c`)
- **Issue:** `str(EstadoPedido.aceptado)` retorna `'EstadoPedido.aceptado'` (enum mixin `(str, Enum)` usa `__str__` de Enum) — el payload habría llegado como `"EstadoPedido.enviado"` en vez de `"enviado"`.
- **Fix:** `pedido.estado.value` / `body.estado.value` / `EstadoMesa.ocupada.value` en las 6 emisiones.
- **Files:** pedido_service.py, sesion_service.py, staff_service.py
- **Commit:** 6e66e00

**2. [Rule 2 - Hardening] Defensas menores sobre el esqueleto prescriptivo**
- **Found during:** Task 1
- **Issue:** (a) `_listen` con try/except dejaba el disconnect sin garantía ante excepciones no-WebSocketDisconnect; (b) `int(payload["sub"])` sin defensa en el esqueleto (sub malformado → ValueError sin manejar).
- **Fix:** (a) `try/finally` en `_listen` (disconnect garantizado); (b) try KeyError/ValueError → 4401 (mirror de deps/auth.py).
- **Files:** app/api/ws.py
- **Commit:** 323a588

**3. [Rule 1 - Lint] B904/UP017 en código NUEVO**
- ruff del proyecto exige `raise ... from None` en los except de `_ws_user` y alias `datetime.UTC` en broadcaster.
- **Files:** app/api/ws.py, app/core/broadcaster.py — **Commit:** 323a588

### Notas (no desviaciones)

- **Wave 0 (forma del rechazo):** OBSERVADO handshake HTTP 403 pre-accept (uvicorn 0.52.3 + websockets); el close code 4401/4400 NO viaja antes del handshake. El diseño conserva los códigos app-defined (contrato del cliente: "close 4401" y "handshake rechazado durante auth" son el mismo caso → refresh+retry). Tests 3-6 en RED pasaban trivialmente (403 sin ruta == 403 rechazado); el RED quedó anclado en los tests 1-2 (conexión OK) y, en Task 2, en los 6 tests de eventos.
- **Entorno host:** los tests con `db_session` requieren `$env:DB_PASSWORD = <MYSQL_APP_PASSWORD del .env>` antes de pytest (comportamiento documentado desde Phase 1 — verificado con suite existente antes/después).
- **Deferred (out of scope):** `ruff B904` pre-existente en sesion_service.py (código Phase 6 no tocado) → `.planning/phases/07-tiempo-real-websockets/deferred-items.md`.
- **Requisitos:** RT-01/RT-02/RT-03 permanecen Pending — son end-to-end y 07-02/07-03 (mismos IDs en frontmatter) cierran el lado cliente.

## Self-Check: PASSED

- Archivos: broadcaster.py (119 líneas ≥40), ws.py (113 ≥60), test_ws.py (520 ≥150) — FOUND
- Commits: a3cd75d, 323a588, 09d62f7, 6e66e00 — FOUND (git log)
- Suite: 155 passed, 0 regresiones, 2 runs consecutivos WS verdes
