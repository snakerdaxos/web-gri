---
phase: 09-pagos-calificaciones-y-deploy
plan: 01
subsystem: backend-pagos
tags: [pagos, wompi, webhook, sandbox, idempotencia, migracion]
requires:
  - "state_machines PAGO/PEDIDO/SESION/MESA transitions (fases 3-6)"
  - "broadcaster emit_event + rooms (fase 7)"
  - "sesion_mesa + pedido.sesion_id (migraciones 0002/0004)"
provides:
  - "migración 0006: pago.sesion_id NOT NULL + pedido_id nullable + transaction_id UNIQUE + tabla pago_event (event_key UNIQUE)"
  - "PagoGateway Protocol + SandboxGateway/WompiGateway + get_pago_gateway()"
  - "POST /cliente/pagos/intencion (monto server-side, idempotencia de intención)"
  - "GET /cliente/pagos/{id} (existence hiding + pedido_ids para calificación)"
  - "POST /webhooks/pago (firma timing-safe + dedup at-least-once + efectos atómicos)"
  - "GET/POST /pagos/sandbox/* (checkout que ejercita el pipeline REAL del webhook)"
  - "helpers conftest: abrir_sesion_con_pedido_servido + borrar_residuo_pago"
affects:
  - "backend/app/models/pago.py (re-shape por sesión)"
  - "backend/tests/test_domain_constraints.py (test pago actualizado)"
  - "backend/app/services/reserva_service.py (fix curdate() — Rule 1)"
  - "docker-compose.yml / .env.example (SANDBOX_MODE + WOMPI_EVENTS_SECRET)"
  - "backend/pyproject.toml (httpx promovido a prod deps)"
tech-stack:
  added:
    - "httpx>=0.28 en [project] dependencies (promovido de dev — WompiGateway.consultar_transaccion)"
  patterns:
    - "Gateway abstracto (Protocol) — sandbox ejercita el MISMO pipeline del webhook público"
    - "Dedup at-least-once por clave derivada txn_id:status (sin event.id en payload Wompi — verificado)"
    - "Efectos atómicos en UNA transacción + emisiones WS post-commit (patrón 07-01)"
    - "Guard por-request 404 + montaje condicional del router sandbox (defensa en profundidad)"
    - "FOR UPDATE sobre el pago en procesar_webhook (serializa webhooks concurrentes)"
key-files:
  created:
    - backend/alembic/versions/0006_pago_sesion_eventos.py
    - backend/app/models/pago_event.py
    - backend/app/core/gateways/__init__.py
    - backend/app/core/gateways/base.py
    - backend/app/core/gateways/wompi_gateway.py
    - backend/app/core/gateways/sandbox_gateway.py
    - backend/app/services/pago_service.py
    - backend/app/schemas/pago.py
    - backend/app/api/pagos.py
    - backend/app/api/webhooks.py
    - backend/tests/test_pagos.py
    - backend/tests/test_webhook_pago.py
    - backend/tests/test_pago_sandbox.py
  modified:
    - backend/app/models/pago.py
    - backend/app/models/__init__.py
    - backend/app/core/config.py
    - backend/app/main.py
    - backend/app/services/reserva_service.py
    - backend/pyproject.toml
    - backend/uv.lock
    - docker-compose.yml
    - .env.example
    - backend/tests/conftest.py
    - backend/tests/test_domain_constraints.py
decisions:
  - "El pago es por SESIÓN (migración 0006): pago.pedido_id queda nullable legacy y ya no se escribe"
  - "Dedup por clave derivada f\"{txn_id}:{status}\" — el payload Wompi NO trae event.id (verificado 09-RESEARCH)"
  - "El sandbox firma eventos reales y pasa por procesar_webhook — NO es un mock del handler"
  - "Re-entrega sobre pago terminal: TransicionInvalidaError → 200 ya-procesado (la fila pago_event de esa entrega se revierte con el rollback — efectos cero)"
  - "FOR UPDATE en el lookup del pago: dos APPROVED concurrentes con txn ids distintos no pueden aplicar efectos doble"
  - "DECLINED no emite WS (sin efectos que sincronizar); el cliente lo descubre por polling"
metrics:
  duration: 53 min
  completed: 2026-08-15
  tests-before: 181
  tests-after: 206
  commits: 8
---

# Phase 9 Plan 01: Backend de Pagos (Wompi/Sandbox + Webhook + Efectos) Summary

Migración 0006 + gateway abstracto de pago + webhook público firmado timing-safe con dedup at-least-once y efectos atómicos (pedidos→pagado, sesión cerrada, mesa→limpieza) + checkout sandbox que ejercita el pipeline REAL del webhook — 206 tests (baseline 181 + 25 nuevos).

## What Was Built

### Task 1 — Migración 0006 + Settings + env dev (TDD)

- **0006_pago_sesion_eventos**: `pago.sesion_id` (NULLable → backfill JOIN pedido → DELETE residuo pre-0004 documentado → NOT NULL, FK + ix_pago_sesion), `pedido_id` → nullable, `transaction_id` VARCHAR(100) NULL UNIQUE, tabla `pago_event` (event_key VARCHAR(150) UNIQUE, pago_id NULL-able FK, payload TEXT, recibido_en, estado default 'procesado'). Downgrade espejo con FK antes que índice (lección 1553).
- **ORM**: Pago re-shapeado por sesión; PagoEvent nuevo exportado en models/__init__.
- **Settings aditivos**: SANDBOX_MODE/WOMPI_* con defaults dev (`dev-events-secret` EXACTO en compose y .env.example); warning fuerte en lifespan si SANDBOX_MODE=true con ENVIRONMENT=production.
- **pyproject**: httpx promovido de dev → [project] dependencies (uv lock sin cambios de resolución — crítico porque el Dockerfile instala sin dev deps y WompiGateway lo necesita en runtime).
- **Test actualizado**: test_pago_referencia_unique construye cadena mesa→sesión→pedido; nuevo test_pago_event_event_key_unique (dedup + pago_id NULL válido).

### Task 2 — Gateways + intención/estado + endpoints (TDD)

- **core/gateways/**: `PagoGateway` Protocol (crear_checkout/consultar_transaccion), `WompiGateway` (URL determinista Web Checkout con signature:integrity URL-encoded + consultar via httpx sin raise), `SandboxGateway` (URL relativa /pagos/sandbox/{ref}), factory `get_pago_gateway()` según SANDBOX_MODE.
- **Firmas exactas del research** (vector conocido testead): firma_integridad = SHA256 concat plana referencia+cents+currency+[exp]+secret; verificar_firma_webhook = dot-paths + timestamp + events_secret + hmac.compare_digest; firmar_evento (público — sandbox/tests).
- **pago_service.crear_intencion**: 404 sin sesión → 409 sin pedidos → 409 pedidos en curso (rechazado excluido) → idempotencia de intención (pago pendiente existente → 200 misma referencia) → monto = SELECT SUM(total de servido) SERVER-SIDE (body jamás trae montos).
- **consultar_estado**: existence hiding (404 ajeno), pedido_ids para el sheet de calificación post-pago (Pitfall 6).

### Task 3 — Webhook público + efectos atómicos + sandbox e2e (TDD)

- **procesar_webhook**: FOR UPDATE sobre el pago (serializa concurrentes) → INSERT pago_event (IntegrityError = re-entrega → router 200 ya-procesado) → referencia desconocida (auditoría pago_id NULL) → fraude monto/currency (alerta 'monto-mismatch' sin efectos) → PENDING (solo transaction_id) / APPROVED (efectos) / DECLINED-ERROR (rechazo sin efectos) / VOIDED (post-aprobado → log sin revertir).
- **aplicar_pago_aprobado**: UNA transacción (pago aprobado + pedidos servido→pagado + sesión cerrada con cerrada_en + mesa ocupada→limpieza) + emisiones WS post-commit (pedido.estado × N → sesion.cerrada → mesa.estado → pago.estado).
- **api/webhooks.py**: POST /webhooks/pago público, firma PRIMERA (401 antes de negocio), IntegrityError/TransicionInvalida → 200 no-op (jamás 500).
- **Sandbox**: GET /{ref} HTML con monto COP + forms; POST aprobar/rechazar construyen evento firmado → MISMO procesar_webhook → redirect 303. Guard por-request 404 + montaje condicional en main.py.
- **e2e verificado**: intención → HTML → aprobar → estado aprobado + DB completa; rechazar sin efectos; SANDBOX_MODE=false → 404 in-process; WS user room recibe pedido.estado/sesion.cerrada/pago.estado.

## Commits

| Task | Commit | Tipo |
| ---- | ------ | ---- |
| T1 RED | bb1dc22 | test: pago test exige sesion_id + pago_event unique |
| T1 GREEN | da45ad8 | feat: migración 0006 + settings Wompi + env |
| T1 (Rule 1) | f6537a4 | fix: reservas validan hoy con curdate() DB-side |
| T2 RED | fab93ab | test: intención server-side + helpers conftest |
| T2 GREEN | ed25c3a | feat: gateways + intención + estado |
| T3 RED | 2b52c6e | test: webhook firmado + dedup + e2e sandbox |
| T3 GREEN | 9e9c94c | feat: webhook público + efectos + sandbox |
| T3 chore | dd08e9c | chore: producto_id en helper + ruff imports |

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Reservas validaban "hoy" con dt.date.today() Python-side (TZ del contenedor UTC)**

- **Found during:** Task 1 (verificación de suite completa)
- **Issue:** Entre 00:00–05:00 UTC la fecha del contenedor API (UTC) difiere de la de la BD (America/Bogota): crear reserva "para hoy" recibía 400 "fecha pasada" y test_default_today fallaba por divergencia curdate()/today(). Bug time-bombed preexistente que bloqueaba el criterio "suite verde ×2" del Task 3.
- **Fix:** `_hoy_db()` con `func.curdate()` (patrón propio del codebase — staff_service línea 762) aplicado en crear_reserva y cancelar_reserva. La doctrina Pitfall 6 ya lo exigía; el test que lo documentaba como "known issue" ahora pasa siempre.
- **Files modified:** backend/app/services/reserva_service.py
- **Commit:** f6537a4

**2. [Rule 2 - Seguridad/Corrección] FOR UPDATE en el lookup del pago dentro de procesar_webhook**

- **Found during:** Task 3 (diseño del pipeline)
- **Issue:** Dos webhooks APPROVED concurrentes con txn ids distintos podían leer ambos estado=pendiente y aplicar efectos doble (validar_transicion es in-memory). El plan no lo especificaba; el códigobase usa FOR UPDATE para exactamente esto (reserva/sesion services).
- **Fix:** `.with_for_update()` en el SELECT del pago — el segundo webhook lee estado post-commit y valida terminal → no-op.
- **Files modified:** backend/app/services/pago_service.py
- **Commit:** 9e9c94c

**3. [Rule 3 - Bloqueo] Residuo de BD de corridas fallidas de desarrollo**

- **Found during:** Task 2 (iteración RED→GREEN)
- **Issue:** Las corridas fallidas previas al fix del helper (MissingGreenlet al construir el ctx) dejaron 2 mesas GRI-MESA-T% + sesiones + pedidos servido del restaurante 1 → corruptión test_seed (esperaba 8 mesas) y test_staff_reportes (sumas de ventas).
- **Fix:** Script one-off de limpieza por QR prefix (orden FK inverso). Los tests finales limpian con borrar_residuo_pago en finally — verificado cero residuo tras 2 corridas completas.
- **Files modified:** (sin archivos del repo — script temporal)

### Notas de implementación (decisiones menores dentro del espíritu del plan)

- `GET /cliente/pagos/{pago_id}` (sin sufijo /estado) — según el action 7 del Task 2 (la tabla del research sugería /estado; el action manda).
- Re-entrega sobre pago terminal con event_key nuevo: la fila pago_event se revierte con el rollback de TransicionInvalidaError (efectos cero, 200 ya-procesado) — fiel al action 1(d) del plan.
- La reconciliación lazy de consultar_estado queda documentada como limitación v1 (sin webhook previo no hay transaction_id; sandbox entrega confiable) — el plan la describe con reprocesar vía Task 3 pero sin transaction_id nunca dispara; se implementa cuando exista Wompi real.

## Test Evidence

- **Suite completa: 206 passed ×2 corridas consecutivas** (baseline 181 + 25 nuevos: 1 constraint + 11 pagos + 13 webhook/sandbox e2e)
- `alembic current` = 0006 (head); DESCRIBE pago: sesion_id NOT NULL, pedido_id YES NULL, transaction_id UNI; pago_event con uq_pago_event_key
- e2e manual de respaldo (script): intención (monto 32000.0 server-side) → checkout HTML ($32.000) → aprobar (303) → estado aprobado + pedido_ids
- Grep anti-patrones: 0 schemas Create en schemas/pago.py; firma-primero en webhooks.py:35; `estado = EstadoPago.aprobado` solo en aplicar_pago_aprobado
- Residuo tras corrida completa: pago=0, pago_event=0, mesas GRI-MESA-T%=0

## Verification of Plan Success Criteria

- **PAGO-02** ✓ intención con monto server-side + checkout_url (tests/test_pagos.py, 11 tests)
- **PAGO-03** ✓ firma timing-safe + dedup pago_event + no-op terminal (tests/test_webhook_pago.py, 8 tests)
- **PAGO-04** ✓ efectos atómicos + WS post-commit (tests/test_pago_sandbox.py e2e + assert WS, 5 tests)
- **Cero regresiones** ✓ 181 preexistentes verdes (incluye fix Rule 1 del test time-bombed)

## Self-Check: PASSED

13/13 archivos creados verificados en disco · 8/8 commits verificados en `git log` · pago_service.py = 410 líneas (min 80 del must_have) · `alembic current` == 0006 · suite 206 ×2 verde.
