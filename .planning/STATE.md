---
status: Phase 5 EN PROGRESO - backend completo (05-01 core + 05-02 staff extensions, 105/105 tests); 05-03 app_cliente Flutter en progreso (agente paralelo)
stopped_at: "Completed 05-02-PLAN.md (backend staff: GET /staff/reservas + POST /staff/mesas/{id}/estado)"
current_phase: 5
updated: 2026-08-14
last_activity: 2026-08-14 - Plan 05-02 ejecutado completo (2 tasks TDD, 4 commits); RESV-05 + MESA-04 cerrados; suite 105/105
---

# STATE

## Project Reference

See: .planning/PROJECT.md (updated 2026-08-13)

**Core value:** Un cliente puede sentarse en una mesa, escanear su QR, pedir del menu y recibir su comida en tiempo real sin intermediarios.
**Current focus:** Phase 5 IN PROGRESS - App Cliente (Descubrimiento y Reservas). Backend completo (05-01 + 05-02, 105/105 tests); 05-03 (app_cliente Flutter) en ejecución paralela

## Recent Activity

### 2026-08-14 — Plan 05-02 completo (Wave 2 backend staff extensions)
- GET /staff/reservas?fecha= tenant-scoped via _resolve_rid (param ignorado staff; super_admin 400 sin param / 404 inválido); default hoy con func.curdate() DB-side (Pitfall 6); joins display Restaurante.nombre + Mesa.numero; incluye canceladas (estado discrimina)
- POST /staff/mesas/{id}/estado (RESV-05 marcar + MESA-04): validar_transicion("mesa", ...) como ÚNICA fuente de verdad → TransicionInvalidaError → 409 en router; existence hiding cross-tenant (mesa ajena → 404 idéntico a inexistente); sin drift en rechazos
- MesaEstadoUpdate schema (estado destino validado contra enum → 422 unknown)
- Suite: 95 → 105 tests (4 staff reservas + 6 mesa estado), 0 regresiones, 2 runs consecutivos sin residuo
- Commits: 34f6793 (RED reservas), b5e5948 (GREEN reservas), 0454d35 (RED mesa), da8ec8e (GREEN mesa)
- Desviaciones: Rule 1 — gotcha identity map en tests (lección 05-01 "rollback+get" incompleta: solo refresca con tx activa; expire_all() es determinístico); restores siempre a disponible (invariant seed, auto-repara residuo)
- REQUISITOS: RESV-05, MESA-04 marcados completos

### 2026-08-14 — Plan 05-01 completo (Wave 1 backend core)
- /public/* (restaurantes + detalle con menú, precio float) + /cliente/* (reservas FOR UPDATE + auto-confirm + cancel Pitfall 4 + perfil PATCH email immutable)
- Migración 0003 UNIQUE (mesa_id, fecha, hora_inicio); HARD GATE concurrencia (10 POSTs → 1x201 + 9x409)
- Suite: 70 → 95 tests. Commits: a3b853f, 9795b6a, c441b37

### 2026-08-14 — Plan 04-02 completo (Wave 2 panel Flutter Web)
- panel_admin/ Flutter Web (package gri_panel_admin) con deps locked (riverpod 3.4.2, go_router 17.5.0, dio 5.11.0, secure_storage 11.0.0)
- Auth feature: AuthState keepAlive FutureProvider<User?>, login_controller (valida red-pre), LoginScreen con validators, GoRouter redirect guard (T-04-08)
- ApiClient con QueuedInterceptor + Completer<String?> compartido: N 401s concurrentes → 1 solo refresh (T-04-06 anti refresh-storm)
- Dashboard completo: 4 StatCards (Mesas disponibles/ocupadas, Reservas hoy, Pedidos activos) + grid MesaTile color-coded por EstadoMesa + MesaLegend; polling 10s (Timer.periodic + Stream + ref.onDispose)
- AppShell: sidebar 250px (7 items, solo Dashboard activo) + topbar (avatar + nombre + restaurante via /admin/restaurantes/{id}) + dropdown super_admin
- Paleta GriColors exacta del mockup (16+ constantes); helpers mesaTileBg/FG/Dot con switch exhaustivo (pixel-perfect ADMN-02)
- Suite: 11/11 widget tests verdes (4 login form + 4 mesa_tile_color + 3 stats_render); flutter analyze 0 issues; flutter build web --release OK
- Commits: 5577727 (T1 scaffold+core), e718ac7 (T2 RED), 9514caf (T2 GREEN auth), 9aa2aff (T3 RED), 402f26a (T3 GREEN dashboard)
- Desviaciones: 3 auto-fixed (Rule 1: theme alpha opaco 0xFF..; Rule 3 x2: Riverpod 3 API changes - valueOrNull/StateProvider/wildcards)
- REQUISITOS: PLAT-01, ADMN-01, ADMN-02 marcados completos; Fase 4 cerrada

### 2026-08-14 — Plan 04-01 completo (Wave 1 backend)
- GET /staff/mesas + GET /staff/stats tenant-scoped via _resolve_rid (param restaurante_id IGNORADO para staff; super_admin requiere param -> 400, desconocido -> 404)
- CORSMiddleware con origins explicitos via CORS_ORIGINS (default http://localhost:5173, allow_credentials, sin wildcard); docker-compose ahora interpola CORS_ORIGINS
- Stats: 1 GROUP BY por estado; reservas_hoy con func.curdate() (DB-side Bogota); pedidos_activos excluye borrador y terminales
- Suite: 59 -> 70 tests (8 staff + 3 cors), cero regresiones, cero deps nuevas, cero migraciones
- Commits: f7b42f6 (feat), f9a6368 (test)
- Desviaciones: docker-compose CORS_ORIGINS passthrough (Rule 2); tests deterministas ante residuo GRI-TEST-* acumulable de test_domain_constraints (subset seed + invariantes + DB cross-check)

### 2026-08-13 — Phase 3 completa
- 03-01: 9 tablas de dominio + migracion 0002 + 5 state machines (modulo puro) + fixture db_session + tests constraints (MESA-02 QR global unique, sesion activa unica, CHECKs)
- 03-02: seed_service con gate DEMO_MODE + idempotencia natural-key + lifespan wiring + verify_seed.sh end-to-end (INFR-03)
- Suite: 59/59 passed al cierre de fase
- Commits: a232ca1, 1cdd9d7, 7997a73, 159859d, 165134d, 22ddbdd, 222f412, 5b7619f

## Progress

Status: Phase 5 IN PROGRESS (backend 2/2 planes completo; 05-03 app_cliente en progreso por agente paralelo)

### Phases
- Phase 1: COMPLETE (verified passed)
- Phase 2: COMPLETE (verified passed)
- Phase 3: EXECUTED (verification pending)
- Phase 4: COMPLETE - 04-01 (backend staff endpoints + CORS) + 04-02 (panel Flutter Web) ejecutados; PLAT-01, ADMN-01, ADMN-02 cerrados
- Phase 5: IN PROGRESS - 05-01 (backend core) + 05-02 (backend staff) COMPLETOS (105/105 tests); 05-03 (app_cliente Flutter) en ejecución paralela
- Phase 6-9: Not started

## Gotchas para futuras sesiones

- Riverpod 3.4.2 API: `AsyncValue.value` ya es nullable (NO `.valueOrNull`); `StateProvider` deprecado → `NotifierProvider` con clase Notifier<T> custom.
- GoRouter 17: callbacks `GoRoute.builder` ahora `(_, _)` (wildcards Dart 3.7), `ShellRoute.builder` `(_, _, child)`.
- build_runner: NO usar `--delete-conflicting-outputs` (removido); el runner nuevo maneja conflictos solo.
- flutter_secure_storage 11.0 en Web = WebCrypto + LocalStorage (NO Keystore/Keychain); "obfuscado, no cifrado" — solo aceptable sobre HTTPS (T-04-05).
- La BD dev acumula residuo GRI-TEST-* (mesas/pedidos borrador) porque test_domain_constraints commitea sin cleanup: NUNCA asertar counts absolutos sobre la BD compartida; usar subset seed (patron GRI-MESA-\d{3}), invariantes o DB cross-check.
- Tests que leen efectos de commits del API tras commitear su propia sesión: `rollback + get` SOLO refresca si hay tx activa (gotcha identity map, expire_on_commit=False). Usar `db_session.expire_all()` + get — determinístico. Y restaurar SIEMPRE al estado invariant (disponible), no al estado de entrada (auto-repara residuo).
- El contenedor api NO tiene volume mount: todo cambio de codigo/test requiere docker compose up -d --build api antes de pytest.
- PowerShell 5.1 no tiene Get-Date -AsUTC; usar [DateTimeOffset]::UtcNow.
- login() de conftest retorna (access, refresh) — desempaquetar al reves manda el refresh token y da 401 "Tipo de token incorrecto" (guard PITFALL 6).
- Flutter SDK en `C:\src\flutter\bin` (NO en PATH global): cada comando flutter/dart requiere `$env:Path += ";C:\src\flutter\bin"` en PowerShell.
