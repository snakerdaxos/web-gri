---
phase: 03-modelo-de-dominio-y-seed-demo
plan: 02
subsystem: backend-seed-demo
tags: [seed, demo, idempotency, lifespan, infr-03, plat-04, demo-mode]
requires:
  - "03-01 (9 tablas de dominio + migración 0002 + db_session fixture)"
  - "Phase 2 auth + ensure_super_admin (lifespan precedent)"
provides:
  - "seed_service.py: gate DEMO_MODE + seed_demo natural-key get-or-create (restaurante + 3 staff + 8 mesas + 4 categorías + 16 productos COP + 2 clientes)"
  - "Lifespan wiring: ensure_super_admin → seed_if_demo_mode (boot automático)"
  - "verify_seed.sh + verify_seed.py: aceptación manual INFR-03 end-to-end"
  - "DEMO_MODE gate verificado en ambas direcciones (True siembra, False no-op)"
affects:
  - "Phase 4 (panel admin): operará sobre restaurante demo con menú y mesas reales desde el primer boot"
  - "Phase 5 (app cliente): descubrirá Restaurante Demo GRI (activo=True) y su menú COP"
  - "Phase 6+ (pedidos/sesiones): las 8 mesas GRI-MESA-001..008 existen para primer QR scan"
tech-stack:
  added: []
  patterns:
    - "Natural-key get-or-create por entidad (email, codigo_qr, nombre, (rest,nombre), (rest,cat,nombre)) — idempotencia sin tabla de tracking"
    - "Gate DEMO_MODE DENTRO del service (defense-in-depth PITFALL 4) — no confiar solo en el caller del lifespan"
    - "Atomicidad: UN solo commit al final de seed_demo + flush() intermedio para asignar IDs sin commit (anti-PITFALL 6)"
    - "Decimal exacto para precios COP (no float/int) — asyncmy devuelve Decimal"
    - "verify_seed.sh delega queries a verify_seed.py (api container no tiene mysql client pero sí Python+SQLAlchemy+asyncmy)"
    - "Scoping por natural keys en tests/verify (codigo_qr LIKE, categoria nombre IN) para evitar contaminación de test_domain_constraints.py"
key-files:
  created:
    - backend/app/services/seed_service.py
    - backend/tests/test_seed.py
    - backend/scripts/verify_seed.sh
    - backend/scripts/verify_seed.py
  modified:
    - backend/app/main.py
decisions:
  - "Gate DEMO_MODE vive dentro del service (seed_if_demo_mode), no en el caller del lifespan — defense-in-depth PITFALL 4"
  - "Idempotencia por natural-key get-or-create en CADA entidad (no tabla de tracking, no delete+reinsert)"
  - "Atomicidad: un solo commit al final; flush() intermedio asigna IDs para FKs dentro de la tx"
  - "Emails @demo.gri.dev (.dev es gTLD real; .local rechazado por email-validator — lección 02-02)"
  - "verify_seed.sh + verify_seed.py como suite combinada (sh wrapper + py workhorse) — api container sin mysql client"
  - "DEMO_PASSWORD=Demo!1234 (demo-only; DEMO_MODE=false en prod lo excluye completamente)"
  - "Restaurante demo con activo=True → aparece en list_restaurantes de Phase 2 sin config extra"
metrics:
  duration: "30 min"
  tasks: 2
  files: 5
  tests-new: 6
  tests-total: 59
  completed: 2026-08-13
---

# Phase 3 Plan 02: Seed Demo Idempotente + Lifespan Wiring Summary

Seed del restaurante demo ("Restaurante Demo GRI") con 3 staff, 8 mesas GRI-MESA-001..008, 4 categorías, 16 productos COP (Decimal exacto) y 2 clientes — gateado por `DEMO_MODE` dentro del service, idempotente por natural-key get-or-create, sembrado automáticamente en el lifespan del API tras `ensure_super_admin`. Cierra PLAT-04 + INFR-03: `docker compose down -v && up -d` deja la plataforma lista para usar sin intervención humana.

## Goal

Cerrar Phase 3 con el seed del restaurante demo de forma idempotente, gateada por DEMO_MODE, dentro del lifespan del API — de modo que `docker compose down -v && up -d --build` entregue la plataforma con esquema migrado + datos demo presentes. Phase 4 (panel admin) y Phase 5 (app cliente) podrán apuntar a un restaurante con menú y mesas reales desde el primer boot.

## Instructions

- CERO dependencias nuevas (todo ya instalado en Phase 1-2).
- Seed idempotente: get-or-create por natural key, commit único al final, reiniciar el stack N veces no duplica nada.
- Gate DEMO_MODE DENTRO del service (defense-in-depth — no confiar solo en el caller del lifespan).
- Restaurante demo prescrito en 03-RESEARCH Pattern 4 (contenido + precios COP exactos).
- Emails @demo.gri.dev (no .local — lección 02-02-SUMMARY).
- NO romper los 53 tests existentes (regression gate).
- NO crear endpoints (Phase 4+).

## Discoveries

- **`app.models` import resolution:** el api container tiene WORKDIR=/app pero al correr `python scripts/verify_seed.py`, Python NO añade /app a sys.path (solo el directorio del script). Fix: `PYTHONPATH=/app` en verify_seed.sh. pytest sí lo resuelve vía pyproject.toml + rootdir.
- **api container no tiene cliente mysql** (imagen slim). verify_seed.sh delega TODA la lógica de queries a verify_seed.py (Python + SQLAlchemy text() + asyncmy). El sh wrapper es POSIX puro + echo "ALL CHECKS PASSED" al final (patrón verify_auth.sh).
- **Test pollution cross-tests:** `test_domain_constraints.py::_demo_restaurante(session)` retorna el PRIMER restaurante en la BD — después del lifespan seed, ese es el restaurante demo (id=1). Los tests de constraints adjuntan sus mesas `GRI-TEST-*` y categorías `cat-XXXXXX` al restaurante demo. Los tests de seed DEBEN scopear por natural keys (`Mesa.codigo_qr.like('GRI-MESA-%')`, `Categoria.nombre.in_(demo_nombres)`) para no contar la contaminación. Mismo fix aplicado a verify_seed.py secciones 3+4.
- **`docker compose up -d --build` (sin `-v`) preserva datos:** el volume `gri_mysql_data` sobrevive recreate. Para simular deploy limpio real (INFR-03) hay que usar `down -v` (wipea el volume).
- **Real container restart idempotency verificado end-to-end:** `docker restart gri-api` → lifespan re-corre `seed_if_demo_mode` → counts idénticos antes/después (8 mesas, 16 productos, 5 demo users). Esto valida INFR-03 en el caso real, no solo en simulación in-process.
- **Decimal exacto confirmado empíricamente:** asyncmy devuelve `Decimal('32000.00')` (no float) para columnas `Numeric(10,2)`. El test `test_seed_crea_menu_cop` hace `assert bandeja.precio == Decimal("32000.00")` y pasa.

## Accomplished

- ✅ **Task 1 (TDD)** (`159859d` RED + `165134d` GREEN): `seed_service.py` con `seed_if_demo_mode(session)` (gate DEMO_MODE dentro del service) + `seed_demo(session)` (orquestación: restaurante → flush → 3 staff → flush → 8 mesas → flush → 4 categorías → flush → 16 productos → flush → 2 clientes → UN commit). Helpers `_get_or_create_*` por natural key (email lower+strip, codigo_qr global, nombre restaurante, (rest,nombre) categoria, (rest,cat,nombre) producto). 6 tests en `tests/test_seed.py` (contenido, menú COP Decimal, idempotencia × 2, gate DEMO_MODE × 2 direcciones).
- ✅ **Task 2** (`22ddbdd`): `main.py` wiring — `await seed_if_demo_mode(session)` en lifespan tras `ensure_super_admin(session)`. `scripts/verify_seed.sh` (POSIX sh wrapper, última línea `echo "ALL CHECKS PASSED"`) + `scripts/verify_seed.py` (8 secciones: restaurante, mesas, categorías, productos, usuarios demo, before-counts, re-seed, after-counts + comparación). `.env` flippeado a `DEMO_MODE=true` (dev stack).
- ✅ **Deviation fix** (`222f412`): scope test_seed queries por demo natural keys (test isolation cross-test_domain_constraints pollution).
- ✅ **Regression gate:** 59 passed (53 baseline + 6 nuevos seed tests).
- ✅ **INFR-03 end-to-end:** `docker compose down -v && up -d --build` → datos demo presentes; `docker restart gri-api` → counts idénticos; `docker exec -w /app gri-api sh scripts/verify_seed.sh` → "ALL CHECKS PASSED".
- ✅ **SC2 end-to-end:** DEMO_MODE=false (temporal) + `docker compose up -d --force-recreate api` → 0 filas nuevas creadas.

## Verification

| Check | Resultado |
|-------|-----------|
| `uv run pytest tests/test_seed.py -v` | 6 passed in 0.40s (DB-direct) |
| `uv run pytest tests/` (suite completa) | 59 passed in 9.95s (53 regression + 6 seed) |
| `docker exec -w /app gri-api sh scripts/verify_seed.sh` | ALL CHECKS PASSED (8 secciones + comparación idempotencia) |
| `docker compose down -v && up -d --build` | Stack up con datos demo (1 restaurante, 8 mesas, 4 cats, 16 productos, 5 usuarios) |
| `docker restart gri-api` (real container restart) | Counts idénticos pre/post: mesas=8 productos=16 demo_users=5 |
| DEMO_MODE=false + `docker compose up -d --force-recreate api` | SC2: 0 filas nuevas (5 → 5 demo users) |
| `seed_service.py` gate check | `if not settings.DEMO_MODE: return None` (línea 100, dentro del service) |
| `seed_service.py` commit count | 1 `await session.commit()` real (línea 330) + 1 mención docstring (anti-PITFALL 6) |
| `seed_service.py` Decimal check | `Decimal("32000.00")` (Bandeja Paisa, línea 73) — exacto COP |
| `seed_service.py` idempotencia natural keys | cada `session.add` precedido por select en helpers `_get_or_create_*` |
| `main.py` wiring | `seed_if_demo_mode` en import (línea 16) + lifespan body (línea 26) tras `ensure_super_admin` |
| `verify_seed.sh` última línea ejecutable | `echo "ALL CHECKS PASSED"` (tras `python scripts/verify_seed.py`) |

## Contenido exacto del seed (PLAT-04)

| Entidad | Count | Detalle |
|---------|-------|---------|
| Restaurante | 1 | "Restaurante Demo GRI" / Colombiana / Cra. 7 #63-44, Bogotá / activo=True |
| Staff | 3 | admin@demo.gri.dev (admin_restaurante), mesero@demo.gri.dev (mesero), cocina@demo.gri.dev (cocina) |
| Mesas | 8 | numeros 1-8, capacidades [2,2,4,4,4,6,6,8], QR GRI-MESA-001..008, estado disponible |
| Categorías | 4 | Entradas(1), Platos Fuertes(2), Bebidas(3), Postres(4) |
| Productos | 16 | Entradas×4 (Patacón $12k, Empanadas $9.5k, Arepa $11k, Sopita $14k), Fuertes×5 (Bandeja $32k, Ajiaco $28k, Lechona $30k, Trout $34k, Sancocho $26k), Bebidas×4 (Limonada $9k, Jugo $8k, Gaseosa $5.5k, Cerveza $12k), Postres×3 (Tres Leches $9.5k, Flan $8.5k, Café $4.5k) |
| Clientes | 2 | carlos@demo.gri.dev, maria@demo.gri.dev (cross-tenant, restaurant_id=NULL) |

## Lifespan boot order (INFR-03)

```
docker compose up
  → CMD Dockerfile: alembic upgrade head              (migraciones — Phase 2)
  → uvicorn arranca
  → lifespan: ensure_super_admin(session)             (Phase 2)
  → lifespan: seed_if_demo_mode(session)              (Phase 3 — gate DEMO_MODE)
       ├─ DEMO_MODE=False → return None (no-op, no toca BD)
       └─ DEMO_MODE=True  → seed_demo(session) → commit único
```

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] verify_seed.sh no podía correr dentro del api container**
- **Found during:** Task 2 (primera ejecución del script)
- **Issue:** El plan prescribía verify_seed.sh DENTRO del api container via `docker exec -w /app gri-api sh scripts/verify_seed.sh`. Pero el container no tiene cliente mysql (imagen slim) ni acceso al socket docker (no puede `docker exec gri-mysql mysql ...`).
- **Fix:** verify_seed.sh (POSIX sh wrapper) delega TODA la lógica de queries a verify_seed.py (Python + SQLAlchemy text() + asyncmy, que SÍ están en el container). PYTHONPATH=/app para que `from app.* import` resuelva. El sh wrapper conserva `echo "ALL CHECKS PASSED"` como última línea ejecutable (patrón verify_auth.sh).
- **Files modified:** backend/scripts/verify_seed.sh, backend/scripts/verify_seed.py (new)
- **Commit:** 22ddbdd

**2. [Rule 1 - Bug] Test pollution cross-tests rompía test_seed counts**
- **Found during:** Task 2 (re-run pytest tras clean deploy)
- **Issue:** `test_domain_constraints.py::_demo_restaurante(session)` retorna el primer restaurante de la BD — tras lifespan seed, ese es el restaurante demo (id=1). Los tests de constraints adjuntan sus mesas `GRI-MESA-TEST-*` y categorías `cat-XXXXXX` al restaurante demo. Los tests de seed contaban esta contaminación (14 mesas en vez de 8, 10 categorías en vez de 4).
- **Fix:** Scopear los queries de test_seed por demo natural keys: `Mesa.codigo_qr.like('GRI-MESA-%')` (no solo restaurant_id) y `Categoria.nombre.in_(demo_nombres)`. Mismo fix aplicado a verify_seed.py secciones 3+4 (categorias y productos).
- **Files modified:** backend/tests/test_seed.py, backend/scripts/verify_seed.py
- **Commit:** 222f412

**3. [Rule 3 - Blocking] PYTHONPATH no resuelto al correr script Python directo**
- **Found during:** Task 2 (segunda iteración de verify_seed.sh)
- **Issue:** `python scripts/verify_seed.py` no encuentra `app.core.db` porque Python añade el directorio del script (scripts/) a sys.path, no el cwd (/app). WORKDIR=/app solo afecta sh, no sys.path de Python.
- **Fix:** `PYTHONPATH=/app python scripts/verify_seed.py` en verify_seed.sh.
- **Files modified:** backend/scripts/verify_seed.sh
- **Commit:** 22ddbdd

## Deferred Issues

Ninguno. Todos los acceptance criteria del plan están verificados.

## Commits

- `159859d` — test(03-02): add failing tests for PLAT-04 seed (6 tests RED)
- `165134d` — feat(03-02): seed_service with DEMO_MODE gate + natural-key idempotency (GREEN)
- `22ddbdd` — feat(03-02): lifespan wiring + verify_seed.sh end-to-end acceptance (INFR-03)
- `222f412` — fix(03-02): scope test_seed queries by demo natural keys (test isolation)

## Relevant Files

- `backend/app/services/seed_service.py` — gate `seed_if_demo_mode` + `seed_demo` (orquestación get-or-create por natural key) + helpers privados `_get_or_create_*`. 340 líneas.
- `backend/app/main.py` — lifespan extende con `await seed_if_demo_mode(session)` tras `ensure_super_admin`.
- `backend/tests/test_seed.py` — 6 tests DB-direct: contenido, menú COP Decimal, idempotencia × 2, gate DEMO_MODE × 2 direcciones.
- `backend/scripts/verify_seed.sh` — POSIX sh wrapper, última línea `echo "ALL CHECKS PASSED"`.
- `backend/scripts/verify_seed.py` — 8 secciones de verificación INFR-03 via SQLAlchemy text().

## Self-Check: PASSED

**Files:** 5/5 FOUND (4 created + 1 modified on disk).
**Commits:** 159859d FOUND, 165134d FOUND, 22ddbdd FOUND, 222f412 FOUND (all in git log).
**Tests:** 59/59 passed (53 regression Phase 1-2 + Plan 01 + 6 new seed tests).
**End-to-end:** verify_seed.sh ALL CHECKS PASSED + real `docker restart gri-api` idempotency confirmed (8/16/5 → 8/16/5).
**SC2:** DEMO_MODE=false + recreate api → 0 filas nuevas (5 → 5 demo users).
