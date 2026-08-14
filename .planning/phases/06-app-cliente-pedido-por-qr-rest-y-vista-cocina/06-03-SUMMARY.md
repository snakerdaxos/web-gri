---
phase: 06-app-cliente-pedido-por-qr-rest-y-vista-cocina
plan: 03
subsystem: panel-admin-cocina
tags: [vista-cocina, cola-pedidos, polling, matriz-rol-transicion, badge-cuenta, sidebar, go-router]
requires:
  - "06-01 (GET /staff/pedidos?activos=true con badge solicita_cuenta + POST /staff/pedidos/{id}/estado con TRANSITION_ROLES)"
  - "04-02 (panel_admin: ApiClient interceptor, AppShell sidebar, patrones polling/test)"
provides:
  - "features/cocina/ completa: CocinaScreen (AsyncValue loading/error/vacío) + PedidoCard (mesa/items/total COP/notas/usuario/badge) + pedidosStaffProvider (polling 10s)"
  - "PedidoStaff/PedidoStaffItem freezed con nextActions(rol) — espejo client-side de TRANSITION_ROLES (el server es la autoridad)"
  - "ApiClient.getPedidosActivos/avanzarPedido (queryRid solo super_admin, patrón getMesas)"
  - "core/format.dart formatCOP (es_CO) para todo el panel"
  - "Sidebar '📋 Pedidos' activo → /cocina (isActive derivado del path vía ShellRoute state)"
affects:
  - "Phase 7 (WS): retira el Timer.periodic de pedidosStaffProvider sin tocar los consumers"
  - "Phase 8 (CRUD panel): el mapa _routes del sidebar es el punto de activación de nuevos ítems"
  - "F9 pagos: la cola muestra servido esperando pago; badge pidió la cuenta es el insumo del mesero"
tech-stack:
  added: []
  patterns:
    - "nextActions(rol) como espejo client-side de la matriz server: ocultar botones es UX, 409/403 del server son la autoridad"
    - "Material ancestor explícito en screens bombeadas fuera de Scaffold (tests/standalone) — sin él Flutter inyecta fallback style 48px"
    - "Mapa ruta→índice en el sidebar para isActive derivado del path del ShellRoute builder"
    - "ListView lazy en widget tests: agrandar tester.view.physicalSize para cards fuera del fold"
key-files:
  created:
    - panel_admin/lib/models/pedido_staff.dart
    - panel_admin/lib/core/format.dart
    - panel_admin/lib/features/cocina/pedidos_staff_provider.dart
    - panel_admin/lib/features/cocina/cocina_screen.dart
    - panel_admin/lib/features/cocina/widgets/pedido_card.dart
    - panel_admin/test/cocina/cola_test.dart
  modified:
    - panel_admin/lib/core/api_client.dart (+getPedidosActivos/avanzarPedido)
    - panel_admin/lib/app.dart (GoRoute /cocina + location al AppShell)
    - panel_admin/lib/features/shared/app_shell.dart (isActive por path + Pedidos navega)
    - panel_admin/pubspec.yaml (freezed 4.0.0-dev.3 pin)
decisions:
  - "Label del botón servido por rol: cocina/admin ven 'Servido', mesero ve 'Marcar servido' (must_have del plan)"
  - "freezed pineado a 4.0.0-dev.3 en panel_admin (mismo pin que app_cliente): 3.2.6-dev.1 genera 'required final List<T>' inválido"
  - "CocinaScreen se envuelve en Material(color: GriColors.background): robustez standalone/tests sin depender del Scaffold del AppShell"
  - "El índice activo de '/cocina' es 2 (no 1 como decía el plan): _items real es Dashboard 0, Mesas 1, Pedidos 2"
  - "avanzarPedido refresca la cola SIEMPRE (éxito → nuevo estado; 409/403 → re-sincroniza con el server)"
requirements-completed: [ADMN-05, PEDI-05, PEDI-06, PAGO-01]
metrics:
  duration: 102min
  tasks: 2
  tests-new: 6
  tests-total: 17
  completed: 2026-08-14
---

# Phase 6 Plan 03: Panel Admin — Vista Cocina (Cola de Pedidos) Summary

**Vista cocina del panel: cola de pedidos activos con polling 10s, cards completas (mesa/items ×cantidad/total COP/notas/usuario), badge "🍽️ pidió la cuenta", botones según la matriz rol×transición (mesero solo "Marcar servido") y el item "📋 Pedidos" del sidebar activo vía /cocina — suite 11→17.**

## Performance

- **Duration:** 102 min (13:59Z → 15:41Z)
- **Tasks:** 2 (auto, secuenciales)
- **Files:** 6 creados + 4 modificados (+7 codegen regenerados)
- **Commits:** 5afda4b (T1) + 8cd2aba (T2)

## Accomplishments

- **Task 1** (`5afda4b`): `PedidoStaff`/`PedidoStaffItem` freezed (snake_case↔wire, estados con color/label coherentes con GriColors: enviado azul, aceptado naranja, en_preparación morado, servido verde) + `nextActions(rol)` espejo client-side de TRANSITION_ROLES. `ApiClient.getPedidosActivos` (`activos=true` + queryRid solo super_admin) y `avanzarPedido` (POST estado destino). `pedidosStaffProvider` clon exacto de mesas_provider (Timer.periodic + try/catch + ref.onDispose cancel/close). `PedidoCard` con borde lateral de estado, chip, hora HH:mm, badge amarillo "🍽️ pidió la cuenta", items con subtotal, total formatCOP, notas itálicas, usuario sutil y botones (Rechazar outlined rojo, resto primary). `CocinaScreen` con AsyncValue idiomático + SnackBars accionables 409 ("Alguien ya movió este pedido — refrescando") / 403 ("Tu rol no puede hacer esta acción") + invalidate SIEMPRE.
- **Task 2** (`8cd2aba`): `GoRoute /cocina` dentro del ShellRoute con `state.uri.path` pasado al AppShell; sidebar con isActive derivado del path (mapa `_routes`), "📋 Pedidos" navega a /cocina (antes "Próximamente"), Dashboard navega a /, los otros 5 siguen deshabilitados (Phase 8). Tests (e) tap Aceptar → `avanzarPedido(7, 'aceptado')` verificado con fake ApiClient + invalidación espía (onDispose); (f) mesero sin Aceptar/Rechazar sobre enviado y solo "Marcar servido" en en_preparación. **flutter analyze 0 issues · suite 17/17 · flutter build web --release OK.**

## Verification

| Check | Resultado |
|-------|-----------|
| flutter test test/cocina/cola_test.dart | **6/6** ((a) render mesa/items/totales COP/chips/hora, (b) badge cuenta, (c) cocina Aceptar+Rechazar, (d) vacío, (e) avance+invalidate, (f) restricción mesero) |
| flutter test (suite completa) | **17/17** (11 previos sin regresión + 6 nuevos) |
| flutter analyze | **No issues found** |
| flutter build web --release | ✓ Built build\web |
| pedidos_staff_provider | Timer.periodic + ref.onDispose + queryRid solo si isSuperAdmin (patrón mesas_provider) ✓ |
| Matriz client-side | enviado→Aceptar/Rechazar (cocina/admin/super_admin), aceptado→En preparación (ídem), en_preparación→Servido (todos los staff), servido→sin botones — espejo de TRANSITION_ROLES ✓ |
| Sidebar | "📋 Pedidos" → context.go('/cocina'); isActive = índice derivado del path ✓ |
| Scope | app_cliente/ y backend/ INTACTOS (otro agente en paralelo); dashboard/mapa sin regresión (17/17) ✓ |

**UAT manual (NO bloqueante, pendiente):** docker compose up -d → flutter run -d chrome --web-port=5173 → login cocina@demo.gri.dev / Demo!1234 → sidebar "Pedidos" → cola refleja pedidos de la app cliente → Aceptar → En preparación → Servido; login mesero@demo.gri.dev → solo "Marcar servido"; badge "🍽️ pidió la cuenta" tras solicitar cuenta desde la app.

## Task Commits

1. **Task 1: feature cocina completa** — `5afda4b`
2. **Task 2: sidebar/ruta activos + tests e/f + verificación global** — `8cd2aba`

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] `core/format.dart` no existía en panel_admin**
- **Found during:** Task 1 (el plan lo referenciaba como existente)
- **Issue:** El plan decía "formatCOP existe en core/format.dart del panel" pero el panel nunca lo tuvo (solo app_cliente)
- **Fix:** Creado `panel_admin/lib/core/format.dart` espejo exacto del de app_cliente (intl, es_CO, symbol $, 0 decimales)
- **Files:** panel_admin/lib/core/format.dart

**2. [Rule 3 - Blocking] freezed 3.2.6-dev.1 genera código Dart inválido para campos List**
- **Found during:** Task 1 (build_runner OK pero compilación de tests fallaba)
- **Issue:** `required final List<PedidoStaffItem> items` — `required final` en parámetro plain es inválido ("Can't have modifier 'final' here"). app_cliente ya había topado con esto ("verificar codegen de List fields") y pineó 4.0.0-dev.3
- **Fix:** `freezed: '4.0.0-dev.3'` en pubspec.yaml (mismo pin que app_cliente) + regeneración de todos los .freezed.dart
- **Files:** panel_admin/pubspec.yaml, pubspec.lock, 5 .freezed.dart regenerados
- **Verification:** suite 17/17 sin `required final` en generados

**3. [Rule 1 - Bug] `--build-dir .dart_tool` no es flag válido de build_runner**
- **Found during:** Task 1 (verify automatizado del plan imprimía help)
- **Fix:** `dart run build_runner build` sin el flag (el runner maneja conflictos solo — consistente con gotcha 04-02)

**4. [Rule 1 - Bug] Riverpod 3.4.2 no exporta el tipo `Override`**
- **Found during:** Task 1 (helper tipado del test no compilaba)
- **Fix:** Cada test inlinea el ProviderScope con su lista de overrides (patrón stats_render_test ya probado en el repo)
- **Files:** panel_admin/test/cocina/cola_test.dart

**5. [Rule 1 - Bug] Índice del sidebar: plan decía '/cocina' → 1, pero '📋 Pedidos' es el índice 2**
- **Found during:** Task 2 (_items real: Dashboard 0, Mesas 1, Pedidos 2 — el plan olvidó 'Mesas')
- **Fix:** Mapa `_routes` ruta→índice; `/` → 0, `/cocina` → 2 (indexOf sobre el mapa, imposible drift)
- **Files:** panel_admin/lib/features/shared/app_shell.dart

**6. [Rule 1 - Bug] Texts a 48px en tests standalone (fallback style de Flutter)**
- **Found during:** Task 1 (badge "pidió la cuenta" renderizaba 720×48 y overfloweaba)
- **Issue:** `MaterialApp(home:)` NO provee Material ancestor → Flutter inyecta el fallback style (48px amarillo subrayado) a todo Text sin fontSize explícito. En producción lo provee el Scaffold del AppShell, así que era invisible en prod pero rompía/engañaba a los tests
- **Fix:** CocinaScreen envuelta en `Material(color: GriColors.background)` — fiel standalone y en prod
- **Files:** panel_admin/lib/features/cocina/cocina_screen.dart

**7. [Rule 1 - Test] ListView lazy esconde cards fuera del viewport default (800×600)**
- **Found during:** Task 1 (test (a) no encontraba "Mesa 5")
- **Fix:** `tester.view.physicalSize = Size(800, 1800)` + dpr 1.0 + `addTearDown(tester.view.reset)` en tests multi-card

---

**Total deviations:** 7 auto-fixed (3× Rule 3, 4× Rule 1)
**Impact on plan:** Todas necesarias para compilar/corrección. Cero scope creep; una dev-dep re-pineada (freezed, ya validada por app_cliente).

## Issues Encountered

- El plan prescribía el label "Servido" para todos los roles pero el must_have y el test (f) exigen "Marcar servido" para mesero → label por rol implementado (cocina/admin "Servido").
- `documentos/` (mockups del usuario) sigue untracked — preexistente, fuera de alcance, NO commiteado.

## User Setup Required

None — sin servicios externos nuevos. El panel consume el backend 06-01 ya desplegado (docker compose).

## Next Phase Readiness

- ADMN-05 cerrado; la UI staff de PEDI-05/PEDI-06/PAGO-01 queda completa sobre el backend 06-01.
- Phase 7 (WS): reemplazar el Timer de pedidosStaffProvider/mesasProvider por un Stream WS — los consumers no cambian.
- Phase 8: activar nuevos ítems del sidebar agregando rutas al mapa `_routes` de app_shell.dart.
- UAT manual pendiente (documentado arriba) — no bloquea el cierre del plan.

## Self-Check: PASSED

8/8 archivos fuente verificados en disco (pedido_staff.dart, format.dart, pedidos_staff_provider.dart, cocina_screen.dart, pedido_card.dart, cola_test.dart, app.dart, app_shell.dart); 2/2 commits verificados en `git log` (5afda4b, 8cd2aba).

---
*Phase: 06-app-cliente-pedido-por-qr-rest-y-vista-cocina*
*Completed: 2026-08-14*
