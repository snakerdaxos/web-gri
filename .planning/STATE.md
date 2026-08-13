---
gsd_state_version: 1.0
milestone: v1.0
milestone_name: milestone
status: Phase 2 completa (02-01 + 02-02 ejecutados) — listo para `/gsd-verify-work 2` (UAT) y luego `/gsd-plan-phase 3`
stopped_at: "Phase 2 completa (02-02-PLAN.md ejecutado — roles, multi-tenant, admin platform). Próximo paso: `/gsd-verify-work 2`, luego `/gsd-plan-phase 3` (Modelo de Dominio + Seed)."
last_updated: "2026-08-14T00:10:00.000Z"
last_activity: 2026-08-13 — Phase 2 ejecutada completa (02-01 auth foundation + 02-02 roles/tenant/admin); suite 34/34, verify_auth.sh 19/19
progress:
  total_phases: 9
  completed_phases: 2
  total_plans: 3
  completed_plans: 3
  percent: 22
---

# Estado del Proyecto

## Project Reference

See: .planning/PROJECT.md (updated 2026-08-13)

**Core value:** Un cliente puede sentarse en una mesa, escanear su QR, pedir del menú y recibir su comida — con el pedido fluyendo en tiempo real hacia cocina — sin intermediarios.
**Current focus:** Fase 2 — Autenticación, Roles y Multi-tenant (completada)

## Current Position

Phase: 2 de 9 (Autenticación, Roles y Multi-tenant) — **COMPLETADA**
Plan: 2/2 planes ejecutados (02-01 auth foundation, 02-02 roles/tenant/admin platform)
Status: Phase 2 completa — listo para `/gsd-verify-work 2` (UAT) y luego `/gsd-plan-phase 3`
Last activity: 2026-08-13 — Phase 2 ejecutada completa; 4/6 requisitos de fase (AUTH-03/04, PLAT-02/03) cerrados en 02-02

Progress: [██░░░░░░░░] 22% (2/9 fases)

## Performance Metrics

**Velocity:**

- Total plans completed: 3
- Average duration: ~47 min
- Total execution time: ~140 min

**By Phase:**

| Phase | Plans | Total | Avg/Plan |
|-------|-------|-------|----------|
| 1. Fundación e Infraestructura | 1 | ~45min | ~45min |
| 2. Autenticación, Roles y Multi-tenant | 2 | ~95min | ~47min |

**Recent Trend:**

- Last 5 plans: Phase 2 / Plan 02 (~45min, 2 tasks, 10 files, 3 commits) · Phase 2 / Plan 01 (~50min, 2 tasks, 21 files, 4 commits) · Phase 1 / Plan 01 (~45min, 3 tasks, 16 files, 3 commits)
- Trend: estable (~45-50min/plan); 02-02 reanudado a mitad (RED ya commiteado)

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

### Pending Todos

None yet.

### Blockers/Concerns

- [Fase 9]: research de pasarela MANDATORIO antes de planear (docs Wompi/PayU fueron inaccesibles — HTTP 403).
- [Fase 7]: research de reconexión Flutter WS (replay, heartbeat) antes de planear.
- [Fase 5]: decisiones abiertas de SPEC — auto-confirm vs aprobación manual de reservas; política de cancelación.

## Session Continuity

Last session: 2026-08-13
Stopped at: Phase 2 completa (02-01 + 02-02 ejecutados; AUTH-01..04 + PLAT-02/03 verificados: suite 34/34, verify_auth.sh 19/19 ALL CHECKS PASSED). Próximo paso: `/gsd-verify-work 2` (UAT), luego `/gsd-plan-phase 3` (Modelo de Dominio + Seed).
Resume file: None

**Stack estado actual:** `docker compose up -d` deja corriendo `gri-mysql` (healthy) + `gri-api` (Up, /health=200). Super-admin bootstrap desde .env (admin@gri.dev). Para verificar auth completo: `docker exec -w /app gri-api sh scripts/verify_auth.sh` (curl+jq efímeros: `docker exec -u root gri-api sh -c "apt-get update -qq && apt-get install -y -qq curl jq"`).
