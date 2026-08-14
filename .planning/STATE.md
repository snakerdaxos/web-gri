---
status: Phase 6 EN PROGRESO - 06-01 backend + 06-02 app_cliente + 06-03 panel cocina COMPLETOS (141 backend + 34 cliente + 17 panel); pendiente actualizar 06-02 en STATE por su agente
stopped_at: "Completed 06-03-PLAN.md (panel_admin: vista cocina + sidebar Pedidos activo, suite 17/17)"
current_phase: 6
updated: 2026-08-14
last_activity: 2026-08-14 - Plan 06-03 ejecutado completo (2 tasks, commits 5afda4b/8cd2aba); ADMN-05 cerrado; suite panel 17/17 + analyze 0 + build web OK
---

# STATE

## Project Reference

See: .planning/PROJECT.md (updated 2026-08-13)

**Core value:** Un cliente puede sentarse en una mesa, escanear su QR, pedir del menu y recibir su comida en tiempo real sin intermediarios.
**Current focus:** Phase 6 IN PROGRESS - 06-01 (backend), 06-02 (app_cliente) y 06-03 (panel cocina) COMPLETOS; UAT manual pendiente (no bloqueante)

## Recent Activity

### 2026-08-14 — Plan 06-03 completo (Wave 2 panel cocina)
- feature cocina/ en panel_admin: CocinaScreen (AsyncValue loading/error/vacío + SnackBars 409/403 accionables + invalidate SIEMPRE) + PedidoCard (borde/chip color estado, items ×cantidad con subtotal, total formatCOP, notas itálicas, usuario, badge amarillo "🍽️ pidió la cuenta") + pedidosStaffProvider polling 10s (clon mesas_provider: queryRid solo super_admin + Timer.periodic + ref.onDispose)
- PedidoStaff/PedidoStaffItem freezed + nextActions(rol): espejo client-side de TRANSITION_ROLES (cocina/admin/super_admin todo; mesero solo servido con label "Marcar servido"); server es la autoridad
- ApiClient: getPedidosActivos (activos=true + queryRid condicional) + avanzarPedido (POST /staff/pedidos/{id}/estado con restaurante_id solo super_admin)
- Sidebar: "📋 Pedidos" navega a /cocina (GoRoute dentro del ShellRoute); isActive derivado del path (mapa _routes ruta→índice); Dashboard navega a '/'; resto sigue Phase 8
- core/format.dart formatCOP (es_CO) creado — el plan lo asumía existente
- Suite panel: 11 → 17 (6 widget tests: render cards/badge/totales, botones cocina, vacío, tap Aceptar→avanzarPedido(7,'aceptado')+invalidate espía, mesero restringido); flutter analyze 0; build web --release OK
- Commits: 5afda4b (T1 feature), 8cd2aba (T2 sidebar/ruta/tests)
- Desviaciones x7 (Rule 3 x3: format.dart faltante, freezed 3.2.6-dev.1 genera 'required final List<T>' inválido → pin 4.0.0-dev.3 igual que app_cliente; Rule 1 x4: flag --build-dir inexistente, Override no exportado por riverpod 3.4.2 (inlinear ProviderScope), índice sidebar '/cocina'→2 no 1 (plan olvidó Mesas), fallback style 48px sin Material ancestor → Material wrapper en CocinaScreen)
- REQUISITOS: ADMN-05 marcado completo (PEDI-05/06/PAGO-01 ya completos de 06-01)
- UAT manual NO bloqueante documentado en SUMMARY (login cocina@demo.gri.dev → cola → avanzar estados; mesero solo Marcar servido; badge cuenta)

### 2026-08-14 — Plan 06-01 completo (Wave 1 backend core value)
- Migración 0004 ÚNICA: sesion_mesa.solicita_cuenta/solicitada_en + UNIQUE(usuario_id, activo_flag) uq_sesion_mesa_usuario_activa + pedido.sesion_id FK + ix_pedido_sesion (alembic current = 0004)
- POST /cliente/sesiones: FOR UPDATE + 2 UNIQUEs + IntegrityError→409 (BD gana la carrera); idempotencia propia 200 (mismo id), ajena 409, usuario con sesión en otra mesa 409, limpieza 409; mesa→ocupada AL ABRIR
- HARD GATE concurrencia verificado: 2 usuarios simultáneos misma mesa → exactamente 1×201 + 1×409 + refuerzo DB (1 sesión activa)
- POST /cliente/pedidos: estado=enviado directo, total server-side SIEMPRE (PedidoCreate sin campos de precio), snapshot precio_unitario en pedido_item, sesion_id SIEMPRE escrito; 404 ajena/cross-restaurante, 409 inactiva/agotado, 422 items/cantidad
- GET /staff/pedidos?activos=true: cola FIFO FIELD(estado,'enviado','aceptado','en_preparacion','servido')+created_at ASC, joins batch (items+usuario+sesión), badge solicita_cuenta; POST /staff/pedidos/{id}/estado con TRANSITION_ROLES (cocina/admin/super_admin todo, mesero solo servido) y 409 ANTES de 403
- Anti-zombi: mesa→limpieza cierra sesión activa EN LA MISMA tx (verificado end-to-end: /cliente/sesiones/actual → 404)
- Cuenta PAGO-01: POST /cliente/sesiones/actual/cuenta idempotente (no re-escribe solicitada_en)
- Suite: 105 → 141 tests (36 nuevos: 9 sesión + 14 pedidos/cuenta + 13 staff), 0 regresiones, 2 runs consecutivos + smoke runtime real sin residuo
- Commits: 2546d2e/ec80f7b (T1), 75daeed/738bcc8 (T2), 3d25446/63b9cc4/36e9602 (T3)
- Desviaciones Rule 1 x4: sa.false_() inexistente en SA 2.0 (→ sa.text("0")); MissingGreenlet por PK de objeto expirado (capturar ids ANTES de expire_all); fixture cross-tenant necesitó usuario dedicado (¡la UNIQUE 0004 funcionó!); cleanup anidado en test con asserts intermedios
- REQUISITOS: MESA-05, MESA-06, PEDI-01..06, PAGO-01 marcados completos

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

Status: Phase 6 IN PROGRESS (06-01 + 06-02 + 06-03 COMPLETOS; UAT manual pendiente no bloqueante)

### Phases
- Phase 1: COMPLETE (verified passed)
- Phase 2: COMPLETE (verified passed)
- Phase 3: EXECUTED (verification pending)
- Phase 4: COMPLETE - 04-01 (backend staff endpoints + CORS) + 04-02 (panel Flutter Web) ejecutados; PLAT-01, ADMN-01, ADMN-02 cerrados
- Phase 5: EXECUTED - 05-01 + 05-02 (backend) + 05-03 (app_cliente Flutter) completos
- Phase 6: IN PROGRESS - 06-01 (backend core value) + 06-02 (app_cliente) + 06-03 (panel cocina: vista cola + badge cuenta + matriz rol×transición + sidebar Pedidos activo) COMPLETOS (141 backend + 34 cliente + 17 panel tests)
- Phase 7-9: Not started

## Gotchas para futuras sesiones

- Riverpod 3.4.2 API: `AsyncValue.value` ya es nullable (NO `.valueOrNull`); `StateProvider` deprecado → `NotifierProvider` con clase Notifier<T> custom.
- GoRouter 17: callbacks `GoRoute.builder` ahora `(_, _)` (wildcards Dart 3.7), `ShellRoute.builder` `(_, _, child)`.
- build_runner: NO usar `--delete-conflicting-outputs` (removido); el runner nuevo maneja conflictos solo.
- flutter_secure_storage 11.0 en Web = WebCrypto + LocalStorage (NO Keystore/Keychain); "obfuscado, no cifrado" — solo aceptable sobre HTTPS (T-04-05).
- La BD dev acumula residuo GRI-TEST-* (mesas/pedidos borrador) porque test_domain_constraints commitea sin cleanup: NUNCA asertar counts absolutos sobre la BD compartida; usar subset seed (patron GRI-MESA-\d{3}), invariantes o DB cross-check.
- Tests que leen efectos de commits del API tras commitear su propia sesión: `rollback + get` SOLO refresca si hay tx activa (gotcha identity map, expire_on_commit=False). Usar `db_session.expire_all()` + get — determinístico. Y restaurar SIEMPRE al estado invariant (disponible), no al estado de entrada (auto-repara residuo).
- MissingGreenlet (06-01): evaluar `obj.id` como PK de un objeto EXPIRADO (tras expire_all) dispara lazy-load síncrono → capturar PKs/valores en ints ANTES de expire_all. El `get(Model, pk_int)` con int crudo siempre es seguro.
- Fixtures que crean sesiones de prueba: usuario DEDICADO por fixture — UNIQUE(usuario_id, activo_flag) de 0004 rechaza dos sesiones activas del mismo usuario (aunque sean de mesas/tenants distintos).
- Cleanups de tests con setups anidados: SIEMPRE nested try/finally — un assert fallido antes del cleanup del setup interno filtra filas (residuo acumulado en BD compartida).
- `sa.false_()` NO existe en SQLAlchemy 2.0 top-level: usar `sa.text("0")` o `sa.false()` en migraciones (server_default boolean).
- El contenedor api NO tiene volume mount: todo cambio de codigo/test requiere docker compose up -d --build api antes de pytest.
- PowerShell 5.1 no tiene Get-Date -AsUTC; usar [DateTimeOffset]::UtcNow.
- login() de conftest retorna (access, refresh) — desempaquetar al reves manda el refresh token y da 401 "Tipo de token incorrecto" (guard PITFALL 6).
- Flutter SDK en `C:\src\flutter\bin` (NO en PATH global): cada comando flutter/dart requiere `$env:Path += ";C:\src\flutter\bin"` en PowerShell.
- freezed 3.2.6-dev.1 (y presumiblemente el dev line 3.2.x) genera `required final List<T>` INVÁLIDO para campos List — pin `freezed: '4.0.0-dev.3'` en ambos paquetes Flutter (mismo pin, ya validado).
- Riverpod 3.4.2 NO exporta el tipo `Override`: en widget tests inlinear el ProviderScope por test (patrón stats_render_test) en vez de helper tipado.
- Screens bombeadas fuera de Scaffold (MaterialApp home directo en tests): envolver en Material(color: bg) — sin Material ancestor Flutter inyecta fallback style 48px amarillo subrayado a los Text sin fontSize explícito.
- ListView lazy en widget tests: cards fuera del viewport default (800×600) no se buildan — `tester.view.physicalSize = Size(800, 1800)` + `devicePixelRatio = 1.0` + `addTearDown(tester.view.reset)`.
