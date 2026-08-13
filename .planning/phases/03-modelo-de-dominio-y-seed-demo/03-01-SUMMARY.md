---
phase: 03-modelo-de-dominio-y-seed-demo
plan: 01
subsystem: backend-domain-model
tags: [domain, models, state-machines, alembic, mysql-constraints, tests]
requires:
  - "0001_initial (restaurante + usuario)"
  - "Phase 2 auth + tenancy (TenantScope, super_admin bootstrap)"
provides:
  - "9 tablas de dominio (mesa, categoria, producto, pedido, pedido_item, reserva, sesion_mesa, pago, calificacion)"
  - "5 state machines (MESA/PEDIDO/RESERVA/PAGO/SESION_TRANSITIONS + validar_transicion + TransicionInvalidaError)"
  - "db_session fixture (asyncmy directo, reusable por Plan 02 y fases 4-9)"
  - "Constraints en BD: QR único global, sesión activa única, CHECKs, uniques de pago/calificación"
affects:
  - "Phase 4-9 (todas las fases de endpoints descansan sobre estas tablas + state machines)"
  - "Plan 03-02 (seed_service consume los models + db_session fixture)"
tech-stack:
  added: []
  patterns:
    - "Enum + dict[Enum, set[Enum]] state machines como módulo puro (sin ORM/HTTP deps)"
    - "Columna Computed + UNIQUE multi-columna para unique parcial en MySQL (sesion_mesa.activo_flag)"
    - "CHECK constraints en BD (MySQL 8.0.16+ enforce) como última línea de defensa"
    - "Snapshot de precio en pedido_item (precio_unitario Numeric(10,2))"
    - "Numeric(10,2) + decimal.Decimal end-to-end para dinero (asyncmy devuelve Decimal)"
    - "Capturar IDs en variables locales antes de rollback (evita MissingGreenlet en async)"
key-files:
  created:
    - backend/app/core/state_machines.py
    - backend/app/models/mesa.py
    - backend/app/models/menu.py
    - backend/app/models/pedido.py
    - backend/app/models/reserva.py
    - backend/app/models/sesion_mesa.py
    - backend/app/models/pago.py
    - backend/app/models/calificacion.py
    - backend/alembic/versions/0002_domain_tables.py
    - backend/tests/test_state_machines.py
    - backend/tests/test_domain_constraints.py
  modified:
    - backend/app/models/__init__.py
    - backend/alembic/env.py
    - backend/tests/conftest.py
decisions:
  - "codigo_qr UNIQUE GLOBAL (no por restaurante) — MESA-02/SC3 explícito"
  - "activo_flag Computed + UNIQUE(mesa_id, activo_flag) para sesión activa única — MySQL no tiene partial indexes"
  - "9 tablas en UNA migración 0002 (cohesión, up/down atómico)"
  - "CHECK constraints en BD además de validación futura en Pydantic"
  - "db_session fixture usa settings.database_url (resuelve host mysql/localhost según entorno)"
metrics:
  duration: "12 min"
  tasks: 2
  files: 14
  tests-new: 19
  tests-total: 53
  completed: 2026-08-13
---

# Phase 3 Plan 01: Modelo de Dominio + State Machines + Migración 0002 Summary

9 tablas de dominio con constraints en BD (QR único global, sesión activa única via columna Computed, CHECKs de rango, uniques de pago/calificación) + 5 state machines explícitas como módulo puro + migración Alembic 0002 escrita a mano + fixture db_session DB-directa — 53 tests verdes (34 regression + 19 nuevos), 0 dependencias nuevas.

## Goal

Construir toda la capa de datos de negocio de GRI en una sola migración cohesiva, con las state machines como módulo puro testeable en milisegundos, y dejar la defensa permanente en la BD (constraints) para que las fases 4-9 no tengan que preocuparse por invariantes de dominio.

## Instructions

- CERO dependencias nuevas en pyproject.toml (todo ya instalado en Phase 1-2).
- `codigo_qr` UNIQUE GLOBAL (no por restaurante) — requisito explícito MESA-02/SC3.
- Las 9 tablas en UNA migración 0002, orden FK-dependiente.
- State machines: solo módulo + tests unitarios, SIN endpoints.
- NO romper los 34 tests existentes (regression gate).

## Discoveries

- **MySQL 8.4 CHECK violations → `OperationalError`, NO `IntegrityError`.** asyncmy devuelve error 3819 (ER_CHECK_CONSTRAINT_VIOLATED) que SQLAlchemy mapea a `OperationalError`. Las UNIQUE violations sí son `IntegrityError`. Los tests de CHECK capturan ambos: `CHECK_VIOLATION = (IntegrityError, OperationalError)`.
- **Tras `rollback()`, SQLAlchemy expira TODOS los objetos de la sesión** (incluso con `expire_on_commit=False`). Acceder a atributos ORM post-rollback dispara lazy-load → `MissingGreenlet` en async. Solución: capturar IDs en variables locales ANTES de cualquier rollback.
- **`pool_pre_ping=True` en la fixture db_session causa `MissingGreenlet` post-rollback** — el ping intenta hacer IO en path sync. Removido (no necesario para tests).
- **El contenedor API no tiene volume mount** — el código se bakea en la imagen. Para iteración rápida se usó `docker cp` + `docker exec`; el `docker compose up -d --build` final persiste los cambios.
- **`alembic downgrade base && upgrade head` wipea el super_admin bootstrap** (la BD queda vacía). Tras el roundtrip de validación, fue necesario `docker restart gri-api` para que el lifespan re-cree el super_admin.
- **db_session debe usar `settings.database_url`** (no localhost hardcodeado): dentro del contenedor el host MySQL es `mysql` (Docker DNS), no `localhost`. settings.DB_HOST resuelve correctamente en cada entorno.
- **Pydantic v2 + Decimal**: asyncmy devuelve `decimal.Decimal` para columnas `Numeric(10,2)` — exacto COP, sin drift de centavos. Confirmado empíricamente.

## Accomplished

- ✅ **Task 1** (`a232ca1`): 7 archivos de models (mesa, menu=categoria+producto, pedido=pedido+pedido_item, reserva, sesion_mesa, pago, calificacion) + `core/state_machines.py` (módulo puro: 5 dicts de transiciones + `validar_transicion` + `puede_transicionar` + `TransicionInvalidaError`) + `models/__init__.py` extendido + `alembic/env.py` con imports de los 7 módulos nuevos.
- ✅ **Task 2** (`1cdd9d7`): Migración `0002_domain_tables.py` (9 tablas en orden FK-dependiente, todos los constraints con nombres explícitos, upgrade/downgrade limpio) + fixture `db_session` en conftest.py + `test_state_machines.py` (11 unitarios puros) + `test_domain_constraints.py` (8 DB-direct: QR único, sesión activa, CHECKs cantidad/estrellas/num_personas, pago referencia, calificación unique).
- ✅ **Regression gate**: 34 tests Phase 1-2 + 19 nuevos = 53 passed, 0 failed.
- ✅ **Docker rebuild**: `docker compose up -d --build` exitoso, CMD aplicó migración automáticamente, API arrancó limpio.

## Verification

| Check | Resultado |
|-------|-----------|
| `uv run pytest tests/test_state_machines.py` | 11 passed in 0.04s (puros, sin stack) |
| `uv run pytest tests/test_domain_constraints.py` | 8 passed in 0.55s (DB-direct) |
| `uv run pytest tests/` (suite completa) | 53 passed in 12.29s |
| `alembic upgrade head` | Clean (0001 → 0002) |
| `alembic downgrade base && alembic upgrade head` | Idempotente (roundtrip limpio) |
| `SHOW TABLES` | 11 tablas de dominio + alembic_version + infra_probe |
| `state_machines.py` pure module | 0 imports de sqlalchemy/fastapi |
| `0002_*.py` 6 nombres críticos | uq_mesa_codigo_qr, uq_sesion_mesa_activa, uq_pago_referencia, uq_calificacion_pedido, ck_pedido_item_cantidad_positiva, ck_calificacion_estrellas_rango — todos presentes |

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] CHECK constraint violations lanzan OperationalError, no IntegrityError**
- **Found during:** Task 2 (test_domain_constraints.py)
- **Issue:** El plan y research prescribían `pytest.raises(IntegrityError)` para CHECKs. MySQL 8.4 + asyncmy mapea el error 3819 (ER_CHECK_CONSTRAINT_VIOLATED) a `OperationalError`, no `IntegrityError`.
- **Fix:** Definido `CHECK_VIOLATION = (IntegrityError, OperationalError)` y usado en los 3 tests de CHECK. UNIQUE/FK violations siguen usando `IntegrityError` (correcto).
- **Files modified:** backend/tests/test_domain_constraints.py
- **Commit:** 1cdd9d7

**2. [Rule 3 - Blocking] db_session fixture usaba localhost:3306 pero tests corren dentro del contenedor**
- **Found during:** Task 2 (ejecución inicial de tests DB-direct)
- **Issue:** El plan hardcodeaba `localhost:3306` en la URL de la fixture. No hay `uv` en el host, los tests corren via `docker compose exec api` → dentro del contenedor el host MySQL es `mysql` (Docker DNS), no `localhost`.
- **Fix:** La fixture usa `settings.database_url` que resuelve el host correcto según el entorno (DB_HOST=mysql en compose, localhost en host directo).
- **Files modified:** backend/tests/conftest.py
- **Commit:** 1cdd9d7

**3. [Rule 1 - Bug] MissingGreenlet al acceder atributos ORM post-rollback**
- **Found during:** Task 2 (test_una_sesion_activa_por_mesa)
- **Issue:** Tras `rollback()`, SQLAlchemy expira todos los objetos (incluso con `expire_on_commit=False`). Acceder a `r.id` después de un rollback dispara lazy-load → `MissingGreenlet` en async SQLAlchemy.
- **Fix:** Todos los tests capturan IDs en variables locales (`r_id = r.id`) antes de cualquier operación que pueda llevar a rollback.
- **Files modified:** backend/tests/test_domain_constraints.py
- **Commit:** 1cdd9d7

**4. [Rule 1 - Bug] pool_pre_ping causaba MissingGreenlet en la fixture**
- **Found during:** Task 2 (test_una_sesion_activa_por_mesa, intento inicial)
- **Issue:** `pool_pre_ping=True` en `create_async_engine` intenta hacer un ping sincrónico al checkout de conexión post-rollback, chocando con el path async.
- **Fix:** Removido `pool_pre_ping=True` (no necesario para tests — conexiones frescas cada vez).
- **Files modified:** backend/tests/conftest.py
- **Commit:** 1cdd9d7

## Deferred Issues

Ninguno. Todos los acceptance criteria del plan están verificados.

## Commits

- `a232ca1` — feat(03-01): domain models + state machines module
- `1cdd9d7` — feat(03-01): migration 0002 + db_session fixture + domain tests

## Relevant Files

- `backend/app/core/state_machines.py` — módulo PURO: 5 dicts de transiciones + validar_transicion + TransicionInvalidaError. Phase 5/6 importan validar_transicion() y traducen a 409.
- `backend/app/models/mesa.py` — Mesa + EstadoMesa. codigo_qr UNIQUE GLOBAL.
- `backend/app/models/sesion_mesa.py` — SesionMesa + EstadoSesion. activo_flag Computed + UNIQUE(mesa_id, activo_flag) = una sesión activa por mesa.
- `backend/app/models/pedido.py` — Pedido + PedidoItem + EstadoPedido. Snapshot de precio + CHECK cantidad > 0.
- `backend/alembic/versions/0002_domain_tables.py` — 9 tablas en orden FK-dependiente, constraints con nombres explícitos, upgrade/downgrade limpio.
- `backend/tests/conftest.py` — db_session fixture (settings.database_url) + _read_env_var helper.
- `backend/tests/test_state_machines.py` — 11 unitarios puros (sin DB, <0.1s).
- `backend/tests/test_domain_constraints.py` — 8 DB-direct: QR único, sesión activa, CHECKs, uniques pago/calificación.

## Self-Check: PASSED

**Files:** 14/14 FOUND (all created + modified files exist on disk).
**Commits:** a232ca1 FOUND, 1cdd9d7 FOUND (both task commits in git log).
**Tests:** 53/53 passed (34 regression + 19 new).
**Migration:** 0002 applied, current revision = 0002 (head), roundtrip clean.
