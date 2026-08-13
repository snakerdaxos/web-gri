# Walking Skeleton — GRI

**Phase:** 1 — Fundación e Infraestructura
**Generated:** 2026-08-13
**Plan:** 01-01-PLAN.md (Wave 1)

---

## Capability Proven End-to-End

Tras `docker compose up -d`, `GET /health` responde `200` con `{"status":"ok","database":"connected"}`, demostrando que la API FastAPI (en un contenedor Docker) alcanza MySQL 8.4 (en otro contenedor), conectados por variables de entorno, con charset `utf8mb4` + collation `utf8mb4_unicode_ci` + timezone `-05:00` (America/Bogota). El `SELECT 1` que ejecuta `/health` recorre: FastAPI → Depends(get_session) → async_sessionmaker → AsyncEngine (mysql+asyncmy) → red interna Docker → MySQL.

Esto prueba la capability mínima sobre la que se construyen todas las fases siguientes: **una API puede hablar con una BD, configurada 100% por entorno, en contenedores reproducibles.**

---

## Architectural Decisions

| Decisión | Elección | Justificación (vinculada al contrato del Walking Skeleton) |
|----------|----------|------------------------------------------------------------|
| **Framework web** | FastAPI 0.141 + uvicorn[standard] | Async nativo, WebSocket-ready para Phase 7 (pedidos en tiempo real), OpenAPI automático, lifespan context manager (no el `@app.on_event` deprecado). uvicorn[standard] trae uvloop + httptools + websockets. |
| **Data layer** | MySQL 8.4 LTS + SQLAlchemy 2.0 async + asyncmy 0.2.14 | MySQL 8.4 LTS hasta Abr 2032. SQLAlchemy 2.0 con `Mapped[T]` y AsyncSession. asyncmy sobre aiomysql (5x más rápido, wheels cp312 manylinux — sin toolchain C). |
| **Auth plugin** | caching_sha2_password (default MySQL 8.4) | NO se pasa `--default-authentication-plugin` al contenedor (removido en 8.4). El cliente (asyncmy) requiere `cryptography` para completar el handshake sobre conexiones no-TLS (red interna Docker). |
| **Config** | pydantic-settings parts-based (DB_HOST/PORT/USER/PASSWORD/NAME + DEMO_MODE inerte) con `.env` | INFR-02 contract: cambiar `.env`/compose cambia la conexión sin tocar código. Una property `database_url` compone la URL `mysql+asyncmy://...?charset=utf8mb4`. |
| **Deployment target** | Docker Compose en Ubuntu Server | Dev ahora (Docker Desktop); prod en Phase 9 añade nginx + TLS y quita el port 3306 expuesto. `depends_on: { mysql: { condition: service_healthy } }` gatea el arranque. |
| **Directory layout** | `backend/app/{core,api}/` | `core/` = config + db (infraestructura); `api/` = routers (endpoints). `tests/` al nivel de `app/`. `scripts/` para tooling. `docker-compose.yml` en la RAÍZ del repo (no en backend/) — coincide con el deploy de Ubuntu Server. |
| **Dependency mgmt** | uv 0.12 + uv.lock commiteado | 10-100x más rápido que pip. Lockfile reproducible. Dockerfile usa `COPY --from=ghcr.io/astral-sh/uv:0.12` + `uv sync --locked --no-dev`. |
| **Test framework** | pytest + pytest-asyncio + httpx (asyncio_mode="auto") | Smoke tests contra stack corriendo. `async_client` fixture apunta a `http://localhost:8000`. `test_db_config` reutiliza la engine singleton. |
| **Charset / TZ** | `--character-set-server=utf8mb4 --collation-server=utf8mb4_unicode_ci --default-time-zone=-05:00` + `TZ=America/Bogota` | utf8mb4 desde server boot fluye a DB→tabla→columna (evita error 1366 en emojis). `-05:00` ≡ America/Bogota permanentemente (sin DST desde 1993). |
| **Engine pool** | `pool_pre_ping=True`, `pool_size=10`, `max_overflow=20`, `pool_recycle=3600`, `expire_on_commit=False` | `pool_pre_ping` detecta "MySQL has gone away". `expire_on_commit=False` previene `MissingGreenlet` en async. |
| **Non-root container** | `useradd --uid 1000 appuser` + `USER appuser` | Higiene de seguridad: el proceso API no corre como root dentro del contenedor. |

---

## Stack Touched in Phase 1

- [x] **Scaffold Python** — `backend/` con `pyproject.toml` (uv), `app/{core,api}/`, `tests/`
- [x] **Routing real** — `GET /` y `GET /health` (este último ejecuta `SELECT 1`)
- [x] **Database read real** — `SELECT 1` vía asyncmy contra MySQL 8.4
- [x] **Deployment local** — `docker compose up -d` levanta mysql + api con gate de healthcheck
- N/A **UI** — Esta fase no tiene UI. La app cliente (móvil) llega en Phase 5 y el panel admin (web) en Phase 4.

---

## Key Files

| Archivo | Rol |
|---------|-----|
| `docker-compose.yml` | Orquestación mysql:8.4 + api con `depends_on: condition: service_healthy` y volumen `gri_mysql_data` |
| `backend/Dockerfile` | Imagen API uv from GHCR sobre `python:3.12-slim`, sin build toolchain, CMD = `uvicorn` solo |
| `backend/.dockerignore` | Evita que `.venv/` Windows-host se copie al image Linux (Pitfall 3) |
| `backend/app/core/config.py` | `Settings(BaseSettings)` parts-based + `database_url` property. **INFR-02 contract.** |
| `backend/app/core/db.py` | `engine` (pool_pre_ping) + `async_session_maker` (expire_on_commit=False) + `get_session` dep |
| `backend/app/api/health.py` | `GET /health` → `SELECT 1` → 200/503 |
| `backend/app/main.py` | `FastAPI` app con `lifespan` (dispose engine al shutdown) + router health |
| `backend/tests/conftest.py` | `async_client` fixture (httpx vs stack corriendo) |
| `backend/tests/test_health.py` | INFR-02 smoke: `/health` → 200 `database: connected` |
| `backend/tests/test_db_config.py` | INFR-01 integration: charset, collation, tz, round-trip `'Açaí 🍜 café Bogotá'` |
| `backend/scripts/verify_infra.sh` | Aceptación manual: 4 checks (health, charset/TZ/unicode, persistencia, env-swap) |
| `.env.example` | Template commiteado (MYSQL_ROOT_PASSWORD, MYSQL_APP_PASSWORD, DEMO_MODE) |
| `.gitignore` | Excluye `.env`, `backend/.venv/`, caches |

---

## Corrections to the Original STACK.md / RESEARCH.md (applied during execution)

1. **`mysql:8.4-lts` tag does NOT exist on Docker Hub.** Verified via the registry tags API Aug 2026 — the valid rolling tag for the 8.4 LTS branch is **`mysql:8.4`** (or `mysql:lts`). The compose file uses `mysql:8.4`.
2. **`cryptography` package is required** for the `caching_sha2_password` handshake over non-TLS connections. The RESEARCH listed asyncmy + SQLAlchemy but missed that MySQL 8.4's default auth plugin needs `cryptography` on the client side. Added to `backend/pyproject.toml` (wheels available — no toolchain).

---

## How to Run / Verify

```bash
# 1. Levantar el stack (desde la raíz del repo)
docker compose up -d --build

# 2. Esperar ~35s y verificar ambos healthy
docker compose ps   # gri-mysql (healthy), gri-api (Up)

# 3. Health check
curl -s http://localhost:8000/health
# -> {"status":"ok","database":"connected"}

# 4. Tests Wave 0 (devel local: export DB_HOST=127.0.0.1 DB_USER=gri_app
#    DB_PASSWORD=dev-app-secret DB_NAME=gri primero, porque el test
#    test_db_config importa la engine singleton que se conecta al mysql
#    publicado en localhost:3306)
cd backend && uv run python -m pytest tests/ -v
# -> 2 passed

# 5. Aceptación manual completa (4 checks: health, charset/TZ/unicode,
#    persistencia tras restart, env-swap documentado)
sh backend/scripts/verify_infra.sh
# -> ALL CHECKS PASSED
```

---

## Out of Scope (Deferred to Later Phases)

| Tema | Fase |
|------|------|
| Auth / JWT / roles (super-admin, admin, mesero, cocina, cliente) / multi-tenant | Phase 2 |
| Alembic migrations + modelos de dominio (mesa, pedido, reserva, producto, ...) + seed DEMO_MODE | Phase 3 (aquí se modifica el CMD del Dockerfile para añadir `alembic upgrade head &&`) |
| Panel admin UI (Flutter Web) | Phase 4 |
| App cliente móvil (Flutter) — Discover/Reservas | Phase 5 |
| App cliente — QR ordering REST + vista cocina | Phase 6 |
| WebSockets tiempo real (pedidos, estados de mesa) | Phase 7 |
| Panel admin CRUD + reportes | Phase 8 |
| Pagos online (Wompi/PayU Colombia) + calificaciones + deploy Ubuntu Server (nginx + TLS, remover port 3306) | Phase 9 |
| Redis Pub/Sub (escalar WebSockets a múltiples instancias API) | v2 (PLT2-02) |

---

## Subsequent Slice Plan

- **Phase 2** = Auth multi-rol + multi-tenant sobre este skeleton. Añade tablas `restaurante`, `usuario`, `rol`, routers `/auth/login`, JWT (PyJWT), bcrypt hashing. Reutiliza `engine`, `get_session`, `Settings.database_url` intactos.
- **Phase 3** = Modelo de dominio + Alembic. Scaffold `alembic/` con `env.py` async (pattern en 01-RESEARCH.md "Reference: Alembic async env.py"). El CMD del Dockerfile se modifica aquí: `CMD ["sh","-c","alembic upgrade head && uvicorn ..."]`. Lee `DEMO_MODE` para sembrar el restaurante demo.
- **Phase 4** = Panel admin UI (Flutter Web) — consume los endpoints de Phase 2/3.
- **Phase 5–6** = App cliente móvil (Flutter).
- **Phase 7** = WebSockets (`uvicorn[standard]` ya trae `websockets`; solo falta el handler).
- **Phase 8** = Panel admin CRUD + reportes.
- **Phase 9** = Pagos + deploy Ubuntu Server (nginx reverse proxy + TLS, remover exposición del port 3306).
