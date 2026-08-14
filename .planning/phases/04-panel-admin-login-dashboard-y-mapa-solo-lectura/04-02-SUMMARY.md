---
phase: 04-panel-admin-login-dashboard-y-mapa-solo-lectura
plan: 02
subsystem: panel-admin
tags: [flutter-web, riverpod-3, go-router-17, dio-5, flutter-secure-storage, freezed, dashboard, mesas-map, polling, sidebar]

# Dependency graph
requires:
  - phase: 02-auth-y-multi-tenant
    provides: /auth/login, /auth/refresh, /auth/me, /admin/restaurantes, /admin/restaurantes/{id}, RolUsuario (5 roles)
  - phase: 03-modelo-de-dominio
    provides: Seed demo (admin@demo.gri.dev / Demo!1234 → 8 mesas GRI-MESA-001..008), EstadoMesa enum
  - phase: 04-panel-admin-login-dashboard-y-mapa-solo-lectura
    plan: 01
    provides: GET /staff/mesas + GET /staff/stats tenant-scoped, CORSMiddleware (origen :5173)
provides:
  - "Proyecto Flutter Web panel_admin (package gri_panel_admin) — login + dashboard con polling 10s"
  - "Core reutilizable: theme GriColors (paleta mockup), api_client con QueuedInterceptor (Bearer + refresh-on-401 con Completer), auth_storage flutter_secure_storage"
  - "5 providers Riverpod: authState, loginController, currentRestauranteId, restaurante, restaurantesList, stats, mesas"
  - "feature/dashboard: 4 stat cards + grid de mesas + leyenda; widgets StatCard/MesaTile/MesaLegend"
  - "feature/shared: AppShell sidebar 250px (7 ítems, solo Dashboard activo) + topbar con avatar y nombre restaurante"
affects: [07-tiempo-real-websockets, 08-panel-admin-gestion-completa-y-reportes]

# Tech tracking
tech-stack:
  added:
    - flutter_riverpod 3.4.2 (state + DI)
    - riverpod_annotation 3.0.0 + riverpod_generator 3.0.0 + riverpod_lint 3.0.0 + custom_lint (codegen)
    - go_router 17.5.0 (declarative routing + redirect + ShellRoute)
    - dio 5.11.0 (HTTP + QueuedInterceptor)
    - flutter_secure_storage 11.0.0 (token storage Web = WebCrypto + LocalStorage)
    - freezed + freezed_annotation + json_serializable + json_annotation (modelos inmutables + DTOs)
    - flutter_dotenv 5.2.1 (.env)
    - intl 0.19.0
  patterns:
    - "QueuedInterceptor + Completer<String?> compartido: serializa N 401s concurrentes en UN solo /auth/refresh (T-04-06 anti refresh-storm)"
    - "authStateProvider con @Riverpod(keepAlive: true) + goRouter.refreshListenable vía ValueNotifier que escucha authState (redirect se re-evalúa en cada cambio)"
    - "Stream<DashboardStats> / Stream<List<Mesa>> con yield fetch-inicial + Timer.periodic + ref.onDispose → swap limpio a WS en Phase 7"
    - "currentRestauranteIdProvider como NotifierProvider custom (NO StateProvider — Riverpod 3.x lo deprecó); super_admin defaultea al primer /admin/restaurantes activo"
    - "AsyncValue.when(loading/error/data) idiomático — loading = spinner, error = mensaje + Reintentar, data = grid"
    - "Feature-first layout (lib/features/<domain>/{providers,widgets,screens}); core/ para infra compartida"
    - "TDD: RED-GREEN por task; tests overridean providers con AsyncData(mock) para no tocar red"

key-files:
  created:
    - panel_admin/lib/main.dart
    - panel_admin/lib/app.dart
    - panel_admin/lib/core/env.dart
    - panel_admin/lib/core/theme.dart
    - panel_admin/lib/core/auth_storage.dart
    - panel_admin/lib/core/api_client.dart
    - panel_admin/lib/core/token_provider.dart
    - panel_admin/lib/models/user.dart
    - panel_admin/lib/models/mesa.dart
    - panel_admin/lib/models/restaurante.dart
    - panel_admin/lib/models/dashboard_stats.dart
    - panel_admin/lib/models/token_pair.dart
    - panel_admin/lib/features/auth/login_screen.dart
    - panel_admin/lib/features/auth/login_controller.dart
    - panel_admin/lib/features/shared/app_shell.dart
    - panel_admin/lib/features/dashboard/dashboard_screen.dart
    - panel_admin/lib/features/dashboard/stats_provider.dart
    - panel_admin/lib/features/dashboard/mesas_provider.dart
    - panel_admin/lib/features/dashboard/restaurante_provider.dart
    - panel_admin/lib/features/dashboard/restaurantes_list_provider.dart
    - panel_admin/lib/features/dashboard/widgets/stat_card.dart
    - panel_admin/lib/features/dashboard/widgets/mesa_tile.dart
    - panel_admin/lib/features/dashboard/widgets/mesa_legend.dart
    - panel_admin/test/auth/login_form_test.dart
    - panel_admin/test/dashboard/stats_render_test.dart
    - panel_admin/test/dashboard/mesa_tile_color_test.dart
    - panel_admin/pubspec.yaml
    - panel_admin/analysis_options.yaml
    - panel_admin/assets/.env.example
    - panel_admin/.gitignore
  modified: []

key-decisions:
  - "Riverpod 3.4.2: AsyncValue.value ya es nullable → use .value (NO .valueOrNull, no existe). StateProvider deprecated → usar NotifierProvider custom con clase Notifier<T>."
  - "currentRestauranteIdProvider como NotifierProvider (NO StateProvider): super_admin defaultea al primer restaurante activo de /admin/restaurantes en AppShell.initState post-frame; staff arranca con su restaurantId del /auth/me."
  - "Polling StreamProvider: yield fetch-inicial + StreamController + Timer.periodic + ref.onDispose(timer.cancel + controller.close). Cambio a WS en Phase 7 es solo el INPUT del provider (este archivo no se toca)."
  - "Para staff, statsProvider/mesasProvider mandan restaurante_id=null (backend usa el tenant del token); super_admin manda el rid seleccionado. Defensa T-04-02 en el cliente además del backend."
  - "flutter_secure_storage 11.0.0 (STACK.md decía ^9.2.0 — STALE). En Web = WebCrypto+LocalStorage, NO Keystore/Keychain; aceptable para panel staff-only sobre HTTPS (T-04-05)."
  - "theme.dart usa alpha opaco 0xFF… (no 0xff… del plan que es transparente). Desviación Rule 1 documentada abajo."
  - "GoRouter redirect: solo AsyncData con User no-null = 'logueado'. isLoading y AsyncError → /login (T-04-08)."

patterns-established:
  - "feature-first layout (lib/features/<domain>/{providers,widgets,screens}) — Phase 8 lo replica para /mesas, /pedidos, /reservas, /clientes, /reportes, /configuracion"
  - "ProviderScope override en tests con AsyncData(mock) — sin tocar red ni fake ApiClient cuando solo se testea UI"
  - "Dashboard polling vía StreamProvider con Timer.periodic cancelable — patrón reutilizable para cualquier vista 'live' pre-WS"

requirements-completed: [PLAT-01, ADMN-01, ADMN-02]

# Metrics
duration: 25min
completed: 2026-08-14
---

# Phase 4 Plan 02: Panel Admin Flutter Web Summary

**Primer frontend del proyecto: login staff + dashboard con 4 stat cards + mapa de mesas coloreado por estado + sidebar — replica pixel-for-pixel la paleta del mockup, consume /staff/* del Plan 04-01 con polling 10s (deuda Phase 7: WS), persiste sesión en flutter_secure_storage. 11/11 widget tests verdes.**

## Goal

Construir `panel_admin/` (Flutter Web, package `gri_panel_admin`) — el frontend admin que cierra Phase 4 (PLAT-01, ADMN-01, ADMN-02). El staff abre http://localhost:5173, ingresa credenciales, aterriza en un dashboard con stats reales y mapa de mesas. Replica la identidad visual del mockup `documentos/index.html`.

## Instructions / Constraints respetadas

- **Stack versions locked del research:** flutter_riverpod 3.4.2, go_router 17.5.0, dio 5.11.0, flutter_secure_storage 11.0.0, freezed/json_serializable latest. Cero desviaciones.
- **Flutter SDK en `C:\src\flutter\bin`** (NO en PATH): cada comando `flutter`/`dart` requirió `$env:Path += ";C:\src\flutter\bin"` (PowerShell 5.1).
- **Puerto fijado :5173** (origen determinista para CORS del Plan 04-01 que permite exactamente http://localhost:5173).
- **NO tocar backend** (70/70 tests de Phase 4 ya verdes por Plan 01).
- **Paleta EXACTA** del mockup (16+ constantes en `GriColors`, función helper `mesaTileBg/FG/Dot(EstadoMesa)` con switch exhaustivo).
- **Polling 10s** configurable vía `PANEL_POLL_SECONDS` en `assets/.env` — Stream<List<Mesa>> / Stream<DashboardStats> para swap limpio a WS en Phase 7.

## Discoveries

- **Riverpod 3.4.2 API breakers vs el plan:**
  - `AsyncValue.valueOrNull` NO existe → `AsyncValue.value` ya es nullable directamente (T → T?).
  - `StateProvider` está deprecado en 3.x → se reemplaza con `NotifierProvider<MyNotifier, T>` + clase `Notifier<T>` custom. `currentRestauranteIdProvider` se implementó así.
  - `(_, __)` en callbacks → `(_, _)` (Dart 3.7+ wildcard, lint `unnecessary_underscores`).
  - Codegen: `dart run build_runner build` SIN `--delete-conflicting-outputs` (esa flag se removió del runner nuevo; el propio runner maneja conflictos).
- **flutter_secure_storage 11.0.0 en Web:** usa WebCrypto + LocalStorage (NO Keystore/Keychain como en móvil). La clave la genera el browser, queda atada al dominio. "Obfuscado, no cifrado" — aceptable para panel staff-only sobre HTTPS (T-04-05). Documentado inline en `auth_storage.dart`.
- **Dio QueuedInterceptor + Completer para refresh:** el primer 401 crea un `Completer<String?>`; los N-1 401s concurrentes esperan su future y reciben el mismo token nuevo. Si refresh falla → clear storage + `onSessionExpired?.call()` (cableado desde `AuthState.build`) → redirect a /login. T-04-06 mitigado.
- **`cupertino_icons` warning en `flutter build web`:** no afecta producción (es un warning de tree-shaking del icon font del SDK, no de nuestro código). No se resuelve en este plan.
- **GoRouter 17 redirect idiom:** `refreshListenable: ValueNotifier<int>` que se incrementa en cada cambio del authState vía `ref.listen(authStateProvider, ...)`. El redirect lee `ref.read(authStateProvider).value` (solo AsyncData con User no-null = "logueado", T-04-08).

## Accomplished

- ✅ **T1 Scaffold + core** (commit `5577727`): `panel_admin/` Flutter Web con `pubspec.yaml` (deps locked), `analysis_options.yaml` (custom_lint + riverpod_lint), `assets/.env` (con .env.example commiteado, .env real en .gitignore), `main.dart` (ProviderScope + dotenv.load), `theme.dart` (GriColors con 16+ constantes exactas del mockup + helpers mesaTileBg/FG/Dot), `env.dart`, `auth_storage.dart`, `api_client.dart` (Dio + AuthInterceptor QueuedInterceptor + Completer-guarded refresh), 5 modelos freezed (User, Mesa con EstadoMesa enum, DashboardStats, TokenPair, Restaurante). `flutter analyze` limpio + codegen OK.
- ✅ **T2 Auth feature + go_router** (commits `e718ac7`, `9514caf`): `token_provider.dart` (AuthState keepAlive FutureProvider, lee storage → si tokens → me() → User|null), `login_controller.dart` (valida email RegExp + password ≥8 antes de red; escribe storage, invalida authState), `login_screen.dart` (card centrada + logo GRI + form con validators), `app.dart` (GoRouter con redirect guard T-04-08 + ShellRoute), `app_shell.dart` placeholder (sustituido en T3). 4/4 widget tests verdes (login_form_test).
- ✅ **T3 Dashboard + sidebar completo** (commits `9aa2aff`, `402f26a`):
  - **Providers:** `statsProvider` (Stream<DashboardStats> polling), `mesasProvider` (Stream<List<Mesa>> polling), `restauranteProvider` (Future<Restaurante> para topbar), `restaurantesListProvider` (Future<List<Restaurante>> para dropdown super_admin), `currentRestauranteIdProvider` (NotifierProvider<int?> — staff defaultea a su restaurantId, super_admin defaultea al primero activo vía AppShell post-frame callback).
  - **Widgets:** `StatCard` (card blanca radius 15 con emoji en círculo coloreado), `MesaTile` (tile color-coded por EstadoMesa con los 4 colores exactos), `MesaLegend` (fila wrap con 4 dots + labels).
  - **Screens:** `dashboard_screen.dart` (LayoutBuilder responsive + AsyncValue.when para stats y mesas, 4 stat cards + grid mesas + leyenda + botón "+ Nueva mesa" placeholder disabled), `app_shell.dart` completo (sidebar 250px fijo / 70px colapsado <750px, 7 ítems solo Dashboard activo, topbar con avatar iniciales + nombre restaurante + dropdown super_admin).
  - 7/7 widget tests verdes (4 mesa_tile_color + 3 stats_render).
- ✅ **Build web:** `flutter build web --release` compila OK (36.8s). Solo warning menor de `cupertino_icons` (no nuestro).
- ✅ **Suite completa:** `flutter test` → **11/11 verdes** (4 login form + 4 mesa tile color + 3 stats render). `flutter analyze` → 0 issues.

## Task Commits

1. **T1 scaffold + core** — `5577727` (feat)
2. **T2 RED failing login tests** — `e718ac7` (test, TDD)
3. **T2 GREEN auth + go_router** — `9514caf` (feat)
4. **T3 RED failing dashboard tests** — `9aa2aff` (test, TDD)
5. **T3 GREEN dashboard + sidebar + polling** — `402f26a` (feat)

## Providers Riverpod creados

| Provider | Tipo | Propósito |
|----------|------|-----------|
| `authStateProvider` | `FutureProvider<User?>` (keepAlive) | Sesión persistida; lee storage al startup; logout clears storage + state=null |
| `loginControllerProvider` | `AsyncNotifier<void>` | Validación pre-red + login API + write storage + invalidate authState |
| `apiClientProvider` | `Provider<ApiClient>` | Dio singleton con AuthInterceptor (Bearer + refresh-on-401 Completer-guarded) |
| `authStorageProvider` | `Provider<AuthStorage>` | Wrapper sobre FlutterSecureStorage (keys gri_access, gri_refresh) |
| `goRouterProvider` | `Provider<GoRouter>` | Router con redirect guard + ShellRoute + refreshListenable |
| `currentRestauranteIdProvider` | `NotifierProvider<Notifier<int?>, int?>` | Restaurante activo: staff=propio tenant, super_admin=default primero activo |
| `restauranteProvider` | `FutureProvider<Restaurante>` | Restaurante a mostrar en topbar (GET /admin/restaurantes/{id}) |
| `restaurantesListProvider` | `FutureProvider<List<Restaurante>>` | Lista para dropdown super_admin (GET /admin/restaurantes) |
| `statsProvider` | `StreamProvider<DashboardStats>` | Polling 10s de /staff/stats |
| `mesasProvider` | `StreamProvider<List<Mesa>>` | Polling 10s de /staff/mesas |

## Paleta Dart (referencia para Phase 8 — no redescubrir)

```dart
// App chrome
GriColors.primary       = Color(0xFFFF4C05);  // #ff4c05 — botones, active menu, avatar bg, logo icon
GriColors.primaryDark   = Color(0xFFD93D00);  // #d93d00 — hover
GriColors.background    = Color(0xFFF5F6F8);  // #f5f6f8 — fondo página
GriColors.sidebar       = Color(0xFF1F2329);  // #1f2329 — barra lateral
GriColors.text          = Color(0xFF252525);  // #252525 — texto principal
GriColors.gray          = Color(0xFF777777);  // #777777 — texto secundario

// Mesa estados (4 colores del ADMN-02) — bg/fg/dot por estado
GriColors.mesaDisponibleBg = Color(0xFFE7F8F0);  GriColors.mesaDisponibleFg = Color(0xFF168A52);  GriColors.mesaDisponibleDot = Color(0xFF20B26B);
GriColors.mesaOcupadaBg    = Color(0xFFFFE9E6);  GriColors.mesaOcupadaFg    = Color(0xFFC83C2E);  GriColors.mesaOcupadaDot    = Color(0xFFE74C3C);
GriColors.mesaReservadaBg  = Color(0xFFFFF5D8);  GriColors.mesaReservadaFg  = Color(0xFFAA7A00);  GriColors.mesaReservadaDot  = Color(0xFFF5B82E);
GriColors.mesaLimpiezaBg   = Color(0xFFE9F0FF);  GriColors.mesaLimpiezaFg   = Color(0xFF3167C9);  GriColors.mesaLimpiezaDot   = Color(0xFF3478F6);

// Stat card icon backgrounds (tint del dot)
GriColors.statIconDisponibleBg = Color(0xFFE7F8F0);  // mesas disponibles (verde tint)
GriColors.statIconOcupadaBg    = Color(0xFFFFF0E9);  // mesas ocupadas (naranja tint)
GriColors.statIconReservasBg   = Color(0xFFFFF7DF);  // reservas hoy (amarillo tint)
GriColors.statIconPedidosBg    = Color(0xFFE9F0FF);  // pedidos activos (azul tint)
```

Helpers: `mesaTileBg(EstadoMesa)`, `mesaTileFg(EstadoMesa)`, `mesaDot(EstadoMesa)` — switch exhaustivo sobre los 4 estados (defensa pixel-perfect ADMN-02).

## Cómo correr el panel

```powershell
# 1. Backend corriendo (Plan 04-01 deployado)
docker compose up -d

# 2. Desde el directorio raíz del proyecto:
cd panel_admin
$env:Path += ";C:\src\flutter\bin"   # SDK no está en PATH global
flutter run -d chrome --web-port=5173

# 3. Browser abre http://localhost:5173 → redirige a /login
#    Login: admin@demo.gri.dev / Demo!1234 → redirige a / (dashboard)
#    F5 → sigue logueado (sesión persistida en flutter_secure_storage)
```

Credenciales demo (seed Phase 3): `admin@demo.gri.dev` / `Demo!1234` (rol `admin_restaurante`, `restaurant_id=1`). El super-admin se crea vía `.env` (SUPER_ADMIN_EMAIL/SUPER_ADMIN_PASSWORD); sus credenciales las ingresa el usuario (el panel NO las hardcodea).

## Verification

- ✅ `flutter analyze` → **No issues found** (0 errores, 0 warnings, 0 hints).
- ✅ `dart run build_runner build` → 8 outputs generados sin conflictos (*.freezed.dart + *.g.dart).
- ✅ `flutter test` → **11/11 passed** (4 login form + 4 mesa_tile_color + 3 stats_render) en ~2s.
- ✅ `flutter build web --release` → Built build\web (36.8s, compila sin errores).

### UAT manual (NO bloqueante, documentado para `/gsd-verify-work`)

Pasos para reproducir el flujo completo en browser:
1. `docker compose up -d` (backend 70/70 tests verdes).
2. `cd panel_admin && $env:Path += ";C:\src\flutter\bin" && flutter run -d chrome --web-port=5173`
3. Browser abre en http://localhost:5173 → redirect automático a /login (no autenticado).
4. Ingresar `admin@demo.gri.dev` / `Demo!1234` → redirige a / (Dashboard).
5. Dashboard muestra (seed limpio): **8 mesas disponibles, 0 ocupadas, 0 reservas, 0 pedidos**. 8 tiles verdes en el mapa.
6. Sidebar muestra los 7 ítems (Dashboard activo naranja, otros 6 grises). Click en cualquier ítem no-Dashboard → SnackBar "Próximamente".
7. Topbar muestra "Administrador" + "Restaurante Demo GRI" (vía GET /admin/restaurantes/1) + avatar "AD".
8. **F5** → sigue logueado, sigue en dashboard (sesión persistida).
9. Cambio manual en BD para verificar polling:
   ```bash
   docker compose exec mysql mysql -u root -p$MYSQL_ROOT_PASSWORD gri -e "UPDATE mesa SET estado='ocupada' WHERE numero=2"
   ```
10. Esperar ≤10s → Mesa 2 tile cambia a rojo (polling). Stat "Mesas disponibles" baja a 7, "Mesas ocupadas" sube a 1.
11. Login con super-admin (creds del .env) → topbar muestra DropdownButton con restaurantes; al cambiar selección, stats y mapa se rebuild (restauranteProvider + statsProvider + mesasProvider reaccionan a currentRestauranteIdProvider).

## Files Created/Modified

```
panel_admin/
├── pubspec.yaml                          # deps locked (riverpod 3.4.2, go_router 17.5.0, dio 5.11.0, secure_storage 11.0.0)
├── analysis_options.yaml                 # custom_lint + riverpod_lint
├── .gitignore                            # assets/.env ignorado
├── assets/
│   ├── .env                              # API_BASE_URL + PANEL_POLL_SECONDS (gitignored)
│   └── .env.example                      # placeholder commiteado
├── lib/
│   ├── main.dart                         # ProviderScope + dotenv.load + GriApp
│   ├── app.dart                          # GoRouter (redirect + ShellRoute) + GriApp
│   ├── core/
│   │   ├── env.dart                      # API_BASE_URL + PANEL_POLL_SECONDS con defaults
│   │   ├── theme.dart                    # GriColors (16+ constantes) + mesaTileBg/FG/Dot + griTheme
│   │   ├── auth_storage.dart             # FlutterSecureStorage wrapper (T-04-05)
│   │   ├── api_client.dart               # Dio + AuthInterceptor (Queued + Completer refresh)
│   │   └── token_provider.dart           # AuthState @Riverpod(keepAlive: true) Future<User?>
│   ├── models/
│   │   ├── user.dart                     # User freezed (isSuperAdmin getter)
│   │   ├── mesa.dart                     # Mesa + EstadoMesa enum + estadoMesaFromJson
│   │   ├── restaurante.dart              # Restaurante freezed
│   │   ├── dashboard_stats.dart          # 7 counts int
│   │   └── token_pair.dart               # access + refresh
│   └── features/
│       ├── auth/
│       │   ├── login_screen.dart         # ConsumerStatefulWidget con form validators
│       │   └── login_controller.dart     # AsyncNotifier — validación + API + storage + invalidate
│       ├── shared/
│       │   └── app_shell.dart            # Sidebar 250px (7 items) + topbar + dropdown super_admin
│       └── dashboard/
│           ├── dashboard_screen.dart     # 4 StatCards + grid mesas + leyenda + AsyncValue.when
│           ├── stats_provider.dart       # Stream<DashboardStats> polling 10s
│           ├── mesas_provider.dart       # Stream<List<Mesa>> polling 10s
│           ├── restaurante_provider.dart # currentRestauranteIdProvider (Notifier) + restauranteProvider
│           ├── restaurantes_list_provider.dart  # para dropdown super_admin
│           └── widgets/
│               ├── stat_card.dart        # card blanca radius 15 con emoji coloreado
│               ├── mesa_tile.dart        # tile color-coded por EstadoMesa
│               └── mesa_legend.dart      # fila wrap 4 dots
└── test/
    ├── auth/login_form_test.dart         # 4 tests (validación + SnackBar)
    └── dashboard/
        ├── stats_render_test.dart        # 3 tests (render 4 cards + loading + error)
        └── mesa_tile_color_test.dart     # 4 tests (un test por estado, assert bg+fg exactos)
```

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] theme.dart: `0xff…` del plan es transparente en Dart**
- **Found during:** Task 1 (escritura de theme.dart).
- **Issue:** El plan especificaba los hex como `Color(0xff4c05)` (6 dígitos después de `0x`). En Dart, los colores ARGB requieren 8 dígitos: `0xff4c05` se interpreta como alpha=0x00 (completamente transparente) + RGB=0xff4c05. Toda la UI habría sido invisible.
- **Fix:** Todas las constantes se escribieron con alpha opaco `0xFF…` (mayúscula por convención): `Color(0xFFFF4C05)`, etc. Los 16+ colores del mockup quedaron correctos.
- **Files modified:** `panel_admin/lib/core/theme.dart` (única fuente de verdad visual).
- **Verification:** `mesa_tile_color_test.dart` asserts `Color(0xFFE7F8F0)` y pasan; visually OK en build web.
- **Committed in:** `5577727` (T1).

**2. [Rule 3 - Blocking] Riverpod 3.4.2 cambió la API vs el plan (escrito para 2.x)**
- **Found during:** Task 3 (primer `flutter analyze` post-impl).
- **Issue:** El plan usaba tres APIs que no existen o están deprecadas en Riverpod 3.4.2:
  - `AsyncValue.valueOrNull` → ahora es `.value` (nullable directo en v3).
  - `StateProvider<T>` → deprecado en 3.x (a favor de `NotifierProvider`).
  - `(_, __)` en callbacks → Dart 3.7 trata `_` como wildcard, lint `unnecessary_underscores` falla.
- **Fix:** Reemplazos puntuales: `.valueOrNull` → `.value` en 5 archivos; `StateProvider<int?>` → `NotifierProvider<CurrentRestauranteId, int?>` con clase custom; `(_, __)` → `(_, _)` en callbacks de `.when(error: ...)`. Cero cambios de comportamiento.
- **Files modified:** `restaurante_provider.dart`, `stats_provider.dart`, `mesas_provider.dart`, `restaurantes_list_provider.dart`, `app_shell.dart`.
- **Verification:** `flutter analyze` limpio (0 issues); `flutter test` 11/11.
- **Committed in:** `402f26a` (T3).

**3. [Rule 3 - Blocking] `--delete-conflicting-outputs` removido del build_runner nuevo**
- **Found during:** Task 1 (primera corrida de codegen).
- **Issue:** El plan pedía `dart run build_runner build --delete-conflicting-outputs`. La versión actual de build_runner emite warning "These options have been removed and were ignored: --delete-conflicting-outputs" y maneja conflictos automáticamente.
- **Fix:** Quitar la flag. El runner nuevo detecta y maneja conflictos sin necesidad.
- **Files modified:** Ninguno (solo el comando de invocación).
- **Committed in:** N/A (cambio de comando, no de código).

---

**Total deviations:** 3 auto-fixed (1 bug de color transparente, 2 blocking por API changes de Riverpod 3 / build_runner).
**Impact on plan:** Cero scope creep. Todas las desviaciones son correcciones puntuales para que el código compile y se comporte como el plan especificaba en intent. Cero impacto en la arquitectura o en los AC del plan.

## Issues Encountered

- **`cupertino_icons` warning en `flutter build web`:** "Expected to find fonts for (MaterialIcons, packages/cupertino_icons/CupertinoIcons), but found (MaterialIcons)". Es un warning del SDK sobre tree-shaking de icon fonts — no afecta producción (el build termina OK). No se resuelve en este plan; si aparece en Phase 8 se puede añadir `cupertino_icons: ^1.0.6` a pubspec o desactivar con `--no-tree-shake-icons`.
- **`flutter analyze` en PowerShell con `2>&1 | Select-Object`:** lanza `NativeCommandError` porque el stderr de Dart lo interpreta como error del comando (aunque la salida sea exitosa). Cosmético — el análisis corre bien.
- **Working tree actual:** `documentos/` está sin commitear (carpeta con mockups y assets). No se commitea porque es referencia visual del proyecto, no código del milestone.

## User Setup Required

None — el panel corre contra el backend ya deployado del Plan 04-01. `assets/.env` commiteado como `.env.example` con los defaults (`API_BASE_URL=http://localhost:8000`, `PANEL_POLL_SECONDS=10`). Si el usuario quiere correr en otro host/puerto, copia `.env.example` → `.env` y edita (sin tocar código).

## Deudas explícitas para próximas fases

- **Phase 7 (WS):** `statsProvider` y `mesasProvider` se reescriben — el INPUT cambia de `Timer.periodic + StreamController` a un Stream alimentado por WebSocket. El body de `dashboard_screen.dart` (este archivo) NO se toca — solo los providers. Patrón diseñado para esto desde el día 1.
- **Phase 8 (Panel gestión completa):**
  - Sidebar ítems "Mesas / Pedidos / Reservas / Clientes / Reportes / Configuración": actualmente muestran SnackBar "Próximamente". Cada uno necesita su route + screen + providers.
  - Botón "+ Nueva mesa" en dashboard_screen: actualmente `ElevatedButton.icon(onPressed: null)` (disabled). Necesita el modal de creación + endpoint `POST /staff/mesas` (fase 8 lo añade).
  - `MesaTile` onTap: actualmente no-op (MouseRegion cursor click para affordance visual). En Phase 8 abre el detalle/mutation de mesa.
  - Mutación de estado de mesa (ADMN-04): no hay endpoint hasta Phase 5/8.
- **Phase 9 (deploy):** panel SIEMPRE sobre HTTPS (nginx + TLS). flutter_secure_storage en Web es "obfuscado, no cifrado" (T-04-05) — aceptable solo sobre HTTPS en prod.

## Next Phase Readiness

- **Phase 5 (App Cliente Descubrimiento):** Puede arrancar en paralelo. No comparte código con `panel_admin/` (es otra app Flutter — móvil, no web). Decisiones de arquitectura del panel (riverpod 3.4.2, dio 5.11.0, freezed) son referencia pero no bloqueante.
- **Phase 6 (Pedido por QR REST):** Idem Phase 5.
- **Phase 7 (WS):** `statsProvider` y `mesasProvider` son los puntos de swap. Patrón StreamProvider + ref.onDispose documentado arriba.
- **Phase 8 (Panel gestión):** Continúa sobre `panel_admin/`. La feature-first layout (lib/features/<domain>/...) está lista para replicarse en mesas/pedidos/reservas/clientes/reportes/configuracion. La paleta GriColors está centralizada.

**Sin blockers.** Fase 4 cierra con los 3 requisitos completos (PLAT-01, ADMN-01, ADMN-02).

## Widget tests count + gotchas Riverpod 3 / go_router 17

- **Tests:** 11/11 (4 login form + 4 mesa tile color + 3 stats render). Run completo en ~2s.
- **Gotcha Riverpod 3 (mayor):** `StateProvider` deprecado → `NotifierProvider`. Cualquier `.notifier).state = x` se vuelve `.notifier).someMethod(x)` con clase Notifier custom.
- **Gotcha Riverpod 3 (menor):** `AsyncValue.valueOrNull` removido → `.value` nullable directo.
- **Gotcha go_router 17:** `GoRoute.builder` signature ahora `(_, _)` en vez de `(context, state)` — Dart 3.7 wildcards. No usa `ShellRouteBuilder` (v17 unificó a `(context, state, child)` → `(_, _, child)`).
- **Gotcha testing:** Para testear widgets que consumen providers sin tocar red, hacer `ProviderScope(overrides: [statsProvider.overrideWithValue(AsyncData(mock))]` — el Stream nunca se construye, no hay Timer.periodic, no hay Dio. Limpio.

---
*Phase: 04-panel-admin-login-dashboard-y-mapa-solo-lectura*
*Plan: 02*
*Completed: 2026-08-14*

## Self-Check: PASSED

- 9 archivos must_haves creados: FOUND (main.dart, app.dart, api_client.dart, auth_storage.dart, token_provider.dart, theme.dart, login_screen.dart, dashboard_screen.dart, mesa_tile.dart)
- 11 patrones must_haves (ProviderScope, ShellRoute, QueuedInterceptor, FlutterSecureStorage, @Riverpod(keepAlive), 0xff4c05 → 0xFF4C05 corregido, LoginScreen, statsProvider, mesaTileBg con Color exacto, login_form_test, stats_render_test, mesa_tile_color_test): FOUND
- Commits 5577727, e718ac7, 9514caf, 9aa2aff, 402f26a: FOUND en git log
- `flutter test` 11/11 verde: VERIFICADO
- `flutter analyze` 0 issues: VERIFICADO
- `flutter build web --release` exitoso: VERIFICADO
