---
phase: 08-panel-admin-gesti-n-completa-y-reportes
plan: "03"
subsystem: panel-admin
tags: [mesas-ui, qr-imprimible, state-transitions-ui, admn-04, ws-kick-refetch, flutter-web]
requires:
  - "Plan 08-02 completo (POST/PATCH /staff/mesas + POST /staff/mesas/{id}/estado; backend 181/181)"
  - "mesasProvider Stream WS kick-to-refetch (07-02) — reusado tal cual, sin provider nuevo"
  - "AppShell sidebar + TopBar (T-04) sobre el que se activó el ítem Mesas"
provides:
  - "Pantalla /mesas: grid vivo de mesas + FAB Nueva mesa + edición inline vía actions sheet"
  - "MesaFormDialog: crear/editar con warning de regeneración de QR antes de guardar (Pitfall 6)"
  - "showQrDialog: QrImageView fondo blanco + SelectableText + Imprimir (window.print web-only)"
  - "showMesaActionsSheet + kMesaTransitions/kMesaActionLabels: mirror client-side de MESA_TRANSITIONS reutilizable por mapa y gestión"
  - "MesaTile.onTap (InkWell aditivo) + dashboard interactivo ADMN-04 (showEdit false)"
  - "print_service.dart: patrón export condicional stub/web para APIs del browser (VM-safe en tests)"
  - "TopBar dinámico: mapa estático path → (título, subtítulo) de los 7 paths del sidebar"
affects:
  - "Plan 08-04/08-05: el patrón print_service (export condicional) aplica a cualquier API web futura; el TopBar ya tiene los títulos de /reportes y /configuracion"
tech-stack:
  added:
    - "qr_flutter 4.1.0 (QrImageView — pintado QR puro Dart, sin platform channels)"
    - "data_table_2 2.8.0 (instalada para próximas pantallas de gestión —tablas paginadas)"
    - "web 1.1.1 (window.print; JAMÁS import directo — rompe la VM de tests)"
  patterns:
    - "Export condicional `export 'stub.dart' if (dart.library.js_interop) 'web.dart'` para APIs del browser — package:web en la VM del runner no compila"
    - "Sheet de acciones por estado: UI ofrece SOLO el mirror de transiciones; el 409 del server sigue siendo la autoridad (carrera entre staff)"
    - "Sin drift: tras create/update/setEstado NUNCA se invalida/muta la lista — el evento WS mesa.estado (emitido post-commit por el backend) dispara el kick-to-refetch"
    - "Capturas síncronas antes del await: messenger/navigator/ref.read todos ANTES del primer await (patrón cocina_screen extendido a diálogos)"
key-files:
  created:
    - panel_admin/lib/features/mesas/mesas_screen.dart
    - panel_admin/lib/features/mesas/mesa_form_dialog.dart
    - panel_admin/lib/features/mesas/mesa_actions_sheet.dart
    - panel_admin/lib/features/mesas/qr_dialog.dart
    - panel_admin/lib/features/mesas/print_service.dart
    - panel_admin/lib/features/mesas/print_service_stub.dart
    - panel_admin/lib/features/mesas/print_service_web.dart
    - panel_admin/test/mesas/mesas_screen_test.dart
    - panel_admin/test/mesas/qr_dialog_test.dart
    - panel_admin/test/dashboard/mesa_actions_test.dart
  modified:
    - panel_admin/pubspec.yaml
    - panel_admin/lib/core/api_client.dart
    - panel_admin/lib/app.dart
    - panel_admin/lib/features/shared/app_shell.dart
    - panel_admin/lib/features/dashboard/dashboard_screen.dart
    - panel_admin/lib/features/dashboard/widgets/mesa_tile.dart
decisions:
  - "Orden de commits T2→T1→T3 (sancionado por la nota del plan-checker): app.dart importa MesasScreen y el InkWell del tile requiere el Material del dashboard — así cada snapshot compila y pasa tests"
  - "window.print vía export condicional (stub VM / web browser) en vez del fallback 'usa Ctrl+P': mantiene MESA-03 completo sin romper la suite"
  - "El sheet del mapa usa showEdit: false (la edición vive en /mesas); el sheet de gestión lo reutiliza con true — un solo dueño de la lógica de transiciones"
  - "updateMesa con null-aware elements `{'numero': ?numero}` — estilo del repo (getPedidosActivos); solo los campos modificados viajan"
  - "Form deshabilita Guardar cuando la edición no tiene cambios (evita el 422 'Nada que actualizar' del backend por diseño)"
metrics:
  duration: "~28 min (2026-08-14 13:56→14:24 UTC)"
  tests: "28 → 39 (+3 mesas_screen, +2 qr_dialog, +6 mesa_actions/ADMN-04), 2 runs completos verdes + build web OK"
  completed: 2026-08-14
---

# Phase 8 Plan 03: Panel gestión de mesas + QR + mapa interactivo Summary

**One-liner:** Feature completa `features/mesas/` — pantalla /mesas con grid vivo (reutiliza el Stream WS del dashboard, cero providers nuevos), form con warning de regeneración de QR, QR dialog imprimible vía `window.print` (export condicional VM/web), y actions sheet con el mirror `kMesaTransitions` que ofrece solo transiciones válidas por estado con manejo de carrera 409 — suite panel 28 → 39, build web OK.

## Tasks Completed

| # | Task | Commit | Verificación |
|---|------|--------|--------------|
| 2 | Feature mesas: screen + form (warning QR) + actions sheet + QR dialog + tests | `39abaec` | test/mesas 5/5; analyze 0; suite 33 |
| 1 | Deps + ApiClient (create/update/setEstado) + ruta /mesas + sidebar + TopBar dinámico | `386a94a` | suite 33 sin regresiones; sidebar índice 1 navega; TopBar dinámico |
| 3 | ADMN-04: mapa dashboard interactivo (MesaTile.onTap → sheet) + suite 6 casos | `9e5fda3` | mesa_actions 6/6 + tile_color 4/4 sin cambios; suite 39; build web OK |

> Nota de orden: los commits se hicieron T2 → T1 → T3 (dependencia de compilación: app.dart importa MesasScreen; ver Deviations #3).

## What Was Built

### Pantalla /mesas (MESA-01 UI) — `mesas_screen.dart`
- `MesasScreen` ConsumerWidget: watch del **mesasProvider existente** (Stream WS kick-to-refetch + wsResync + safety net 60s) — el backend (08-02) emite `mesa.estado` también en create/update → las mesas nuevas aparecen solas sin invalidate manual.
- Grid responsive 4/3/2 (mismo criterio del mapa), loading/error (Reintentar)/vacío 'Sin mesas configuradas', header + `FloatingActionButton.extended` 'Nueva mesa'.
- Tap en tile → actions sheet con edición habilitada (showEdit: true).

### Form crear/editar — `mesa_form_dialog.dart`
- 2 TextFormField (numero/capacidad, validators int > 0), modo crear (`mesa == null` → createMesa) o editar (updateMesa con SOLO campos modificados — la suite asienta `(5, 6, null, null)` al cambiar solo el número).
- **Warning naranja de regeneración** visible únicamente en edición cuando el número tipeado != original: '⚠️ Cambiar el número regenera el código QR de la mesa — el QR impreso anterior quedará obsoleto' (Pitfall 6 del research, ANTES de guardar).
- DioException 409 → 'Ya existe una mesa con ese número'; éxito → pop + SnackBar; JAMÁS invalida el provider (el WS refresca). Guardar deshabilitado sin cambios (evita el 422 "Nada que actualizar").

### QR dialog (MESA-03) — `qr_dialog.dart` + `print_service*.dart`
- `QrImageView(data: codigo_qr, size: 280, gapless: false, backgroundColor: Colors.white)` + `SelectableText(codigo_qr)` (fallback tipeable) + botón 🖨️ Imprimir.
- **Export condicional** `print_service.dart`: stub (VM) ↔ `package:web` (browser) vía `if (dart.library.js_interop)` — un import directo de package:web rompe la compilación de TODA la suite en la VM.

### Actions sheet (ADMN-04 core) — `mesa_actions_sheet.dart`
- `kMesaTransitions` espejo literal de MESA_TRANSITIONS + `kMesaActionLabels` ((origen, destino) → label de negocio) + orden estable por lista fija filtrada.
- Header 'Mesa {n} — {estado}', ListTiles SOLO de destinos válidos, Divider, '📷 Ver código QR', y '✏️ Editar mesa' condicionado a showEdit.
- `_cambiarEstado`: capturas síncronas (messenger/user/rid/client) → pop → `setMesaEstado` → SnackBar 'Mesa {n} → {destino}'; 409 → 'La mesa cambió de estado (otro usuario la actualizó) — se refrescó la lista'; sin invalidate (WS kick).

### Infra (Task 1)
- ApiClient: `createMesa/updateMesa/setMesaEstado` con queryRid solo super_admin (patrón getMesas); updateMesa con null-aware elements.
- app.dart: GoRoute `/mesas` en el ShellRoute; app_shell: `_routes[1] = '/mesas'` + `_TopBar` con mapa estático de los 7 paths (título, subtítulo) — default Dashboard; dashboard: botón 'Nueva mesa' → `context.go('/mesas')`.
- MesaTile: `onTap` aditivo (InkWell borderRadius 15 dentro del MouseRegion; default null); dashboard envuelto en `Material(color: background)` (standalone-safe, patrón cocina).

### Tests (28 → 39)
- `qr_dialog_test` (2): QrImageView + QrPainter montado + igualdad EXACTA del código vía SelectableText; Cerrar hace pop. Imprimir JAMÁS se tapea.
- `mesas_screen_test` (3): render 2 tiles + FAB; crear viaja `createMesa(9, 4, null)`; edición 5→6 muestra 'regenera' + `updateMesa(5, 6, null, null)`.
- `mesa_actions_test` (6, ADMN-04): (a) disponible → exactamente reservada+ocupada, sin Editar; (b) limpieza → solo Liberar; (c) ocupada → solo Marcar en limpieza; (d) espía `setMesaEstado(7, 'limpieza')` + sheet cerrado + SnackBar; (e) 409 → SnackBar 'cambió de estado' sin crash; (f) tap del MesaTile del dashboard abre el sheet.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] `package:web` rompía la compilación de TODA la suite en la VM**
- **Found during:** Task 2 (primer `flutter test` completo tras escribir qr_dialog)
- **Issue:** `package:web` importa `dart:js_interop`, indisponible en la VM del runner — el import directo en qr_dialog hacía fallar la compilación de cualquier test que lo alcanzara transitivamente (login_form, stats_render, mesas, qr_dialog).
- **Fix:** Export condicional `print_service.dart` (stub VM ↔ web browser). El botón Imprimir llama `printCurrentView`. Verificado: suite completa verde en VM + `flutter build web --release` OK (compila print_service_web).
- **Files:** features/mesas/print_service{,_stub,_web}.dart, qr_dialog.dart
- **Commit:** 39abaec

**2. [Rule 1 - Bug] InkWell del MesaTile exigía Material ancestor (dashboard standalone)**
- **Found during:** Task 2 (stats_render_test: 'No Material widget found')
- **Issue:** El plan pedía envolver el Container del tile en InkWell; el dashboard se bombea standalone sin Scaffold en tests (y en producción el Material lo da el Scaffold del AppShell).
- **Fix:** `DashboardScreen` envuelto en `Material(color: GriColors.background)` — exactamente el patrón documentado de cocina_screen para standalone-fidelity.
- **Files:** dashboard_screen.dart
- **Commit:** 39abaec

**3. [Decisión de orden — sancionada por la nota del plan-checker] Commits T2 → T1 → T3**
- **Issue:** Task 1 agrega la ruta que importa MesasScreen (Task 2) y el onTap del tile (T3) requiere Material del dashboard; commits en orden de plan dejarían snapshots que no compilan.
- **Fix:** Feature primero (39abaec), luego infra (386a94a), luego mapa (9e5fda3). Cada snapshot verificado verde.
- **Commits:** 39abaec, 386a94a, 9e5fda3

**4. [Nota] qr_flutter 4.1.0 no expone getter público `data` (privado `_data`)**
- **Found during:** Task 2 (analyze: undefined_getter en el test)
- **Fix:** La igualdad EXACTA del código se asienta vía SelectableText + el pintado real vía CustomPaint con QrPainter (exportado por qr_flutter). Mismo valor de verificación, API pública.
- **Commit:** 39abaec

## Auth Gates

None — no se requirió intervención humana de autenticación.

## Verification Results

| Check | Resultado |
|-------|-----------|
| `flutter analyze` | **0 issues** (3 runs durante la ejecución) |
| `flutter test` (workdir panel_admin) | **39 passed** (28 previos + 11 nuevos), 2 runs completos |
| `flutter build web --release` | **OK** (28.8s; Wasm dry run OK — qr_flutter + print_service_web compilan en el target) |
| deps | qr_flutter 4.1.0, data_table_2 2.8.0, web 1.1.1 en pubspec; **sin** fl_chart ni cached_network_image |
| Regresiones | dashboard (stats_render, mesa_tile_color) y cocina (cola_test) intactos; WS tests intactos |

## Requirements Covered

- **MESA-01 (UI)** — /mesas desde el sidebar (índice 1) con grid vivo, FAB crear, edición inline; QR autogenerado visible desde el sheet (Ver código QR).
- **MESA-03** — QR dialog con QrImageView (fondo blanco) + código seleccionable + Imprimir (window.print en web).
- **ADMN-04** — mapa del dashboard con acciones SOLO-válidas por estado (mirror kMesaTransitions), 409 → SnackBar, refresh por WS kick (mesa.estado emitido post-commit por el backend).

## Manual UAT (para verificación humana)

1. Login `admin@demo.gri.dev` (Demo!1234) → sidebar **Mesas** → TopBar muestra 'Mesas / Gestión de mesas y códigos QR'.
2. FAB **Nueva mesa** → numero 9, capacidad 4 → Guardar → SnackBar 'Mesa 9 creada' y el tile aparece solo (WS).
3. Tap mesa 9 → **Ver código QR** → QR grande + código `GRI-MESA-R1-009` seleccionable + Imprimir (Ctrl+P del browser).
4. **Editar mesa** 9 → cambiar numero a 10 → warning naranja de regeneración → Guardar → QR regenerado (verificar en Ver código QR).
5. Dashboard → tap mesa ocupada → SOLO 'Marcar en limpieza' + Ver QR (sin Editar) → aplicar → color cambia en vivo (WS).

## Notes for Next Plans

- **08-04/08-05:** el TopBar ya tiene títulos/subtítulos de todos los paths restantes (solo falta registrar la ruta en app.dart y activar el índice en _routes). data_table_2 ya está instalada para las tablas de gestión.
- **Patrón print_service** para cualquier API del browser futura (ej. share, clipboard): export condicional, jamás import directo de package:web.
- El actions sheet es reutilizable desde cualquier superficie (mapa, gestión, futuro listado de reservas que marque mesa reservada).
- qr_flutter: `data` no tiene getter público — para asertar el contenido en tests usar SelectableText/QrPainter (documentado en qr_dialog_test).

## Self-Check: PASSED

- Archivos verificados en disco: qr_dialog.dart (55 líneas ≥ min 30), mesa_actions_sheet.dart (~200 ≥ min 50), mesa_form_dialog.dart (~230 ≥ min 40), mesa_actions_test.dart (~250 ≥ min 60) — FOUND.
- 3/3 commits verificados en `git log`: 39abaec, 386a94a, 9e5fda3 — FOUND.
