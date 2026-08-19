# Testing Patterns

**Analysis Date:** 2026-08-19

**Scope:** `app_cliente/test/` (12 files) and `panel_admin/test/` (15 files). The `backend/tests/` suite (pytest, FastAPI+MySQL) belongs to the ARCHIVED backend and is not covered here — see backend's own history if ever needed, but it is not part of the live system.

## Answering the key questions up front

**Are these real integration tests against the Firestore emulator, or fakes/mocks?**
**They are fakes, not emulator integration tests.** Every test in both `app_cliente/test/` and `panel_admin/test/` runs under plain `flutter test` and substitutes Firebase with in-memory Dart packages:
- `fake_cloud_firestore` (`FakeFirebaseFirestore`) stands in for `cloud_firestore` — an in-memory Dart re-implementation of the Firestore client API (queries, transactions, snapshots), not a wire-protocol client talking to any server.
- `firebase_auth_mocks` (`MockFirebaseAuth`, `MockUser`) stands in for `firebase_auth`.
- `mock_exceptions` (`whenCalling(...).thenThrow(...)`) is used to simulate `FirebaseAuthException`s from the mock.

This is a deliberate, documented choice, not an oversight — both `test/helpers/firebase_fakes.dart` files state explicitly: *"Los emuladores NO funcionan en `flutter test` (sin platform channels de red) — por eso fakes in-memory."* (Firebase emulators require real network/platform channels that `flutter test`'s host-only test runner does not provide.)

Practical consequence: these tests validate the Dart-side domain logic (transactions, state transitions, snapshot handling, UI reactions to Firestore stream changes) against a Firestore-*shaped* in-memory store — they do **not** validate `firestore.rules` (fakes have no rules engine), Firestore's real transaction/OCC semantics, real composite-index requirements, or real network error modes.

**Do any tests exercise `firestore.rules`?**
**No.** There is no `@firebase/rules-unit-testing` suite, no `firestore-emulator` invocation in CI/test scripts, and no `*.rules.test.*` file anywhere in the repo (verified: no such file exists, and `scripts/package.json` only has a `seed` script, no `test:rules` script). `firestore.rules` (repo root) is verified only by:
1. Manual/human review, and
2. The manual smoke-test runbook `docs/SMOKE-E2E.md` (running the real apps against the Firebase emulators or the real project by hand, per the checkpoint-human step referenced in recent commits: "checkpoint humano deploy pendiente (SMOKE-E2E)").

This is a real coverage gap: rule regressions (e.g. a loosened `allow write` clause) are not caught by any automated test in this repo, only by human execution of the smoke runbook before deploy.

**Is there a test covering the empty-database / first-run bootstrap scenario?**
**No.** Every single test helper builds its `FakeFirebaseFirestore` via `buildFakeFirestoreConSeed()` (`test/helpers/firebase_fakes.dart` in both apps), which pre-populates `restaurantes/demo`, 3 mesas, 2 categorías, 4 productos before the test body runs. No test in either suite constructs a bare `FakeFirebaseFirestore()` and exercises the app against a genuinely empty Firestore (no restaurant doc, no seed data). This means:
- There is no test proving what the app does on a truly fresh/unseeded project (e.g. a new restaurant's first login, or a first deploy before `scripts/seed_firebase.mjs` has ever run).
- The closest thing to a "first-run" check is the **idempotency** of the seed script itself, and that check is manual, not automated: `docs/FIREBASE_SETUP.md` §3 instructs a human to run `node scripts/seed_firebase.mjs` twice against the emulator and eyeball the log for "6/6, 4/4, 16/16 existente, no duplicados" — there is no `*.test.mjs` asserting this.

## Test Framework

**Runner:**
- `flutter_test` (bundled with Flutter SDK) — both apps, no separate config file (no `dart_test.yaml`).
- Widget tests use `testWidgets(...)`; pure-Dart/business-logic tests use plain `test(...)` in the same files, freely mixed within one `main()` per test file.

**Assertion Library:**
- Built-in `package:flutter_test` / `package:test` matchers: `expect`, `expectLater`, `throwsA(isA<T>())`, `.having(...)` for exception field assertions, `findsOneWidget`/`findsNWidgets`/`findsNothing`/`findsAtLeastNWidgets` for widget finders.

**Run Commands:**
```powershell
cd app_cliente
flutter test                          # run all tests
flutter test test/pedidos/carrito_test.dart   # run a single file
flutter test --coverage               # coverage (writes coverage/lcov.info)

cd panel_admin
flutter test
flutter test test/cocina/entregar_cuenta_test.dart
flutter test --coverage
```
There is no root-level script that runs both suites together — each Flutter project's tests must be run from within its own directory (`app_cliente/` or `panel_admin/`).

## Test File Organization

**Location:** Not co-located with source — tests live in a parallel `test/` tree per app, mirroring the `lib/features/<name>/` structure:
```
app_cliente/test/
├── auth/login_register_test.dart
├── helpers/firebase_fakes.dart      # shared fixtures (not a test file itself)
├── pagos/calificacion_sheet_test.dart
├── pedidos/carrito_test.dart
├── pedidos/cuenta_test.dart
├── pedidos/estado_test.dart
├── perfil/perfil_edit_test.dart
├── reservas/mis_reservas_render_test.dart
├── reservas/wizard_form_test.dart
├── restaurantes/list_test.dart
├── sesion_qr/scan_test.dart
└── state_machines_test.dart         # pure-logic test, no feature subfolder

panel_admin/test/
├── auth/login_form_test.dart
├── clientes/clientes_screen_test.dart
├── cocina/cola_test.dart
├── cocina/entregar_cuenta_test.dart
├── configuracion/restaurantes_test.dart
├── dashboard/mesa_actions_test.dart
├── dashboard/mesa_tile_color_test.dart
├── dashboard/stats_render_test.dart
├── helpers/firebase_fakes.dart
├── menu/menu_screen_test.dart
├── mesas/mesas_screen_test.dart
├── mesas/qr_dialog_test.dart
├── reportes/reportes_screen_test.dart
├── reservas/reservas_screen_test.dart
└── state_machines_test.dart
```

**Naming:** `<feature_or_screen>_test.dart`. Test names inside `test(...)`/`testWidgets(...)` are full Spanish sentences describing behavior + expected outcome, often prefixed with a scenario tag, e.g. `'crearPedido con sesión CERRADA → error controlado, sin doc creado'`, `'(a) data: sesión activa+ocupada → cerrada y mesa a limpieza (una tx)'`. Multi-case suites (like `entregar_cuenta_test.dart`) letter-prefix related cases `(a)`, `(b)`, `(c)`, `(d)` to group data-layer cases before the widget-layer case.

**Structure:** One `helpers/firebase_fakes.dart` per app is the single shared fixture file — everything else is self-contained per test file (no separate `setUp`/`tearDown` blocks in most files; fixtures are built fresh inline at the top of each `test`/`testWidgets` body via local helper functions like `_pumpConSesion`, `_sesion`, `_detalle`).

## Test Structure

**Suite Organization:** Tests are NOT wrapped in `group(...)` blocks in the files reviewed — a flat `main() { test(...); test(...); testWidgets(...); }` list per file, with `//` section-divider comments to separate logical groups, e.g.:
```dart
void main() {
  // ── Unidad: snapshot del carrito + tx crearPedido ───────────────────────
  test('...', () async { ... });
  test('...', () async { ... });

  // ── Widgets: menú de la mesa + carrito (sesión real Firestore) ──────────
  testWidgets('...', (tester) async { ... });
}
```

**Patterns:**
- **Setup:** Each test builds its own fresh `FakeFirebaseFirestore` at the top of the test body (`final db = await buildFakeFirestoreConSeed();`) — no shared mutable fixture between tests, so tests are naturally isolated even without explicit `setUp`/`tearDown`.
- **Widget pump pattern:** `ProviderScope(overrides: [firestoreProvider.overrideWithValue(db), firebaseAuthProvider.overrideWithValue(mockAuth()), ...], child: MaterialApp(home: SomeScreen()))` → `tester.pumpWidget(...)` → `await tester.pumpAndSettle()`.
- **Teardown:** When a bare `ProviderContainer()` is created directly (unit tests that don't need a widget tree), it is disposed via `addTearDown(container.dispose);` immediately after creation.
- **Assertion style:** Assert against the FAKE FIRESTORE'S RAW DOCUMENT DATA after an action, not just against in-memory model state — e.g. after calling `crearPedido`, tests re-fetch the doc (`(await db.collection('pedidos').get()).docs...`) and assert on the raw map (`pedido.data()['estado']`, `['items']`, `['total']`) rather than trusting the returned `Pedido` model. This is deliberate: it verifies the actual wire-shape written to Firestore matches the documented doc shape.

## Mocking

**Framework:** `fake_cloud_firestore` (in-memory Firestore), `firebase_auth_mocks` (mock Auth), `mock_exceptions` (`whenCalling`).

**Patterns:**
```dart
// Standard override block used at the top of nearly every widget test:
final db = await buildFakeFirestoreConSeed();
final auth = mockAuth(email: 'carlos@demo.gri.dev');
final container = ProviderContainer(overrides: [
  firebaseAuthProvider.overrideWithValue(auth),
  firestoreProvider.overrideWithValue(db),
]);

// Simulating an Auth error (from firebase_fakes.dart doc-comment):
whenCalling(any).on(auth).thenThrow(
  FirebaseAuthException(code: 'invalid-credential'),
);

// Overriding claims directly (role/rid) instead of mocking the ID token:
claimsProvider.overrideWith((ref) async => (role: 'mesero', rid: 'demo'))
```
`mockAuth({String? email, String uid = 'test-uid', String? displayName, bool signedIn = true})` is the shared factory in both `test/helpers/firebase_fakes.dart` files — it defaults to a stable `uid: 'test-uid'` so that `usuarios/{uid}` docs are predictable across tests.

**What to Mock:** Only the two Firebase entry points (`firebaseAuthProvider`, `firestoreProvider`) — because of the "features never touch `FirebaseX.instance` directly" convention (see CONVENTIONS.md), overriding these two providers is sufficient to isolate ANY feature from the network, with no per-feature mocking needed.

**What NOT to Mock:** Domain logic (state machines, transaction functions, controllers) is exercised for real against the fake Firestore — `crearPedido`, `entregarCuenta`, `validarTransicion` etc. are called directly, not stubbed. The test suite's philosophy is "fake the infrastructure boundary, run the real domain code."

## Fixtures and Factories

**Test Data:** `buildFakeFirestoreConSeed()` (in both `test/helpers/firebase_fakes.dart`) is the canonical seed — restaurante `demo`, mesas `GRI-MESA-demo-001..003` (doc ID = QR code), 2 categorías (Platos fuertes, Bebidas), 4 productos with `int` COP prices. Its comment states it intentionally mirrors the SAME shape as `scripts/seed_firebase.mjs` (the real seed script), just a smaller subset (3 mesas / 4 productos vs. the real seed's 8 mesas / 16 productos across 4 categories) — keep the two in sync if the Firestore doc shape changes.

```dart
Future<FakeFirebaseFirestore> buildFakeFirestoreConSeed() async {
  final db = FakeFirebaseFirestore();
  await db.doc('restaurantes/demo').set({ ... });
  // mesas/GRI-MESA-demo-001..003, categorias, productos ...
  return db;
}

MockFirebaseAuth mockAuth({String? email, String uid = 'test-uid', ...}) => ...;
```

**Location:** `app_cliente/test/helpers/firebase_fakes.dart` and `panel_admin/test/helpers/firebase_fakes.dart` (one per app, not shared as a package). Feature-specific fixture data (e.g. a `RestauranteDetalle` with specific products for a menu test, or a `sesiones/{mesaId}` doc for a cuenta/session test) is defined locally inside the test file that needs it (e.g. `_detalle()` in `carrito_test.dart`, `_sesion(...)` in `entregar_cuenta_test.dart`) rather than centralized.

## Coverage

**Requirements:** No enforced coverage threshold found (no CI config, no `codecov.yml`, no coverage gate script in the repo). Coverage is generated on demand only.

**View Coverage:**
```powershell
flutter test --coverage
# writes app_cliente/coverage/lcov.info or panel_admin/coverage/lcov.info
# view with genhtml (lcov) or any lcov-compatible viewer
```

## Test Types

**Unit Tests:** Pure-Dart logic tests with zero widget tree — state machine transition tables (`state_machines_test.dart`, present in both apps, ports of the same coverage as the archived Python backend's tests), and Firestore-transaction domain functions called directly against `FakeFirebaseFirestore` without pumping any widget (e.g. the first several `test(...)` blocks in `carrito_test.dart` and `entregar_cuenta_test.dart`).

**Integration Tests (fake-backed, in-process):** `testWidgets` tests that pump a real screen widget wired to `FakeFirebaseFirestore`/`MockFirebaseAuth` via `ProviderScope` overrides, then interact via `tester.tap`/`tester.pump` and assert both on rendered widgets AND on the resulting Firestore fake's document state. This is the dominant test type in both suites — it is the closest thing to an "integration test" this repo has, but it integrates Dart code with a Dart fake, not with real Firebase infrastructure. There is no true integration test against the Firebase emulator or real project anywhere in the automated suite.

**E2E Tests:** Not automated. `docs/SMOKE-E2E.md` is a manual, human-executed runbook (labelled "Gate final Fase 10") that walks through the full flow (reserve → occupy → QR → order → kitchen → served → bill → close table → rate → super-admin → deploy rules) against either the Firebase emulators or the real `p-gri-b5b40` project. It requires a human checkpoint before rules/index deploy — see the repo's recent commit history (`docs: Phase 10 verificada - checkpoint humano deploy pendiente (SMOKE-E2E)`). No `integration_test/` directory (Flutter's own e2e test package) exists in either app.

## Common Patterns

**Async Testing:**
```dart
test('crearPedido con sesión CERRADA → error controlado, sin doc creado', () async {
  final db = await buildFakeFirestoreConSeed();
  await abrirSesion(db, uid: 'uid-a', codigoQR: _mesa);
  await db.doc('sesiones/$_mesa').update({'estado': 'cerrada'});

  await expectLater(
    crearPedido(db, uid: 'uid-a', mesaCodigo: _mesa, items: _items),
    throwsA(isA<PedidoException>()),
  );
  expect((await db.collection('pedidos').get()).docs, isEmpty);
});
```

**Widget + live-stream testing** (asserting a Firestore `.snapshots()`-driven UI updates after a write, without manually re-pumping a stream):
```dart
testWidgets('... el aviso DESAPARECE del header en vivo', (tester) async {
  final db = await buildFakeFirestoreConSeed();
  await _sesion(db, mesaId: 'GRI-MESA-demo-003', estado: 'activa', cuentaSolicitada: true);
  await tester.pumpWidget(_cocina(db));
  await tester.pumpAndSettle();

  expect(find.text('1 mesa pidió la cuenta'), findsOneWidget);
  await tester.tap(find.text('1 mesa pidió la cuenta'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Mesa 3'));
  await tester.pumpAndSettle();               // re-settles after the fake Firestore write re-emits

  expect(find.text('1 mesa pidió la cuenta'), findsNothing);
});
```

**Error Testing (exception field assertions):**
```dart
await expectLater(
  crearPedido(db, uid: 'uid-a', mesaCodigo: _mesa, items: const []),
  throwsA(isA<PedidoException>()
      .having((e) => e.message, 'message', 'Tu carrito está vacío')),
);
```

## Gaps to Be Aware of When Adding Tests

- **No `firestore.rules` coverage anywhere** — if you change `firestore.rules`, there is no automated test to catch a regression; only the manual `docs/SMOKE-E2E.md` runbook and human review. Consider this a standing risk when touching rules, especially `allow write` clauses.
- **No empty/unseeded-Firestore test path** — every fixture assumes `buildFakeFirestoreConSeed()` has already run. First-run/bootstrap behavior (what happens before `scripts/seed_firebase.mjs` has ever executed against a project) is unverified by any automated test.
- **Fakes diverge from real Firestore semantics** in at least two known ways relevant to this codebase: (1) fakes have no security rules engine at all, so client-side "anti-spoofing" checks inside `runTransaction` are the only thing exercised by tests — the redundant `firestore.rules` enforcement is never exercised; (2) fakes don't require composite indexes, so a query missing a real Firestore index will pass in tests and fail in production (`docs/FIREBASE_SETUP.md` troubleshooting table calls this out as a known gotcha: "`The query requires an index`").
- **No JS/Node test for `scripts/seed_firebase.mjs`** — its idempotency ("doble corrida = prueba de idempotencia") is a manual, documented procedure, not an automated test.

---

*Testing analysis: 2026-08-19*
