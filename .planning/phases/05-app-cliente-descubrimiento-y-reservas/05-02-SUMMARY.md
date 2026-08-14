---
phase: 05-app-cliente-descubrimiento-y-reservas
plan: 02
subsystem: backend-staff-extensions
tags: [staff, reservas, mesas, state-machine, tenant-isolation, existence-hiding]
requires:
  - "05-01 (ReservaRead schema, /cliente/reservas para crear reservas en tests)"
  - "Phase 4 (staff router + get_tenant_scope + _resolve_rid pattern)"
  - "Phase 3 (MESA_TRANSITIONS, validar_transicion, TransicionInvalidaError)"
provides:
  - "GET /staff/reservas?fecha= (tenant-scoped, joins display, default hoy DB-side)"
  - "POST /staff/mesas/{id}/estado (MESA-04: validar_transicion → 409 inválidas; cross-tenant 404)"
  - "MesaEstadoUpdate schema"
affects:
  - "05-03 (panel/app cliente pueden consumir staff reservas del día)"
tech-stack:
  added: []
  patterns:
    - "Existence hiding cross-tenant en writes: mesa ajena == mesa inexistente → 404"
    - "TransicionInvalidaError → 409 mapeada en el router (dominio no decide HTTP)"
    - "expire_all() + get: lectura post-commit-del-API determinística (lección 05-01 refinada)"
key-files:
  created:
    - backend/tests/test_staff_reservas.py
    - backend/tests/test_mesa_estado.py
  modified:
    - backend/app/api/staff.py (GET /reservas + POST /mesas/{id}/estado)
    - backend/app/services/staff_service.py (list_reservas_by_fecha + set_mesa_estado)
    - backend/app/schemas/mesa.py (MesaEstadoUpdate)
decisions:
  - "GET /staff/reservas incluye TODAS las reservas del día (también canceladas): el admin ve el historial y el campo estado discrimina (decisión del plan)"
  - "Default de fecha DB-side func.curdate() (Pitfall 6), nunca date.today() Python-side"
  - "set_mesa_estado valida rid ANTES que la existencia de la mesa (el 404 del restaurante de super_admin no revela mesas de otros tenants)"
  - "Tests de mesa restauran SIEMPRE a disponible (invariant del seed), no al estado de entrada — auto-repara residuo"
metrics:
  duration: "~50 min"
  tasks: 2
  tests-new: 10 (4 staff reservas + 6 mesa estado)
  tests-total: 105
  completed: 2026-08-14
---

# Phase 5 Plan 02: Staff Extensions (GET /staff/reservas + POST mesas estado) Summary

Extensiones operativas del router /staff que cierran el ciclo de la reserva del lado del restaurante: el admin ve las reservas del día (tenant-scoped, con joins display) y marca la mesa ocupada al llegar el cliente aplicando MESA_TRANSITIONS (inválidas → 409, cross-tenant → 404 existence hiding).

## Goal

Cubrir RESV-05 (ver reservas del día + marcar mesa ocupada) y MESA-04 (transiciones de mesa controladas por la state machine, única fuente de verdad).

## Accomplished

- Task 1 (34f6793 RED + b5e5948 GREEN): `staff_service.list_reservas_by_fecha` (tenant filter via `_resolve_rid`, default `func.curdate()` DB-side, joins Restaurante/Mesa para display, incluye canceladas) + `GET /staff/reservas` en el router + 4 tests (filtro fecha, default hoy, cross-tenant con tenant 2 creado vía /admin, super_admin 400/200/404).
- Task 2 (0454d35 RED + da8ec8e GREEN): `MesaEstadoUpdate` schema + `staff_service.set_mesa_estado` (`_resolve_rid` → existence hiding cross-tenant 404 → `validar_transicion("mesa", ...)` → mutación+commit) + `POST /staff/mesas/{mesa_id}/estado` con catch `TransicionInvalidaError` → 409 + 6 tests (3 transiciones válidas, 409 inválida sin drift, 404 cross-tenant, 404 unknown id).

## Verification

| Check | Resultado |
|-------|-----------|
| test_list_by_fecha (solo hoy + joins display) | PASSED |
| test_default_today (default ≡ ?fecha=hoy DB-side) | PASSED |
| test_cross_tenant (tenant 2 no ve reservas del tenant 1; lista propia []) | PASSED |
| test_super_admin_requires_restaurante_id (400 sin param / 200 con / 404 inválido) | PASSED |
| test_reservada_to_ocupada / disponible_to_ocupada / ocupada_to_limpieza | PASSED (200 + estado DB verificado fresco) |
| test_invalid_transition_409 (limpieza→ocupada rechazada, sin drift) | PASSED |
| test_cross_tenant_404 (mesa ajena 404 + sanity admin propio 200) | PASSED |
| Suite completa | 105/105 passed (~24s), 2 runs consecutivos sin residuo |

## Deviations

1. **[Rule 1 - Test bug] Lección 05-01 "rollback + get fresco" era incompleta — gotcha identity map.** En el primer run GREEN de test_mesa_estado, los tests leían el estado STALE del objeto en el identity map de la sesión de test (`expire_on_commit=False` + `get()` identity-map hit no re-queryea; el rollback solo expira si hay tx activa, y tras el commit de `_set_estado` no la hay). El API respondía 200 correcto pero el assert de verificación DB leía el valor que el propio test había seteado. La cascada de restores con valores stale dejó residuo (mesa #1 en limpieza) que rompió tests posteriores y `test_staff_read.py::test_mesas_own_tenant` (invariant seed disponible).
   - **Fix:** `_estado_fresco` y `_restaurar_*` usan `db_session.expire_all()` antes del `get` (SELECT en tx nueva → siempre post-commit-del-API). Los restores terminan SIEMPRE en `disponible` (invariant del seed, igual que `_cleanup_reserva` de 05-01) en lugar de restaurar el estado de entrada — auto-repara residuo de runs fallidos. Se reparó manualmente el residuo existente (limpieza→disponible, transición válida).
   - **Files:** backend/tests/test_mesa_estado.py
   - **Commits:** incluido en da8ec8e
2. **[Rule 3 - Test robustez]** test_cross_tenant_404 (mesas) fuerza `reservada` antes de los POSTs: el sanity check final (admin propio → ocupada) requiere un estado con transición válida a ocupada, y el residuo de runs previos podía dejar limpieza. Setup determinístico independiente del estado de entrada.

## Notas para 05-03 / siguientes

- `GET /staff/reservas` incluye canceladas — el UI del panel filtra por `estado` si quiere solo activas.
- `POST /staff/mesas/{id}/estado` devuelve `MesaRead` completa (id, numero, capacidad, codigo_qr, estado).
- super_admin sobre /staff/reservas sin `?restaurante_id=` → 400 (mismo contrato que /staff/mesas y /staff/stats).
- La lección expire_all() aplica a CUALQUIER test que verifique efectos de commits del API tras haber commiteado su propia sesión (más general que la de 05-01).

## Self-Check: PASSED

- 6/6 artifacts encontrados en disco (3 modificados + 2 tests nuevos + SUMMARY).
- 4/4 commits verificados en git log (34f6793, b5e5948, 0454d35, da8ec8e).
- Suite 105/105 verde.
