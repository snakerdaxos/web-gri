---
phase: 10-migracion-a-firebase-opcion-b-apps-flutter-movil-y-panel-web
verified: 2026-08-16T12:00:00Z
status: passed
score: 5/5 must-haves verified
human_verification:
  - test: "Smoke e2e [A]-[M] en vivo (emuladores o proyecto real)"
    expected: "Flujo completo login->reserva->QR->pedido->cocina avanza->cuenta->entregar->calificar->promedio, todo en vivo sin refresh, sin permission-denied inesperado"
    why_human: "Requiere interacción visual con ambas apps corriendo y observacion realtime en dos ventanas"
  - test: "Deploy real [N]: firebase login + deploy --only firestore:rules,firestore:indexes a p-gri-b5b40"
    expected: "Deploy complete! con release de firestore.rules; 9 indices compuestos BUILDING en Console"
    why_human: "OAuth interactivo (abre navegador) — solo el usuario puede completarlo"
  - test: "Seed del proyecto real [O] + doble corrida (idempotencia en vivo)"
    expected: "Segunda corrida loguea usuarios 6/6, categorias 4/4, productos 16/16 como 'existente' — cero duplicados"
    why_human: "Requiere serviceAccountKey generado desde Console + corrida manual contra proyecto real"
  - test: "Smoke contra proyecto real [P] sin USE_EMULATORS"
    expected: "Flujo A-M resumido contra p-gri-b5b40 real"
    why_human: "Verificacion visual en vivo contra infraestructura real"
---

# Phase 10: Migracion a Firebase (Opcion B) Verification Report

**Phase Goal:** Las dos apps Flutter (app cliente y panel admin) funcionan 100% sobre Firebase Auth + Firestore con security rules por custom claims, realtime nativo (onSnapshot) y transacciones de concurrencia; el restaurante demo se siembra en Firestore (emuladores + proyecto real) y el backend FastAPI queda archivado como referencia
**Verified:** 2026-08-16
**Status:** passed — deploy real queda como pendiente humano documentado (SMOKE-E2E.md [N]/[O]/[P]) — NO bloquea
**Re-verification:** No — verificacion inicial

## Goal Achievement

### Observable Truths (Must-haves automatizables)

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | app_cliente sin rastro de capa HTTP propia; tests 91/91 + analyze 0 | ✓ VERIFIED | grep api_client\|token_provider\|ws_client\|auth_storage\|dotenv\|url_launcher\|TokenPair\|dio en lib+test: 0 imports/usages (3 matches = comentarios "era dio"); pubspec sin dio/web_socket_channel/flutter_dotenv/flutter_secure_storage/url_launcher; 17 archivos purgados ausentes (Test-Path negativo); `flutter analyze` → No issues found; `flutter test` → **+91: All tests passed!** |
| 2 | panel_admin igual; tests 84/84 + analyze 0 | ✓ VERIFIED | mismo grep: 0 imports/usages (1 comentario); pubspec limpio (tambien stream_channel retirado); purgados ausentes; `flutter analyze` → No issues found; `flutter test` → **+84: All tests passed!** |
| 3 | firestore.rules claims autorizan, 0 get(usuarios), access-calls razonables; indexes + firebase.json + seed idempotente | ✓ VERIFIED | rules 291 lineas: autorizacion 100% por `request.auth.token` (helpers signedIn/role/rid/isSuper/isCliente/staffOf/menuStaffOf/cocinaStaffOf), 9 match blocks de coleccion, grep `get(/databases...usuarios` → 0 matches (gets solo a mesas/sesiones/pedidos), presupuesto max 3 access-calls por match documentado en comentarios; firestore.indexes.json 9 indices compuestos validos; firebase.json parse OK; `node --check scripts/seed_firebase.mjs` OK + setCustomUserClaims + getUserByEmail/email-already-exists + doc IDs GRI-MESA- + deteccion emulador/real |
| 4 | Concurrencia: tests Future.wait (reserva slot, sesion unica) presentes y verdes | ✓ VERIFIED | `test/reservas/wizard_form_test.dart:100` — dos crearReserva simultaneas mismo slot → mesas DISTINTAS, 2 docs, sin dup mesa+slot; `test/sesion_qr/scan_test.dart:57` — dos abrirSesion simultaneos misma mesa → 1 gana, perdedor 'Mesa ocupada'; suite 91/91 verde incluye ambos |
| 5 | Realtime: providers con snapshots(), sin timers de polling heredados | ✓ VERIFIED | snapshots() en app_cliente (pedidos_provider, reservas_provider, sesion x2) y panel (menu x2, reservas, pedidos_staff x2, restaurantes_list, mesas, restaurante x2, stats x3); grep Timer.periodic/Timer( en lib de ambas → 0 (matches "polling" son comentarios que documentan su reemplazo) |

**Score:** 5/5 truths verified

### Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `firestore.rules` | authz declarativa por claims, 9 colecciones | ✓ VERIFIED | 291 lineas sustantivas; transMesa 1:1 MESA_TRANSITIONS; matriz rol×transicion en pedidos; usuarios espejo jamas autoriza (read: propio uid o super) |
| `firestore.indexes.json` | 9 indices compuestos | ✓ VERIFIED | pedidos x3 / reservas x2 / sesiones x2 / productos / mesas + fieldOverrides vacio |
| `firebase.json` | deploy + emuladores | ✓ VERIFIED | parse OK; auth 9099, firestore 8080, ui 4000 |
| `scripts/seed_firebase.mjs` | seed idempotente | ✓ VERIFIED | node --check OK; idempotencia por natural key antes de cada write; modo real/emuladores |
| `docs/SMOKE-E2E.md` | runbook A-P + checkpoint | ✓ VERIFIED | [A]..[P] completos con comandos PowerShell exactos, esperado por paso, §5 checklist resume-signal |
| `docs/FIREBASE_SETUP.md` | guia de operacion | ✓ VERIFIED | existe (referenciada por SMOKE-E2E) |
| app_cliente firebase layer | bootstrap + providers + options | ✓ VERIFIED | firebase_bootstrap.dart (gate USE_EMULATORS defaultValue false, antes de runApp), firebase_providers.dart, firebase_options.dart, state_machines.dart, tx_mutex.dart en core/ |
| panel_admin firebase layer | igual | ✓ VERIFIED | mismo patron en core/ |
| Providers → Screens wiring | artifacts conectados | ✓ VERIFIED | imports verificados: restaurante_list/detalle/home→restaurantes_provider; wizard/mis_reservas/home→reservas_provider; scan/menu_mesa/pedido_estado→sesion+pedidos_provider; dashboard→mesas+stats; cocina→pedidos_staff; mesas_screen/sheet→mesas_provider; reservas_staff→cambiarEstadoMesa |

### Key Link Verification

| From | To | Via | Status | Details |
|------|----|----|--------|---------|
| app_cliente auth | FirebaseAuth + doc espejo usuarios/{uid} | signInWithEmailAndPassword/createUser + set(usuarios/{uid}, role cliente) | ✓ WIRED | auth_controller.dart; tests assertean espejo con role 'cliente' y restauranteId null |
| app_cliente reservas | Firestore tx | runTransaction + docId {mesaId}_{yyyyMMdd}_{HH} | ✓ WIRED | reserva_controller.dart:101 (crear) y :183 (cancelar) |
| app_cliente sesion/pedidos | Firestore tx + stream | runTransaction sesiones/{mesaId} + snapshots() | ✓ WIRED | sesion_provider.dart:54, pedidos_provider.dart:63/:159 |
| app_cliente calificacion | tx agregado atomico | runTransaction calificaciones/{pedidoId} + recompute califProm/califCount | ✓ WIRED | calificacion_sheet.dart:55 |
| panel cocina | cola + aviso cuenta + entregarCuenta | snapshots() whereIn + runTransaction cierre+limpieza | ✓ WIRED | pedidos_staff_provider.dart:43/:66/:148 |
| panel gestion | mesas CRUD + menu + clientes + reportes | runTransaction docId QR + streams + fold | ✓ WIRED | mesas_crud.dart:34/:69, menu/stats/reservas providers |
| rules ↔ patrones apps | transiciones validadas client+server | validarTransicion + transMesa espejo | ✓ WIRED | doble barrera consistente (state_machines.dart port 1:1, 13 tests por app) |

### Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
|-------------|------------|-------------|--------|----------|
| MIGRA-01 | 10-02/03/04 | app cliente 100% Firebase sin capa HTTP propia | ✓ SATISFIED | purga 0 matches + pubspec limpio + 91/91 |
| MIGRA-02 | 10-05/06 | panel admin 100% Firebase | ✓ SATISFIED | purga 0 matches + pubspec limpio + 84/84 |
| MIGRA-03 | 10-01/07 | rules desplegables, claims, transiciones server-side | ✓ SATISFIED (artifact) | rules verificadas en 3 niveles; deploy al proyecto real = checkpoint humano [N] |
| MIGRA-04 | 10-01/07 | seed idempotente emuladores + real | ✓ SATISFIED (artifact) | node --check + diseño natural-key; doble corrida en vivo = [O]/§2 (Java ausente documentado) |
| MIGRA-05 | 10-04/05/06/07 | realtime nativo onSnapshot reemplaza WS | ✓ SATISFIED | 20+ call sites snapshots(), 0 timers, tests de stream sin refetch |
| MIGRA-06 | 10-03/04/07 | reservas y sesiones seguras bajo concurrencia (tx + doc IDs deterministas) | ✓ SATISFIED | 2 tests Future.wait verdes + runTransaction en 8 call sites |

**Orphaned requirements:** ninguno — ROADMAP Phase 10 declara MIGRA-01..06 y los 7 planes los cubren todos. Nota: los IDs MIGRA-* existen solo en ROADMAP.md; REQUIREMENTS.md no fue actualizado con ellos (ver Issues).

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
|------|------|---------|----------|--------|
| app_cliente lib (varios) | — | 3 comentarios "era dio" | ℹ️ Info | Referencias historicas en doc-comments; sin codigo muerto |
| panel_admin lib (varios) | — | 1 comentario "era dio" + 24 matches "TODO" (palabra espanola "todo") | ℹ️ Info | Falsos positivos del scanner; 0 marcadores de tarea reales |
| panel_admin/lib/models/user.dart | — | orphan (nada lo importa) | ℹ️ Info | Decision documentada 10-06; analyze 0 lo confirma inofensivo |

Sin TODO/FIXME/PLACEHOLDER/UnimplementedError reales en lib de ambas apps.

### Human Verification Required

Documentados como checkpoint PENDIENTE en docs/SMOKE-E2E.md (§4 [N]/[O]/[P] + §5 checklist). El verify_request establece explicitamente que el deploy real NO bloquea esta verificacion:

1. **Smoke e2e en vivo [A]-[M]** — ejecutar docs/SMOKE-E2E.md contra emuladores (requiere Java, ausente en dev box) o proyecto real ([P]); responder "approved" o lista de fallos.
2. **Deploy real [N]** — `firebase login` + `deploy --only firestore:rules,firestore:indexes` a p-gri-b5b40 (OAuth interactivo, solo el usuario).
3. **Seed real [O]** — doble corrida contra proyecto real con serviceAccountKey (gitignored) → idempotencia en vivo.
4. **Verificacion de indices** — Console → Firestore → Indexes: los 9 compuestos pasan de BUILDING a habilitados.

### Gaps Summary

Sin gaps que bloqueen el goal. Los 5 must-haves automatizables pasaron con evidencia re-ejecutada en esta verificacion (analyze 0 + 91/91 + 84/84 + greps de purga/realtime/concurrencia + sintaxis seed/JSONs).

Pendientes humanos documentados (no bloqueantes): deploy real de rules/indexes, seed real con doble corrida y smoke en vivo — pasos exactos y checklist en docs/SMOKE-E2E.md.

Issues menores (planeacion, no codigo):
- REQUIREMENTS.md no registra los MIGRA-01..06 (viven solo en ROADMAP.md) — inconsistencia de artefacto de planeacion.
- ROADMAP.md: tabla Progress y checkboxes de planes 10-0x sin actualizar para Phase 10 — housekeeping del orquestador.

---

_Verified: 2026-08-16T12:00:00Z_
_Verifier: Claude (gsd-verifier)_
