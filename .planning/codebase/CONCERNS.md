# Codebase Concerns

**Analysis Date:** 2026-08-19

**Scope:** System-wide risks after the Phase 10 migration from FastAPI+MySQL to
serverless Firebase (Auth + Firestore + security rules, no backend server).
Services in scope: `app_cliente/` (Flutter mobile client), `panel_admin/`
(Flutter Web admin panel), and the Firebase backend defined by
`firestore.rules` + `firestore.indexes.json` + `scripts/seed_firebase.mjs`.
`backend/` (FastAPI+MySQL) is archived/reference-only and out of scope.

**User-reported symptom under investigation:** "las funciones no sirven y no
permite crear nada desde cero si la base de datos no tiene contenido" — the
apps don't work and nothing can be created from scratch when the database is
empty. Findings below are ranked by severity; **#1–#3 together fully explain
the reported symptom** and are backed by direct evidence in the code and
rules.

---

## CRITICAL — Bootstrap gap: no in-app path to create the first tenant

**Issue:** On a brand-new Firebase project (no prior seed run), there is
**no way, from either app, to create the first `super_admin`, the first
`restaurante`, or any staff user.** The only mechanism that can do any of
these is `scripts/seed_firebase.mjs`, a Node.js script run manually from a
developer machine with either the Firebase emulators or a downloaded
`serviceAccountKey.json` (Admin SDK). This is a deliberate Phase 10 design
choice (see `.planning/phases/10-.../10-RESEARCH.md:594` and
`docs/FIREBASE_SETUP.md` §3–4), not an oversight, but it means **the product
has zero self-service bootstrap** — exactly the reported symptom.

**Evidence:**
- `firestore.rules:99` — `restaurantes` collection: `allow create, delete: if isSuper();`. `isSuper()` (`firestore.rules:38-40`) requires `request.auth.token.role == 'super_admin'`, a **custom claim**.
- Custom claims can only be written by the Admin SDK. The rules comment header states this explicitly: `firestore.rules:8-9` — "La autorización es 100% por custom claims { role, rid } que viajan en request.auth.token (los setea SOLO scripts/seed_firebase.mjs con Admin SDK)."
- `firestore.rules:198-201` (`usuarios/{uid}` create rule) forces every self-registered account to `role == 'cliente'` and `restauranteId == null` — a client can never self-promote to staff or super_admin: `request.resource.data.role == 'cliente' && request.resource.data.restauranteId == null`.
- `app_cliente/lib/features/auth/auth_controller.dart:123-165` (`RegisterController.submit`) — the ONLY registration path in the client app, writes `'role': 'cliente', 'restauranteId': null` unconditionally (line 161-162). No UI, flag, or code path exists to create a restaurant or a staff account.
- `panel_admin/lib/features/configuracion/restaurantes_admin_provider.dart:17-44` — the super-admin's only "Restaurantes" management surface. It provides `restaurantesAdmin` (list all, including inactive) and `toggleRestauranteActivo` (flips the `activo` boolean on an **existing** doc). There is no `crearRestaurante`/create function anywhere in this file or in `panel_admin/lib/features/configuracion/configuracion_screen.dart` (grep for "crear|Crear|Nuevo|FloatingActionButton|showDialog" in that screen returns no restaurant-creation UI).
- `panel_admin/lib/features/auth/login_controller.dart:79-91` — even the super_admin's login only routes to a restaurant *selector*; it never offers to create one. If `restaurantesListProvider` (`restaurantes where activo == true`) returns an empty list, `panel_admin/lib/features/shared/app_shell.dart:54-56` just leaves the selector empty — there is nothing to select and nothing to create.
- `docs/FIREBASE_SETUP.md:112-118` confirms in plain language: "**Quién los setea: SOLO el seed (Admin SDK).** Ningún cliente puede escribir sus propios claims."

**Impact:** A fresh Firebase project (fresh `p-gri-b5b40` or any new project
this is redeployed to) is **completely unusable from the apps alone**. Both
apps assume a `super_admin` user and at least one `restaurante` already
exist. Without running `node scripts/seed_firebase.mjs` from a terminal with
Node.js, Java (for emulators) or a service-account key (for the real
project), nobody — not even a super-admin — can create the first restaurant,
menu, tables, or staff accounts. This matches the user's report precisely.

**Fix approach:** Either (a) ship a one-time "platform setup" screen in
`panel_admin` that an operator with direct Firebase Console access can use to
promote the *first* signed-up user to `super_admin` via a callable Cloud
Function (requires adding Cloud Functions, currently absent from the stack),
or (b) treat `scripts/seed_firebase.mjs` as a required, documented
deployment step (already partially done in `docs/FIREBASE_SETUP.md`) and add
a **pre-flight check in both apps** that detects "no restaurantes exist /
no super_admin claim reachable" and shows an explicit setup instructions
screen instead of a silent empty state or a `StateError`.

---

## CRITICAL — Rules/query mismatch breaks the entire public menu when any item is inactive or out of stock

**Issue:** The per-document Firestore rule for `categorias` and `productos`
denies a query for **the entire collection scan** if even one matched
document fails the rule — and the client's public menu query does not apply
the matching filter, so this is not a hypothetical edge case but a routine
admin action.

**Evidence:**
- `firestore.rules:112-115` (`categorias`) and `firestore.rules:123-128` (`productos`): `allow read: if resource.data.activo == true || menuStaffOf(...)` (categorias), `allow read: if (resource.data.activo == true && resource.data.disponible == true) || menuStaffOf(...)` (productos).
- The rules file's own header comment warns about this exact failure mode: `firestore.rules:109-111` — "OJO (rules por-doc en queries): la query pública DEBE filtrar activo == true o un solo doc inactivo deniega toda la query" and `firestore.rules:120-122` similarly for productos.
- `app_cliente/lib/features/restaurantes/restaurantes_provider.dart:46-53` (`restauranteDetalle`, the public menu-detail screen used by `restaurante_detalle_screen.dart` and `menu_mesa_screen.dart`) issues:
  ```dart
  final catsSnap = await db.collection('categorias').where('restauranteId', isEqualTo: id).get();
  final prodsSnap = await db.collection('productos').where('restauranteId', isEqualTo: id).get();
  ```
  Neither query filters `activo` (categorias) nor `activo`/`disponible` (productos) server-side; filtering happens **after** the fetch, client-side, at lines 60 (`if (!producto.activo) continue;`) and 68 (`..retainWhere((c) => c.activo)`). By the time the client-side filter runs, Firestore has already evaluated the rule against every matched document and — per the documented per-doc semantics — will return `permission-denied` for the **whole** query if any one category is inactive or any one product is inactive/out-of-stock.
- The same file even documents awareness of a *related* index gap in a comment (lines 33-36) but does not address the rules-mismatch risk for `activo`/`disponible` filtering.
- `panel_admin/lib/features/menu/producto_form_dialog.dart:41-46` confirms `disponible` (agotado/out-of-stock toggle) and `activo` are routine, expected staff actions (`_agotado`, `_activo` mutable switch state), not rare edge cases.

**Impact:** As soon as a restaurant admin marks **any single product as
"agotado" (out of stock, `disponible: false`)** or deactivates any category —
completely normal, everyday operations exposed in the panel's own menu
editor — the **entire public menu screen breaks for every customer** of that
restaurant with a Firestore `permission-denied` error, not just that one
item disappearing. This directly produces the "functions don't work"
symptom for any restaurant beyond the pristine seed state, and it will
reproduce on the demo restaurant itself the first time staff mark one item
unavailable.

**Fix approach:** Add server-side filters matching the rule exactly:
`.where('activo', isEqualTo: true)` on `categorias`, and
`.where('activo', isEqualTo: true).where('disponible', isEqualTo: true)` on
`productos`, in `restaurantes_provider.dart`. Note this requires new
composite indexes (see next finding) since `productos` would then combine
two equality filters with `restauranteId` — an equality-only 3-field
combination that Firestore can serve via automatic single-field indexes
without a composite index (equality-only compound queries do not require
one), so no new index should actually be needed for this specific fix, but
verify against `firestore.indexes.json` once implemented.

---

## HIGH — Panel-admin menu screen requires a Firestore composite index that does not exist; feature is 100% broken

**Issue:** `panel_admin`'s "Categorías y productos" (menu management) screen
issues a query that requires a composite index Firestore has never been
asked to build, so it fails with `FAILED_PRECONDITION` (Firestore surfaces
this as "The query requires an index") on every load, for every
restaurant, from day one — including the seeded demo restaurant.

**Evidence:**
- `panel_admin/lib/features/menu/menu_provider.dart:35-39`:
  ```dart
  final cats$ = db.collection('categorias')
      .where('restauranteId', isEqualTo: rid)
      .orderBy('orden')
      .snapshots();
  ```
  An equality filter (`restauranteId`) combined with `orderBy` on a
  **different** field (`orden`) requires a Firestore composite index
  `categorias(restauranteId ASC, orden ASC)`.
- `firestore.indexes.json` (repo root) defines exactly 9 composite indexes,
  covering `pedidos` (×3), `reservas` (×2), `sesiones` (×2), `productos`
  (×1), `mesas` (×1). **There is no `categorias` index at all.**
- The codebase itself documents the gap for the *other* (client-side) query
  that reads the same collection: `app_cliente/lib/features/restaurantes/restaurantes_provider.dart:33-36` — "el `orderBy('orden')` de las categorías se hace client-side — el índice compuesto `categorias(restauranteId, orden)` NO existe en 10-01 y el where simple usa índice de campo único." The client app was written to work around the missing index by sorting client-side (`restaurantes_provider.dart:69`: `categorias.sort((a, b) => a.orden.compareTo(b.orden));`) — but `panel_admin/lib/features/menu/menu_provider.dart` was **not** given the same workaround; it still calls `.orderBy('orden')` server-side.
- `panel_admin/lib/features/menu/menu_screen.dart:58-75` — the screen does have an `AsyncValue.error` branch ("Error cargando el menú" + Reintentar button), so it fails gracefully rather than crashing the app — but the retry button re-runs the same broken query and will fail identically forever, since the cause is a missing server-side index, not a transient error.

**Impact:** The panel-admin screen that restaurant staff/admins use to
**create categories and products from scratch** is non-functional on any
project, seeded or not — the exact "no permite crear nada desde cero"
complaint, but this instance affects even a fully-seeded restaurant, not
just an empty one. This is arguably the single most direct match to the
user's reported symptom, because it blocks menu creation regardless of
whether the seed script has been run.

**Fix approach:** Add `{ "collectionGroup": "categorias", "queryScope":
"COLLECTION", "fields": [{"fieldPath": "restauranteId", "order":
"ASCENDING"}, {"fieldPath": "orden", "order": "ASCENDING"}] }` to
`firestore.indexes.json` and redeploy with `firebase deploy --only
firestore:indexes` (per `docs/FIREBASE_SETUP.md:140`). Until the index is
deployed and finishes building (can take minutes), this screen will
continue to fail for every environment, including any that already ran the
seed script.

---

## MEDIUM — Custom-claim propagation depends on forced token refresh; correctly implemented but fragile to future edits

**Issue:** Both apps correctly force a fresh ID token read after
authentication so that custom claims set by the seed script take effect
immediately, avoiding the up-to-1-hour claim propagation delay Firebase
documents. This is implemented correctly today, but the pattern is easy to
silently break in future edits since it depends on remembering to pass
`true` to `getIdTokenResult`.

**Evidence (currently correct):**
- `app_cliente/lib/features/auth/auth_controller.dart:34` — `final token = await user.getIdTokenResult(true);` inside `claims()`, invoked via `ref.invalidate(claimsProvider)` after every login/register/logout (`auth_controller.dart:100`, `166`, `187`).
- `panel_admin/lib/features/auth/login_controller.dart:74-77` — same pattern: "Claims frescos AL INSTANTE (forceRefresh dentro de claimsProvider)" then `ref.invalidate(claimsProvider); final claims = await ref.read(claimsProvider.future);`.
- `docs/FIREBASE_SETUP.md:121-125` documents the pitfall and the mitigation (re-login or `getIdToken(true)`) for the case where claims are changed on an **already-logged-in** user (e.g., an admin re-running the seed script against a user who is currently using the app) — this scenario is NOT automatically handled, since `forceRefresh` only runs at the next explicit `claimsProvider` invalidation (login/logout), not on an idle, already-authenticated session.

**Impact:** Low risk today because both login flows do call
`forceRefresh: true`. The residual risk is an already-logged-in staff member
whose claims change server-side (re-seed, manual Console edit) mid-session:
their app will keep using stale claims until they log out/in or the token
naturally expires (up to 1h), and neither app has a periodic or
app-resume re-check of claims.

**Fix approach:** Low priority for v1 (claims rarely change after initial
seeding), but if staff role changes become a supported operation, add a
periodic or app-lifecycle-triggered `getIdTokenResult(true)` refresh (e.g.
on `AppLifecycleState.resumed`) rather than relying solely on
login/register/logout transitions.

---

## MEDIUM — `restaurantes` rating-update rule is an unauthenticated write vector for any signed-in client

**Issue:** The `firestore.rules` file itself documents this as an accepted
v1 gap, but it is worth flagging explicitly as it allows any authenticated
`cliente` to overwrite a restaurant's aggregate rating fields directly,
without going through the calificación transaction that is supposed to
compute them.

**Evidence:**
- `firestore.rules:100-107`:
  ```
  allow update: if (isSuper() && ... hasOnly(['activo']))
                || (isCliente()
                    && request.resource.data.diff(resource.data).affectedKeys().hasOnly(['califProm', 'califCount'])
                    && request.resource.data.califProm is number
                    && request.resource.data.califCount is int);
  ```
- Comment at `firestore.rules:98`: "Un update standalone de esas 2 keys sin calificación real es un gap estructural aceptado en v1 — validación fuerte = Functions, DEFERRED."

**Impact:** Any signed-in `cliente` (i.e., anyone who has registered an
account — trivial, self-service) can write arbitrary values to
`califProm`/`califCount` on any restaurant document, independent of whether
they ever placed an order or submitted a real `calificaciones` doc. This
does not compromise tenant data isolation but can corrupt the public rating
shown to all customers — a data-integrity, not access-control, risk.

**Fix approach:** Move rating aggregation to a Cloud Function triggered on
`calificaciones` writes (already the acknowledged long-term fix in the
rules comment); until Cloud Functions are introduced, this remains an
accepted, documented v1 limitation — not a first-run blocker, ranked MEDIUM
rather than CRITICAL because it does not prevent bootstrap or basic
functionality.

---

## LOW — Seed script and app assume a single hardcoded restaurant id (`demo`) and project id (`p-gri-b5b40`)

**Issue:** `scripts/seed_firebase.mjs` hardcodes `PROJECT_ID = 'p-gri-b5b40'`
(`scripts/seed_firebase.mjs:34`) and `RID = 'demo'`
(`scripts/seed_firebase.mjs:35`). Running the seed against a different
Firebase project id works (the Admin SDK is initialized from the service
account file's own `project_id`, `scripts/seed_firebase.mjs:82-88`), but
anyone standing up a second, non-demo restaurant must do so entirely by hand
through the (currently non-existent, see CRITICAL #1) super-admin UI, or by
writing a second bespoke seed script.

**Impact:** Low — this only affects operational scaling beyond the single
demo tenant, not correctness of the demo flow itself. Documented here
because it compounds CRITICAL #1: even once someone manually grants
`super_admin` via the Firebase Console, there is still no supported,
repeatable, in-app way to onboard restaurant #2.

**Fix approach:** Once a super-admin "create restaurante" UI exists (fix for
CRITICAL #1), this concern is resolved as a side effect; no separate action
needed beyond that.

---

## Test Coverage Gaps

**First-run / empty-database bootstrap flow:**
- What's not tested: There is no automated test (unit, widget, or
  emulator-backed integration) in `app_cliente/test/` or `panel_admin/test/`
  that exercises "fresh project, zero documents, zero custom claims" and
  asserts that the app shows an actionable message rather than a dead end.
- Files: `app_cliente/test/`, `panel_admin/test/` (test suites exist and are
  reported green per `.planning/phases/10-.../10-07-SUMMARY.md`, but none
  specifically cover the zero-super-admin/zero-restaurante state).
- Risk: This exact gap is what let the reported symptom ship undetected —
  the test suites validate behavior assuming a seeded restaurant exists.
- Priority: High — a smoke test asserting "empty restaurantes collection →
  public list screen shows an empty state, not an error" and "no
  super_admin claim reachable → panel shows setup guidance, not a dead
  selector" would have caught this class of issue directly.

**Rules-vs-query parity for public menu queries:**
- What's not tested: No test asserts that `restaurantes_provider.dart`'s
  `categorias`/`productos` queries stay filtered consistently with
  `firestore.rules`'s per-document `activo`/`disponible` conditions.
- Files: `app_cliente/lib/features/restaurantes/restaurantes_provider.dart`,
  `firestore.rules:109-128`.
- Risk: Silent breakage the moment any product is marked unavailable or any
  category is deactivated (see CRITICAL finding above) — no test would
  catch a future regression here either, since Firestore emulator tests
  would need explicit "one inactive item present" fixtures to reproduce it.
- Priority: High.

**Composite index coverage:**
- What's not tested: No CI check compares queries issued in
  `app_cliente/lib` and `panel_admin/lib` against
  `firestore.indexes.json` to catch missing composite indexes before
  deploy (the `categorias(restauranteId, orden)` gap above shipped
  silently).
- Files: `firestore.indexes.json`, all `*_provider.dart` files under
  `lib/features/**/`.
- Risk: Any new `.where(...).orderBy(...)` query added in either app can
  reintroduce this exact class of bug with no automated signal until a
  human clicks the broken screen.
- Priority: Medium — the Firestore emulator (already used in this project,
  see `docs/FIREBASE_SETUP.md` §2) can surface `FAILED_PRECONDITION`
  errors in integration tests if such tests are added against seeded
  emulator data that includes deliberately unsorted/multi-value fields.

---

*Concerns audit: 2026-08-19*
