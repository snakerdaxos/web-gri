---
phase: 10-migracion-a-firebase-opcion-b-apps-flutter-movil-y-panel-web
plan: "06"
subsystem: panel_admin
tags: [firebase, firestore, panel-admin, mesas-crud, qr, menu-crud, clientes, reservas, reportes, super-admin, purge]
requires:
  - "10-01 (rules/indexes/seed — doc ID determinista mesas, índice pedidos restauranteId+estado+createdAt)"
  - "10-05 (ridActivoProvider, mesasProvider+cambiarEstadoMesa, fakes, claimsProvider)"
provides:
  - "mesas_crud: crearMesa tx get+set con doc ID GRI-MESA-{rid}-{num:03d} (colisión → MesaDuplicadaException), actualizarMesa quirúrgico/move-de-doc, eliminarMesa"
  - "menu_provider: stream vivo categorias+productos (combineLatest2 sync) anidado + CRUD con toggles activo/disponible (alta autoId nace activa)"
  - "clientes_provider: fold distinct usuarioId desde pedidos (sin leer usuarios/) + clienteHistorial family (equality-only)"
  - "reservas: reservasHoy stream + marcarMesaOcupada (reservada→ocupada vía cambiarEstadoMesa) + cancelarReservaNoShow"
  - "restaurantes_admin: get() de TODOS (super re-activa) + toggleRestauranteActivo update SOLO {activo} (rules hasOnly)"
  - "reportesProvider(desde, hasta) family: fold client-side de pedidos servidos (totalVentas int, numeroPedidos, topPlatos cantidad DESC)"
  - "PURGE completo: panel SIN dio/web_socket_channel/flutter_dotenv/flutter_secure_storage/api_client/token_provider/ws_client/env/token_pair"
affects:
  - "panel_admin 100% Firestore — ambas apps migradas, backend formalmente archivado (prontas para smoke e2e 10-07)"
tech-stack:
  removed:
    - dio, web_socket_channel, flutter_dotenv, flutter_secure_storage (deps) + stream_channel (dev, fakes WS)
  patterns:
    - "Doc ID determinista = QR: cambiar numero MUEVE el doc (tx set nuevo + delete viejo) — el invariant doc ID == código se preserva siempre"
    - "Clientes derivados de pedidos (fold distinct usuarioId + clienteNombre denormalizado) — cero expansión de rules sobre usuarios/"
    - "Queries equality-only + orden client-side cuando no hay índice compuesto (clientes/historial) — higiene de índices 10-01"
    - "Toggles super acotados por rules: update diff hasOnly(['activo']) sin updatedAt adicional"
key-files:
  created:
    - panel_admin/lib/features/mesas/mesas_crud.dart
    - panel_admin/lib/features/reportes/reportes_provider.dart
  modified:
    - panel_admin/lib/features/mesas/{mesa_form_dialog,mesas_screen}.dart
    - panel_admin/lib/features/menu/{menu_provider,categoria_form_dialog,producto_form_dialog}.dart
    - panel_admin/lib/features/clientes/{clientes_provider,clientes_screen,historial_dialog}.dart
    - panel_admin/lib/features/reservas/{reservas_provider,reservas_screen}.dart
    - panel_admin/lib/features/configuracion/{restaurantes_admin_provider,configuracion_screen}.dart
    - panel_admin/lib/features/dashboard/restaurante_provider.dart
    - panel_admin/lib/features/reportes/reportes_screen.dart
    - panel_admin/lib/models/{categoria_staff,producto_staff,reserva,cliente_resumen,restaurante,reporte}.dart
    - panel_admin/lib/main.dart
    - panel_admin/pubspec.yaml
    - panel_admin/test/{mesas,menu,clientes,reservas,configuracion,reportes}/ (6 suites reescritas con fakes)
  deleted:
    - panel_admin/lib/core/{api_client,auth_storage,token_provider,token_provider.g,ws_client,env}.dart
    - panel_admin/lib/models/token_pair.{dart,g,freezed}.dart
    - panel_admin/lib/models/reporte.g.dart
    - panel_admin/assets/.env.example
    - panel_admin/test/ws_client_test.dart
decisions:
  - "actualizarMesa con numero distinto = move-de-doc (tx set+delete) en vez de update in-place: el doc ID ES el QR derivado del número — un update rompería el invariant; el warning de regeneración del form preserva la semántica"
  - "clientes/historial con queries equality-only (sin orderBy createdAt en el server): restauranteId+createdAt compuesto no está en los índices 10-01 — se ordena client-side (zigzag merge sobre índices simples)"
  - "restaurantesAdmin usa get() de TODOS los docs (super lee todo por rules) — where activo==true escondería los inactivos y no se podrían re-activar"
  - "reporte.dart se rellena SOLO con el fold (total/count/topPlatos int COP): la tabla por-día de la era REST no se recrea (fuera del diseño del plan)"
  - "reservas_screen pasa a stream de HOY en vivo sin date-picker (el provider del plan es hoy-only — un picker que no puede cambiar la query sería una mentira de UI); se agrega acción No-show"
  - "stream_channel (dev) retirado junto a la capa WS aunque no estaba en la lista LOCKED: su único consumidor era ws_client_test (su propio comentario lo ataba a los fakes WS)"
  - "models/user.dart queda como orphan (no estaba en la lista LOCKED de deletes, nada lo importa, analyze limpio)"
metrics:
  duration: "~150min (3 sesiones de ejecución continua)"
  completed: "2026-08-16"
  tests: "80/80 (87 tras Task 1-2; -6 ws_client_test y -7+5 reportes en el purge)"
  analyze: "0 issues"
---

# Phase 10 Plan 06: panel_admin — mesas CRUD+QR + menú + clientes + super-admin + reportes + PURGE Summary

**One-liner:** El panel completa su migración big-bang: mesas CRUD con QR determinista por doc ID (colisión = duplicado, move-de-doc al renumerar), menú CRUD en vivo con toggles activo/disponible, clientes DERIVADOS de pedidos (fold, sin leer usuarios/), reservas del día en vivo con marcar-ocupada/no-show, super-admin con toggle `activo` acotado por rules, reportes por rango con fold client-side de pedidos servidos — y el PURGE final elimina toda la capa REST/WS (dio, ws, dotenv, secure storage, api_client/token_provider) dejando el panel 100% Firebase sin código muerto.

## What Was Built

### Task 1 — mesas CRUD con QR determinista (ad30dec RED + d95f695 GREEN)

- `mesas_crud.dart`: `docIdDeMesa(rid, numero)` = `GRI-MESA-{rid}-{num:03d}` (paridad seed 10-01). `crearMesa` = tx get+set — el número repetido colisiona el doc ID → `MesaDuplicadaException` SIN tocar el doc original (anti-duplicado por construcción). `actualizarMesa`: solo capacidad → update quirúrgico `{capacidad, updatedAt}`; numero distinto → tx que crea el doc nuevo (estado/capacidad preservados) y borra el viejo. `eliminarMesa` → delete.
- `mesa_form_dialog` rewired a `firestoreProvider` + `ridActivoProvider`: validación numero 1..999 / capacidad 1..20, botón Eliminar con confirmación (invalida el QR impreso), cero dio/api_client/token_provider. El grid refleja altas/bajas/moves por el onSnapshot del `mesasProvider` 10-05 — sin invalidate manual.
- `qr_dialog` ya pintaba el código del doc (`QrImageView data: mesa.codigoQr` = id) — tests alineados al código determinista demo-009.
- 10/10 tests: 5 data-level (doc determinista, colisión ×2, update quirúrgico, move-de-doc, delete+stream) + 3 widget (render, crear en vivo, duplicado controlado) + 2 QR.

### Task 2 — menú CRUD + clientes + reservas + super-admin (45f563c + fe81eff codegen)

- **Models String ids + fromDoc** (precio int COP): `CategoriaStaff` (orden/activo, productos anidados), `ProductoStaff` (categoriaId String, disponible/activo), `Reserva` (fecha Timestamp, mesaId QR → mesaNumero derivado), `ClienteResumen` (usuarioId/clienteNombre/nPedidos/totalConsumo/ultimoPedido), `Restaurante` (activo/califProm/califCount).
- **menu_provider**: stream `categorias where restauranteId orderBy orden` + `productos where restauranteId` combinados con combineLatest2 `sync:true` (patrón stats 10-05) y anidado client-side — los cambios se ven en vivo en el panel Y en el discover del cliente. CRUD: alta autoId nace `activo: true`; updates quirúrgicos diff-only con toggles.
- **clientes_provider**: `pedidos where restauranteId` (equality-only) + orden DESC client-side + fold distinct por `usuarioId` con `clienteNombre` denormalizado — CERO lecturas de `usuarios/` (rules las prohíben al staff). `clienteHistorial(rid, uid)` family con dos igualdades (zigzag merge, sin índice nuevo).
- **reservas**: `reservasHoyProvider` = la MISMA query del dashboard 10-05 (ventana TZ local, índice restauranteId+fecha). `marcarMesaOcupada` lee la mesa real y delega en `cambiarEstadoMesa` (valida reservada→ocupada ANTES del write); `cancelarReservaNoShow` = validarTransicion('reserva') + update `{estado, updatedAt}` (rules: soloEstado + estado cancelada).
- **restaurantes_admin**: `get()` de TODOS los restaurantes (super lee todo — los inactivos deben poder re-activarse), orden alfabético; `toggleRestauranteActivo` = update SOLO `{activo}` (rules `hasOnly(['activo'])`).
- **restauranteProvider** → stream Firestore del doc del tenant (alimenta el tab Restaurante); sección legacy (`currentRestauranteIdProvider`) sobrevive una task más por `ws_client`. Forms y screens (menú/clientes/reservas/config) rewired a `ridActivoProvider`/`claimsProvider`; gating super por claims con spinner al resolver. `api_client` reducido a superficie mínima (me/refreshTokens/reportes) para compilar hasta el purge.
- 16/16 tests: menú (render+badges, alta categoría doc, toggle Agotado quirúrgico, badge Inactiva), clientes (fold data-level con tenant-filtro, tabla, historial DESC, empty), reservas (hoy sin ayer ni otro tenant, marcar ocupada pasa mesa, no-show cancela+tacha, carrera ocupada, empty), configuración (3 restaurantes con switch OFF sur, toggle persiste SOLO activo, tab ausente para staff).

### Task 3 — reportes fold + PURGE (00e875e)

- **PARTE A**: `reportesProvider(desde, hasta)` family — `pedidos where restauranteId + estado == servido + createdAt rango` (índice 10-01) → get() + fold: `totalVentas` (Σ total int), `numeroPedidos`, `topPlatos` (map nombre→Σ cantidad/Σ precio×cantidad desde snapshots, orden cantidad DESC, top 10). `reporte.dart` reescrito (Reporte/TopPlato int COP). `reportes_screen` rewired al family: mismo rango picker, default últimos 7 días sin fechas, validación client-side intacta, resultados con cards + top platos numerados.
- **PARTE B — purge LOCKED**: DELETE `core/{api_client, auth_storage, token_provider(.g), ws_client, env}.dart`, `models/token_pair.*`, `assets/.env.example` (el `.env` real ya estaba gitignored), `test/ws_client_test.dart`. `restaurante_provider` sin sección legacy. pubspec sin `dio`/`web_socket_channel`/`flutter_dotenv`/`flutter_secure_storage`/`stream_channel` ni assets block. `main.dart` sin dotenv.load.
- Verificación del plan: `rg "api_client|token_provider|ws_client|auth_storage|dotenv|TokenPair" lib test` → **0 matches**; aislamiento revisado (16 puntos `.collection()` — todas las queries de negocio llevan `where restauranteId`, las 2 de restaurantes son super-gated).

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Task 1: actualizarMesa con numero podría romper el invariant doc ID = QR**
- **Found during:** Task 1 (diseño de la implementación)
- **Issue:** El plan decía `actualizarMesa → update {capacidad?, numero?, updatedAt}`, pero el doc ID ES el QR derivado del número — un update in-place de `numero` dejaría el doc `GRI-MESA-demo-005` con numero 6 (QR apunta al doc equivocado; `mesaNumeroDeQr` derivaría mal)
- **Fix:** numero distinto → tx move-de-doc (set nuevo ID con estado/capacidad + delete viejo); test dedicado verifica el move y que el destino ocupado lanza MesaDuplicadaException
- **Files:** mesas_crud.dart · **Commit:** d95f695

**2. [Rule 3 - Blocking] api_client dejaba de compilar tras migrar los models (Task 2)**
- **Issue:** Los métodos REST usaban `fromJson` de models que ya no lo tienen — pero api_client NO se elimina hasta Task 3 y Task 2 exige analyze 0
- **Fix:** Superficie mínima transitoria (me/refreshTokens/getReporteVentas/getTopPlatos + interceptor) con comentario explícito del purge inminente; Task 3 lo eliminó completo
- **Files:** core/api_client.dart (transitorio) · **Commit:** 45f563c

**3. [Rule 2 - Missing] Gating super por claims era async (DefaultTabController length cambiante)**
- **Issue:** `authStateProvider.isSuperAdmin` (sync REST) fue reemplazado por `claimsProvider` (async) — cambiar el length del TabController mid-life es inestable
- **Fix:** `claimsAsync.when` — tabs se construyen SOLO con claims resueltos (spinner breve al abrir)
- **Files:** configuracion_screen.dart · **Commit:** 45f563c

**4. [Rule 1 - Bug] Tests Task 2: orden alfabético de restaurantes y acciones vivas tras no-show**
- **Issue:** (a) Los switches de restaurantes se asertaban en orden Demo/Norte/Sur pero la lista se ordena alfabéticamente (Norte, Sur, Demo); (b) tras cancelar UNA reserva, 'No-show' sigue existiendo (la OTRA viva lo conserva)
- **Fix:** Índices corregidos + aserción findsOneWidget para el No-show restante
- **Files:** restaurantes_test.dart, reservas_screen_test.dart · **Commit:** 45f563c

**5. [Rule 1 - Bug] Test reportes: '2' colisionaba (card Pedidos + avatar del 2º plato)**
- **Fix:** Aserción por descendant-of-CircleAvatar + findsNWidgets(2) documentado
- **Files:** reportes_screen_test.dart · **Commit:** 00e875e

### Desviaciones de alcance (documentadas en decisions del frontmatter)

- `stream_channel` (dev) retirado junto a la capa WS (su único consumidor era ws_client_test) — no estaba en la lista LOCKED literal.
- `assets/.env.example` eliminado (artefacto de la capa env purgada); el `.env` real ya estaba gitignored.
- `models/user.dart` queda orphan por la misma razón inversa (no estaba en la lista LOCKED de deletes).
- `historial_dialog` requería un ajuste de una línea (`cliente.nombre` → `clienteNombre`) pese a "intacto" en el plan — consecuencia directa de la migración del model.

## Testing

- **80/80 verdes** + `flutter analyze` 0 issues + rg legacy 0 matches.
- TDD completo en Task 1 (RED ad30dec con stubs UnimplementedError → GREEN d95f695); Tasks 2-3 implementación + suites reescritas (el plan solo marca tdd la Task 1).
- Patrón fakes idéntico a 10-05 (FakeFirebaseFirestore + claimsProvider override) — nada de mocks HTTP. Lección aplicada: `container.listen` antes de `read(.future)` en providers autoDispose de stream (tests de mesas).
- Horas fijas 12:00/14:00 para reservas de hoy (no cruzar medianoche — flake lesson 10-05).

## Self-Check: PASSED

- Archivos clave en disco: mesas_crud.dart, menu_provider.dart, clientes_provider.dart, reservas_provider.dart, restaurantes_admin_provider.dart, reportes_provider.dart, pubspec.yaml (sin capa HTTP), main.dart (sin dotenv) — verificados.
- 5 commits del plan verificados en git: ad30dec, d95f695, 45f563c, fe81eff, 00e875e.
- Deletes verificados: core legacy (6), token_pair (3), reporte.g.dart, .env.example, ws_client_test.dart — inexistentes en el árbol.
