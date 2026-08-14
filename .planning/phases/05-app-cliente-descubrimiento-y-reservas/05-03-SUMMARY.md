---
phase: 05-app-cliente-descubrimiento-y-reservas
plan: 03
subsystem: app-cliente-flutter
tags: [flutter, riverpod-3, go-router-17, dio-5, statefulshellroute, wizard, reservas, freezed, web-first]
requires:
  - "phase: 05 plan 01 — GET /public/restaurantes{,/{id}}, /cliente/reservas (POST/GET/cancelar), /cliente/perfil, CORS :5174"
  - "phase: 04 plan 02 — lib/core de panel_admin (api_client QueuedInterceptor, auth_storage, token_provider, lecciones Riverpod 3)"
provides:
  - "Proyecto Flutter app_cliente (package gri_cliente, web-first Chrome :5174) — journey completo: registro/login → descubrir → menú → reservar (wizard) → mis reservas → perfil"
  - "GoRouter con redirect guard + StatefulShellRoute.indexedStack (4 tabs con estado preservado) + marco móvil 480px en web"
  - "core reutilizable adaptado: theme cliente (#f7f7f7), env sin polling, formatCOP"
  - "Wizard de reserva Stepper (fecha/hora :00 12-21/personas 1-20/confirmar) con manejo 409 user-friendly"
affects:
  - "06-pedido-por-qr (QR placeholder del header/home se vuelve scanner real)"
  - "07-tiempo-real (reservasProvider/restaurantesListProvider pasan de invalidate a WS)"
  - "09-calificaciones (calificacion '—' se llena con agregado)"
tech-stack:
  added:
    - flutter_riverpod 3.4.2 + riverpod_annotation 4.0.3 + riverpod_generator 4.0.4
    - go_router 17.5.0 (StatefulShellRoute.indexedStack)
    - dio 5.11.0 / flutter_secure_storage 11.0.0 / flutter_dotenv 5.2.1 / intl 0.19.0
    - freezed 4.0.0-dev.3 + freezed_annotation 3.1.0 + json_serializable 6.14.1
  patterns:
    - "StatefulShellRoute.indexedStack 4 branches + navigationShell.goBranch — cada tab preserva scroll/datos (vs ShellRoute del panel)"
    - "reservasProvider sin polling: invalidate tras cada mutación (swap a WS en Phase 7 sin tocar screens)"
    - "Wizard slots :00: dropdown desde lista estática (ReservaWizardScreen.horasSlot) — nunca TimeOfDay libre (coincide con validación server)"
    - "Split próximas/pasadas client-side: comparación lexicográfica de fechas ISO (Reserva.esProxima)"
    - "Class-based providers en tests: overrideWith(Fake.new); functional: overrideWithValue(AsyncData(...))"
key-files:
  created:
    - app_cliente/lib/app.dart
    - app_cliente/lib/main.dart
    - app_cliente/lib/core/{api_client,auth_storage,token_provider,env,theme,format}.dart
    - app_cliente/lib/models/{user,token_pair,restaurante,producto,categoria,restaurante_detalle,reserva,reserva_create}.dart
    - app_cliente/lib/features/auth/{login_screen,register_screen,auth_controller}.dart
    - app_cliente/lib/features/restaurantes/{home_screen,restaurantes_list_screen,restaurante_detalle_screen,restaurantes_provider}.dart
    - app_cliente/lib/features/reservas/{reserva_wizard_screen,mis_reservas_screen,reservas_provider,reserva_controller}.dart
    - app_cliente/lib/features/perfil/{perfil_screen,perfil_controller}.dart
    - app_cliente/lib/features/shared/app_shell.dart
    - app_cliente/test/{auth/login_register_test,restaurantes/list_test,reservas/wizard_form_test,reservas/mis_reservas_render_test,perfil/perfil_edit_test}.dart
  modified: []
decisions:
  - "freezed 4.0.0-dev.3: el prerelease 3.2.6-dev.1 (que pub resuelve por el grafo json_serializable 6.14.1/analyzer>=10) genera 'required final List<T>' inválido en modelos con List — 4.0.0-dev.3 lo corrige; el panel nunca lo detectó porque no tenía campos List"
  - "Stepper controlsBuilder solo renderiza controles del step activo (el Stepper llama controlsBuilder por TODOS los steps)"
  - "Perfil: controllers sincronizados una vez (_synced flag) en vez de initState — authState puede resolver async en tests"
  - "Wizard sin preselect (FAB +): step 0 'Restaurante' extra con dropdown de /public/restaurantes"
  - "Logout en Perfil (Rule 2): sin él no había forma de cerrar sesión en la app"
metrics:
  duration: "~23 min"
  tasks: 3
  tests-new: 19 (5 auth + 3 restaurantes + 5 wizard + 3 mis_reservas + 3 perfil)
  completed: 2026-08-14
---

# Phase 5 Plan 03: App Cliente (Descubrimiento + Reservas) Summary

**App cliente Flutter web-first (Chrome :5174) que cierra el journey móvil de la Fase 5: registro/login → descubrir restaurantes → menú con precios COP → wizard de reserva (slots :00) → mis reservas (split próximas/pasadas + cancelar) → perfil. Clona el stack de auth probado del panel_admin, añade navegación inferior de 4 tabs con StatefulShellRoute.indexedStack y 19/19 widget tests verdes + analyze 0 + build web release exitoso.**

## Goal

Construir `app_cliente/` (package `gri_cliente`) — la UI de AUTH-05, REST-01/02, RESV-01/03 sobre los endpoints /public + /cliente del Plan 05-01 (95/95 backend tests), replicando el mockup `documentos/indexcliente.html`.

## Accomplished

- ✅ **T1 Scaffold + core** (`eb3522e`): flutter create (android+web — NO ios, dev web-first), lib/core copiado de panel_admin (api_client con QueuedInterceptor+Completer idéntico, auth_storage keys gri_access/gri_refresh, token_provider AuthState keepAlive), theme adaptado a paleta cliente (`background #f7f7f7`, chips estado mockup), env sin polling, `formatCOP` (intl es_CO), 8 modelos freezed, GoRouter con redirect guard + `StatefulShellRoute.indexedStack` (4 branches: /inicio /restaurantes /reservas /perfil) + rutas push fullscreen (/restaurantes/:id, /reservas/wizard), AppShell con bottom nav 4 tabs (emoji del mockup) + `Center+ConstrainedBox(480)` marco móvil.
- ✅ **T2 Auth + restaurantes + perfil** (`27dcd4c` RED, `ec580b3` GREEN): LoginController + RegisterController (auto-login post-registro: register 201 → login → JWTs → invalidate authState), login/register screens con validación pre-red, restaurantesListProvider + restauranteDetalleProvider (family), lista con rating "—", detalle con ExpansionTiles por categoría + formatCOP, home réplica del mockup (header+QR placeholder Phase 6, welcome, card restaurante gradiente, 2 actions, próxima reserva), perfil con email disabled + password opcional + logout. 11/11 tests.
- ✅ **T3 Reservas** (`1b8dafd` RED, `65b76bb` GREEN): ReservaController (create/cancel → invalidate reservasProvider), wizard Stepper 4 pasos (fecha showDatePicker min mañana → hora dropdown SOLO slots :00 12:00-21:00 → personas 1-20 con clamp → confirmar con resumen), 409 → "Ese horario acaba de ser reservado, elige otro", éxito → SnackBar verde "¡Reserva confirmada! Mesa N" + pop; mis_reservas con split próximas/pasadas client-side, chips de estado (confirmada #dff7eb/#168a52, cancelada rojo), cancelar con dialog de confirmación, FAB "+" (wizard sin preselect → step Restaurante extra). 8/8 tests.
- ✅ **Verificación global**: `flutter analyze` → No issues found; `flutter test` → **19/19**; `flutter build web --release` → ✓ Built build\web (26.3s).

## Verification

| Check | Resultado |
|-------|-----------|
| flutter analyze | No issues found (0/0/0) |
| flutter test | 19/19 passed (~2s) |
| flutter build web --release | ✓ Built build\web |
| must_haves (grep) | StatefulShellRoute.indexedStack ✓, QueuedInterceptor ✓, Stepper ✓, próximas ✓, testWidget ✓ |
| key_links (grep) | /public/restaurantes ✓, /cliente/reservas ✓, navigationShell ✓ |

### UAT manual (NO bloqueante — para `/gsd-verify-work`)

```powershell
# 1. Backend (95/95): docker compose up -d
# 2. Desde la raíz:
cd app_cliente
$env:Path += ";C:\src\flutter\bin"
flutter run -d chrome --web-port=5174
# 3. http://localhost:5174 → redirect a /login
#    Login demo: carlos@demo.gri.dev / Demo!1234 (cliente, seed Phase 5)
#    O crear cuenta nueva en "¿No tienes cuenta? Regístrate"
# 4. Home: welcome con nombre, card Restaurante Demo GRI (⭐ —), botón 📷 → "Próximamente"
# 5. Restaurantes tab: cards con "—" → tap → detalle con menú ($ COP) → "Reservar una mesa"
# 6. Wizard: fecha (mañana+) → hora (solo :00) → personas → Confirmar → "¡Reserva confirmada! Mesa N"
# 7. Reservas tab: Próximas/Pasadas + chip verde + Cancelar (con dialog)
# 8. Perfil tab: editar nombre → Guardar → "Perfil actualizado"; email disabled; Cerrar sesión → /login
# 9. F5 → sesión persiste (flutter_secure_storage)
```

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] freezed prerelease genera código inválido con campos List**
- **Found during:** Task 1 (primer codegen).
- **Issue:** El grafo de deps (json_serializable 6.14.1 → analyzer ≥10) fuerza freezed 3.2.6-dev.1, que genera `required final List<Producto> productos` (modifier inválido) en los constructores de modelos con List (Categoria, RestauranteDetalle). El panel_admin usa la MISMA versión pero nunca tuvo campos List, por eso no lo detectó.
- **Fix:** Pin `freezed: '4.0.0-dev.3'` (el prerelease compatible que lo corrime; además sube flutter_riverpod a 3.4.2 — la versión locked del plan). Como `pubspec.lock` NO se commitea en panel_admin pero SÍ quedó commiteado aquí, la versión queda reproducible.
- **Files:** app_cliente/pubspec.yaml.
- **Verification:** codegen 26 outputs; analyze 0; tests 19/19.
- **Committed in:** eb3522e.

**2. [Rule 3 - Blocking] HomeScreen necesita reservasProvider (archivo de T3)**
- **Issue:** La card "Próxima reserva" del home consume `reservasProvider` que el plan creaba en T3 — sin él T2 no compila.
- **Fix:** `reservas_provider.dart` se creó en T2 (forma final, 12 líneas). Cero cambios en T3.
- **Committed in:** ec580b3.

**3. [Rule 2 - Missing functionality] Logout ausente**
- **Issue:** El plan no incluía forma de cerrar sesión en la app (sin logout, el JWT persiste para siempre en storage).
- **Fix:** TextButton "Cerrar sesión" en PerfilScreen → `authStateProvider.notifier.logout()` → redirect a /login.
- **Committed in:** ec580b3.

**4. [Rule 1 - Bug] dangling-else en _Seccion de mis_reservas**
- **Issue:** `if (empty) if (vacio) X else Y` — el `else` se ligaba al `if` interno: con reservas NO vacías no se renderizaban las cards.
- **Fix:** Collection-if con spreads `...[ ] else ...[ ]`.
- **Committed in:** 65b76bb.

**5. [Rule 1 - Bug] Stepper controlsBuilder por step**
- **Issue:** El Stepper llama controlsBuilder por TODOS los steps → 4 botones "Continuar" ambiguos para tap().
- **Fix:** Renderizar controles solo cuando `details.stepIndex == _currentStep`.
- **Committed in:** 65b76bb.

### Ajustes de API modernos (cosméticos)

- `DropdownButtonFormField.value` → `initialValue` (deprecado tras Flutter 3.33).
- Perfil: controllers sincronizados con flag `_synced` en build (en vez de initState) — authState puede resolver async.
- Tests de class-based providers: `overrideWith(Fake.new)` (no existe overrideWithValue para AsyncNotifierProvider en Riverpod 3.4.2).

**Impacto en el plan:** cero scope creep — todas las desviaciones son correcciones puntuales para compilar/comportarse como el plan especificaba.

## Notas para próximas fases

- **Phase 6 (QR):** botón 📷 del header/home y action "Escanear mesa" son placeholders (SnackBar "Próximamente") — reemplazar por mobile_scanner. La plataforma android ya está scaffoldeda.
- **Phase 7 (WS):** `reservasProvider` y `restaurantesListProvider` se reescriben — las screens NO se tocan.
- **Phase 9 (calificaciones):** `Restaurante.calificacionLabel` muestra "—" mientras el backend mande null; cuando CALI-02 llene el float, muestra "4.8" sin cambios de UI.
- **Demo login:** carlos@demo.gri.dev / Demo!1234 (restaurante id=1).
- `cupertino_icons` warning en build web: cosmético del SDK (idem panel 04-02), no se resolvió.

## Issues Encountered

- PowerShell `2>&1` sobre stderr de flutter lanza `NativeCommandError` cosmético (idem panel) — los comandos corren bien.
- `assets/.env` creado localmente desde `.env.example` (gitignored — commiteado solo el example).

## Self-Check: PASSED

- 5 artifacts must_haves: FOUND (grep StatefulShellRoute.indexedStack, QueuedInterceptor, Stepper, próximas, testWidget)
- 3 key_links: FOUND (/public/restaurantes, /cliente/reservas, navigationShell)
- Commits eb3522e, 27dcd4c, ec580b3, 1b8dafd, 65b76bb: FOUND en git log
- flutter test 19/19: VERIFICADO
- flutter analyze 0 issues: VERIFICADO
- flutter build web --release: VERIFICADO

---
*Phase: 05-app-cliente-descubrimiento-y-reservas*
*Plan: 03*
*Completed: 2026-08-14*
