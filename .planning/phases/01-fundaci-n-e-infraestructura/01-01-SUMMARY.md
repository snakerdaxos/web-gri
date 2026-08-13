---
phase: 01-fundaci-n-e-infraestructura
plan: "01"
subsystem: infra
tags: [docker, mysql, fastapi, sqlalchemy, asyncmy, uvicorn, pydantic-settings, uv, walking-skeleton]

# Dependency graph
requires: []
provides:
  - "Stack Docker reproducible: docker compose up levanta MySQL 8.4 + FastAPI/uvicorn"
  - "GET /health que ejecuta SELECT 1 contra MySQL (200 connected | 503 unreachable)"
  - "Engine async SQLAlchemy 2.0 (pool_pre_ping, expire_on_commit=False) + get_session dependency"
  - "Settings parts-based (DB_HOST/PORT/USER/PASSWORD/NAME + DEMO_MODE inerte) con database_url property"
  - "Patrón FastAPI lifespan (engine.dispose al shutdown) — reemplaza @app.on_event deprecado"
  - "Volumen Docker persistente gri_mysql_data; charset utf8mb4 / collation utf8mb4_unicode_ci / tz -05:00"
  - "Layout backend/app/{core,api}/ + tests/ + scripts/ como contrato para fases 2-9"
  - "Wave 0 test framework: pytest + pytest-asyncio + httpx (asyncio_mode=auto)"
affects: [02-autenticacion, 03-modelo-dominio, 04-panel-admin, 05-app-cliente, 07-tiempo-real, 09-pagos-deploy]

# Tech tracking
tech-stack:
  added:
    - "fastapi[standard] 0.141.1"
    - "uvicorn[standard] 0.52.3"
    - "sqlalchemy[asyncio] 2.0.52"
    - "asyncmy 0.2.14 (driver MySQL async, wheels cp312)"
    - "pydantic-settings 2.15.0"
    - "cryptography 50.0.0 (REQ para handshake caching_sha2_password sobre non-TLS)"
    - "pytest 9.1.1 + pytest-asyncio 1.4.0 + httpx 0.28.1 (dev)"
    - "ruff 0.16.3 (dev)"
    - "uv 0.12 como gestor de dependencias + Docker image ghcr.io/astral-sh/uv:0.12"
    - "mysql:8.4 (rolling tag LTS; el tag mysql:8.4-lts NO existe en Docker Hub)"
  patterns:
    - "Config parts-based con property database_url (INFR-02 contract: cambiar .env cambia conexión)"
    - "AsyncSession con expire_on_commit=False (anti-MissingGreenlet)"
    - "create_async_engine con pool_pre_ping=True (anti 'MySQL has gone away')"
    - "FastAPI lifespan context manager (NO @app.on_event deprecado)"
    - "docker-compose depends_on: { service: { condition: service_healthy } } (gate determinista)"
    - "healthcheck mysqladmin ping con $$ escape Compose (container lee su propio env)"
    - "Dockerfile uv from GHCR + bind-mount uv.lock/pyproject.toml (layer caching)"
    - ".dockerignore excluye .venv/ (anti Pitfall 3: venv Windows-host leak al image Linux)"

key-files:
  created:
    - "docker-compose.yml — orquestación mysql:8.4 + api con condition: service_healthy y volumen gri_mysql_data"
    - "backend/Dockerfile — imagen uv from GHCR sobre python:3.12-slim, CMD uvicorn solo (sin alembic)"
    - "backend/.dockerignore — evita leak de .venv/ Windows-host al image Linux"
    - "backend/pyproject.toml — deps runtime (5) + dev (4) + tool.ruff + tool.pytest asyncio_mode=auto"
    - "backend/uv.lock — lockfile reproducible (57 packages)"
    - "backend/app/core/config.py — Settings(BaseSettings) + database_url property"
    - "backend/app/core/db.py — engine + async_session_maker + get_session dep"
    - "backend/app/api/health.py — GET /health -> SELECT 1 -> 200|503"
    - "backend/app/main.py — FastAPI app con lifespan (engine.dispose) + router health + GET /"
    - "backend/tests/conftest.py — async_client fixture (httpx vs http://localhost:8000)"
    - "backend/tests/test_health.py — INFR-02 smoke: /health -> 200 connected"
    - "backend/tests/test_db_config.py — INFR-01 integration: charset, collation, tz, round-trip emoji"
    - "backend/scripts/verify_infra.sh — aceptación manual: 4 checks ALL PASSED"
    - ".env.example — template commiteado (MYSQL_ROOT_PASSWORD, MYSQL_APP_PASSWORD, DEMO_MODE)"
    - ".gitignore — .env, backend/.venv/, caches"
    - ".planning/phases/01-fundaci-n-e-infraestructura/SKELETON.md — contrato de decisiones arquitectónicas"
  modified: []

key-decisions:
  - "Tag mysql:8.4 (NO mysql:8.4-lts que no existe en Docker Hub)"
  - "cryptography añadido como dep runtime (req para caching_sha2_password sobre non-TLS)"
  - "Charset utf8mb4 + collation utf8mb4_unicode_ci + tz -05:00 seteados al server boot (fluye a DB→tabla→columna)"
  - "Alembic DIFIERIDO a Phase 3 (no hay modelos; CMD del Dockerfile es solo uvicorn)"
  - "Config parts-based (DB_HOST/...) sobre DATABASE_URL string (INFR-02 verificable por parte)"
  - "TZ -05:00 (offset) sobre named zone America/Bogota (Bogota no tiene DST desde 1993, equivalente permanente)"
  - "expire_on_commit=False seteado desde Phase 1 (anti MissingGreenlet para Phase 2+)"

patterns-established:
  - "Pattern: Settings parts-based + database_url property (composición de URL en un solo lugar)"
  - "Pattern: AsyncSession con expire_on_commit=False (default del sessionmaker del proyecto)"
  - "Pattern: lifespan context manager para startup/shutdown de FastAPI (no @app.on_event)"
  - "Pattern: get_session() como FastAPI Depends que yields AsyncSession scoped por request"
  - "Pattern: /health ejecuta SELECT 1 y devuelve 200|503 (no raise) — contract para LB y depends_on"
  - "Pattern: docker-compose con condition: service_healthy para gates de startup"
  - "Pattern: .dockerignore SIEMPRE excluye .venv/ y __pycache__/"
  - "Pattern: backend/app/{core,api}/ layout (core=infra, api=routers)"
  - "Pattern: docker-compose.yml en RAÍZ del repo (no en backend/) — coincide con deploy Ubuntu Server"

requirements-completed: [INFR-01, INFR-02]

# Metrics
duration: ~45min
completed: 2026-08-13
---

# Phase 1 Plan 01: Walking Skeleton Summary

**Stack Docker MySQL 8.4 + FastAPI/uvicorn con `/health` ejecutando `SELECT 1`, charset utf8mb4 + tz America/Bogota y conexión 100% por `.env` — las 3 Success Criteria de INFR-01/02 demostradas end-to-end con `verify_infra.sh` ALL CHECKS PASSED.**

## Goal

Levantar el Walking Skeleton de GRI: stack Docker (MySQL 8.4 + FastAPI/uvicorn) corriendo end-to-end, verificado con `GET /health` que ejecuta `SELECT 1` real contra la BD. Establece la base arquitectónica (composición Docker, config parts-based, SQLAlchemy 2 async, layout `backend/app/`) sobre la que todas las fases siguientes se construyen, registrada en SKELETON.md como contrato.

## Performance

- **Duration:** ~45 min (incluye arranque de Docker Desktop + descarga de imágenes base)
- **Tasks:** 3/3 completadas
- **Files created:** 16 (15 commiteados + `.env` gitignored)
- **Commits atómicos:** 3 (uno por task) + 1 pendiente (metadata)

## Accomplished

- **Stack corre end-to-end:** `docker compose up -d` levanta `gri-mysql` (healthy vía mysqladmin ping) y `gri-api` (gateado por `condition: service_healthy`), sin race condition ni crash-loop.
- **`GET /health` responde `200 {"status":"ok","database":"connected"}`** tras ejecutar `SELECT 1` vía asyncmy contra MySQL.
- **Charset/collation/TZ verificados directamente:** `@@character_set_database=utf8mb4`, `@@collation_database=utf8mb4_unicode_ci`, `@@global.time_zone=-05:00`.
- **Round-trip de `'Açaí 🍜 café Bogotá'`** intacto (acentos + emoji de 4 bytes).
- **Persistencia probada:** tras `docker compose restart mysql`, la fila con emoji sigue en la tabla `infra_probe` (volumen `gri_mysql_data`).
- **Env-driven contract (INFR-02):** cambiar `DB_NAME`/`DB_PASSWORD` en compose/.env rompe la conexión → `/health` 503 (documentado en `verify_infra.sh` CHECK 4).
- **Tests Wave 0:** 2/2 verde (`test_health_returns_connected`, `test_db_charset_tz_and_unicode`).
- **Script de aceptación:** `sh backend/scripts/verify_infra.sh` → `ALL CHECKS PASSED` (4 checks).
- **Anti-regresión cumplido:** NO `--default-authentication-plugin`, NO `@app.on_event`, NO `expire_on_commit=True`, NO `build-essential` en Dockerfile, NO `alembic upgrade head` en CMD, `.dockerignore` excluye `.venv/`.

## Task Commits

1. **Task 1: App Python skeleton + tests Wave 0** — `c18474f` (feat) — 15 archivos: pyproject.toml, uv.lock, app/{main,core/config,core/db,api/health}.py, tests/, .gitignore, .env.example
2. **Task 2: docker-compose.yml + Dockerfile** — `cbd0586` (feat) — 5 archivos: docker-compose.yml, Dockerfile, .dockerignore, pyproject.toml (+cryptography), uv.lock. Incluye 2 Rule-1 auto-fixes.
3. **Task 3: verify_infra.sh + SKELETON.md** — `a108832` (feat) — 2 archivos: scripts/verify_infra.sh, SKELETON.md

## Files Created

- `docker-compose.yml` — orquestación mysql:8.4 + api con `condition: service_healthy`, volumen `gri_mysql_data`, healthcheck `mysqladmin ping` con `$$` escape
- `backend/Dockerfile` — imagen `COPY --from=ghcr.io/astral-sh/uv:0.12` sobre `python:3.12-slim`, sin build toolchain, non-root `appuser`, CMD `uvicorn app.main:app`
- `backend/.dockerignore` — excluye `.venv/`, `__pycache__/`, `.env`, `tests/` (Pitfall 3)
- `backend/pyproject.toml` — `requires-python=">=3.12"`, 6 deps runtime (incl. cryptography), 4 dev, `[tool.ruff.lint]` E/F/I/B/UP/ASYNC/S/T20, `[tool.pytest.ini_options] asyncio_mode="auto"`
- `backend/uv.lock` — 57 packages lockfile reproducible (commiteado)
- `backend/app/__init__.py`, `backend/app/core/__init__.py`, `backend/app/api/__init__.py`, `backend/tests/__init__.py` — paquetes vacíos
- `backend/app/core/config.py` — `Settings(BaseSettings)` con DB_HOST/PORT/USER/PASSWORD/NAME + ENVIRONMENT + DEMO_MODE inerte + `database_url` property
- `backend/app/core/db.py` — `engine` (pool_pre_ping, pool_size=10, max_overflow=20, pool_recycle=3600) + `async_session_maker` (expire_on_commit=False) + `get_session` dependency
- `backend/app/api/health.py` — `router` con `GET /health` que ejecuta `text("SELECT 1")` → 200 connected | 503 unreachable
- `backend/app/main.py` — `app` FastAPI con `lifespan` (asynccontextmanager, engine.dispose al shutdown), `include_router(health.router)`, `GET /` → `{"app":"GRI API","environment":...}`
- `backend/tests/conftest.py` — fixture `async_client` (httpx.AsyncClient base_url http://localhost:8000)
- `backend/tests/test_health.py` — INFR-02 smoke: assert status 200 + json database connected
- `backend/tests/test_db_config.py` — INFR-01 integration: usa engine singleton para verificar charset/collation/tz + round-trip `'Açaí 🍜 café Bogotá'`
- `backend/scripts/verify_infra.sh` — bash con `set -euo pipefail`, 4 checks etiquetados [CHECK 1/4]..[CHECK 4/4], termina `ALL CHECKS PASSED`
- `.env.example` — template commiteado (MYSQL_ROOT_PASSWORD, MYSQL_APP_PASSWORD, DEMO_MODE) + nota sobre DB_* en compose
- `.gitignore` — `.env`, `backend/.venv/`, `__pycache__/`, `.pytest_cache/`, `.ruff_cache/`, `*.pyc`, `.idea/`, `.vscode/`
- `.env` — gitignored, dev secrets (dev-root-secret, dev-app-secret, DEMO_MODE=false)
- `.planning/phases/01-fundaci-n-e-infraestructura/SKELETON.md` — registro de decisiones arquitectónicas (Capability, Decisions table, Stack Touched, Out of Scope, Subsequent Slice Plan)

## Verification Results

| Verificación | Resultado |
|---|---|
| `docker compose ps` (ambos Up, mysql healthy) | ✅ `gri-mysql Up (healthy)`, `gri-api Up` |
| `curl http://localhost:8000/health` | ✅ `{"status":"ok","database":"connected"}` HTTP 200 |
| `curl http://localhost:8000/` | ✅ `{"app":"GRI API","environment":"development"}` HTTP 200 |
| `docker exec gri-mysql mysql ... SELECT @@character_set_database, @@collation_database, @@global.time_zone` | ✅ `utf8mb4 / utf8mb4_unicode_ci / -05:00` |
| `cd backend && uv run python -m pytest tests/ -v` | ✅ `2 passed in 1.06s` (test_health + test_db_config) |
| `sh backend/scripts/verify_infra.sh` | ✅ `ALL CHECKS PASSED` (4/4 checks: health, charset/TZ/unicode, persistencia tras restart, env-swap documentado) |
| Anti-regresión grep (no auth-plugin, no on_event, no expire_on_commit=True, no build-essential, no alembic CMD) | ✅ Ningún anti-patrón presente |

## Decisions Made

1. **Tag `mysql:8.4` (no `mysql:8.4-lts`)** — verificado vía Docker Hub API Aug 2026 que el tag `-lts` no existe; `8.4` es el rolling tag de la rama LTS. Documentado en SKELETON.md.
2. **`cryptography` como dep runtime** — asyncmy necesita el paquete para completar el handshake `caching_sha2_password` (default MySQL 8.4) sobre conexiones no-TLS (red interna Docker). Wheels cp312 disponibles, sin toolchain.
3. **Diferimiento de Alembic a Phase 3** — confirmado: no hay modelos, `alembic upgrade head` crashearía. CMD del Dockerfile queda como solo `uvicorn`.
4. **`DEMO_MODE` inerte en config pero wired en compose** — Phase 3 lo leerá para sembrar demo; definirlo ahora estabiliza el shape del `.env` desde día 1.
5. **TZ `-05:00` (offset) + `TZ=America/Bogota` (container)** — Bogota no tiene DST desde 1993, offset es equivalente permanente y evita cargar tz tables.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Tag `mysql:8.4-lts` no existe en Docker Hub**
- **Found during:** Task 2 (primer `docker compose up`)
- **Issue:** El RESEARCH prescribía `image: mysql:8.4-lts`. Docker Hub respondió `not found`. Verificado vía API de tags: los tags válidos son `mysql:8.4` (rolling LTS branch), `mysql:lts`, o patches específicos (`8.4.6`-`8.4.11`).
- **Fix:** Cambiado a `image: mysql:8.4` con comentario explicatorio.
- **Files modified:** `docker-compose.yml`
- **Verification:** `docker compose up -d --build` descargó la imagen y `gri-mysql` llegó a `healthy`.
- **Committed in:** `cbd0586`

**2. [Rule 1 - Bug] Falta paquete `cryptography` para handshake caching_sha2_password**
- **Found during:** Task 2 (verificación `/health` post-build)
- **Issue:** `/health` devolvía `503` con `detail: "'cryptography' package is required for sha256_password or caching_sha2_password auth methods"`. MySQL 8.4 usa `caching_sha2_password` por default; sobre conexiones no-TLS el cliente debe cifrar el password con `cryptography`. El RESEARCH listó asyncmy + SQLAlchemy pero omitió esta dep transitiva requerida.
- **Fix:** Añadido `"cryptography>=43.0"` a `backend/pyproject.toml` deps runtime. `uv lock` añadió cryptography 50.0.0 + cffi 2.1.1 + pycparser 3.0 (todos wheels, sin compilación). Reconstruido solo el servicio `api`.
- **Files modified:** `backend/pyproject.toml`, `backend/uv.lock`
- **Verification:** `curl /health` → `200 {"status":"ok","database":"connected"}`. Tests pytest 2/2 verde.
- **Committed in:** `cbd0586`

---

**Total deviations:** 2 auto-fixed (2 × Rule 1 Bug)
**Impact on plan:** Ambos auto-fixes son correcciones de bugs del RESEARCH/PLAN (no scope creep). El SKELETON.md los documenta como "Corrections to the Original STACK.md / RESEARCH.md" para que fases futuras y el update de STACK.md los incorporen.

## Issues Encountered

- **Docker Desktop no estaba corriendo al inicio.** Resuelto iniciándolo con `Start-Process` y esperando (~0s, ya estaba en startup). No afectó el plan.
- **`test_db_config.py` requiere `DB_*` env vars en el host.** El test importa la `engine` singleton de la app, que se inicializa con defaults (`DB_PASSWORD=""`) si no hay env vars. En el contenedor API, compose las inyecta; en el host, hay que exportarlas manualmente (`DB_HOST=127.0.0.1 DB_USER=gri_app DB_PASSWORD=dev-app-secret DB_NAME=gri`) antes de `uv run pytest`. Esto está alineado con la nota del `.env.example` ("For local non-Docker dev: set DB_HOST=127.0.0.1"). Documentado en SKELETON.md "How to Run / Verify".

## User Setup Required

None — no external service configuration required. Los secrets dev (`dev-root-secret`, `dev-app-secret`) viven en `.env` (gitignored). Para producción (Phase 9) se generarán secrets reales y se configurarán en el Ubuntu Server.

## Next Phase Readiness

- **Listo para Phase 2 (Auth multi-rol + multi-tenant):** el engine, `get_session`, `Settings.database_url`, el layout `backend/app/{core,api}/`, y el Dockerfile uv-based están listos para recibir tablas `restaurante`, `usuario`, `rol`, routers `/auth/login`, JWT (PyJWT), bcrypt.
- **Listo para Phase 3 (Alembic + modelos):** el CMD del Dockerfile se modificará aquí para añadir `alembic upgrade head &&` antes de uvicorn. El pattern async `env.py` está referenciado en 01-RESEARCH.md "Reference: Alembic async env.py".
- **Pre-existing change pendiente:** `.planning/config.json` tiene un diff GSD pre-existente (no relacionado a este plan) que quedó sin commitear — no afecta este plan; el equipo puede commitearlo por separado.

## Relevant Files

- `docker-compose.yml` — orquestación del stack (raíz del repo)
- `backend/Dockerfile` — imagen API uv-based (python:3.12-slim)
- `backend/app/core/config.py` — **INFR-02 contract**: Settings parts-based + database_url
- `backend/app/core/db.py` — engine async + sessionmaker + get_session dep
- `backend/app/api/health.py` — GET /health (SELECT 1 → 200|503)
- `backend/app/main.py` — FastAPI app + lifespan
- `backend/scripts/verify_infra.sh` — aceptación manual (4 checks)
- `.planning/phases/01-fundaci-n-e-infraestructura/SKELETON.md` — contrato arquitectónico para fases 2-9

---
*Phase: 01-fundaci-n-e-infraestructura*
*Plan: 01*
*Completed: 2026-08-13*

## Self-Check: PASSED

- **Files (21/21):** all FOUND (docker-compose.yml, Dockerfile, .dockerignore, pyproject.toml, uv.lock, app/{__init__,main}.py, app/core/{__init__,config,db}.py, app/api/{__init__,health}.py, tests/{__init__,conftest,test_health,test_db_config}.py, scripts/verify_infra.sh, .env.example, .gitignore, SKELETON.md, 01-01-SUMMARY.md)
- **Commits (3/3):** c18474f (Task 1), cbd0586 (Task 2), a108832 (Task 3) — all in `git log`
- **Anti-regression:**
  - `--default-authentication-plugin` in compose `command:` → absent (only in warning comment)
  - `@app.on_event(` decorator in main.py → absent (only in docstring warning)
  - `expire_on_commit=True` in db.py → absent (`expire_on_commit=False` IS present)
  - `build-essential`/`default-libmysqlclient-dev` in Dockerfile RUN → absent (only in comment)
  - `alembic` in Dockerfile CMD → absent (CMD is `uvicorn app.main:app` only)
  - `mysql:8.4-lts` tag → absent (uses `mysql:8.4`)
- **Positive invariants:**
  - `expire_on_commit=False` present, `pool_pre_ping=True` present, `lifespan` + `engine.dispose()` present, `ghcr.io/astral-sh/uv:0.12` present, `condition: service_healthy` present, `gri_mysql_data` volume present, `$$MYSQL_ROOT_PASSWORD` escape present

