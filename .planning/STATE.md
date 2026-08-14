---
status: Phase 4 en progreso - Plan 04-01 (backend staff endpoints + CORS) ejecutado; siguiente: 04-02 (panel Flutter Web)
stopped_at: "Completed 04-01-PLAN.md (Wave 1 backend: GET /staff/mesas + GET /staff/stats tenant-scoped + CORSMiddleware; suite 70/70)"
current_phase: 4
updated: 2026-08-14
last_activity: 2026-08-14 - Plan 04-01 ejecutado completo (2 tasks, 2 commits); proximo: ejecutar 04-02-PLAN.md (panel admin Flutter)
---

# STATE

## Project Reference

See: .planning/PROJECT.md (updated 2026-08-13)

**Core value:** Un cliente puede sentarse en una mesa, escanear su QR, pedir del menu y recibir su comida en tiempo real sin intermediarios.
**Current focus:** Phase 4 - Panel Admin Solo Lectura (login staff + dashboard + mapa de mesas)

## Recent Activity

### 2026-08-14 — Plan 04-01 completo (Wave 1 backend)
- GET /staff/mesas + GET /staff/stats tenant-scoped via _resolve_rid (param restaurante_id IGNORADO para staff; super_admin requiere param -> 400, desconocido -> 404)
- CORSMiddleware con origins explicitos via CORS_ORIGINS (default http://localhost:5173, allow_credentials, sin wildcard); docker-compose ahora interpola CORS_ORIGINS
- Stats: 1 GROUP BY por estado; reservas_hoy con func.curdate() (DB-side Bogota); pedidos_activos excluye borrador y terminales
- Suite: 59 -> 70 tests (8 staff + 3 cors), cero regresiones, cero deps nuevas, cero migraciones
- Commits: f7b42f6 (feat), f9a6368 (test)
- Desviaciones: docker-compose CORS_ORIGINS passthrough (Rule 2); tests deterministas ante residuo GRI-TEST-* acumulable de test_domain_constraints (subset seed + invariantes + DB cross-check)
- NOTA requisitos: ADMN-01/ADMN-02 NO se marcan completos en REQUIREMENTS.md todavia — son requisitos de PANEL (frontend); completan con 04-02

### 2026-08-13 — Phase 3 completa
- 03-01: 9 tablas de dominio + migracion 0002 + 5 state machines (modulo puro) + fixture db_session + tests constraints (MESA-02 QR global unique, sesion activa unica, CHECKs)
- 03-02: seed_service con gate DEMO_MODE + idempotencia natural-key + lifespan wiring + verify_seed.sh end-to-end (INFR-03)
- Suite: 59/59 passed al cierre de fase
- Commits: a232ca1, 1cdd9d7, 7997a73, 159859d, 165134d, 22ddbdd, 222f412, 5b7619f

## Progress

Status: Phase 4 en progreso (1/2 planes)

### Phases
- Phase 1: COMPLETE (verified passed)
- Phase 2: COMPLETE (verified passed)
- Phase 3: EXECUTED (verification pending)
- Phase 4: IN PROGRESS - 04-01 ejecutado (backend listo); 04-02 (panel Flutter) pendiente
- Phase 5-9: Not started

## Gotchas para futuras sesiones

- La BD dev acumula residuo GRI-TEST-* (mesas/pedidos borrador) porque test_domain_constraints commitea sin cleanup: NUNCA asertar counts absolutos sobre la BD compartida; usar subset seed (patron GRI-MESA-\d{3}), invariantes o DB cross-check.
- El contenedor api NO tiene volume mount: todo cambio de codigo/test requiere docker compose up -d --build api antes de pytest.
- PowerShell 5.1 no tiene Get-Date -AsUTC; usar [DateTimeOffset]::UtcNow.
- login() de conftest retorna (access, refresh) — desempaquetar al reves manda el refresh token y da 401 "Tipo de token incorrecto" (guard PITFALL 6).
