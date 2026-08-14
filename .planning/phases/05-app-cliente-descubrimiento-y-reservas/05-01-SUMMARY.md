---
phase: 05-app-cliente-descubrimiento-y-reservas
plan: 01
subsystem: backend-core-public-cliente
tags: [reservas, concurrencia, public-api, cliente-api, for-update, unique-slot]
requires:
  - "Phase 2 (auth deps: get_current_user, require_roles)"
  - "Phase 3 (models reserva/mesa, state machines, migracion base)"
provides:
  - "GET /public/restaurantes + GET /public/restaurantes/{id} (con menu, precio float)"
  - "POST /cliente/reservas (asignacion mesa automatica, FOR UPDATE + IntegrityError 409, auto-confirm)"
  - "GET /cliente/reservas + POST /cliente/reservas/{id}/cancelar (reverte mesa solo si reservada)"
  - "GET/PATCH /cliente/perfil (nombre + password; email immutable)"
  - "Migracion 0003: UNIQUE (mesa_id, fecha, hora_inicio)"
affects:
  - "05-02 (staff extensions consumen ReservaRead y reserva queries)"
  - "05-03 (app cliente consume /public + /cliente)"
tech-stack:
  added: []
  patterns:
    - "/cliente/* usa require_roles(cliente) + get_current_user (get_tenant_scope REJECTS cliente con 403)"
    - "Existence hiding cross-user: reserva ajena = 404"
    - "Slots por hora (turno 60min v1) + UNIQUE slot previene solapamiento"
key-files:
  created:
    - backend/alembic/versions/0003_reserva_unique_slot.py
    - backend/app/api/public.py
    - backend/app/api/cliente.py
    - backend/app/services/public_service.py
    - backend/app/services/reserva_service.py
    - backend/app/services/cliente_service.py
    - backend/app/schemas/menu.py
    - backend/app/schemas/reserva.py
    - backend/tests/test_public_read.py
    - backend/tests/test_reserva.py
    - backend/tests/test_reserva_concurrency.py
    - backend/tests/test_cliente_perfil.py
  modified:
    - backend/app/main.py (routers public/cliente + CORS :5174)
    - backend/app/schemas/perfil.py
    - .env.example
decisions:
  - "Asignacion de mesa automatica server-side (primera mesa con capacidad >= personas y slot libre)"
  - "Auto-confirm: reserva nace confirmada (decision del usuario)"
  - "Cancelar reverte mesa SOLO si reservada (nunca ocupada/limpieza) — Pitfall 4"
  - "precio float via @field_serializer (Pydantic Decimal->string gotcha)"
metrics:
  duration: "~35 min (2 sesiones: una interrumpida por caida de Docker Desktop)"
  tasks: 2
  tests-new: 25 (7 public + 13 reserva + 3 concurrency + 2 perfil... conteo suite: 70 -> 95)
  tests-total: 95
  completed: 2026-08-14
---

# Phase 5 Plan 01: Backend Core (/public + /cliente + concurrencia) Summary

Backend core del ciclo de reservas: endpoints publicos de restaurantes con menu (sin auth), endpoints de cliente autenticados (reservas con asignacion automatica de mesa + cancelacion + perfil), migracion 0003 con UNIQUE slot, y el HARD GATE de concurrencia (10 POSTs simultaneos al mismo slot -> exactamente 1 x 201 + 9 x 409).

## Goal

Cerrar el backend del descubrimiento y reserva: REST-01/02 (publicos), RESV-01..04 (cliente), AUTH-05 (perfil), RESV-02 (concurrencia verificada).

## Accomplished

- Task 1 (a3b853f): migracion 0003 (UNIQUE mesa/fecha/hora_inicio) + /public router + schemas (menu con precio float) + test_public_read (7 tests)
- Task 2 (9795b6a): /cliente router + reserva_service (FOR UPDATE en mesas candidatas + IntegrityError 409 + asignacion automatica + auto-confirm + cancelar con Pitfall 4) + cliente_service (perfil nombre/password, email immutable) + tests (reserva 13, concurrency 3, perfil 2)

## Verification

| Check | Resultado |
|-------|-----------|
| HARD GATE test_reserva_concurrency.py | PASSED (10 POSTs concurrentes -> 1x201 + 9x409) |
| Suite completa | 95/95 passed en ~20s |
| Cancel via curl (runtime real) | 200 + estado cancelada + mesa revertida |
| Existence hiding | reserva ajena -> 404 (test) |
| Decimal->float | test_precio_is_float PASSED |

## Deviations

1. [Rule 1 - Test bug] test_cancel_reverts_mesa fallaba por MySQL REPEATABLE READ: la tx del test mantenia snapshot viejo tras el commit del API. Fix: rollback + get fresco en lugar de refresh. Verificado via curl que el comportamiento del API era correcto antes de tocar el test.
2. [Rule 3 - Env] Docker Desktop cayo durante la ejecucion (interrupcion); reiniciado y stack re-levantado sin perdida de datos (volumen persistente).

## Notas para 05-02 / 05-03

- ReservaRead schema en schemas/reserva.py (base para staff listado)
- reserva.estado usa EstadoReserva (confirmada/cancelada); transicion confirmada->cancelada via validar_transicion
- CORS ya incluye http://localhost:5174
- Demo: restaurante id=1, carlos@demo.gri.dev / Demo!1234 (cliente)
