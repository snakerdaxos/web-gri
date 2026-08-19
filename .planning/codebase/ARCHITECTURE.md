<!-- refreshed: 2026-08-19 -->
# Architecture

**Analysis Date:** 2026-08-19

## System Overview

GRI is a **serverless, client-direct-to-Firestore** system (post Phase 10 "Migración a Firebase Opción B"). There is no application backend in production: both Flutter apps talk directly to Firebase Auth and Cloud Firestore over the official SDKs, and ALL authorization/business-rule enforcement that used to live in a FastAPI backend now lives declaratively in `firestore.rules` at the repo root.

```text
┌───────────────────────────────┬───────────────────────────────────────┐
│   app_cliente (Flutter mobile)│   panel_admin (Flutter Web)            │
│   `app_cliente/lib/`          │   `panel_admin/lib/`                   │
│   roles: cliente (público)    │   roles: super_admin, admin_restaurante│
│                                │          mesero, cocina                │
└───────────────┬────────────────────────────────┬──────────────────────┘
                │  firebase_auth SDK              │  firebase_auth SDK
                │  cloud_firestore SDK            │  cloud_firestore SDK
                ▼                                  ▼
┌─────────────────────────────────────────────────────────────────────┐
│                     Firebase Auth (p-gri-b5b40)                      │
│   Email/Password provider. Custom claims { role, rid } embedded in   │
│   the ID token — the ONLY source of truth for authorization.         │
└───────────────────────────────┬───────────────────────────────────────┘
                                 │ request.auth.token.{role,rid}
                                 ▼
┌─────────────────────────────────────────────────────────────────────┐
│               firestore.rules (declarative authorization)            │
│               `firestore.rules` (repo root, 291 lines)               │
│   Replaces backend/app/core/deps.py (require_roles) + TenantScope.   │
│   Per-document, per-field (diff().affectedKeys()) rules; state       │
│   machines for mesa/pedido/sesion/reserva ported inline.              │
└───────────────────────────────┬───────────────────────────────────────┘
                                 ▼
┌─────────────────────────────────────────────────────────────────────┐
│                    Cloud Firestore (collections)                     │
│  restaurantes · categorias · productos · mesas · usuarios · sesiones │
│  · pedidos · reservas · calificaciones                                │
└─────────────────────────────────────────────────────────────────────┘

  Out-of-band administration (NOT reachable from either Flutter app):
┌─────────────────────────────────────────────────────────────────────┐
│  scripts/seed_firebase.mjs (Node.js, Firebase Admin SDK)              │
│  Runs OUTSIDE the client/rules model — bypasses firestore.rules       │
│  entirely and is the ONLY writer of custom claims. See "Bootstrap"    │
│  section below.                                                       │
└─────────────────────────────────────────────────────────────────────┘
```

## Component Responsibilities

| Component | Responsibility | File |
|-----------|----------------|------|
| App Cliente | Customer-facing mobile app: discover restaurants, reserve, scan table QR, order, track order, request check, rate | `app_cliente/lib/` |
| Panel Admin | Staff/admin web app: dashboard, table map, kitchen queue, menu/table CRUD, clients, reports, platform config | `panel_admin/lib/` |
| Firebase Auth | Identity provider; issues ID tokens carrying custom claims `{role, rid}` | Firebase project `p-gri-b5b40` |
| Firestore | Single source of truth for all domain data; read directly by both apps via realtime listeners/`StreamProvider` | Firebase project `p-gri-b5b40` |
| `firestore.rules` | 100% of authorization + state-machine + tenant-isolation enforcement — the de facto "backend" | `firestore.rules` |
| `firestore.indexes.json` | 9 composite indexes required by staff/tenant-scoped queries (`pedidos`, `reservas`, `sesiones`, `productos`, `mesas`) | `firestore.indexes.json` |
| `scripts/seed_firebase.mjs` | Admin-SDK-only bootstrap/seed script: creates demo restaurant, 6 demo users with custom claims, 8 tables, menu | `scripts/seed_firebase.mjs` |
| `backend/` (FastAPI+MySQL) | **ARCHIVED legacy** — the pre-Phase-10 backend, kept only as historical/reference code. Not deployed, not imported by either Flutter app. Do not extend it. | `backend/` |

## Pattern Overview

**Overall:** Serverless BaaS (Backend-as-a-Service) architecture — "thin client, thick rules." There is no server-side application code executing custom logic per request; Cloud Functions are explicitly **not used** (deferred, noted throughout `firestore.rules` as "Functions, DEFERRED").

**Key Characteristics:**
- Authorization is 100% declarative, expressed in Firestore Security Rules, evaluated per-document and sometimes per-field (`diff().affectedKeys().hasOnly([...])`).
- Multi-tenancy (`restauranteId`) is enforced by rules comparing `request.auth.token.rid` against document fields — not by query-side filtering (clients must still filter tenant-scoped queries themselves; rules deny non-matching docs and can fail an entire query — see "Anti-Patterns").
- Both apps share nearly identical core plumbing (`core/firebase_bootstrap.dart`, `core/firebase_providers.dart`, `core/state_machines.dart`) — `panel_admin`'s versions were the template later copied into `app_cliente` (per Phase 5 roadmap notes).
- State transitions (mesa, pedido, sesion, reserva, pago) are defined identically in THREE places that must stay in sync: `backend/app/core/state_machines.py` (archived reference), `app_cliente/lib/core/state_machines.dart` / `panel_admin/lib/core/state_machines.dart` (client-side pure validation, advisory only), and inline boolean functions in `firestore.rules` (the only one that's actually enforced).
- Financial/quantity invariants that would normally be server-validated (order totals, item price snapshots, rating aggregate math) are only as strong as what Firestore Rules can express per-document; several are explicitly documented as accepted v1 gaps (see Anti-Patterns / Cross-Cutting Concerns).

## Layers

**Presentation + State (Flutter):**
- Purpose: UI screens + Riverpod controllers/providers per feature
- Location: `app_cliente/lib/features/*`, `panel_admin/lib/features/*`
- Contains: `*_screen.dart` (widgets), `*_controller.dart` / `*_provider.dart` (Riverpod, code-generated `.g.dart` via `riverpod_generator`)
- Depends on: `core/firebase_providers.dart` (injected `FirebaseAuth`/`FirebaseFirestore` instances — never touched directly outside `core/`), `models/*`
- Used by: `app.dart` (GoRouter route table), `main.dart` (entrypoint)

**Domain Models (Flutter, shared shape):**
- Purpose: Immutable DTOs mapping 1:1 to Firestore document shapes
- Location: `app_cliente/lib/models/*.dart`, `panel_admin/lib/models/*.dart`
- Contains: `freezed` classes with a canonical `fromDoc(DocumentSnapshot)` factory (the `fromJson` factories are dead code left over from the REST era)
- Depends on: `cloud_firestore` (`Timestamp` conversion), `freezed_annotation`
- Used by: providers/controllers, screens

**Core/Bootstrap (Flutter):**
- Purpose: Firebase initialization, emulator wiring, pure state-machine tables, cross-cutting formatting/mutex helpers
- Location: `app_cliente/lib/core/*`, `panel_admin/lib/core/*`
- Contains: `firebase_bootstrap.dart` (init order), `firebase_providers.dart` (DI seam for tests), `state_machines.dart` (pure, no Firestore import), `tx_mutex.dart` (client-side in-process write serialization)
- Depends on: `firebase_core`, `firebase_auth`, `cloud_firestore`
- Used by: `main.dart`, all features

**Authorization (declarative, server-side):**
- Purpose: Enforce tenant isolation, role gating, and state-machine transitions on every read/write
- Location: `firestore.rules`
- Contains: helper functions (`signedIn`, `role`, `rid`, `isSuper`, `isCliente`, `staffOf`, `menuStaffOf`, `cocinaStaffOf`, `soloEstado`, `transMesa`) + one `match` block per collection
- Depends on: custom claims in `request.auth.token`; a small number of cross-document `get()` calls (budgeted, documented at top of file — max 3 access-calls per collection, 10/20 hard Firestore limits)
- Used by: Firebase's rules engine at request time — not imported by any app code

**Bootstrap/Ops tooling (Node.js, out-of-band):**
- Purpose: Seed demo data and mint the FIRST privileged users via Admin SDK (bypasses rules)
- Location: `scripts/seed_firebase.mjs`, `scripts/package.json`
- Depends on: `firebase-admin` npm package, either emulator env vars or `GOOGLE_APPLICATION_CREDENTIALS` service-account JSON
- Used by: developers/operators manually, documented in `docs/FIREBASE_SETUP.md`

**Archived legacy backend (not part of runtime architecture):**
- Purpose: Historical FastAPI+MySQL implementation from Phases 1–9, superseded by Phase 10's Firebase migration
- Location: `backend/` (`backend/app/api`, `backend/app/core`, `backend/app/models`, `backend/app/services`, `backend/alembic`)
- Status: kept for reference only (e.g., `backend/app/core/state_machines.py` is the canonical source the Dart `state_machines.dart` files and `firestore.rules` transition logic were ported from). Not deployed; not consumed by either Flutter app at runtime.

## Data Model

Collections (top-level, no subcollections):

| Collection | Doc ID convention | Key fields | Notes |
|---|---|---|---|
| `restaurantes` | slug (e.g. `demo`) — human-chosen, not auto-id | `nombre`, `descripcion`, `tipoCocina`, `direccion`, `activo`, `califProm` (double), `califCount` (int), `createdAt` | Public read (`allow read: if true`); only `super_admin` can `create`/`delete`/toggle `activo`; clients can update ONLY `califProm`+`califCount` as a rating-aggregate side effect of the calificaciones transaction (`firestore.rules:93-100`) |
| `categorias` | Firestore auto-id | `restauranteId`, `nombre`, `orden`, `activo` | Public read filtered by `activo == true`; writes gated by `menuStaffOf` (super or that restaurant's `admin_restaurante`) |
| `productos` | Firestore auto-id | `restauranteId`, `categoriaId`, `nombre`, `descripcion`, `precio` (int COP), `imagenUrl`, `disponible`, `activo` | Public read requires `activo == true AND disponible == true`; writes gated by `menuStaffOf` |
| `mesas` | **Deterministic**: `GRI-MESA-{restauranteId}-{numero:3digits}` (this IS the QR code content) | `restauranteId`, `numero`, `capacidad`, `estado`, `updatedAt` | Doc-ID-as-QR gives O(1) resolution on scan (`mesas/{codigo}.get()`), guarantees QR uniqueness by construction. Read requires only `signedIn()`. Three separate `allow update` rules: staff full-state-machine moves, client-restricted moves (open/reserve), and ficha edits (`numero`/`capacidad`) |
| `usuarios` | Firebase Auth `uid` | `nombre`, `email`, `role`, `restauranteId` | **Mirror/profile doc only — NEVER used for authorization.** No rule ever calls `get()` on `usuarios/` (explicit anti-desync + access-call-budget design, see `firestore.rules:8-10`). Self-registration forces `role: 'cliente'`, `restauranteId: null`; the user can only ever update their own `nombre` afterward |
| `sesiones` | **Deterministic**: `= mesaId` (one active session per table by construction) | `restauranteId`, `mesaId`, `usuarioId`, `estado` (`activa\|cerrada\|expirada`), `cuentaSolicitada`, `cuentaPedidaAt`, `inicioAt`, `cerradaAt` | `create` costs 1 access-call (reads `mesas/{sesionId}`, cached). Re-opening a closed session is blocked because Firestore treats `set()` on an existing doc as an UPDATE, not a create |
| `pedidos` | Firestore auto-id | `restauranteId`, `mesaId`, `sesionId` (== `mesaId`), `usuarioId`, `clienteNombre`, `estado`, `total` (int COP), `items` (list, embeds name/price **snapshot** per item), `createdAt`, `updatedAt` | `create` costs 2 access-calls / 3 gets (sesiones + mesas, anti-spoofing per Phase 6 threat model); item snapshot means totals are NOT re-validated server-side beyond `total is int && total >= 0` — accepted v1 gap |
| `reservas` | **Deterministic**: `{mesaId}_{yyyyMMdd}_{HH}` (one slot per hour per table, built in `app_cliente/lib/features/reservas/reserva_controller.dart:29`) | `restauranteId`, `mesaId`, `usuarioId`, `estado`, `fecha`, `numPersonas` | `create` validates against the live `mesas/{mesaId}.capacidad` server-side (1 access-call, cached) |
| `calificaciones` | **Deterministic**: `= pedidoId` (1:1, enforces "one rating per order") | `pedidoId`, `usuarioId`, `restauranteId`, `estrellas` (int 1-5) | `create` costs 2 access-calls / 4 gets: reads `pedidos/{pedidoId}` (owner + `servido`) and, via a nested `get()`, `sesiones/{pedido.sesionId}` (must be `cerrada` — payments-deferred design). Public read (`allow read: if true` — used for restaurant discovery ratings). Immutable: `update, delete: if false` |

## State Machines

Five state machines are defined, three of which are enforced end-to-end by `firestore.rules`. All are ported 1:1 from the archived `backend/app/core/state_machines.py` into `firestore.rules` (server-enforced) and into `app_cliente/lib/core/state_machines.dart` / `panel_admin/lib/core/state_machines.dart` (client-side pure validation used for UI gating only — **not a security boundary**).

**Mesa** (`mesa`) — enforced by `transMesa()` in `firestore.rules:77-82`:
```
disponible → {reservada, ocupada}
reservada  → {ocupada, disponible}
ocupada    → {limpieza}
limpieza   → {disponible}
```
Two independent Firestore rules drive this: staff can perform any valid `transMesa` move (`firestore.rules:149-152`); a client can only do `disponible→reservada` (creating a reservation) or `{disponible,reservada}→ocupada` (opening a session) (`firestore.rules:156-161`).

**Pedido** (`pedido`) — enforced inline in the `pedidos` `update` rule (`firestore.rules:231-243`), NOT via a generic transition-table function (the rule hand-codes each allowed hop plus a role check per hop):
```
enviado         → {aceptado, rechazado}   (role: admin_restaurante | cocina | super_admin)
aceptado        → {en_preparacion}         (role: admin_restaurante | cocina | super_admin)
en_preparacion  → {servido}                (any cocinaStaffOf: admin_restaurante | cocina | mesero | super_admin)
rechazado       → terminal
servido         → terminal in v1 rules (pagado is unreachable — no rule allows it)
```
Note: the Dart `pedidoTransitions` table (`app_cliente/lib/core/state_machines.dart:44-52`) still lists `servido → pagado`, but no Firestore rule permits that write — payments are deferred/out of scope for this transition in v1.

**Sesion** (`sesion_mesa`):
```
activa → {cerrada, expirada}   (terminal otherwise)
```
Enforced in `firestore.rules:199-203` (staff only, `soloEstado()`).

**Reserva** (`reserva`):
```
pendiente  → {confirmada, cancelada}
confirmada → {cancelada}
cancelada  → terminal
```
Only the `→ cancelada` edge is reachable via rules (`firestore.rules:263-267`); reservations are created directly in `confirmada` state (auto-confirm design decision from Phase 5), so `pendiente` is defined in the Dart table but never actually produced.

**Pago** (`pago`): defined in the Dart table (`pagoTransitions`) but has **no corresponding Firestore collection or rule** — payments are not implemented in the Firebase architecture; this table is inert legacy carried over from the archived backend port.

## Bootstrap Path for an Empty Database (CRITICAL)

**This is the single most important operational fact about this architecture: neither Flutter app can create the first privileged user. The system cannot bootstrap itself from either client.**

Trace of why, precisely:

1. **Custom claims are the only authorization signal**, and only `role`/`rid` in `request.auth.token` matter — the `usuarios/{uid}` mirror doc is explicitly never read by any rule (`firestore.rules:9-10, 164`). So "being `super_admin`" or "being staff of restaurant X" means having those custom claims on your Firebase Auth account — nothing else.

2. **No client-callable path sets custom claims.** The Firebase Admin SDK's `auth.setCustomUserClaims()` is a privileged server-side-only API — it does not exist in the `firebase_auth` client SDK used by `app_cliente`/`panel_admin`. Grep confirms neither Flutter app imports `firebase-admin` or calls anything claim-related; `panel_admin/lib/features/auth/login_controller.dart` only ever *reads* claims (`user.getIdTokenResult`), never writes them.

3. **Client self-registration is hard-restricted to `cliente` with no restaurant.** `app_cliente/lib/features/auth/auth_controller.dart:112-176` (`RegisterController.submit`) creates a Firebase Auth user via `createUserWithEmailAndPassword` and then writes the `usuarios/{uid}` mirror doc with hardcoded `role: 'cliente'`, `restauranteId: null`. Even if a malicious client tried to write a different role into that doc, `firestore.rules:169-171` rejects any self-registration `create` where `role != 'cliente'` or `restauranteId != null`. There is **no registration flow at all** in `panel_admin` (no `register_screen.dart` exists there — only `login_screen.dart` + `login_controller.dart`).

4. **The `restaurantes` collection cannot be created by an unprivileged user either.** `firestore.rules:88` — `allow create, delete: if isSuper();` — so even producing the FIRST restaurant document requires already having `super_admin` claims, which circles back to point 1/2.

5. **`panel_admin` has no UI to create a restaurant even for an existing `super_admin`.** `panel_admin/lib/features/configuracion/restaurantes_admin_provider.dart` only exposes `restaurantesAdmin` (list) and `toggleRestauranteActivo` (flip `activo`) — there is no `createRestaurante()` function or create-restaurant screen anywhere in `panel_admin/lib/features/configuracion/`. So even after claims exist, day-to-day restaurant onboarding is not self-service from the panel; it must go through the seed script or manual Firestore/Admin SDK writes.

**Conclusion — the only way to bootstrap an empty Firestore/Auth project:**

Run `scripts/seed_firebase.mjs` with the Firebase **Admin SDK**, either against:
- **Local emulators** (`FIREBASE_AUTH_EMULATOR_HOST` + `FIRESTORE_EMULATOR_HOST` env vars, no credentials needed — `scripts/seed_firebase.mjs:91-117`), or
- **The real project** (`GOOGLE_APPLICATION_CREDENTIALS=./scripts/serviceAccountKey.json` pointing at a downloaded Firebase service-account key — `scripts/seed_firebase.mjs:96-102`, documented in `docs/FIREBASE_SETUP.md:93-106`).

The script (`scripts/seed_firebase.mjs:132-280`) then, using Admin-SDK-only privileges that bypass `firestore.rules` entirely:
1. Writes `restaurantes/demo` directly (`seedRestaurante()`, line 132) — the FIRST restaurant.
2. Calls `auth.createUser()` for 6 hardcoded demo accounts and `auth.setCustomUserClaims(uid, { role, rid })` for each (`seedUsuarios()`, lines 155-193) — this is the ONLY place in the entire codebase that sets custom claims, including the FIRST `super_admin` (`admin@gri.dev`, `role: 'super_admin', rid: null`, line 46) and the first staff (`admin@demo.gri.dev` / `mesero@demo.gri.dev` / `cocina@demo.gri.dev`, all `rid: 'demo'`).
3. Writes the `usuarios/{uid}` mirror doc for each seeded user (same function) — this is allowed because it runs with Admin SDK privileges, which are exempt from Firestore Security Rules by design.
4. Seeds 8 `mesas` documents with deterministic QR-based IDs and the demo menu (`seedCategorias`/`seedProductos`).

The script is **idempotent** by natural key (email for users, doc ID for restaurant/mesas, `(restauranteId, nombre)` for categorías, `(restauranteId, categoriaId, nombre)` for productos) so it is safe to re-run, but it is a **manual, human-run Node.js operation** — it is not triggered by any app install flow, not run automatically on first app launch, and has no in-app equivalent. Onboarding a brand-new (non-demo) restaurant and its first admin in production today requires either editing/extending this script or performing manual Admin SDK / Firebase Console operations — there is no self-service "sign up my restaurant" path in the shipped product.

**Architectural risk:** this makes `scripts/seed_firebase.mjs` (and whoever holds `scripts/serviceAccountKey.json`) a single, out-of-band, ungoverned super-user-creation mechanism with no audit trail beyond console logs, and no in-product multi-restaurant onboarding flow exists yet (`configuracion_screen.dart` in `panel_admin` only manages restaurant *activation toggling*, not creation, and has no staff-invitation flow either — inviting the first `admin_restaurante` for a new restaurant is currently equivalent to bootstrapping a new super_admin: only achievable by re-running/extending the seed script or hand-editing Firebase Auth + custom claims).

## Key Abstractions

**Custom Claims `{ role, rid }`:**
- Purpose: Sole authorization signal, embedded in the Firebase ID token, read via `request.auth.token.role` / `.rid` in rules and `user.getIdTokenResult()` client-side for UI routing only
- Examples: `app_cliente/lib/features/auth/auth_controller.dart:27-41` (`claims` provider), `panel_admin/lib/features/auth/login_controller.dart:46-105` (role-gated login)
- Pattern: absence of `role` claim == `cliente` (both in rules `isCliente()` and Dart `claims` provider fallback)

**Doc-ID-as-natural-key:**
- Purpose: Encode uniqueness constraints structurally instead of via server-side transactions/uniqueness checks
- Examples: `mesas/{GRI-MESA-{rid}-{num}}`, `sesiones/{mesaId}`, `reservas/{mesaId}_{yyyyMMdd}_{HH}`, `calificaciones/{pedidoId}`
- Pattern: "set() on an existing doc ID is treated as update" is deliberately exploited to block illegal re-creation (e.g. re-opening a closed session, `firestore.rules:184-185`)

**`tx_mutex.dart` (`seccionCritica`):**
- Purpose: In-process (single Flutter isolate) write serialization to prevent double-tap / overlapping mutation races, complementing (not replacing) Firestore's own transaction OCC
- Location: `app_cliente/lib/core/tx_mutex.dart`
- Pattern: token-based critical section wrapping `runTransaction` calls in reservas/sesiones/pedidos/calificaciones controllers

## Entry Points

**`app_cliente/lib/main.dart` → `app_cliente/lib/app.dart`:**
- Triggers: app launch
- Responsibilities: `bootstrap()` (Firebase init + optional emulator wiring, must run before any provider), then `GriApp`/`GoRouter` with a `StatefulShellRoute.indexedStack` of 4 tabs (Inicio/Restaurantes/Reservas/Perfil) plus full-screen pushed routes (`/sesion/scan`, `/mesa`, `/mesa/pedidos`, `/restaurantes/:id`, `/reservas/wizard`)

**`panel_admin/lib/main.dart` → `panel_admin/lib/app.dart`:**
- Triggers: web app load
- Responsibilities: same `bootstrap()` pattern, then `GriApp`/`GoRouter` with a single `ShellRoute` (persistent sidebar) wrapping `/`, `/mesas`, `/cocina`, `/clientes`, `/reservas`, `/reportes`, `/configuracion`; `LoginController.submit` (`panel_admin/lib/features/auth/login_controller.dart:56-105`) is the role gate that signs out and rejects any non-staff, non-super_admin login attempt

**`scripts/seed_firebase.mjs`:**
- Triggers: manual `node scripts/seed_firebase.mjs` invocation by a developer/operator
- Responsibilities: the ONLY bootstrap/administration entry point for creating privileged accounts (see Bootstrap section)

## Architectural Constraints

- **No server-side compute:** Cloud Functions are not used; anything requiring cross-document validation beyond what Security Rules can express (server-computed totals, strong rating-aggregate validation, notifications) is explicitly deferred and documented inline in `firestore.rules` as a known v1 gap.
- **Rules access-call budget:** Firestore Security Rules impose hard limits (10 access-calls per single-doc request, 20 per multi-doc/transaction). `firestore.rules:12-18` documents the exact budget consumed by each collection's `create` rule (e.g. `pedidos` create = 2 access-calls / 3 gets) — this is a real ceiling that constrains how much cross-document validation can ever be added without Cloud Functions.
- **Per-document rule evaluation breaks bulk queries:** a Firestore query that matches even ONE document failing its `read` rule fails the ENTIRE query (not just that doc) — public menu/discovery queries MUST pre-filter (`activo == true`, `disponible == true`) client-side to avoid this, and every staff query MUST filter by the caller's own `rid` (documented in `docs/FIREBASE_SETUP.md` Troubleshooting table).
- **Client-side state machines are advisory only:** `app_cliente/lib/core/state_machines.dart` / `panel_admin/lib/core/state_machines.dart` are pure Dart, unenforced by Firestore — they exist for fast UI-level validation/tests, not security. The real enforcement is the hand-written boolean logic inside `firestore.rules`, which must be kept in sync manually (no shared codegen between rules and Dart).
- **Global/module-level state:** `app_cliente/lib/core/tx_mutex.dart` holds process-level mutable state (`_txToken`, `_txTail`) shared across all callers in the same isolate — intentional, documented, but a single point of serialization for all Firestore transactions in that app.
- **`backend/` is dead code for planning purposes:** any new phase should NOT plan changes against `backend/`; it is retained only as a line-by-line reference for the state-machine/seed logic that was ported into `firestore.rules` and `scripts/seed_firebase.mjs`.

## Anti-Patterns

### Client-writable aggregate fields without strong validation

**What happens:** `restaurantes.califProm`/`califCount` can be updated directly by any `cliente` as a standalone Firestore write, as long as `califProm is number` and `califCount is int` (`firestore.rules:96-100`). The rule cannot verify the update is actually the output of a legitimate rating-averaging transaction.
**Why it's wrong:** A malicious authenticated client could set `califProm`/`califCount` to arbitrary values directly, bypassing the intended calificaciones transaction — there's no cryptographic/transactional binding between "a calificación was created" and "the aggregate was updated correctly."
**Do this instead:** This is called out in the rules file itself as "un gap estructural aceptado en v1... validación fuerte = Functions, DEFERRED" (`firestore.rules:90-92`). Any phase adding stronger guarantees should introduce a Cloud Function trigger on `calificaciones` creation to own the aggregate write, removing client write access to those fields.

### Three independent copies of the same state-machine logic

**What happens:** Mesa/pedido/sesion/reserva transition rules exist simultaneously in `backend/app/core/state_machines.py` (archived), `app_cliente/lib/core/state_machines.dart` + `panel_admin/lib/core/state_machines.dart` (client-side, unenforced), and hand-coded boolean expressions inside `firestore.rules` (the only one actually enforced).
**Why it's wrong:** Changing a transition rule requires remembering to update up to 4 files by hand; a mismatch means the Dart-side "this is a valid move" check can diverge silently from what Firestore will actually allow, producing confusing `permission-denied` errors at write time despite passing client-side validation.
**Do this instead:** Treat `firestore.rules` as the single source of truth going forward; when adding a new phase that touches state machines, update `firestore.rules` first and treat the Dart tables purely as UI-affordance hints, not correctness guarantees.

## Error Handling

**Strategy:** All Firestore/Auth failures surface as SDK exceptions (`FirebaseAuthException`, `FirebaseException`) caught at the controller layer and re-thrown as `StateError`/`ArgumentError` with a human-readable Spanish message for the UI to display verbatim.

**Patterns:**
- `authErrorMessage(FirebaseAuthException, {required fallback})` — duplicated near-identically in `app_cliente/lib/features/auth/auth_controller.dart:45-66` and `panel_admin/lib/features/auth/login_controller.dart:17-34`; maps SDK error codes to Spanish user messages.
- `ArgumentError` — used for local/sync input validation (email regex, password length) performed before any network call.
- `StateError` — used for anything that required a network round-trip and failed (bad credentials, role rejection, transaction failure).
- Firestore `permission-denied` exceptions from rule rejections propagate as generic `FirebaseException` and are the main class of "invisible" bug in this system — a rule mismatch looks identical to a genuine authorization failure from the client's point of view (see Troubleshooting table in `docs/FIREBASE_SETUP.md`).

## Cross-Cutting Concerns

**Logging:** No structured logging in the Flutter apps observed; `scripts/seed_firebase.mjs` uses plain `console.log`/`console.error` for operational visibility.
**Validation:** Split between client-side `ArgumentError` pre-checks (cheap, UX-only) and `firestore.rules` (the actual enforcement boundary). There is no schema validation layer beyond what rules express inline (`is number`, `is int`, `is list`, `.size()` bounds).
**Authentication:** Firebase Auth Email/Password only; JWT-equivalent is the Firebase ID token, auto-refreshed by the SDK; `forceRefresh: true` is used deliberately after login/claims changes to avoid the "stale token" pitfall documented in `docs/FIREBASE_SETUP.md` §4 (claims can take up to 1h to propagate on a cached token otherwise).
**Multi-tenancy:** Enforced by comparing `restauranteId` fields against the caller's `rid` claim inside rules — every collection except `restaurantes`/`usuarios` carries a `restauranteId` field for this purpose.

---

*Architecture analysis: 2026-08-19*
