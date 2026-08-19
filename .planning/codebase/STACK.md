# Technology Stack

**Analysis Date:** 2026-08-19

## System Shape

GRI is a **multi-service repo** with three active pieces and one archived one:

| Service | Path | Role |
|---|---|---|
| `app_cliente` | `app_cliente/` | Flutter mobile+web client app (customers) |
| `panel_admin` | `panel_admin/` | Flutter Web admin panel (restaurant staff + super-admin) |
| Firebase backend | repo root: `firestore.rules`, `firestore.indexes.json`, `firebase.json`, `scripts/seed_firebase.mjs` | Serverless backend-as-a-service — Auth + Firestore + declarative security rules. No custom server code. |
| `backend/` | `backend/` | **ARCHIVED** FastAPI + MySQL implementation, kept as reference only after the Phase 10 migration to Firebase. Not deployed, not maintained, not to be extended. Per-service internals of `app_cliente` and `panel_admin` are mapped separately — this document covers system-wide/shared concerns only. |

**Core architectural fact:** Since Phase 10, there is **no application backend server**. Both Flutter apps talk directly to Firebase Auth and Cloud Firestore via the client SDKs. Authorization that used to live in FastAPI (`TenantScope`, `require_roles`) now lives 100% in `firestore.rules` at the repo root, driven by custom claims `{role, rid}` embedded in the Firebase ID token.

## Languages

**Primary:**
- Dart 3.13+ (SDK constraint `^3.13.0` in both `app_cliente/pubspec.yaml` and `panel_admin/pubspec.yaml`) - Flutter apps (client mobile/web, admin web)
- JavaScript (Node.js, ESM `"type": "module"`) - `scripts/seed_firebase.mjs`, Firebase Admin SDK tooling

**Secondary / archived:**
- Python 3.12 - `backend/` (archived FastAPI+MySQL reference implementation, not in active use)

## Runtime

**Flutter apps:**
- Flutter SDK 3.47 (per `docs/FIREBASE_SETUP.md` requirements table; `C:\src\flutter\bin` expected in PATH for local dev)
- Targets: Android + Web for `app_cliente`; Web only for `panel_admin`
- Package manager: `pub` (via `flutter pub get`), lockfiles present: `app_cliente/pubspec.lock`, `panel_admin/pubspec.lock`

**Node tooling (`scripts/`):**
- Node.js 18+ (verified against v24 per docs)
- npm, lockfile present: `scripts/package-lock.json`
- IMPORTANT (Windows): run `npm install` from inside `scripts/` — `npm install --prefix scripts` from repo root resolves the wrong `package.json` on Windows (documented pitfall in `docs/FIREBASE_SETUP.md` §1)

**Archived backend runtime (do not use for new work):**
- Python 3.12, `uv` package manager, `backend/uv.lock` — reference only

## Frameworks

**Core (client apps):**
- Flutter (UI framework) - both `app_cliente` and `panel_admin`
- `flutter_riverpod` `>=3.0.0 <4.0.0` + `riverpod_annotation` - state management + DI, identical stack pinned across both apps (comment in pubspec: "stack LOCKED — idéntico a panel_admin 04-02")
- `go_router` `^17.5.0` - declarative routing in both apps
- `freezed_annotation` + `json_annotation` + `freezed` (pinned to prerelease `4.0.0-dev.3`) + `json_serializable` - immutable models + JSON codegen. **Pin note:** `freezed 3.2.6-dev.1` generates invalid `required final List<T>` for `List` fields; only `4.0.0-dev.3` paired with `json_serializable >=6.8.0 <7.0.0` works — do not "upgrade" freezed casually.
- `build_runner` - codegen runner for freezed/riverpod_generator/json_serializable

**Firebase client SDKs (exact pins, LOCKED identically in both apps — see `INTEGRATIONS.md`):**
- `firebase_core: 4.13.0`
- `firebase_auth: 6.5.7`
- `cloud_firestore: 6.8.0`

**Testing:**
- `flutter_test` (SDK)
- `fake_cloud_firestore: 4.2.0` + `firebase_auth_mocks: 0.15.2` + `mock_exceptions: ^0.8.2` - Firebase fakes for unit tests. **Constraint:** Firebase emulators do NOT work inside `flutter test` (no platform channels) — tests must use these in-memory fakes instead of the real emulator suite.

**App-specific extras:**
- `app_cliente`: `mobile_scanner: ^7.4.0` (QR scanning; web works on `localhost` secure context — manual code entry `GRI-MESA-XXX` is a first-class fallback, not a hack)
- `panel_admin`: `qr_flutter: 4.1.0` (QR generation for table codes), `data_table_2: 2.8.0` (paginated tables), `web: 1.1.1`

**Server-side tooling (not a runtime framework — dev/ops only):**
- `firebase-admin: 14.2.0` (Node) - used exclusively by `scripts/seed_firebase.mjs` to write Firestore docs and set custom claims
- `firebase-tools: 15.27.0` (Node, devDependency) - emulator suite + `firebase deploy` CLI, installed locally under `scripts/` (NOT global) per `scripts/package.json`

## Key Dependencies

**Critical:**
- `cloud_firestore` 6.8.0 - sole source of truth for all application data (restaurants, tables, orders, reservations, menu, ratings); both apps read/write it directly with `onSnapshot` for realtime and `runTransaction` for concurrency-sensitive writes (table state changes, order creation)
- `firebase_auth` 6.5.7 - identity; ID token carries custom claims `{role, rid}` that `firestore.rules` reads for authorization (zero extra Firestore reads to authorize)
- `firestore.rules` (repo root, 15.6 KB) - the entire authorization layer; replaces the archived backend's `TenantScope` + `require_roles` middleware

**Infrastructure / tooling:**
- `firebase-admin` (Node, `scripts/`) - the ONLY code path that can set custom claims; no client can self-elevate role/rid
- Firebase emulator suite (Auth :9099, Firestore :8080, UI :4000) - configured in `firebase.json` at repo root

## Configuration

**Environment / build-time flags:**
- `USE_EMULATORS` dart-define — the single flag controlling whether a Flutter app talks to local emulators or the real Firebase project (see `INTEGRATIONS.md` for full mechanics). Passed as `flutter run --dart-define=USE_EMULATORS=true`.
- `firebase_options.dart` (one per app: `app_cliente/lib/firebase_options.dart`, `panel_admin/lib/firebase_options.dart`) — hardcoded `DefaultFirebaseOptions` (apiKey, appId, projectId `p-gri-b5b40`, etc.) generated via `flutterfire configure` or filled manually from `documentos/google-services.json` (Android) and `documentos/firebase-config-web.js` (Web). The Firebase `apiKey` here is public-by-design (identifies project, does not authenticate) — real security is Auth + rules.
- Root `.env` / `.env.example` / `.env.production.example` — **legacy, belong to the archived `backend/`** (MySQL credentials, JWT secret, Wompi payment keys, CORS origins). Not consumed by the Flutter apps or the Firebase tooling. `.env` exists on disk but its contents are not read here (gitignored, contains secrets by convention).
- `run_app.bat` (repo root) — convenience launcher: `flutter run -d emulator-5554 --dart-define=USE_EMULATORS=true` for `app_cliente`, logging to `flutter_run.log`.

**Build:**
- `app_cliente/analysis_options.yaml`, `panel_admin/analysis_options.yaml` — Dart/Flutter lint config (`flutter_lints: ^6.0.0` in both)
- `firebase.json` (repo root) — Firestore rules/indexes file pointers + emulator port config only; no hosting/functions config present (no Cloud Functions in this project — noted as a deliberate v1 gap for total/rating validation, see CONCERNS)

## Platform Requirements

**Development:**
- Flutter SDK 3.47 with `C:\src\flutter\bin` in PATH (Windows dev machine observed)
- Node.js 18+ and npm for `scripts/`
- Java JRE 11+ — required ONLY to run the Firebase emulator suite locally (`firebase emulators:*` runs on Java); without it, local emulator-based dev/testing is unavailable (flagged as a known gap in `docs/FIREBASE_SETUP.md` — the dev machine that produced Phase 10 lacked Java, so double-run idempotency of the seed against emulators was left as a pending verification)
- Android SDK/emulator (`emulator-5554` referenced in `run_app.bat`) for `app_cliente` Android target
- Chrome (or any modern browser) for Flutter Web targets (`panel_admin` is web-only; `app_cliente` also runs in Chrome per its pubspec description "web-first en Chrome")

**Production:**
- Firebase project `p-gri-b5b40` (Google Cloud) — Firestore (Native mode) + Authentication (Email/Password provider) + hosting of security rules/indexes via `firebase deploy --only firestore:rules,firestore:indexes`
- No application server to deploy — deployment surface is: (1) Firestore rules/indexes deploy, (2) Flutter app builds (Android APK/AAB, Flutter Web bundle) distributed independently of any backend release
- The archived `backend/` + `docker-compose.yml` + `deploy/` (Ubuntu/Docker/nginx/MySQL) describe a **previous, no-longer-used production target** — do not use these for new deployment work; they predate the Firebase migration

---

*Stack analysis: 2026-08-19*
