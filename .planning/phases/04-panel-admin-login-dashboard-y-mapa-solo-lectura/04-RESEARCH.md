# Phase 4: Panel Admin — Login, Dashboard y Mapa (Solo Lectura) - Research

**Researched:** 2026-08-13
**Domain:** Flutter Web (panel admin) + FastAPI staff-scoped read endpoints (tenant-isolated stats/mesas)
**Confidence:** HIGH

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|-----------------|
| PLAT-01 | Super-admin puede iniciar sesión en el panel web con sus credenciales | Auth flow (§Pattern 1) reuses existing `/auth/login` + `/auth/refresh` + `/auth/me`; `go_router` redirect guard (§Pattern 4) admits any authenticated role; super-admin `restaurant_id=None` handled by the "mi-restaurante" resolution (§Open Q1). |
| ADMN-01 | Panel muestra dashboard con estadísticas: mesas disponibles/ocupadas, reservas del día, pedidos activos | New `GET /staff/stats` endpoint (§Endpoint Contract) returns `DashboardStats`; Riverpod `AsyncValue` + stat cards (§Code Examples) render it. |
| ADMN-02 | Panel muestra mapa de mesas con su estado codificado por color (verde/rojo/amarillo/azul) y actualización en vivo (en esta fase: al refrescar/polling corto) | New `GET /staff/mesas` endpoint (tenant-scoped) + color mapping table from `index.html` mockup (§Color System) + `Timer.periodic` polling provider (§Pattern 6). Real WS arrives Phase 7 (deferred). |
</phase_requirements>

## Summary

Phase 4 is the **first Flutter app** in the project and the **first read-only consumer** of the domain layer seeded in Phase 3. It has two independent workstreams that converge on one UX:

1. **Backend (FastAPI):** three new tenant-scoped read endpoints (`GET /staff/stats`, `GET /staff/mesas`, plus a "mi-restaurante" resolution) + `CORSMiddleware` (currently absent in `app/main.py`). Zero new Python dependencies — everything reuses the Phase 1–3 stack (SQLAlchemy 2.0 async, `get_tenant_scope`, existing models). The endpoints follow the *exact* pattern already proven in `admin_service.get_restaurante_for_staff` (`stmt.where(...restaurant_id == scope.restaurant_id)`).
2. **Frontend (Flutter Web):** a new `panel_admin/` Flutter project, feature-first structure, Riverpod 3 + go_router 17 + dio 5 + flutter_secure_storage. Login screen → redirect-guarded dashboard with 4 stat cards + colored mesa grid, matching the `documentos/index.html` mockup identity verbatim.

The dominant risk is **environmental, not architectural**: Flutter SDK is not yet on PATH on this Windows machine (verified: `Get-Command flutter` → not found), while Chrome IS installed at the default location. The plan MUST gate Wave 0 on confirming `flutter` is callable. The second risk is **CORS**: the panel (e.g. `http://localhost:5173`) and the API (`http://localhost:8000`) are different origins, so without `CORSMiddleware` the browser blocks every request at preflight — this is the #1 "it works in Bruno/Postman but not in the browser" trap.

**Primary recommendation:** Scaffold `panel_admin/` with feature-first layout, add `CORSMiddleware` + a new thin `/staff` router (3 endpoints) on the backend, pin the panel dev port with `--web-port` for a deterministic CORS origin, and use `flutter_secure_storage` for JWT (uniform API with the future cliente app; Web caveat documented). Polling every 10s via a `Timer`-backed Riverpod provider is the explicit Phase 4 debt that Phase 7 WebSockets retires.

## Standard Stack

### Backend — additions (zero new dependencies)

| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| **starlette CORSMiddleware** | (bundled in `fastapi[standard]`) | Allow the Flutter Web origin to call the API from the browser | Ships with FastAPI/Starlette — no install. Required because panel (`:5173`) ≠ API (`:8000`) origin. **Confidence: HIGH** (verified against FastAPI CORS docs Aug 2026) |

**No new `uv add` needed.** The new endpoints reuse `sqlalchemy[asyncio]`, `asyncmy`, `pydantic` v2, and the existing `get_tenant_scope` dependency. The work is: (a) `app/main.py` gains 6 lines for CORS, (b) a new `app/api/staff.py` router + `app/services/staff_service.py` + `app/schemas/mesa.py` (+ `dashboard.py`).

### Frontend — new `panel_admin/` Flutter Web app

| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| **flutter_riverpod** | ^3.4.2 | State + DI | Flutter Favorite. AsyncValue natively models loading/error/data for stats+mesas. Verified pub.dev (published ~16 days ago). **Confidence: HIGH** |
| **riverpod_annotation** + **riverpod_generator** (dev) + **riverpod_lint** (dev) | ^3.x / ^3.x / ^3.x | Code-gen typed providers + lint anti-patterns | `@riverpod` annotation → `boredSuggestionProvider`. riverpod_lint warns on build-time reads. **Confidence: HIGH** |
| **dio** | ^5.11.0 | HTTP client | Interceptors (attach Bearer, refresh-on-401), CancelToken. STACK.md verified. **Confidence: HIGH** |
| **go_router** | ^17.5.0 | Declarative routing + auth redirect + ShellRoute (sidebar) | Official Flutter team, feature-complete (bug-fix only → stable API). Verified pub.dev (published ~3 days ago). **Confidence: HIGH** |
| **flutter_secure_storage** | ^11.0.0 | Persist JWT (access + refresh) | **NOTE: STACK.md says ^9.2.0 — STALE.** Current is **11.0.0** (verified pub.dev, published ~7 days ago). Uniform API across mobile (future cliente app) + Web. **Confidence: HIGH** (version); **MEDIUM** (Web behavior — see Pitfall 3) |
| **freezed_annotation** + **json_annotation** + **freezed** (dev) + **json_serializable** (dev) + **build_runner** (dev) | latest | Immutable DTOs (Mesa, DashboardStats, User) + fromJson/toJson | Standard for typed model layer. **Confidence: HIGH** |
| **flutter_dotenv** | ^5.2.1 | Load `API_BASE_URL` from `.env` | Simpler than raw `--dart-define`. **Confidence: HIGH** |
| **intl** | ^0.19.0 | Number/date formatting (COP currency, today's date for "reservas hoy") | Even Spanish-only needs locale formatting. **Confidence: HIGH** |

**NOT needed this phase (defer to Phase 8):** `qr_flutter` (QR *generation* — Phase 8 MESA-03), `fl_chart` (sales charts — Phase 8 REPO-01), `data_table_2` (CRUD tables — Phase 8). Adding them now is scope creep.

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| **flutter_secure_storage (Web)** | `shared_preferences` / `window.localStorage` | On Web both end up in browser storage; secure_storage adds WebCrypto wrapping + a per-app key. secure_storage wins for API uniformity with the future mobile app. localStorage wins on "no experimental-Web disclaimer". **Default: secure_storage** (document the Web caveat, see Pitfall 3). |
| **flutter_dotenv** | `--dart-define` / `--dart-define-from-file` | dart-define is compile-time (more secure, no asset). dotenv is easier to flip during `flutter run`. **Default: dotenv** for dev; revisit dart-define-from-file in Phase 9 prod. |
| **feature-first structure** | layer-first (`lib/models/`, `lib/services/`, `lib/screens/`) | Feature-first (`lib/features/auth/`, `features/dashboard/`) scales to Phase 8 (6+ features) without a giant flat `screens/` folder; co-locates a feature's widgets+providers+models. ARCHITECTURE.md already prescribes it. **Default: feature-first.** |
| **`/staff` router prefix** | extend existing `/admin` router | `/admin/restaurantes/*` is already a mix of super-admin + staff reads. A dedicated `/staff` router (mesas, stats, future pedidos) cleanly separates "platform ops" from "operational reads" and matches ARCHITECTURE.md's proposed `/staff/*`. **Default: new `/staff` router.** Keep `/admin/restaurantes/{id}` (self-read) where it is. |

**Installation (panel_admin/):**

```bash
# Prerequisite: flutter on PATH (NOT yet installed on this machine — see Prerequisites)
cd C:\Users\valle\Documents\cel
flutter create --org com.gri --project-name gri_panel_admin --platforms=web panel_admin

cd panel_admin
flutter pub add \
  flutter_riverpod:^3.4.2 riverpod_annotation:^3.0.0 \
  dio:^5.11.0 go_router:^17.5.0 \
  flutter_secure_storage:^11.0.0 \
  freezed_annotation json_annotation flutter_dotenv:^5.2.1 intl:^0.19.0

flutter pub add --dev \
  build_runner riverpod_generator:^3.0.0 freezed json_serializable riverpod_lint:^3.0.0 custom_lint

dart run build_runner build --delete-conflicting-outputs
```

**Version verification (already done for you — Aug 2026):**

| Package | Verified | Published |
|---------|----------|-----------|
| flutter_riverpod 3.4.2 | pub.dev | ~Jul 28 2026 |
| go_router 17.5.0 | pub.dev | ~Aug 10 2026 |
| flutter_secure_storage 11.0.0 | pub.dev | ~Aug 6 2026 |
| dio 5.11.0 | STACK.md (verified Aug 2026) | Aug 2026 |

## Architecture Patterns

### Recommended Project Structure (panel_admin/)

Feature-first, mirroring ARCHITECTURE.md `admin_panel/` layout (note: prompt places it at repo root as `panel_admin/`, not `frontend/admin_panel/`):

```
panel_admin/
├── lib/
│   ├── main.dart                    # ProviderScope + MaterialApp.router(goRouter)
│   ├── app.dart                     # Router config (redirect guard + ShellRoute)
│   ├── core/
│   │   ├── api_client.dart          # dio instance + AuthInterceptor + RefreshInterceptor
│   │   ├── auth_storage.dart        # flutter_secure_storage wrapper (read/write/clear tokens)
│   │   ├── token_provider.dart      # auth state (AsyncValue<User?>) + login/logout
│   │   ├── env.dart                 # dotenv loader (API_BASE_URL)
│   │   └── theme.dart               # GRI colors from mockup (see Color System)
│   ├── features/
│   │   ├── auth/
│   │   │   ├── login_screen.dart
│   │   │   └── login_controller.dart
│   │   ├── dashboard/
│   │   │   ├── dashboard_screen.dart   # stat cards + mesa grid (the ShellRoute child)
│   │   │   ├── stats_provider.dart     # GET /staff/stats (polling)
│   │   │   ├── mesas_provider.dart     # GET /staff/mesas (polling)
│   │   │   └── widgets/
│   │   │       ├── stat_card.dart
│   │   │       ├── mesa_tile.dart      # color by estado
│   │   │       └── mesa_legend.dart
│   │   └── shared/
│   │       └── app_shell.dart          # sidebar + topbar (ShellRoute builder)
│   └── models/
│       ├── user.dart                   # freezed: User(id,nombre,email,role,restaurant_id)
│       ├── mesa.dart                   # freezed: Mesa(id,numero,capacidad,codigo_qr,estado)
│       ├── dashboard_stats.dart        # freezed: DashboardStats(...)
│       └── token_pair.dart             # freezed: TokenPair(access,refresh)
├── assets/
│   └── .env                            # API_BASE_URL=http://localhost:8000 (gitignored)
├── test/
│   ├── auth/login_form_test.dart
│   └── dashboard/stats_render_test.dart
└── pubspec.yaml
```

### Pattern 1: Auth state with token persistence + refresh

**What:** A Riverpod provider that owns the auth lifecycle: on app start it reads tokens from `flutter_secure_storage`; if present it calls `GET /auth/me` to validate + load the user; any 401 from the API triggers an automatic `/auth/refresh` (see Pattern 2), and a failed refresh clears storage and redirects to `/login`.

**When to use:** Always — this is the single source of truth for "is the user logged in?" that the go_router redirect reads.

**Example:**

```dart
// core/token_provider.dart — conceptual shape (Riverpod 3 codegen)
// Source: Riverpod 3.x official pub.dev README pattern + flutter_secure_storage 11.0 README
@Riverpod(keepAlive: true)
class AuthState extends _$AuthState {
  @override
  Future<User?> build() async {
    final storage = ref.read(authStorageProvider);
    final access = await storage.readAccessToken();
    final refresh = await storage.readRefreshToken();
    if (access == null || refresh == null) return null;
    // Validate by calling /auth/me. If 401, the RefreshInterceptor retries once.
    try {
      return await ref.read(apiClientProvider).me();
    } catch (_) {
      await storage.clear();
      return null;
    }
  }

  Future<void> login(String email, String password) async { /* POST /auth/login */ }
  Future<void> logout() async { /* clear storage, state = null */ }
}
```

`keepAlive: true` so the auth state survives route changes (it's app-lifetime). All other providers are autoDispose by default in Riverpod 3.

### Pattern 2: dio interceptor — attach Bearer + refresh-on-401

**What:** A `QueuedInterceptor` that (a) injects `Authorization: Bearer <access>` on every request, and (b) on a 401 response, pauses all in-flight requests, calls `/auth/refresh` once, swaps the token, and retries the original request. Concurrent 401s share a single refresh (Completer) to avoid a refresh storm.

**When to use:** Always in this app — it's the canonical dio JWT pattern.

**Example:**

```dart
// core/api_client.dart — interceptor skeleton
// Source: dio 5.x QueuedInterceptor pattern (well-established, stable since dio 4.x)
class AuthInterceptor extends QueuedInterceptor {
  final Dio dio;
  final AuthStorage storage;
  AuthInterceptor(this.dio, this.storage);

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) async {
    final token = await storage.readAccessToken();
    if (token != null) options.headers['Authorization'] = 'Bearer $token';
    handler.next(options);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    if (err.response?.statusCode != 401) return handler.next(err);
    // Refresh once; concurrent errors block on the same Completer.
    final newToken = await _refreshOnce();
    if (newToken == null) return handler.next(err); // -> logout upstream
    final clone = err.requestOptions
      ..headers['Authorization'] = 'Bearer $newToken';
    try {
      final retried = await dio.fetch(clone);
      handler.resolve(retried);
    } catch (e) {
      handler.next(e is DioException ? e : err);
    }
  }

  Future<String?> _refreshOnce() async { /* POST /auth/refresh, persist new pair */ }
}
```

**Critical detail:** `QueuedInterceptor` (not `Interceptor`) serializes, so the refresh is not raced by N parallel failing requests.

### Pattern 3: go_router redirect guard + ShellRoute (sidebar)

**What:** A `GoRouter.redirect` callback reads `ref.read(authStateProvider)` and sends unauthenticated users to `/login` (and bounces logged-in users away from `/login`). A `ShellRoute` wraps the authenticated routes in the sidebar+topbar shell so the menu persists across dashboard/mesas/etc.

**When to use:** Always — this is the official go_router auth pattern (verified in pub.go_router docs, "Redirection" topic).

**Example:**

```dart
// app.dart
// Source: go_router 17.x redirect + ShellRoute (pub.dev/topics Redirection)
final goRouter = GoRouter(
  refreshListenable: /* listenable tied to authState changes */,
  redirect: (context, state) {
    final loggedIn = /* authState has a User */;
    final onLogin = state.matchedLocation == '/login';
    if (!loggedIn && !onLogin) return '/login';
    if (loggedIn && onLogin) return '/';
    return null;
  },
  routes: [
    GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
    ShellRoute(
      builder: (_, __, child) => AppShell(child: child), // sidebar + topbar
      routes: [
        GoRoute(path: '/', builder: (_, __) => const DashboardScreen()),
        // Phase 8 adds /mesas, /pedidos, /reservas, /clientes, /reportes, /configuracion
      ],
    ),
  ],
);
```

**Note (go_router 17 breaking change):** v17 changed some redirect/listenable APIs vs v16 — the plan should follow the `flutter.dev/go/go-router-v17-breaking-changes` guide if any compile error appears. The `ShellRoute` (not `StatefulShellRoute`) is sufficient here since there's only one active branch in Phase 4.

### Pattern 4: Polling via Timer-backed Riverpod provider (Phase 4 debt)

**What:** A provider that fetches stats/mesas, then schedules a `Timer.periodic(Duration(seconds: 10))` to re-fetch, and cancels the timer on dispose. This satisfies ADMN-02's "refleja cambios de la BD al refrescar (polling corto)".

**When to use:** Phase 4 only. Phase 7 replaces the `Timer` with a WebSocket `StreamProvider` (RT-02) — design the provider's *output* (an `AsyncValue<List<Mesa>>`) so only the *input* (timer vs stream) swaps.

**Example:**

```dart
// features/dashboard/mesas_provider.dart
// Source: standard Dart Timer.periodic + Riverpod 3 autoDispose
@riverpod
Stream<List<Mesa>> mesas(Ref ref) async* {
  Future<List<Mesa>> fetch() => ref.read(apiClientProvider).getMesas();
  yield await fetch();
  final controller = StreamController<List<Mesa>>();
  final timer = Timer.periodic(const Duration(seconds: 10), (_) async {
    controller.add(await fetch());
  });
  ref.onDispose(() { timer.cancel(); controller.close(); });
  yield* controller.stream;
}
```

The UI consumes it with the standard `ref.watch(mesasProvider)` + `switch` on `AsyncData`/`AsyncError`/`_` — so the swap to WS in Phase 7 touches only this file.

### Anti-Patterns to Avoid

- **Polling faster than 5s:** hammers the API and MySQL for staff dashboards left open all day. 10s is the sweet spot; Phase 7 removes polling entirely. **Don't** do 1–2s "real-time feel" — that's exactly the Anti-Pattern 3 in ARCHITECTURE.md.
- **Storing JWT in `shared_preferences` on Web without acknowledging it's plaintext:** it's fine if deliberate, but document it. Don't *claim* it's secure.
- **Building the sidebar/topbar inside each screen instead of in the ShellRoute:** rebuilds the chrome on every navigation and loses menu state.
- **Calling the API without the Bearer interceptor (hardcoding tokens in widgets):** leaks tokens into UI code and skips the refresh path. All HTTP goes through the single `apiClientProvider`.
- **Backend: querying `Mesa` / `Pedido` without `scope.restaurant_id` filter:** the Phase 2 hard gate. Every new staff query repeats `stmt.where(Model.restaurant_id == scope.restaurant_id)` (see admin_service precedent). Cross-tenant MUST return 404, never 403 (existence hiding).

## Color System (from `documentos/index.html` — verbatim)

The mockup defines the exact palette. Encode these as Dart `Color` constants in `core/theme.dart` so the panel matches the mockup pixel-for-pixel.

### App chrome
| Token | Hex | Use |
|-------|-----|-----|
| primary | `#ff4c05` | buttons, active menu item, avatar bg, logo icon bg |
| primary-dark | `#d93d00` | button hover |
| background | `#f5f6f8` | page background |
| sidebar | `#1f2329` | sidebar background |
| text | `#252525` | body text |
| gray | `#777777` | secondary text |

### Mesa estado → color (THE core of ADMN-02)
| estado (enum) | dot color | tile bg | tile text | meaning |
|---------------|-----------|---------|-----------|---------|
| `disponible` | `#20b26b` (green) | `#e7f8f0` | `#168a52` | free |
| `ocupada` | `#e74c3c` (red) | `#ffe9e6` | `#c83c2e` | seated/ordering |
| `reservada` | `#f5b82e` (yellow) | `#fff5d8` | `#aa7a00` | booked |
| `limpieza` | `#3478f6` (blue) | `#e9f0ff` | `#3167c9` | post-meal clean |

### Stat card icon backgrounds (tint of the dot color)
| stat | icon bg | icon fg |
|------|---------|---------|
| Mesas disponibles | `#e7f8f0` | green |
| Mesas ocupadas | `#fff0e9` (orange) | primary |
| Reservas hoy | `#fff7df` | yellow |
| Pedidos activos | `#e9f0ff` | blue |

### Layout (from mockup CSS — reproduce in Flutter)
- Sidebar fixed `250px` wide (collapses to icons at <750px). Menu items: Dashboard (active), Mesas, Pedidos, Reservas, Clientes, Reportes, Configuración — **only Dashboard is wired in Phase 4**; others are placeholders (greyed/disabled or simply non-navigating).
- Stats: 4-column grid → 2 cols <1100px → 1 col <750px.
- Mesa grid: 4 columns → 3 cols <1100px → 2 cols <750px. Each tile shows `Mesa {numero}`, estado label, `👥 {capacidad} personas`.
- Topbar: title "Dashboard" + subtitle "Resumen de tu restaurante" + user chip (name + role + avatar initials).

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| JWT attach + refresh on 401 | Manual token threading per request | `dio` `QueuedInterceptor` + `Completer` | Refresh storms, retry ordering, error propagation — all solved by QueuedInterceptor |
| Auth redirect logic | `if (loggedIn) Navigator.push(...)` everywhere | `go_router` `redirect` callback | Single declarative guard; survives deep links & browser refresh (Web!) |
| Loading/error states | `bool _loading` + `try/catch` in widgets | Riverpod `AsyncValue` + `switch` | 3 states (loading/data/error) for free; testable |
| HTTP base URL per env | String concatenation | `flutter_dotenv` (`API_BASE_URL`) | Flip dev/prod without recompile of business logic |
| Secure token persistence | `shared_preferences` + home-grown obfuscation | `flutter_secure_storage` | Platform Keystore/Keychain on mobile; WebCrypto wrap on Web |
| Tenant filter on backend | `if (user.role == ...)` inline per endpoint | existing `get_tenant_scope` dep | Already proven in Phase 2; one missed branch = cross-tenant leak |
| Counting mesas/pedidos | Fetch-all-then-`.length` in Python | `select(func.count()).where(...)` | N rows shipped vs 1 integer; matters when a restaurant has hundreds of historical pedidos |

**Key insight:** Phase 4 introduces *no* novel problems on the backend (it's tenant-scoped COUNT + SELECT, identical shape to Phase 2 reads) and *no* novel problems on the frontend (it's the standard "login → guarded dashboard → polling" Flutter Web app). Resist the urge to invent abstractions.

## Common Pitfalls

### Pitfall 1: CORS — "works in Bruno, blocked in Chrome"
**What goes wrong:** Every API call fails in the browser console with `CORS policy: No 'Access-Control-Allow-Origin' header`, even though Bruno/Postman succeed.
**Why it happens:** Bruno/Postman don't enforce CORS (it's a browser-only mechanism). The panel (`http://localhost:5173`) and API (`http://localhost:8000`) are different origins (different port). `app/main.py` has **no** `CORSMiddleware` today.
**How to avoid:** Add `CORSMiddleware` to `app/main.py` with `allow_origins=["http://localhost:5173"]` (explicit — NOT `["*"]`), `allow_credentials=True`, `allow_methods=["*"]`, `allow_headers=["*"]`. Pin the panel port with `flutter run -d chrome --web-port=5173` so the origin is deterministic.
**Warning signs:** preflight `OPTIONS` 400 in DevTools Network tab.
**Confidence: HIGH** (verified FastAPI CORS docs: `allow_credentials=True` forbids wildcard origins).

### Pitfall 2: flutter not on PATH (environmental blocker)
**What goes wrong:** `flutter create` / `flutter pub get` / `flutter run` fail with "command not found".
**Why it happens:** Verified this session: `Get-Command flutter` → `FLUTTER_NOT_ON_PATH`. The SDK install is "in parallel" per the prompt but not yet complete/registered.
**How to avoid:** Wave 0 task: confirm `flutter --version` works before any Flutter task starts. If still absent, block and surface (the plan cannot proceed). Chrome IS installed (`C:\Program Files\Google\Chrome\Application\chrome.exe` exists) so `flutter run -d chrome` will work once Flutter is present.
**Warning signs:** any "flutter : The term 'flutter' is not recognized" in task output.

### Pitfall 3: flutter_secure_storage on Web is NOT the same as on mobile
**What goes wrong:** Assumption "secure_storage = encrypted on Web too" leads to over-confidence; or it throws because the page is served over plain HTTP from a non-localhost host.
**Why it happens:** flutter_secure_storage 11.0 Web impl uses WebCrypto + **LocalStorage** (per the official README: *"experimental implementation using WebCrypto ... only works on HTTPS or localhost environments"*). The "secure" property is weaker than Keystore/Keychain — the key is browser-generated and same-domain-bound.
**How to avoid:** (1) In dev it's fine — `flutter run -d chrome` serves on `localhost`, which the plugin supports. (2) For Phase 9 production the panel MUST be served over HTTPS (nginx + TLS already planned), or the plugin will throw on Web. (3) Treat the Web JWT as "obfuscated, not encrypted" in the threat model — acceptable for a staff-only panel, would NOT be acceptable for a public kiosk.
**Warning signs:** `UnsupportedError` / `WebCrypto` errors at login on a non-localhost HTTP deploy.
**Confidence: HIGH** (verified flutter_secure_storage 11.0 README, Web section).

### Pitfall 4: super_admin has `restaurant_id=None` — what stats do they see?
**What goes wrong:** `GET /staff/stats` with no restaurant context 500s or returns empty for super_admin, or the panel shows a blank dashboard.
**Why it happens:** `get_tenant_scope` gives super_admin `restaurant_id=None` (sees all), but a dashboard needs *one* restaurant's counts. There's no "current restaurant" concept for super_admin.
**How to avoid:** Resolve in the contract (§Open Q1 / Endpoint Contract): `/staff/stats` and `/staff/mesas` accept `?restaurante_id=` (required for super_admin, ignored-forced-from-scope for staff). The panel: staff → use token's `restaurant_id` directly; super_admin → fetch `GET /admin/restaurantes`, show a picker (or default to the demo restaurant for Phase 4 simplicity).
**Warning signs:** 422/400 on stats for the super-admin login.

### Pitfall 5: Decimal serialization (COP) — only relevant if totals are shown
**What goes wrong:** If the dashboard ever surfaces a pedido total, `Decimal('32000.00')` from asyncmy must serialize cleanly through Pydantic v2 + dio + json_serializable.
**Why it happens:** asyncmy returns `Decimal` (confirmed in 03-02 SUMMARY). Pydantic v2 serializes Decimal → string by default; Dart `double.parse` needs care.
**How to avoid:** Phase 4 stats are *counts* (ints), not money — so this is latent, not active. Flag for Phase 6/8 when pedido totals appear. If a stat card shows revenue, define it as `float` in the Pydantic schema (`Decimal` → `float` via `field_serializer`) or send as string and parse in Dart.

### Pitfall 6: "reservas hoy" timezone (America/Bogota)
**What goes wrong:** `reservas_hoy` counts 0 (or wrong day) because the server date and the business "today" diverge.
**Why it happens:** MySQL `time_zone=-05:00` (America/Bogota, no DST — set in docker-compose). `Reserva.fecha` is a `Date`. `func.now()` on MySQL yields the DB's `NOW()` (Bogota). Python `dt.date.today()` uses the *container* TZ (also America/Bogota via `TZ` env). They agree — but only because compose sets both. If someone runs the API outside Docker without `TZ`, "today" shifts.
**How to avoid:** Compute "today" with `func.curdate()` (DB-side, always Bogota) in the COUNT query, not Python's `date.today()`. This binds "today" to the same TZ as the data.

## Endpoint Contract (new — to implement in Phase 4)

All three reuse `get_tenant_scope` (Phase 2). Put them in a **new `app/api/staff.py`** router (prefix `/staff`, tag `staff`) to separate operational reads from `/admin/*` platform ops (see Alternatives Considered).

### `GET /staff/yo` — resolve "my restaurant" for the topbar
Returns the restaurante the caller operates (for staff) — lets the panel render "Restaurante Demo GRI" in the topbar without a second round trip.

```python
# Response 200 (staff)
{ "id": 1, "nombre": "Restaurante Demo GRI", "tipo_cocina": "Colombiana", ... }  # = RestauranteRead

# super_admin: 409/400 "seleccione un restaurante" OR 200 with a list — see Open Q1
```
**Reuse option:** staff can instead call the *existing* `GET /admin/restaurantes/{restaurant_id}` (from `/auth/me`'s `restaurant_id`). This avoids a new endpoint. **Recommendation: reuse the existing endpoint** for staff; only add `/staff/yo` if the super-admin picker needs it. (Planner decision.)

### `GET /staff/mesas` — tenant-scoped mesa list (ADMN-02)
```python
# Query: ?restaurante_id= (required for super_admin; ignored for staff)
# 200
[
  {"id": 1, "numero": 1, "capacidad": 2, "codigo_qr": "GRI-MESA-001", "estado": "disponible"},
  ...
]
# 404 if restaurante_id unknown/inactive/other-tenant (existence hiding, AUTH-04 style)
# 403 if cliente
# 400 if super_admin and restaurante_id omitted
```

### `GET /staff/stats` — dashboard counts (ADMN-01)
```python
# Query: ?restaurante_id= (same rules as /staff/mesas)
# 200
{
  "mesas_disponibles": 8,
  "mesas_ocupadas": 0,
  "mesas_reservadas": 0,
  "mesas_limpieza": 0,
  "total_mesas": 8,
  "reservas_hoy": 0,          # reservas where fecha = CURDATE() and estado != cancelada
  "pedidos_activos": 0        # pedidos where estado IN (enviado, aceptado, en_preparacion, servido)
}
```

### Pydantic schemas to add (`app/schemas/mesa.py`, `app/schemas/dashboard.py`)
```python
# app/schemas/mesa.py
from app.models.mesa import EstadoMesa
class MesaRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    id: int
    numero: int
    capacidad: int
    codigo_qr: str
    estado: EstadoMesa

# app/schemas/dashboard.py
class DashboardStats(BaseModel):
    mesas_disponibles: int
    mesas_ocupadas: int
    mesas_reservadas: int
    mesas_limpieza: int
    total_mesas: int
    reservas_hoy: int
    pedidos_activos: int
```

### Backend service shape (`app/services/staff_service.py`) — the critical tenant filter
```python
# Source: mirrors admin_service.get_restaurante_for_staff (Phase 2, proven)
from sqlalchemy import select, func
async def list_mesas(session, scope, restaurante_id):
    rid = _resolve_rid(scope, restaurante_id)  # staff: scope.restaurant_id; super_admin: restaurante_id (404 if other tenant)
    stmt = select(Mesa).where(Mesa.restaurant_id == rid).order_by(Mesa.numero)
    return (await session.execute(stmt)).scalars().all()

async def get_stats(session, scope, restaurante_id):
    rid = _resolve_rid(scope, restaurante_id)
    # COUNT by estado — one GROUP BY, or 4 scalar counts; N is tiny so either is fine.
    ...
    # reservas_hoy: Reserva where fecha == func.curdate() and estado != cancelada
    # pedidos_activos: Pedido where estado.in_([enviado, aceptado, en_preparacion, servido])
```
`_resolve_rid` enforces: super_admin without `restaurante_id` → 400; super_admin with a `restaurante_id` that's inactive/absent → 404; staff → always `scope.restaurant_id` (the query param is ignored, never trusted).

### CORS config to add (`app/main.py`)
```python
from fastapi.middleware.cors import CORSMiddleware
app.add_middleware(
    CORSMiddleware,
    allow_origins=["http://localhost:5173"],  # explicit; NOT "*" (allow_credentials forbids wildcard)
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],  # includes Authorization (Bearer)
)
```
Make the origin list env-driven (`CORS_ORIGINS` comma-separated) so Phase 9 prod can set it without code change.

## Code Examples

### Login → token persistence (Flutter)
```dart
// features/auth/login_controller.dart
Future<void> login(String email, String password) async {
  final pair = await ref.read(apiClientProvider).login(email, password);
  await ref.read(authStorageProvider).write(pair.access, pair.refresh);
  ref.read(authStateProvider.notifier).refresh(); // triggers go_router redirect -> dashboard
}
```

### Dashboard screen consuming AsyncValue (Riverpod 3 pattern from pub.dev README)
```dart
class DashboardScreen extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = ref.watch(statsProvider);
    return switch (stats) {
      AsyncData(:final value) => _StatsGrid(stats: value),
      AsyncError(:final error) => Text('Error: $error'),
      _ => const CircularProgressIndicator(),
    };
  }
}
```

### Mesa tile color mapping (ADMN-02 — exact mockup colors)
```dart
Color mesaTileBg(EstadoMesa e) => switch (e) {
  EstadoMesa.disponible => const Color(0xFFe7f8f0),
  EstadoMesa.ocupada   => const Color(0xFFffe9e6),
  EstadoMesa.reservada => const Color(0xFFfff5d8),
  EstadoMesa.limpieza  => const Color(0xFFe9f0ff),
};
Color mesaTileFg(EstadoMesa e) => switch (e) {
  EstadoMesa.disponible => const Color(0xFF168a52),
  EstadoMesa.ocupada   => const Color(0xFFc83c2e),
  EstadoMesa.reservada => const Color(0xFFaa7a00),
  EstadoMesa.limpieza  => const Color(0xFF3167c9),
};
```

### Run the panel in dev (Windows, after Flutter is on PATH)
```bash
cd C:\Users\valle\Documents\cel\panel_admin
flutter pub get
dart run build_runner build --delete-conflicting-outputs   # after model/provider changes
flutter run -d chrome --web-port=5173                        # pinned port for CORS
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Provider (Flutter) | Riverpod 3.x | Provider deprecated by its author (Rousselet) ~2022; Riverpod 3.x is the successor | DO NOT use Provider; the future cliente app uses Riverpod too |
| flutter_secure_storage 9.x | 11.0.0 | Aug 2026 | Android cipher changed (RSA OAEP+AES-GCM), Web impl stable but experimental. STACK.md `^9.2.0` is stale — use `^11.0.0` |
| go_router 16.x | 17.x | 2026 | v17 breaking changes (redirect/listen API) — follow migration guide |
| Polling for "live" | WebSockets (Phase 7) | n/a here | Phase 4 polling is acknowledged debt; design providers so WS swaps in cleanly |
| Manual `allow_origins=["*"]` | Explicit origins w/ credentials | always | Bearer-token apps need explicit origin list; wildcard breaks with `allow_credentials=True` |

**Deprecated/outdated to avoid:**
- `Provider` package (legacy).
- `Navigator.push` for auth gating (use go_router redirect).
- `qr_code_scanner` (deprecated — not used this phase anyway; mobile_scanner is the Phase 6 choice).
- Python `requests` in any async path (use the existing asyncmy/SQLAlchemy + httpx).

## Open Questions

1. **Super-admin dashboard scope**
   - What we know: `get_tenant_scope` gives super_admin `restaurant_id=None`; a dashboard needs one restaurant's counts.
   - What's unclear: should super_admin see (a) a platform dashboard (count of restaurantes/users), (b) auto-default to the demo restaurant, or (c) pick from a list?
   - Recommendation: **(c) picker** is cleanest and reuses `GET /admin/restaurantes`. For Phase 4 minimal effort, default to **(b) the demo restaurant (id=1)** and add the picker only if time allows. The `/staff` endpoints take `?restaurante_id=` for both paths.

2. **`/staff` vs extending `/admin`**
   - What we know: existing `/admin/restaurantes/{id}` already does staff tenant reads (slight ARCHITECTURE.md deviation).
   - Recommendation: introduce `/staff` now (cleaner for Phase 8). Keep `/admin/restaurantes/*` as-is. This is a planner-level convention decision; both work.

3. **Sidebar menu items in Phase 4**
   - What we know: mockup shows 7 menu items; only Dashboard is implemented.
   - Recommendation: render all 7 for visual fidelity but mark non-Dashboard items as disabled/greyed (or tap → "Próximamente" snackbar). Wire them in Phase 8.

4. **Polling interval**
   - Recommendation: 10s. Configurable via `PANEL_POLL_SECONDS` (dotenv) so Phase 7 can drop it to 0 / replace with WS without a rebuild.

## Validation Architecture

*nyquist_validation: true in .planning/config.json → section included.*

### Test Framework

| Property | Value |
|----------|-------|
| Backend framework | pytest 8.x + pytest-asyncio (`asyncio_mode="auto"`) — already configured in `backend/pyproject.toml` |
| Backend config file | `backend/pyproject.toml` `[tool.pytest.ini_options]` (testpaths=["tests"]) |
| Backend quick run | `cd backend && uv run pytest tests/test_staff_read.py -v` |
| Backend full suite | `cd backend && uv run pytest tests/ -v` (existing: 59 tests, <15s) |
| Frontend framework | `flutter test` (built-in, widget tests) — **NOT yet present** (panel_admin/ doesn't exist) |
| Frontend config file | none — `panel_admin/test/` (Wave 0) |
| Frontend quick run | `cd panel_admin && flutter test` |
| Shared backend fixtures | `backend/tests/conftest.py` (`async_client`, `login`, `auth_header`, `super_admin_token`, `db_session`) |

**Backend test precondition:** Docker stack running (`docker compose up -d`) — tests hit `http://localhost:8000` (see `conftest.API_BASE`). This is the established Phase 2–3 convention.

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| PLAT-01 | super_admin login → token pair + `/auth/me` returns role | integration (backend, exists) | `cd backend && uv run pytest tests/test_auth_flow.py -v` | ✅ exists (Phase 2) |
| PLAT-01 | panel login form validates email/password, calls /auth/login | widget (Flutter) | `cd panel_admin && flutter test test/auth/login_form_test.dart` | ❌ Wave 0 |
| ADMN-01 | `GET /staff/stats` staff returns counts of own restaurant | integration (backend) | `cd backend && uv run pytest tests/test_staff_read.py::test_stats_own_tenant -v` | ❌ Wave 0 |
| ADMN-01 | `GET /staff/stats` cross-tenant → 404 | integration (backend) | `cd backend && uv run pytest tests/test_staff_read.py::test_stats_cross_tenant_404 -v` | ❌ Wave 0 |
| ADMN-01 | dashboard renders 4 stat cards from mock stats | widget (Flutter) | `cd panel_admin && flutter test test/dashboard/stats_render_test.dart` | ❌ Wave 0 |
| ADMN-02 | `GET /staff/mesas` staff returns mesas with estado | integration (backend) | `cd backend && uv run pytest tests/test_staff_read.py::test_mesas_own_tenant -v` | ❌ Wave 0 |
| ADMN-02 | `GET /staff/mesas` cross-tenant → 404 (existence hiding) | integration (backend) | `cd backend && uv run pytest tests/test_staff_read.py::test_mesas_cross_tenant_404 -v` | ❌ Wave 0 |
| ADMN-02 | mesa tile color matches estado (verde/rojo/amarillo/azul) | widget (Flutter) | `cd panel_admin && flutter test test/dashboard/mesa_tile_color_test.dart` | ❌ Wave 0 |
| ADMN-02 | manual: change mesa estado in DB → refresh panel → color changes | manual-only (e2e) | n/a — `docker exec` SQL flip + visual check | n/a |
| CORS | preflight OPTIONS from `:5173` returns `Access-Control-Allow-Origin` | integration (backend) | `cd backend && uv run pytest tests/test_cors.py -v` | ❌ Wave 0 |

**Manual-only justification (mesa estado color flip):** Phase 4 is read-only — there's no endpoint to mutate a mesa's estado yet (that's Phase 5/8). The only way to observe a non-disponible color live is to flip it in the DB. Document as a scripted manual check in the plan's verification.

### Sampling Rate
- **Per task commit:** `cd backend && uv run pytest tests/test_staff_read.py -v` (new endpoints) and/or `cd panel_admin && flutter test` (widgets) — whichever the task touched.
- **Per wave merge:** `cd backend && uv run pytest tests/ -v` (full regression — must stay green; baseline 59 from Phase 3).
- **Phase gate:** full backend suite green + `flutter test` green + manual login+dashboard UAT against the demo restaurant (`admin@demo.gri.dev` / `Demo!1234`) + manual mesa-estado color-flip check.

### Wave 0 Gaps
- [ ] **Flutter SDK on PATH** — `flutter --version` must succeed before any frontend task. BLOCKER.
- [ ] `panel_admin/` Flutter project scaffolded (`flutter create --platforms=web`) + `pubspec.yaml` deps installed + `build_runner` codegen run.
- [ ] `backend/app/main.py` — add `CORSMiddleware` (Pitfall 1).
- [ ] `backend/app/api/staff.py` + `backend/app/services/staff_service.py` + `backend/app/schemas/mesa.py` + `backend/app/schemas/dashboard.py` — new files.
- [ ] `backend/app/main.py` — `app.include_router(staff.router)`.
- [ ] `backend/tests/test_staff_read.py` — staff/mesas/stats tenant isolation + counts.
- [ ] `backend/tests/test_cors.py` — preflight from allowed origin (optional but cheap).
- [ ] `panel_admin/test/auth/login_form_test.dart` + `panel_admin/test/dashboard/*_test.dart` — Flutter widget tests + a `mockApiClient` override for Riverpod.

*(Existing test infrastructure (`conftest.py`, `async_client`, `super_admin_token`, `db_session`) covers all backend Phase 4 tests — no new fixtures needed beyond reusing them.)*

## Sources

### Primary (HIGH confidence)
- **pub.dev/packages/flutter_riverpod** — 3.4.2, published ~Jul 28 2026, codegen API (`@riverpod Future<T>(Ref ref)` + `ConsumerWidget` + `switch` on `AsyncData/AsyncError`). ✓
- **pub.dev/packages/go_router** — 17.5.0, published ~Aug 10 2026, official Flutter team, "feature-complete", ShellRoute + redirect confirmed. ✓
- **pub.dev/packages/flutter_secure_storage** — 11.0.0, published ~Aug 6 2026; Web section: "experimental WebCrypto ... only works on HTTPS or localhost"; WebOptions wrapKey. ✓ (resolves STACK.md staleness — STACK said ^9.2.0)
- **pub.dev/packages/dio** — 5.11.0 (via STACK.md, verified Aug 2026). QueuedInterceptor pattern stable since 4.x.
- **fastapi.tiangolo.com/tutorial/cors/** — CORSMiddleware args; `allow_credentials=True` forbids wildcard `allow_origins`/`methods`/`headers`; preflight OPTIONS handling. ✓
- **Existing backend code** (read this session): `app/deps/auth.py` (`get_tenant_scope`, `require_roles`, `CurrentUser`), `app/api/admin.py` (`get_restaurante_for_staff` tenant-filter precedent), `app/core/security.py` (JWT access/refresh, `type` claim guard), `app/services/auth_service.py` (login/refresh/get_user contract), `app/core/config.py` (Settings), `app/models/{mesa,pedido,reserva,restaurante,usuario}.py` (exact fields for stats), `app/core/state_machines.py` (estado enums), `tests/conftest.py` (fixtures), `docker-compose.yml` + `.env` (ports 8000/3306, super-admin creds, DEMO_MODE=true). ✓
- **Phase 3 03-02-SUMMARY.md** — demo content: "Restaurante Demo GRI" id=1, staff `admin@demo.gri.dev`/`mesero@...`/`cocina@...` (pw `Demo!1234`), 8 mesas `GRI-MESA-001..008` all `disponible`, 0 reservas/pedidos seeded, Decimal COP. ✓
- **documentos/index.html** — exact palette (`#ff4c05`, `#1f2329`, `#f5f6f8`, estados `#20b26b`/`#e74c3c`/`#f5b82e`/`#3478f6`), layout (250px sidebar, 4-col stat + mesa grids), menu items. ✓
- **.planning/research/{STACK,ARCHITECTURE}.md** — locked stack decisions, `/staff/*` proposed prefix, feature-first structure, ConnectionManager (Phase 7), anti-patterns. ✓

### Secondary (MEDIUM confidence)
- **dio QueuedInterceptor refresh-on-401 pattern** — well-established community pattern, stable across dio 4.x→5.x; not re-verified against docs this session but low-volatility. Refresh-storm-via-Completer is idiomatic.
- **go_router v17 breaking changes** — `flutter.dev/go/go-router-v17-breaking-changes` referenced; specific API deltas not fetched (likely irrelevant for a greenfield app, relevant only if copy-pasting v15/v16 snippets).

### Tertiary (LOW confidence)
- **flutter_secure_storage production-Web over HTTPS** — README states the requirement; not empirically tested on this stack. Phase 9 (nginx + TLS) is where it bites.

## Metadata

**Confidence breakdown:**
- Backend endpoints + tenant isolation: **HIGH** — exact pattern already proven in Phase 2 (`get_restaurante_for_staff`); models/fields read directly this session.
- Flutter Web stack & versions: **HIGH** — all 4 key pub.dev pages verified Aug 2026.
- CORS: **HIGH** — FastAPI official docs verified.
- flutter_secure_storage Web semantics: **HIGH** (README) on the *fact*, **MEDIUM** on production behavior (untested here).
- dio refresh interceptor specifics: **MEDIUM** — stable pattern, not re-verified against 5.11 changelog.
- Super-admin dashboard UX (picker vs default): **LOW** — a genuine open design choice (Open Q1).

**Research date:** 2026-08-13
**Valid until:** 2026-09-12 (30 days — stable stack; the only fast-moving item is Flutter SDK availability on the host, which is a prerequisite, not a versioning concern)
