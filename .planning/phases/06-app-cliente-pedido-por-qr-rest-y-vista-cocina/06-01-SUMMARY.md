---
phase: 06-app-cliente-pedido-por-qr-rest-y-vista-cocina
plan: 01
subsystem: backend-core-value
tags: [sesion-qr, pedidos, state-machine, cola-cocina, concurrencia, migracion, cuenta]
requires:
  - "05-01/05-02 (require_roles + get_tenant_scope, reserva_service FOR UPDATE + IntegrityError→409, staff router _resolve_rid)"
  - "Phase 3 (models sesion_mesa/pedido con activo_flag computado y snapshot de precio, PEDIDO/MESA/SESION_TRANSITIONS, validar_transicion)"
  - "Phase 3 Plan 02 (seed demo: GRI-MESA-001..008, staff demo, productos COP)"
provides:
  - "POST /cliente/sesiones (QR→sesión; 201/200 idempotente propio/404/409; FOR UPDATE + 2 UNIQUEs + IntegrityError→409)"
  - "GET /cliente/sesiones/actual + POST /cliente/sesiones/actual/cuenta (PAGO-01 idempotente)"
  - "POST /cliente/pedidos (estado=enviado, total server-side, snapshot precio, sin precios del body) + GET /cliente/pedidos/actual (polling)"
  - "GET /staff/pedidos?activos=true (cola FIFO FIELD(estado,...) + badge solicita_cuenta) + POST /staff/pedidos/{id}/estado (matriz rol×transición, 409 antes de 403)"
  - "Anti-zombi: POST /staff/mesas/{id}/estado a limpieza cierra la sesión activa en la misma tx"
  - "Migración 0004: sesion_mesa.solicita_cuenta/solicitada_en + uq_sesion_mesa_usuario_activa + pedido.sesion_id FK + ix_pedido_sesion"
affects:
  - "06-02 (app_cliente: scan_screen + menú/carrito + pedidos_provider + cuenta CTA consumen estos endpoints)"
  - "06-03 (panel_admin: cocina_screen + pedidos_staff_provider con polling clonan el contrato de la cola)"
  - "F9 pagos (pedido.sesion_id + solicita_cuenta son la base del cobro)"
tech-stack:
  added: []
  patterns:
    - "HARD GATE sesión: FOR UPDATE + UNIQUE(mesa_id|usuario_id, activo_flag) + IntegrityError→409 — la BD gana la carrera (extensión del patrón reserva_service)"
    - "Matriz rol×transición: orden de checks 1º validar_transicion→409, 2º TRANSITION_ROLES→403 (la validez nunca se filtra por rol)"
    - "Cola FIFO por etapa: ORDER BY func.field(estado, 'enviado','aceptado','en_preparacion','servido'), created_at ASC"
    - "Total server-side + snapshot: PedidoCreate sin campos de precio; pedido_item.precio_unitario se escribe una vez"
    - "Lección MissingGreenlet: capturar PKs de objetos ORM ANTES de expire_all() (PK de objeto expirado dispara lazy-load síncrono)"
key-files:
  created:
    - backend/alembic/versions/0004_sesion_pedido_cuenta.py
    - backend/app/schemas/sesion.py
    - backend/app/schemas/pedido.py
    - backend/app/services/sesion_service.py
    - backend/app/services/pedido_service.py
    - backend/tests/test_sesion_mesa.py
    - backend/tests/test_cliente_pedidos.py
    - backend/tests/test_cuenta.py
    - backend/tests/test_staff_pedidos.py
  modified:
    - backend/app/models/sesion_mesa.py (solicita_cuenta/solicitada_en + uq usuario)
    - backend/app/models/pedido.py (sesion_id FK + ix_pedido_sesion)
    - backend/app/api/cliente.py (+5 endpoints)
    - backend/app/api/staff.py (+2 endpoints)
    - backend/app/services/staff_service.py (anti-zombi en set_mesa_estado)
    - backend/tests/conftest.py (abrir_sesion + login_staff_demo)
decisions:
  - "Mesa pasa a ocupada AL ABRIR sesión (locked del research); disponible→ocupada y reservada→ocupada válidas, limpieza→409"
  - "Una sesión activa por USUARIO además de por mesa (UNIQUE 0004): A no puede abrir mesa 6 con sesión activa en mesa 5"
  - "Sesión ajena = 404 (existence hiding, spoofing P6); sesión inactiva explícita = 409; producto cross-restaurante = 404"
  - "servido sigue siendo estado activo de la cola (terminal real pagado/rechazado — F9)"
  - "GET /staff/pedidos con activos=false → 400 explícito ('solo true en v1') — contrato honesto vs silencio"
  - "Anti-zombi como UPDATE incondicional (0 filas = no-op) en la misma tx de la transición de mesa"
requirements-completed: [MESA-05, MESA-06, PEDI-01, PEDI-02, PEDI-03, PEDI-04, PEDI-05, PEDI-06, PAGO-01]
metrics:
  duration: 26min
  tasks: 3
  tests-new: 36 (9 sesión + 14 pedidos/cuenta... 11+3 + 13 staff)
  tests-total: 141
  completed: 2026-08-14
---

# Phase 6 Plan 01: Backend Core Value (Sesión QR + Pedidos + Cola Staff + Cuenta) Summary

**Sesión de mesa por QR concurrent-safe (FOR UPDATE + 2 UNIQUEs), pedidos con total server-side y snapshot de precio, cola de cocina FIFO tenant-scoped con matriz rol×transición (409 antes de 403) y solicitud de cuenta idempotente — migración 0004, suite 105→141.**

## Performance

- **Duration:** 26 min
- **Started:** 2026-08-14T13:28:55Z
- **Completed:** 2026-08-14T13:55:07Z
- **Tasks:** 3 (TDD RED→GREEN en las 3)
- **Files modified:** 15 (9 creados + 6 modificados)

## Accomplishments

- **Task 1** (`2546d2e` RED + `ec80f7b` GREEN): Migración 0004 (solicita_cuenta/solicitada_en + UNIQUE(usuario_id, activo_flag) + pedido.sesion_id FK) + `sesion_service.abrir_sesion` (FOR UPDATE, idempotencia propia 200, ajeno 409, una sesión por usuario 409, IntegrityError→409) + POST/GET /cliente/sesiones. **HARD GATE verificado: 2 usuarios concurrentes sobre la misma mesa → exactamente 1×201 + 1×409** (más refuerzo DB: exactamente 1 sesión activa).
- **Task 2** (`75daeed` RED + `738bcc8` GREEN): `pedido_service.crear_pedido` (estado=enviado directo, total server-side Σ(precio×cantidad), snapshot en pedido_item, sesion_id SIEMPRE escrito, una tx) + `pedidos_de_sesion` (newest first para polling) + `solicitar_cuenta` (idempotente: no re-escribe solicitada_en). 404 ajena/cross-restaurante/agotada-no (409), 422 items/cantidad.
- **Task 3** (`3d25446` RED + `63b9cc4` GREEN + `36e9602` fix): `cola_activos` (tenant-scoped via _resolve_rid, FIFO FIELD(estado)+created_at, joins batch sin N+1: items+usuario+sesión) + `TRANSITION_ROLES` (cocina/admin/super_admin todo; mesero solo servido) + `transicionar` (409 ANTES de 403, existence hiding cross-tenant) + **anti-zombi** (mesa→limpieza cierra sesión activa en la misma tx; verificado end-to-end: /cliente/sesiones/actual pasa a 404).

## Verification

| Check | Resultado |
|-------|-----------|
| Suite completa 2× consecutivas | **141 passed, 0 failed** (105 previos + 36 nuevos) |
| HARD GATE concurrencia (2 POST misma mesa) | 1×201 + 1×409 exactos + 1 sesión activa en DB |
| alembic current | 0004 (head), aplicada en boot sin error |
| information_schema | uq_sesion_mesa_usuario_activa (usuario_id, activo_flag) ✓; pedido.sesion_id bigint + fk_pedido_sesion ✓ |
| Snapshot de precio | item mantiene precio_unitario original tras mutar producto.precio |
| 409 antes que 403 | mesero + salto inválido → 409 (no 403) |
| Anti-zombi | limpieza → sesión cerrada_en NOT NULL + estado=cerrada; cliente /actual → 404 |
| Smoke runtime real (curl/PowerShell) | carlos abre GRI-MESA-002 → pedido → cocina ve cola → aceptado → cuenta → badge solicita_cuenta=true en cola ✓ |
| Residuo post-runs | 0 pedidos activos, 0 sesiones activas, 8 mesas seed disponibles |
| grep /cliente sin get_tenant_scope | Solo mención en docstring ("NUNCA get_tenant_scope") |
| PedidoCreate sin campos de precio | Solo sesion_id/items/notas (grep) |

## Task Commits

1. **Task 1: Migración 0004 + sesión QR + HARD GATE** — `2546d2e` (test RED) + `ec80f7b` (feat GREEN)
2. **Task 2: Pedidos cliente + cuenta** — `75daeed` (test RED) + `738bcc8` (feat GREEN)
3. **Task 3: Cola staff + matriz + anti-zombi** — `3d25446` (test RED) + `63b9cc4` (feat GREEN) + `36e9602` (fix cleanup)

## Files Created/Modified

- `backend/alembic/versions/0004_sesion_pedido_cuenta.py` — única migración de la fase (downgrade espejo con FK antes que índice)
- `backend/app/models/sesion_mesa.py` — +solicita_cuenta/solicitada_en + UNIQUE(usuario_id, activo_flag)
- `backend/app/models/pedido.py` — +sesion_id FK nullable + ix_pedido_sesion
- `backend/app/schemas/sesion.py` — SesionCreate/SesionRead (joins display, construido por service)
- `backend/app/schemas/pedido.py` — PedidoCreate (sin precios) / PedidoRead / PedidoItemRead / PedidoEstadoUpdate / PedidoStaffRead (float vía @field_serializer)
- `backend/app/services/sesion_service.py` — abrir_sesion / sesion_actual / solicitar_cuenta
- `backend/app/services/pedido_service.py` — crear_pedido / pedidos_de_sesion / cola_activos / TRANSITION_ROLES / transicionar
- `backend/app/services/staff_service.py` — set_mesa_estado +anti-zombi (UPDATE sesión en misma tx)
- `backend/app/api/cliente.py` — +POST /sesiones, GET /sesiones/actual, POST /sesiones/actual/cuenta, POST /pedidos, GET /pedidos/actual (todos require_roles(cliente))
- `backend/app/api/staff.py` — +GET /pedidos, POST /pedidos/{id}/estado (get_tenant_scope + catch TransicionInvalidaError→409)
- `backend/tests/conftest.py` — +abrir_sesion(client, token, qr) + login_staff_demo(client, email)
- `backend/tests/test_sesion_mesa.py` / `test_cliente_pedidos.py` / `test_cuenta.py` / `test_staff_pedidos.py` — 36 tests de integración

## Decisions Made

- Mesa→ocupada al abrir sesión (no al primer pedido) — fiel al core value (locked del research).
- Sesión ajena→404 (existence hiding, indistinguible de inexistente); sesión inactiva→409; usuario con sesión en otra mesa→409 con el número de mesa en el mensaje.
- `servido` permanece en la cola activa (el terminal real es pagado/rechazado — F9 cobra).
- `activos=false` → 400 explícito en vez de mentir silenciosamente (plan: "solo caso true en v1").
- Cleanup de tests: cerrar sesiones + restaurar mesas a disponible (invariante) + borrar pedidos del usuario (items primero, FK order).

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] `sa.false_()` no existe en SQLAlchemy 2.0**
- **Found during:** Task 1 (boot del contenedor tras la migración — restart loop)
- **Issue:** El plan prescribía `server_default=sa.false_()`; el namespace top-level de SQLAlchemy 2.0 no expone `false_` (es `false()` o `False_`) → AttributeError en alembic → el contenedor no arrancaba
- **Fix:** `server_default=sa.text("0")` (coincide exactamente con el server_default del modelo)
- **Files modified:** backend/alembic/versions/0004_sesion_pedido_cuenta.py
- **Verification:** boot limpio, alembic current = 0004
- **Committed in:** ec80f7b (Task 1 GREEN)

**2. [Rule 1 - Bug] MissingGreenlet al acceder PK de objeto expirado**
- **Found during:** Task 2 (primer run GREEN: test_snapshot_precio + test_producto_agotado_409)
- **Issue:** `db_session.get(Producto, x.id)` tras `expire_all()` — la evaluación de `x.id` sobre el objeto expirado dispara lazy-load síncrono → MissingGreenlet. La lección 05-01 ("rollback+get") era incompleta: el get es seguro solo si la PK es un valor capturado ANTES de expirar
- **Fix:** Capturar `x_id = x.id` antes de cualquier expire_all y usar el int capturado
- **Files modified:** backend/tests/test_cliente_pedidos.py (2 tests)
- **Verification:** 14/14 verdes
- **Committed in:** 738bcc8 (Task 2 GREEN)

**3. [Rule 1 - Bug] Fixture cross-tenant violaba el UNIQUE(usuario_id, activo_flag)**
- **Found during:** Task 3 (RED: 2 tests con sqlalchemy.exc.IntegrityError)
- **Issue:** Los tests creaban la sesión del tenant 2 con el MISMO usuario que ya tenía sesión activa en mesa 1 — la nueva UNIQUE de 0004 (correctamente) la rechazó
- **Fix:** Helper `_crear_pedido_tenant_2` con usuario DEDICADO por fixture (+cleanup en orden FK inverso). Nota: el fallo PROBÓ que la constraint funciona
- **Files modified:** backend/tests/test_staff_pedidos.py
- **Verification:** 13/13 verdes
- **Committed in:** 3d25446 (Task 3 RED, corregido antes del commit)

**4. [Rule 1 - Bug] Leak de pedido en test con assert fallido intermedio**
- **Found during:** Task 3 (análisis de residuo post-suite: 5 pedidos activos en BD de runs fallidos intermedios)
- **Issue:** En test_transicion_invalida_409, el cleanup del segundo setup (`nuevo`) estaba dentro del try DESPUÉS de asserts que pueden fallar (en RED fallaron) → pedido+sesión filtrados
- **Fix:** Nested try/finally con `nuevo_user_id` + limpieza del residuo acumulado en BD (DELETE pedidos activos huérfanos)
- **Files modified:** backend/tests/test_staff_pedidos.py
- **Verification:** 141×2 runs consecutivos + 0 pedidos/sesiones activos + mesas seed disponibles post-run
- **Committed in:** 36e9602

---

**Total deviations:** 4 auto-fixed (4× Rule 1 — 1 código, 3 tests)
**Impact on plan:** Todas necesarias para corrección/determinismo. Cero scope creep; cero deps nuevas.

## Issues Encountered

- PowerShell 5.1 sin heredocs (`python - <<EOF` falla) — edición de archivos vía herramientas Edit en lugar de scripts inline.
- `documentos/` (mockups .docx/.png del usuario) detectado como untracked — contenido preexistente del usuario, fuera de alcance: NO se commiteó ni ignoró.

## User Setup Required

None — sin servicios externos nuevos. El stack Docker existente corre la migración 0004 en boot.

## Next Phase Readiness

- **06-02 (app_cliente)**: contrato completo disponible — POST /cliente/sesiones (201/200/404/409), GET /cliente/pedidos/actual para polling 10s, POST /cliente/sesiones/actual/cuenta. Helpers conftest `abrir_sesion`/`login_staff_demo` reutilizables. Lecciones: capturar PKs antes de expire_all; usuarios dedicados por fixture de sesión (UNIQUE por usuario).
- **06-03 (panel_admin)**: GET /staff/pedidos?activos=true entrega la cola con badge solicita_cuenta; POST /staff/pedidos/{id}/estado con la matriz (mesero → solo servido) — mapear botones por rol.
- Suite 141/141 verde, BD demo prístina (8 mesas disponibles, 0 sesiones/pedidos activos).

## Self-Check: PASSED

10/10 archivos verificados en disco; 7/7 commits verificados en `git log` (2546d2e, ec80f7b, 75daeed, 738bcc8, 3d25446, 63b9cc4, 36e9602).

---
*Phase: 06-app-cliente-pedido-por-qr-rest-y-vista-cocina*
*Completed: 2026-08-14*
