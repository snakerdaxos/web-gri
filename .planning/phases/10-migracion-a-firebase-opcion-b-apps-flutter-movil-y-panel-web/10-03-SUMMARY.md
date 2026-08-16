---
phase: 10-migracion-a-firebase-opcion-b-apps-flutter-movil-y-panel-web
plan: "03"
subsystem: app_cliente
tags: [firebase, firestore, reservas, discover, migracion, concurrencia]
requires:
  - "10-01 (rules/indexes/seed — doc shapes + índices reservas usuarioId+fecha DESC, mesas restauranteId+numero)"
  - "10-02 (firestoreProvider override point, state_machines portados, firebase_fakes con seed demo)"
provides:
  - "Models con fromDoc(DocumentSnapshot) ids String (restaurante/detalle/categoria/producto/reserva) — vía canónica Firestore"
  - "restaurantesList (solo activos) + restauranteDetalle(String) con menú agrupado — 100% Firestore, sin dio"
  - "crearReserva: runTransaction + docId determinista {mesaId}_{yyyyMMdd}_{HH} (port de reserva_service.py, MIGRA-06)"
  - "cancelarReserva: transición state machine + reversión condicional de mesa (paridad Phase 5)"
  - "misReservasProvider(uid): StreamProvider snapshots orderBy fecha DESC con join client-side de restauranteNombre"
  - "Mutex en-proceso _seccionCritica para mutaciones de reservas (determinismo bajo fakes sin OCC + anti doble-tap)"
affects:
  - "app_cliente discover (lista/detalle/home), reservas (wizard/mis reservas), pedidos legacy (solo compile-fix: carrito Map<String>, api_client ids String)"
tech-stack:
  added: []
  patterns:
    - "fromDoc(DocumentSnapshot) como factory manual en models freezed (ids String via doc.id, casts num→int/double defensivos)"
    - "Unicidad por doc ID determinista + tx.get dentro de runTransaction (nunca query→add con autoId)"
    - "Guard UX en cliente / re-validación en rules: el cliente nunca es fuente de verdad"
    - "Mutex en-proceso con fast-path zone-safe y liberación sin whenComplete (gotchas documentados)"
key-files:
  created: []
  modified:
    - app_cliente/lib/models/restaurante.dart
    - app_cliente/lib/models/restaurante_detalle.dart
    - app_cliente/lib/models/categoria.dart
    - app_cliente/lib/models/producto.dart
    - app_cliente/lib/models/reserva.dart
    - app_cliente/lib/models/reserva_create.dart
    - app_cliente/lib/app.dart
    - app_cliente/lib/core/format.dart
    - app_cliente/lib/core/api_client.dart
    - app_cliente/lib/features/restaurantes/restaurantes_provider.dart
    - app_cliente/lib/features/restaurantes/restaurante_detalle_screen.dart
    - app_cliente/lib/features/restaurantes/home_screen.dart
    - app_cliente/lib/features/reservas/reserva_controller.dart
    - app_cliente/lib/features/reservas/reservas_provider.dart
    - app_cliente/lib/features/reservas/reserva_wizard_screen.dart
    - app_cliente/lib/features/reservas/mis_reservas_screen.dart
    - app_cliente/lib/features/pedidos/carrito_controller.dart
    - app_cliente/lib/features/pedidos/menu_mesa_screen.dart
    - app_cliente/test/restaurantes/list_test.dart
    - app_cliente/test/reservas/wizard_form_test.dart
    - app_cliente/test/reservas/mis_reservas_render_test.dart
    - app_cliente/test/pedidos/carrito_test.dart
decisions:
  - "fromJson sobrevive en models SOLO para que api_client (legacy REST) compile hasta la purga 10-04 — fromDoc es la vía canónica"
  - "reservaNombre no vive en el doc: misReservasProvider hace join client-side (get por restaurante distinto del snapshot)"
  - "orderBy('orden') de categorías y filtro de capacidad de mesas son client-side: los índices compuestos no fueron definidos en 10-01 (resultado idéntico, evita failed-precondition en prod)"
  - "Mutex en-proceso para crear/cancelar reserva: el fake ejecuta runTransaction sin OCC (writes inmediatos, sin retry) — es lo que hace determinista el test de concurrencia MIGRA-06; en Firestore real es redundante pero inofensivo (OCC ya serializa) y protege del doble tap"
metrics:
  duration: "53m"
  completed: "2026-08-16"
  tests: "83 pass (74 de 10-02 sin regresión + 9 netos: 17 reservas nuevos reemplazan 8 viejos, restaurantes reescrito 4→5)"
  analyze: "0 issues"
---

# Phase 10 Plan 03: app_cliente — models fromDoc + discover + reservas tx determinista Summary

**One-liner:** Discover (lista de activos + detalle con menú agrupado) y el ciclo completo de reservas (crear con runTransaction + doc ID determinista `{mesaId}_{yyyyMMdd}_{HH}`, mis reservas como stream REALTIME, cancelar con reversión condicional de mesa) corriendo 100% sobre Firestore con models `fromDoc` ids String — concurrencia anti sobre-reserva demostrada por test `Future.wait` del mismo slot.

## What Was Built

### Task 1 — models con fromDoc + ids String end-to-end (cbe0cac)
- `fromDoc(DocumentSnapshot<Map<String, dynamic>>)` manual en restaurante (doc.id como slug, califProm double/califCount int), restaurante_detalle (con categorías inyectadas), categoria (restauranteId + productos agrupados), producto (precio **int** COP, restauranteId/categoriaId String) y reserva (fecha Timestamp→DateTime, fechaStr, hora int, usuarioId, mesaId String; restauranteNombre default '' — lo enriquece el provider).
- `reserva_create.dart` queda DTO del wizard: restauranteId String, fecha "yyyy-MM-dd", hora int, numPersonas — sin fromDoc.
- `app.dart`: `/restaurantes/:id` pasa el slug String directo (sin int.parse); wizard recibe query param String (sin tryParse).
- Ripple compile (Rule 3, ver Deviations): formatCOP(num), carrito Map<String,CarritoLine> con subtotales int, api_client con ids String (getPublicRestaurante/cancelReserva/createPedido), restauranteDetalle family int→String, screens y fixtures actualizados. fromJson sobrevive en todos los models SOLO para que api_client compile hasta 10-04.
- `flutter analyze` 0 + suite 73/73 verde tras el cambio (fixtures con mismos asserts).

### Task 2 — discover sobre Firestore (8e436ac)
- `restaurantesList`: `collection('restaurantes').where('activo', isEqualTo: true)` → fromDoc, orden estable por nombre. Sin dio/api_client.
- `restauranteDetalle(String id)`: doc + categorías + productos (3 gets), productos agrupados por categoriaId, categorías activas ordenadas por `orden`, calificación via ratingLabel ('—' si califCount == 0).
- `list_test.dart` reescrito con `buildFakeFirestoreConSeed`: restaurante **inactivo sembrado no aparece**, rating real "4.8 (245)" tras update del doc, menú agrupado en orden (assert a nivel provider + render), precio COP "$ 28.000", loading/error/Reintentar.

### Task 3 — reservas: tx determinista + stream + cancelar, TDD (79bbe37 RED → b96ea53 GREEN)
- **RED primero**: 12 tests del behavior contra stubs UnimplementedError (firmas estables), 12 fallando como se esperaba.
- **crearReserva** (port de `reserva_service.py`):
  1. Candidatas FUERA de la tx: `mesas.where('restauranteId').orderBy('numero')` (índice 10-01) + capacidad client-side.
  2. DENTRO de `runTransaction`: `tx.get(reservas/{mesaId}_{yyyyMMdd}_{HH})` por candidata en orden — la primera que NO existe es la elegida. **Jamás autoId** (la unicidad mesa+slot vive en el doc ID).
  3. `validarTransicion('mesa', ...)`: disponible→reservada aplica la máquina; ya-reservada se tolera (idempotente); ocupada/limpieza lanza.
  4. `tx.set` reserva confirmada (fecha Timestamp del slot, fechaStr, hora, createdAt serverTimestamp) + `tx.update` mesa solo si estaba disponible.
  5. Sin candidata libre → ReservaException 'No hay mesas disponibles en ese horario' / 'No hay mesas con capacidad suficiente'.
- **cancelarReserva**: guards UX (existence hiding por dueño + fecha futura; rules re-validan) → tx con `validarTransicion('reserva', actual→cancelada)` (terminal: doble cancelación lanza) y reversión de mesa SOLO si estado == 'reservada' (ocupada queda intacta — Pitfall 4).
- **misReservasProvider(uid)**: `where('usuarioId').orderBy('fecha', descending).snapshots()` (índice 10-01) con join client-side de restauranteNombre — REALTIME, sustituye refetch/polling/ws.
- **Controller**: mapea ReservaException/TransicionInvalidaException a los mismos textos UX de la era dio ('Ese horario acaba de ser reservado, elige otro', 'La reserva ya estaba cancelada'); state isLoading para deshabilitar botones.
- Screens: wizard confirma y muestra "Mesa N" asignada desde Firestore; mis_reservas cancela por Reserva (doc) y renderiza el stream; home rewired al stream + greeting FirebaseAuth.

## Verification Results

| Check | Resultado |
|---|---|
| `flutter analyze` | ✅ 0 issues |
| Suite completa | ✅ **83/83** (73 de 10-02 sin regresión + tests nuevos/reescritos) |
| fromDoc en los 5 models (sin reserva_create) | ✅ rg cuenta 5 archivos |
| app.dart sin int.parse/tryParse de ids | ✅ eliminados |
| restaurantes_provider sin dio/api_client, usa firestoreProvider | ✅ |
| crearReserva usa runTransaction + tx.get doc determinista, sin autoId | ✅ (líneas 136-139; 0 matches de `.add(`) |
| misReservasProvider es stream snapshots (sin polling/ws) | ✅ |
| CONCURRENCIA (MIGRA-06): Future.wait mismo slot → 2 docs, mesas DISTINTAS, sin dup mesa+slot | ✅ test verde |
| Slot agotado / capacidad insuficiente → error controlado sin writes | ✅ |
| Cancelar revierte mesa solo si 'reservada' (ocupada queda) | ✅ |
| Stream refleja create/cancel en orden fecha DESC sin refetch | ✅ |

## Deviations from Plan

### Desvíos Rule 3 (auto-aplicados — ripple compile de models compartidos)

**1. [Rule 3 - Blocking] Ripple de compile en pedidos legacy, api_client y format**
- **Found during:** Task 1
- **Issue:** los models son compartidos — pedidos (carrito `Map<int,...>`, `createPedido` con productoId int), `api_client` (ids int) y `formatCOP(double)` no compilaban con ids String/precio int.
- **Fix:** mínimo para compilar sin cambiar comportamiento: `formatCOP(num)`, carrito `Map<String, CarritoLine>` (subtotales int), `api_client` con String ids (dead path hasta purga 10-04), fixtures de carrito con ids String y mismos asserts.
- **Files:** core/format.dart, core/api_client.dart, features/pedidos/carrito_controller.dart, features/pedidos/menu_mesa_screen.dart, test/pedidos/carrito_test.dart
- **Commit:** cbe0cac

**2. [Rule 3 - Blocking] home_screen rewired (no estaba en files_modified)**
- **Found during:** Task 3
- **Issue:** home consumía `reservasProvider` (eliminado al pasar a stream family por uid) y campos `fecha`/`horaInicio` viejos; además seguía en el authStateProvider legacy de token_provider (greeting null — issue conocido de 10-02).
- **Fix:** watch de `misReservasProvider(uid)` (AsyncLoading sin sesión), sort por fechaStr+horaLabel, `_ProximaReservaCard` con fechaStr, greeting con `authStateProvider` nuevo (displayName).
- **Files:** lib/features/restaurantes/home_screen.dart
- **Commit:** 79bbe37

**3. [Rule 3 - Índices] Categorías ordenadas y capacidad filtradas client-side**
- **Issue:** `.where('restauranteId').orderBy('orden')` y `.where(...capacidad >= x).orderBy('numero')` requieren compuestos (categorias restauranteId+orden; mesas restauranteId+capacidad+numero) NO definidos en 10-01 — failed-precondition en producción.
- **Fix:** server-side solo lo que tiene índice (restauranteId; mesas restauranteId+orderBy numero que SÍ existe) + sort/retainWhere client-side. Resultado idéncto para N chico por restaurante. Nota en deferred-items.md por si se quiere server-side.
- **Commits:** 8e436ac, b96ea53

### Desvíos Rule 1/2 (correctness bajo fakes — MIGRA-06)

**4. [Rule 2 - Correctness] Mutex en-proceso `_seccionCritica` para mutaciones de reservas**
- **Found during:** Task 3 GREEN
- **Issue:** `FakeFirebaseFirestore.runTransaction` usa `_DummyTransaction` (verificado en fuente 4.2.0): writes inmediatos, SIN OCC ni reintentos — dos tx simultáneas del mismo slot pueden leer ambas "no existe" y pisarse. En Firestore REAL el OCC + retry hace race-safe el patrón del plan.
- **Fix:** mutex en-proceso alrededor de crear/cancelar: serializa llamadas del mismo proceso (útil real: doble tap) y da determinismo al test de concurrencia bajo fakes. Cross-device queda garantizado por OCC real.
- **Files:** lib/features/reservas/reserva_controller.dart
- **Commit:** b96ea53

**5. [Rule 1 - Bug] Dos bugs del mutex detectados por los tests y corregidos en GREEN**
- **(a) Cross-zone dead-lock:** los callbacks `.then` sobre un future YA completado corren en la zona de creación del future — el tail del mutex completado en la zona de un test anterior (muerta) colgaba al `testWidgets` siguiente (FakeAsync). Fix: fast-path con token (libre ⇒ ejecutar sin encadenar; encadenar solo con acción en vuelo, siempre misma zona).
- **(b) Unhandled error futures:** liberar el lock con `whenComplete` propaga el error al future devuelto — ignorado = unhandled async error que mataba los tests de `throwsA` y el test de slot agotado aunque el error estuviera capturado. Fix: `.then` con onError explícito.
- Ambos gotchas documentados en el código para 10-04 (pedidos reusará el patrón si necesita fakes sin OCC).

### Decisiones técnicas menores
- `restauranteNombre` NO se guarda en el doc de reserva (shape fijo del plan): `misReservasProvider` hace el join client-side con un get por restaurante distinto del snapshot.
- `Reserva.fecha` DateTime (Timestamp del doc) + `fechaStr` String para display/comparaciones — las screens usan fechaStr (comparación lexicográfica ISO preservada).
- En el test de stream se usa `container.listen` con captura de emisiones (el provider es autoDispose: sin listener vivo se dispone antes de emitir en tests planos).

## Auth Gates

Ninguno (todo contra fakes, por diseño del plan).

## Notes for Continuation (10-04)

- `api_client` YA no es usado por restaurantes/reservas (solo pedidos/sesión/pagos legacy + fromJson de models) — la purga 10-04 puede borrarlo junto a token_provider/auth_storage/env/ws_client.
- `restaurantes_provider` ya no lee `apiClientProvider`; carrito_test sigue overridendo `restauranteDetalleProvider('1')` directo (válido).
- El patrón mutex `_seccionCritica` está en reserva_controller.dart; si pedidos necesita tx con fakes, moverlo a core/ en 10-04.
- Índices faltantes anotados en deferred-items.md (categorias restauranteId+orden, mesas restauranteId+capacidad+numero) — hoy innecesarios (sort client-side).

## Self-Check: PASSED

- Archivos clave en disco: reserva_controller.dart ✅ / reservas_provider.dart ✅ / restaurantes_provider.dart ✅ / models fromDoc (5) ✅ / tests reescritos (3) ✅
- Commits verificados en git log: cbe0cac ✅ / 8e436ac ✅ / 79bbe37 ✅ / b96ea53 ✅
- flutter analyze 0 issues + flutter test 83/83 ✅ (última corrida post-último-commit de código)
