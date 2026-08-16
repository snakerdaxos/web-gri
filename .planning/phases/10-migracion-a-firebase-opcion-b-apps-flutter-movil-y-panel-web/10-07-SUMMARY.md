---
phase: 10-migracion-a-firebase-opcion-b-apps-flutter-movil-y-panel-web
plan: "07"
subsystem: verificacion-final
tags: [smoke-e2e, gates, deploy, checkpoint-humano, idempotencia, firebase]
requires:
  - "10-01 (rules/indexes/seed/guía — FIREBASE_SETUP.md, seed_firebase.mjs)"
  - "10-04 (app_cliente 100% Firestore: sesión QR, pedidos, cuenta, calificación, realtime)"
  - "10-06 (panel_admin 100% Firestore: gestión completa + purge legacy)"
provides:
  - "docs/SMOKE-E2E.md — runbook A-P del flujo e2e completo con comandos PowerShell exactos, esperado por paso, deploy real (N), seed real + idempotencia (O) y smoke contra proyecto real (P)"
  - "entregarCuenta (panel cocina) — cierre de sesión activa→cerrada + mesa ocupada→limpieza en UNA tx: el ciclo cuenta→cierre→calificación que el flujo e2e exige (PAGO-04 manual)"
  - "Gates automatizados de fase ejecutados: analyze 0 + suites completas verdes en AMBAS apps + purge legacy 0 matches"
affects:
  - "panel_admin (cocina: pedidos_staff_provider + cocina_screen) — fix Rule 2 del ciclo de cierre"
tech-stack:
  added: []
  patterns:
    - "Tx Firestore con TODOS los gets antes de TODOS los writes (requisito de runTransaction — mismo patrón que abrirSesion/crearPedido del cliente)"
    - "Badge-aviso como entrada de acción: tap → sheet de entrega; el aviso desaparece SOLO por el stream (avisoCuenta filtra sesión activa)"
key-files:
  created:
    - docs/SMOKE-E2E.md
    - panel_admin/test/cocina/entregar_cuenta_test.dart
  modified:
    - panel_admin/lib/features/cocina/pedidos_staff_provider.dart
    - panel_admin/lib/features/cocina/cocina_screen.dart
decisions:
  - "Java ausente en la dev box: idempotencia en vivo contra emuladores queda compensada con la doble corrida contra el proyecto REAL (paso O del runbook) + validación por diseño 10-01 — limitación registrada en SMOKE-E2E.md §1 con el error exacto"
  - "[D] del smoke usa una mesa libre para demostrar el state machine completo del panel sin bloquear el QR de [E]: abrir sesión exige mesa disponible|reservada (rules) — la transición a ocupada la dispara el cliente"
  - "reserva del smoke para HOY+1 19:00 (fecha del plan): siempre futura (rules fecha > request.time) a cualquier hora de ejecución; la mesa queda reservada y el cliente la abre por QR (reservada→ocupada)"
  - "Smoke contra proyecto real (P) SIN --dart-define: bootstrap usa bool.fromEnvironment USE_EMULATORS defaultValue false — sin flag las apps apuntan a p-gri-b5b40"
metrics:
  duration: "~12m"
  completed: "2026-08-16"
  tasks: "1 auto completo + 1 checkpoint humano PENDIENTE (resume-signal del usuario)"
  tests: "app 91/91 · panel 84/84 (80 + 4 nuevas de entregarCuenta) · analyze 0 en ambas · purge legacy 0 matches en ambas"
---

# Phase 10 Plan 07: Smoke e2e + deploy rules/indexes + checkpoint humano Summary

**One-liner:** Gates automatizados de cierre de fase verdes (analyze 0 + 91/91 + 84/84 + purge 0), fix Rule 2 del ciclo cuenta→cierre→calificación (`entregarCuenta` en una tx), runbook SMOKE-E2E.md A-P con comandos exactos (incluye fallback sin Java vía proyecto real) y el checkpoint humano documentado: smoke en vivo + deploy de rules/indexes a `p-gri-b5b40`.

## What Was Built

### Task 1 — gates automatizados + SMOKE-E2E.md (commits 5ab5211, 5fe549e)

**Gates ejecutados (todos verdes):**

| Gate | Resultado |
|---|---|
| `flutter analyze` app_cliente | ✅ 0 issues |
| `flutter test` app_cliente COMPLETA | ✅ **91/91** |
| `flutter analyze` panel_admin | ✅ 0 issues |
| `flutter test` panel_admin COMPLETA | ✅ **84/84** (80 baseline + 4 nuevas) |
| Purge legacy (`api_client\|token_provider\|ws_client\|auth_storage\|dotenv\|TokenPair`) lib+test, ambas apps | ✅ **0 matches** |
| `npm ci` (scripts/) + `npx firebase --version` | ✅ 15.27.0 |
| Emuladores + doble corrida seed (idempotencia en vivo) | ⏸ **Java ausente** — evidencia capturada, limitación registrada (ver Deviations) |
| `SMOKE-E2E.md`: regex `^\[?[A-N]\]?\.` | ✅ **14 matcheos** (≥12) — pasos [A]..[N] + [O]/[P] |
| `SMOKE-E2E.md`: `USE_EMULATORS` presente | ✅ |

**docs/SMOKE-E2E.md** — runbook A-P: §0 requisitos+credenciales · §1 limitación
Java con el error exacto (`Could not spawn 'java -version'`) y su compensación ·
§2 emuladores + doble corrida del seed (idempotencia en vivo) con
`--export-on-exit=./emulator_data` · §3 apps con
`--dart-define=USE_EMULATORS=true` · §4 pasos **[A]** login cliente →
**[B]** reserva 2p hoy+1 19:00 → **[C]** panel dashboard/mapa en vivo →
**[D]** marcar ocupada/limpieza/liberar (mesa libre — el state machine del
panel) → **[E]** input manual `GRI-MESA-demo-00X` → menú → **[F]** Bandeja
Paisa + Limonada ($41.000) en vivo → **[G]** cocina Aceptar→En
preparación→Servido → **[H]** pedir la cuenta (badge amarillo en panel) →
**[I]** Entregar cuenta (sesión cerrada + mesa limpieza, una tx) → **[J]**
calificar 5★ → **[K]** ★ 5.0 (1) en discover → **[L]** realtime transversal
dos ventanas → **[M]** super-admin toggle restaurantes → **[N]** DEPLOY REAL
(`firebase login` + `deploy --only firestore:rules,firestore:indexes`) →
**[O]** seed real con serviceAccountKey + doble corrida (MIGRA-04) → **[P]**
smoke contra proyecto real sin flag · §5 checklist del resume-signal
("approved" o fallos) + git status sin secrets.

### Task 2 — checkpoint humano (PENDIENTE — gate blocking del plan)

No hay código que escribir: el usuario ejecuta `docs/SMOKE-E2E.md` (flujo
A-M en vivo, deploy N, seed O, smoke real P) y responde "approved" o lista
los fallos. Ver "Awaiting" abajo.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 2 - Funcionalidad crítica faltante] Nadie cerraba la sesión de mesa — el flujo e2e era incompleto**
- **Found during:** Task 1 (investigación de etiquetas UI para el runbook)
- **Issue:** El paso [I] del plan ("panel: cerrar sesión/mesa → limpieza") y el must_have ("cuenta → cerrar mesa → calificar → promedio visible") exigen que la sesión `sesiones/{mesaId}` pase a `cerrada` — las rules lo permiten (staff + soloEstado + activa→cerrada|expirada) y `calificar` del cliente lo EXIGE (tx + rules), pero NINGUNA app escribía esa transición (grep: solo lectura en panel; cliente solo escribe `cuentaSolicitada`). Sin el fix, el smoke humano habría fallado en [J]/[K] y el promedio jamás se actualizaría.
- **Fix:** `entregarCuenta` (panel, `pedidos_staff_provider.dart`): runTransaction con TODOS los gets antes de los writes — cierra la sesión (`estado + updatedAt`, `soloEstado`) y pasa la mesa ocupada→limpieza en la MISMA tx (PAGO-04 manual, pagos diferidos v1); doble barrera `validarTransicion` client-side + rules. UI: el badge "pidieron la cuenta" del header de cocina ahora abre un sheet con las mesas y la acción "Entregar cuenta" — el aviso desaparece SOLO (el stream `avisoCuenta` filtra por sesión activa).
- **Files:** panel_admin/lib/features/cocina/{pedidos_staff_provider.dart, cocina_screen.dart} · test/cocina/entregar_cuenta_test.dart (3 data-level + 1 widget en vivo: badge→sheet→entregar→aviso desaparece)
- **Commit:** 5ab5211

**2. [Limitación de entorno — documento, no fix] Java ausente: emuladores no corren en esta máquina**
- **Found during:** Task 1 (gate de idempotencia en vivo)
- **Issue:** `firebase emulators:exec` falla con `Could not spawn 'java -version'` (evidencia textual capturada en SMOKE-E2E.md §1) — previsto por el plan y por FIREBASE_SETUP.md §3.
- **Compensación:** idempotencia queda validada por diseño (10-01: natural key antes de cada write) + doble corrida contra el PROYECTO REAL documentada como paso [O] del runbook + §2 ejecutable en cualquier máquina con Java 11+.
- **Files:** docs/SMOKE-E2E.md
- **Commit:** 5fe549e

### Nota de fidelidad al plan (pasos del smoke)

- **[D] usa una mesa libre** para ejercitar 'Marcar ocupada'→'Marcar en limpieza'→'Liberar' sin romper [E]: abrir sesión por QR exige mesa disponible|reservada (rules) — si el staff marca ocupada la mesa del QR, el cliente no puede abrir sesión. El runbook lo advierte explícitamente.
- **[B] reserva para HOY+1 19:00** (como pide el plan): siempre futura a cualquier hora de ejecución (rules `fecha > request.time`); por eso [C] aclara que NO aparece en "Reservas del día" (hoy-only) pero su mesa sí queda `reservada` en el mapa en vivo.

## Authentication Gates

- **`firebase login` (OAuth interactivo)** — requerido para el deploy [N] del runbook: SOLO el usuario puede completarlo (abre navegador). Pasos exactos en SMOKE-E2E.md [N]. El CLI queda autenticado después y futuros deploys ya no requieren interacción.
- **Service Account (solo seed real [O])** — `GOOGLE_APPLICATION_CREDENTIALS=./scripts/serviceAccountKey.json`, generado desde Console, GITIGNORED. Checklist final verifica que no aparece en `git status`.

## Verification Results

| Check del plan | Resultado |
|---|---|
| analyze + suites completas AMBAS apps | ✅ 0 · 91/91 · 0 · 84/84 |
| Purge grep legacy ambas apps | ✅ 0 matches |
| Idempotencia seed en vivo (emuladores) | ⏸ sin Java — validada por código + paso [O] real |
| SMOKE-E2E.md pasos A-P numerados, comandos exactos, esperado por paso | ✅ ([A]..[P], 14 matcheos regex del plan) |
| `rg USE_EMULATORS docs/SMOKE-E2E.md` | ✅ presente (múltiples) |
| key_links `seed_firebase\|emulators:start\|USE_EMULATORS` referenciados en SMOKE-E2E.md | ✅ (6/3/N ocurrencias) |

## Deferred Issues

- **Checkpoint humano (Task 2) PENDIENTE:** smoke en vivo + deploy real — pasos exactos en `docs/SMOKE-E2E.md`, resume-signal "approved" o lista de fallos. Hasta entonces MIGRA-03 (rules desplegadas) queda sin sellar y MIGRA-04/05/06 sin observación en vivo.
- `emulator_data/` no existe en esta máquina (sin Java) — se crea al ejecutar §2 del runbook (gitignored).

## Self-Check: PASSED

- Archivos verificados en disco: docs/SMOKE-E2E.md ✅ · panel_admin/test/cocina/entregar_cuenta_test.dart ✅ · panel_admin/lib/features/cocina/pedidos_staff_provider.dart (modificado) ✅ · panel_admin/lib/features/cocina/cocina_screen.dart (modificado) ✅
- Commits verificados en git log: 5ab5211 ✅ · 5fe549e ✅
- Suites finales post-fix: app 91/91 · panel 84/84 · analyze 0 ambas ✅
