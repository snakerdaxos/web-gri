# External Integrations

**Analysis Date:** 2026-08-19

## System Integration Model

Both Flutter apps (`app_cliente`, `panel_admin`) are **thin clients that talk directly to Firebase** — there is no intermediary application server. This is the defining integration fact of the system (Phase 10 "Opción B" migration, replacing the archived FastAPI backend in `backend/`).

```
app_cliente (Flutter, Android+Web)  ─┐
                                      ├──> Firebase Auth (Email/Password)  ──> ID token carries custom claims {role, rid}
panel_admin (Flutter Web)           ─┘
                                      └──> Cloud Firestore (direct reads/writes, onSnapshot realtime, runTransaction)
                                                     ▲
                                                     │ authorization enforced by
                                            firestore.rules (repo root)
                                                     ▲
                                                     │ claims {role, rid} written ONLY by
                                    scripts/seed_firebase.mjs (Node, Firebase Admin SDK)
```

Project ID: **`p-gri-b5b40`**.

## APIs & External Services

**Firebase (Google Cloud) — the only external service integrated:**
- **Firebase Authentication** — Email/Password provider only (must be manually enabled: Firebase Console → Authentication → Sign-in method → Email/Password → Enable — this is a manual one-time console step, not automated)
  - Client SDK: `firebase_auth` 6.5.7 (both apps)
  - Custom claims: `{role, rid}` embedded in the ID token
- **Cloud Firestore** — sole data store, accessed directly from both Flutter apps
  - Client SDK: `cloud_firestore` 6.8.0 (both apps)
  - Realtime: `onSnapshot`-style stream listeners for live updates (orders, table state)
  - Concurrency: `runTransaction` used for writes that must be atomic against races (e.g., opening a table session, advancing order state)
- **Firebase Admin SDK (Node)** — server-side only, used exclusively by `scripts/seed_firebase.mjs`
  - Package: `firebase-admin` 14.2.0
  - This is the ONLY code path in the entire system with elevated (Admin SDK) privileges

**No other external APIs are integrated.** No payment gateway (Wompi/PayU/Mercado Pago/Stripe) is wired into either Flutter app — online payment was deferred in the Firebase migration; the client flow only supports "solicitar cuenta" (request the bill), not paying online. The `.env.example` files referencing `WOMPI_*` keys belong to the archived `backend/` and are not consumed anywhere in the active system.

## Custom Claims `{role, rid}` — Authorization Backbone

This is the single most important cross-cutting mechanism in the system.

**What they are:**
- `role`: one of `super_admin`, `admin_restaurante`, `mesero`, `cocina`, `cliente` (implicit default when absent/self-registered)
- `rid`: the restaurant ID a staff member belongs to (`null` for `super_admin` and for `cliente`)
- Both travel inside the Firebase ID token (`request.auth.token.role` / `request.auth.token.rid`), so `firestore.rules` can authorize with **zero extra Firestore reads**.

**WHO can set them — critical constraint:**
- **ONLY `scripts/seed_firebase.mjs`, running with the Firebase Admin SDK, can call `setCustomUserClaims`.** No client-side code, no Flutter app, and no end user can set or modify their own claims — this is enforced by Firebase itself (Admin SDK privilege), not by application logic.
- `firestore.rules` explicitly never reads the `usuarios/{uid}` mirror document for authorization decisions — that doc is a display-only profile mirror ("ESPEJO de perfil: JAMÁS autoriza"). Authorization is 100% claims-based.
- Client self-registration (`usuarios/{uid}` create by the user themselves) is restricted by rule to `role == 'cliente'` and `restauranteId == null` — a client cannot self-elevate to staff even in the mirror doc, and the mirror doc has no bearing on real permissions anyway.

**Propagation pitfall (documented, must be respected in any new work):**
- Claims land in the ID token only on the next token refresh; a token already in memory can live up to 1 hour without the new claims.
- Because the seed script runs BEFORE any user's first login, this is a non-issue for seeded demo users.
- If claims are changed for an already-logged-in user: force re-login, or call `await user.getIdToken(true)`.

**Rules access-call budget (a documented constraint that any new Firestore-touching feature must respect):**
- Firestore security rules charge "access calls" per `get()`; the rules file enforces a self-imposed budget (max ~3 `get()`s per `match` block, repeated gets to the same doc are cached/free). Documented in the rules file header (`firestore.rules` lines ~14-20). Any new rule touching multiple collections must be written with this budget in mind.

## Seeding Path — `scripts/seed_firebase.mjs`

**Purpose:** idempotent seed of one demo restaurant (`restaurantes/demo`), 6 users (Auth + claims + `usuarios/{uid}` mirror), 8 tables (`mesas/GRI-MESA-demo-001..008`), 4 menu categories, 16 products. Ported 1:1 from the archived `backend/app/services/seed_service.py` for parity.

**Two mutually-exclusive modes, auto-detected by environment variables:**

1. **Emulator mode (no credentials):**
   - Requires `FIREBASE_AUTH_EMULATOR_HOST=127.0.0.1:9099` and `FIRESTORE_EMULATOR_HOST=127.0.0.1:8080` set before running
   - Typically invoked via `firebase emulators:exec --only auth,firestore --export-on-exit=./emulator_data "node scripts/seed_firebase.mjs"`
   - Talks to local emulators only — safe to run repeatedly

2. **Real project mode (service account credentials):**
   - Requires `GOOGLE_APPLICATION_CREDENTIALS=./scripts/serviceAccountKey.json` pointing at a key generated via Firebase Console → Project Settings → Service Accounts → Generate new private key
   - **`scripts/serviceAccountKey.json` is gitignored and must never be committed** (`.gitignore` line: `serviceAccountKey.json`)
   - Writes directly to the real `p-gri-b5b40` project — Firestore database must already exist (Console → Firestore Database → Create database) and Email/Password auth provider must be enabled first

**Idempotency (by natural key, checked before every write):**
| Entity | Natural key |
|---|---|
| usuario | email (`createUser` → catch `auth/email-already-exists` → `getUserByEmail`; claims + mirror doc always refreshed via `set`/merge) |
| mesa | doc ID `GRI-MESA-{rid}-{numero:3digits}` (set merge) |
| categoría | `(restauranteId, nombre)` |
| producto | `(restauranteId, categoriaId, nombre)` |
| restaurante | doc ID `demo` (set merge) |

**Seeded demo users (password `Demo!1234` for all — dev/demo only, do not treat as production credential guidance):**
| Email | role claim | rid claim |
|---|---|---|
| `admin@gri.dev` | `super_admin` | `null` |
| `admin@demo.gri.dev` | `admin_restaurante` | `demo` |
| `mesero@demo.gri.dev` | `mesero` | `demo` |
| `cocina@demo.gri.dev` | `cocina` | `demo` |
| `carlos@demo.gri.dev` | `cliente` | `null` |
| `maria@demo.gri.dev` | `cliente` | `null` |

**Running it:** `scripts/package.json` defines `"seed": "node seed_firebase.mjs"`; dependencies (`firebase-admin` 14.2.0, `firebase-tools` 15.27.0 dev) are installed locally via `cd scripts && npm install` (NOT `npm install --prefix scripts` from repo root — documented Windows npm resolution bug in `docs/FIREBASE_SETUP.md` §1).

## Emulator Setup (`USE_EMULATORS` dart-define)

**Ports (configured in `firebase.json` at repo root):**
- Auth emulator: `9099`
- Firestore emulator: `8080`
- Emulator UI: `4000` (http://localhost:4000)

**How apps opt in:**
```
flutter run --dart-define=USE_EMULATORS=true            # app_cliente
flutter run -d chrome --dart-define=USE_EMULATORS=true  # panel_admin
```
- The gate is `const bool.fromEnvironment('USE_EMULATORS', defaultValue: false)` in `app_cliente/lib/core/firebase_bootstrap.dart` and `panel_admin/lib/core/firebase_bootstrap.dart` — a compile-time constant, so builds without the define never even contain the emulator-wiring code path (tree-shaken).
- **Without the flag, both apps talk to the real `p-gri-b5b40` project.** The documented classic symptom of forgetting the flag in dev is an unexpected `permission-denied` from Firestore.
- **Critical ordering constraint:** `Firebase.initializeApp()` must run, THEN `useAuthEmulator`/`useFirestoreEmulator`, BEFORE any Riverpod provider resolves a `FirebaseAuth.instance` or `FirebaseFirestore.instance` — both `main()` functions call `await bootstrap()` before `runApp()` specifically to guarantee this order. If any provider resolves the singleton first, the app silently binds to the real project instead of the emulator.
- Android emulator networking: the Android Firebase SDK auto-maps `localhost` → `10.0.2.2`; a physical Android device needs the LAN IP set manually. `app_cliente/android/app/src/main/res/xml/network_security_config.xml` (present but untracked in git as of this analysis) allow-lists cleartext HTTP traffic to `10.0.2.2`, `127.0.0.1`, and `localhost` specifically so the emulator connection works — all other traffic (real Firebase) stays HTTPS-only.
- Emulator data is volatile by default; `--import=./emulator_data --export-on-exit=./emulator_data` flags make state survive across sessions (`emulator_data/` is gitignored).
- Known gap: emulators require Java 11+ (`firebase emulators:*` runs on the JVM); the dev machine that executed Phase 10 lacked Java, so double-run idempotency testing against live emulators was left as a pending manual verification step (see `.planning/STATE.md`).

## Data Storage

**Database:**
- Cloud Firestore (Native mode), project `p-gri-b5b40` — the only datastore in the active system
- Collections: `restaurantes`, `categorias`, `productos`, `mesas`, `usuarios`, `sesiones`, `pedidos`, `reservas`, `calificaciones`
- Composite indexes defined in `firestore.indexes.json` (repo root) — 9 indexes covering `pedidos`, `reservas`, `sesiones`, `productos`, `mesas` query patterns; deployed via `firebase deploy --only firestore:indexes`
- Legacy/archived: MySQL 8.4 via SQLAlchemy in `backend/` — not connected to anything live

**File storage:** None detected — no Firebase Storage integration found; `productos.imagenUrl` field exists in the seed data model but is seeded as `null` (image upload/hosting is not implemented)

**Caching:** None — Firestore's own client-side persistence/cache is the only caching layer, used implicitly by the SDK

## Authentication & Identity

**Provider:** Firebase Authentication, Email/Password only (must be enabled manually in Firebase Console before any real-project login works)

**Implementation:**
- `firebase_auth` client SDK, direct from both Flutter apps
- Authorization decisions are made entirely via ID token custom claims `{role, rid}`, evaluated in `firestore.rules` — see "Custom Claims" section above
- No session/JWT management code exists in either Flutter app beyond what `firebase_auth` handles internally (the archived `backend/` had custom JWT issuance/refresh — that is gone)

## Monitoring & Observability

**Error Tracking:** None detected — no Crashlytics, Sentry, or similar SDK in either `pubspec.yaml`

**Logs:** No structured logging service integrated; Firebase emulator debug logs (`firestore-debug.log`, `scripts/firestore-debug.log`) are local dev artifacts only, gitignored

## CI/CD & Deployment

**Hosting:** Not configured in `firebase.json` — only `firestore.rules`/`firestore.indexes.json` targets and `emulators` config are present; no Firebase Hosting section, so Flutter Web builds are not currently wired to `firebase deploy`

**Deployment commands (manual, human-run):**
```
npx --prefix scripts firebase login                                          # one-time interactive OAuth
npx --prefix scripts firebase deploy --only firestore:rules,firestore:indexes
```
- **Warning documented in `docs/FIREBASE_SETUP.md`:** a bad rules deploy cuts off ALL Firestore access for every app instantly (client and admin) — rules should always be validated against emulators first.

**CI Pipeline:** None detected — no `.github/workflows/`, no CI config found for either Flutter app or the Node scripts

## Environment Configuration

**Firebase config sources (per-platform, checked into `documentos/` as reference, then baked into `firebase_options.dart` per app):**
- `documentos/google-services.json` — Android app config (present at repo root under `documentos/`, currently untracked in git per `git status`; NOT present inside `app_cliente/android/app/`, the conventional location the Android Gradle plugin expects — Firebase options are instead hardcoded directly into `app_cliente/lib/firebase_options.dart`, so the missing conventional file placement is not currently a functional blocker, but would matter if any native-Android Firebase feature requiring the Google Services Gradle plugin is added later)
- `documentos/firebase-config-web.js` — Web app config, source for the `webOptions` block in both apps' `firebase_options.dart`

**Required build-time flags:**
- `USE_EMULATORS` (dart-define, bool, default `false`) — see Emulator Setup above

**Secrets location:**
- `scripts/serviceAccountKey.json` — gitignored, Admin SDK credential for real-project seeding; never committed
- Root `.env` (exists on disk, gitignored) — belongs to the archived `backend/`, not read by any active-system code

## Webhooks & Callbacks

**Incoming:** None — no HTTP endpoints exist in the active system (no backend server to receive webhooks). The archived `backend/` had a Wompi webhook path (`/webhooks/wompi`) but it is not deployed or reachable.

**Outgoing:** None

---

*Integration audit: 2026-08-19*
