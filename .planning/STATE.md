---
gsd_state_version: 1.0
milestone: v1.0
milestone_name: milestone
status: Phase 3 en progreso (03-01 ejecutado: modelo de dominio + state machines + migración 0002) — próximo: Plan 02 (seed demo)
stopped_at: "Phase 3 / Plan 01 ejecutado (9 tablas dominio + 5 state machines + migración 0002 + db_session fixture + 19 tests). Próximo: Plan 03-02 (seed_service + DEMO_MODE gate)."
last_updated: "2026-08-13T22:55:00.000Z"
last_activity: 2026-08-13 — Phase 3 Plan 01 ejecutado (modelo de dominio, state machines, migración 0002, tests); suite 53/53
progress:
  total_phases: 9
  completed_phases: 2
  total_plans: 4
  completed_plans: 4
  percent: 22
---

# Estado del Proyecto

## Project Reference

See: .planning/PROJECT.md (updated 2026-08-13)

**Core value:** Un cliente puede sentarse en una mesa, escanear su QR, pedir del menú y recibir su comida — con el pedido fluyendo en tiempo real hacia cocina — sin intermediarios.
**Current focus:** Fase 3 — Modelo de Dominio y Seed Demo (en progreso: Plan 01 completo)

## Current Position

Phase: 3 de 9 (Modelo de Dominio y Seed Demo) — **EN PROGRESO**
Plan: 1/2 planes ejecutados (03-01 domain models + state machines + migration 0002)
Status: Phase 3 Plan 01 completo — próximo: Plan 03-02 (seed_service + DEMO_MODE gate + verify_seed.sh)
Last activity: 2026-08-13 — 9 tablas dominio + 5 state machines + migración 0002 + db_session fixture; suite 53/53

Progress: [██░░░░░░░░] 22% (2/9 fases completas + Phase 3 parcial)

## Performance Metrics

**Velocity:**

- Total plans completed: 4
- Average duration: ~38 min
- Total execution time: ~152 min

**By Phase:**

| Phase | Plans | Total | Avg/Plan |
|-------|-------|-------|----------|
| 1. Fundación e Infraestructura | 1 | ~45min | ~45min |
| 2. Autenticación, Roles y Multi-tenant | 2 | ~95min | ~47min |
| 3. Modelo de Dominio y Seed Demo | 1 (de 2) | ~12min | ~12min |

**Recent Trend:**

- Last 5 plans: Phase 3 / Plan 01 (~12min, 2 tasks, 14 files, 2 commits) · Phase 2 / Plan 02 (~45min, 2 tasks, 10 files, 3 commits) · Phase 2 / Plan 01 (~50min, 2 tasks, 21 files, 4 commits) · Phase 1 / Plan 01 (~45min, 3 tasks, 16 files, 3 commits)
- Trend: 03-01 fue rápido (12min) — era declaración de dominio pura, sin endpoints

*Updated after each plan completion*

## Accumulated Context

### Decisions

Decisions are logged in PROJECT.md Key Decisions table.
Recent decisions affecting current work:

- Roadmap: 9 fases derivadas de requirements + research. La fase cliente del research (18 reqs) se dividió en dos journeys verticales: F5 Descubrimiento/Reservas y F6 Pedido por QR (core value).
- Orden dictado por dependencias: REST antes que WebSockets (F6 → F7); pagos aislados al final (F9) por ser el mayor riesgo técnico.
- Conteo corregido: REQUIREMENTS.md decía 47 pero enumera 50 requisitos v1 (error aritmético; traceability actualizada a 50).

**Phase 1 (Walking Skeleton) — decisiones registradas en SKELETON.md:**

- Tag `mysql:8.4` (NO `mysql:8.4-lts` que no existe en Docker Hub — verificado Aug 2026).
- `cryptography` añadido como dep runtime: asyncmy lo requiere para handshake `caching_sha2_password` (default MySQL 8.4) sobre conexiones no-TLS.
- Config parts-based (`DB_HOST/PORT/USER/PASSWORD/NAME`) sobre `DATABASE_URL` string — INFR-02 verificable por parte.
- `expire_on_commit=False` desde Phase 1 (anti MissingGreenlet para Phase 2+).
- `pool_pre_ping=True` + `pool_recycle=3600` (anti "MySQL has gone away").
- Lifespan context manager (NO `@app.on_event` deprecado).
- TZ `-05:00` (offset) + `TZ=America/Bogota` (container) — Bogota no tiene DST desde 1993.
- Alembic DIFIERIDO a Phase 3 (no hay modelos; CMD del Dockerfile es solo `uvicorn`).
- `DEMO_MODE` inerte en config pero wired en compose — Phase 3 lo leerá para sembrar demo.
- Layout `backend/app/{core,api}/` (core=infra, api=routers) + `docker-compose.yml` en raíz.

**Phase 2 (Auth + Multi-tenant) — decisiones clave (detalle en 02-01/02-02 SUMMARY):**

- bcrypt DIRECTO (no passlib — frozen 2020); Alembic adelantado a Phase 2; refresh tokens stateless JWT (HS256 + claim type + jti).
- 5 roles como DB Enum + `restaurant_id` nullable FK (NULL válido para super_admin/cliente).
- **Cross-tenant = 404 (NO 403)** — respuesta uniforme no-existente/inactivo/ajeno; la existencia del recurso jamás se revela.
- **TenantScope como filtro estructural**: toda query staff deriva `WHERE restaurant_id == scope.restaurant_id` de la identidad (JWT), nunca como parámetro del cliente.
- `require_roles(*roles)` dependency factory — única forma de gatear roles; `get_tenant_scope` con defense-in-depth (cliente → 403 aunque el endpoint olvide el gate).
- StaffRole enum Pydantic restringido (admin_restaurante/mesero/cocina) — escalada a super_admin vía API imposible (422).

**Phase 3 (Modelo de Dominio) — decisiones clave (detalle en 03-01 SUMMARY):**

- `codigo_qr` UNIQUE GLOBAL (no por restaurante) — MESA-02/SC3 explícito; el QR escaneado debe resolver a una sola mesa.
- `activo_flag` columna Computed + UNIQUE(mesa_id, activo_flag) para sesión activa única — MySQL no tiene partial indexes; explota semántica NULL ≠ NULL.
- 9 tablas en UNA migración 0002 (cohesión — up/down atómico).
- State machines como módulo PURO (`core/state_machines.py`) — no importa ORM ni FastAPI; tests unitarios en 0.04s.
- CHECK constraints en BD (cantidad>0, estrellas 1-5, num_personas>=1) — MySQL 8.0.16+ enforce; última línea de defensa.
- `Numeric(10,2)` + `decimal.Decimal` end-to-end para dinero (asyncmy devuelve Decimal, no float).
- Snapshot de precio en `pedido_item.precio_unitario` (locked decision — reportes históricos exactos).
- MySQL 8.4 CHECK viol. → `OperationalError` (no `IntegrityError`); UNIQUE viol. → `IntegrityError` (estándar).

### Pending Todos

None yet.

### Blockers/Concerns

- [Fase 9]: research de pasarela MANDATORIO antes de planear (docs Wompi/PayU fueron inaccesibles — HTTP 403).
- [Fase 7]: research de reconexión Flutter WS (replay, heartbeat) antes de planear.
- [Fase 5]: decisiones abiertas de SPEC — auto-confirm vs aprobación manual de reservas; política de cancelación.

## Session Continuity

Last session: 2026-08-13
Stopped at: Phase 3 / Plan 01 ejecutado (9 tablas dominio + 5 state machines + migración 0002 + db_session fixture; MESA-02 cerrado, INFR-03 mitad migraciones completa; suite 53/53). Próximo: Plan 03-02 (seed_service + DEMO_MODE gate + verify_seed.sh → cierra PLAT-04 + SC1/SC2 + mitad seed de INFR-03).
Resume file: None

**Stack estado actual:** `docker compose up -d` deja corriendo `gri-mysql` (healthy) + `gri-api` (Up, /health=200, imagen rebuilt con migración 0002 aplicada automáticamente por CMD). Super-admin bootstrap desde .env (admin@gri.dev). Suite completa: `docker exec -w /app gri-api uv run pytest tests/ -v` (53 tests). Tests SM puros (sin stack): `docker exec -w /app gri-api uv run pytest tests/test_state_machines.py -v` (11 tests en <0.1s).
