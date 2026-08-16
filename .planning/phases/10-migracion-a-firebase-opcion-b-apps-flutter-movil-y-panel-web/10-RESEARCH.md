# Phase 10: Migración a Firebase (Opción B) — Research

**Researched:** 2026-08-16
**Domain:** Flutter apps (móvil + web) hablando directo a Firebase Auth + Firestore con Security Rules; backend FastAPI archivado como referencia
**Confidence:** HIGH (versiones verificadas contra pub.dev/npm el 2026-08-16; patrones verificados contra docs oficiales de Firebase)

## Summary

La fase reemplaza toda la capa de datos de las dos apps Flutter: `dio` + `ws_client` + `token_provider` + `auth_storage` + `env.dart` desaparecen, y su lugar toma `firebase_core`/`firebase_auth`/`cloud_firestore` con `firebase_options.dart` generado por `flutterfire_cli`. Las ~25 pantallas (51 tests cliente + 61 tests panel) se conservan; lo que se reescribe son los providers/controllers y los `models/` (convierten `DocumentSnapshot` en vez de JSON HTTP). El backend FastAPI (215 tests) NO se borra: queda archivado como referencia de lógica de dominio; sus state machines (`state_machines.py`) se portan 1:1 a `core/state_machines.dart`.

El corazón de la fase son **tres piezas de diseño**: (1) el modelo de datos Firestore plano con `restauranteId` en cada doc e IDs de documento deterministas (`mesas/{codigoQR}`, `sesiones/{mesaId}`, `reservas/{mesaId}_{fecha}_{hora}`, `calificaciones/{pedidoId}`) que restauran en el cliente las garantías que antes daban MySQL (`UNIQUE`, `FOR UPDATE`); (2) las **Security Rules** que reemplazan a `TenantScope` + `require_roles` — los roles viajan en custom claims `{role, rid}` seteados por el seed con Admin SDK y se leen en rules vía `request.auth.token` sin costo de `get()`; (3) las **transacciones** (`runTransaction`) para reserva (anti sobre-reserva), apertura de sesión (una activa por mesa) y creación de pedido (sesión válida).

Límite estructural documentado: **sin backend no hay validación server-side del total del pedido**. Las rules no pueden iterar arrays ni hacer aritmética sobre ellos, y el límite de 10/20 access-calls hace inválido validar cada precio con `get()`. La mitigación v1: snapshot de nombre+precio embebido en cada item al crear (leído del doc de producto), rules que validan estructura (items no vacío, cantidad/total numéricos >= 0, restauranteId consistente con la mesa) y totales de confianza solo para display/reportes. La validación fuerte de montos llega con Cloud Functions en la fase de pagos.

**Primary recommendation:** Big-bang por app (app_cliente primero contra emuladores + seed, luego panel_admin), colecciones planas con `restauranteId`, autorización 100% por custom claims en rules, y transacciones con IDs deterministas donde había constraints únicos en MySQL.

<user_constraints>

## User Constraints

> Fuente: decisión del usuario registrada en STATE.md + brief de la fase. No existe CONTEXT.md en este directorio (`has_context: false`); estas decisiones vienen del brief de planning y son LOCKED.

### Locked Decisions
- **Opción B:** las apps Flutter hablan DIRECTO a Firebase (Auth + Firestore + listeners), sin backend propio. El backend FastAPI NO se borra: se archiva como referencia (carpeta `backend/` queda; compose/nginx dejan de ser necesarios para las apps).
- **Pagos DIFERIDOS:** en esta fase "solicitar la cuenta" (aviso al mesero) funciona; el pago en línea real es fase futura (Cloud Functions). Los métodos `crearIntencionPago`/`getPagoEstado` y la pantalla de checkout quedan fuera.
- **Proyecto Firebase:** `p-gri-b5b40`; apps registradas: Android `gri.app` (google-services.json ya en `documentos/`) + Web `grip.web` (firebase-config-web.js, registrada 2026-08-16 — el pendiente de STATE.md quedó resuelto).
- **Stack UI conservado:** Flutter 3.47 / Riverpod 3.x / go_router / freezed — las screens se conservan; se reemplaza la capa de datos.

### Claude's Discretion
- Diseño exacto de colecciones, IDs de documento y reglas de seguridad (este research propone el diseño; el planner lo refina).
- Elección de script de seed (Node `firebase-admin` recomendado — mismo lenguaje que las rules tests opcionales).
- Estrategia de tests (fakes pub.dev verificados + port 1:1 de tests de state machines).
- Estrategia de migración: **big-bang por app** recomendado (auth es transversal; migrar feature-por-feature obligaría a mantener dos capas de auth vivas).

### Deferred Ideas (OUT OF SCOPE)
- Pago en línea real (Wompi u otra pasarela) → fase futura con Cloud Functions.
- Cloud Functions de cualquier tipo (validación de totales, agregaciones server-side, webhooks).
- Migración de datos MySQL→Firestore (el contenido demo se re-siembra desde cero).
- Redis, nginx, Docker para las apps (el hosting del panel web se decide después).
</user_constraints>

## Standard Stack

### Core — Flutter Firebase (verificado pub.dev 2026-08-16)

| Library | Version | Purpose | Why Standard / Notes |
|---------|---------|---------|----------------------|
| **firebase_core** | 4.13.0 (2026-08-03) | Bootstrap + `Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform)` | Requerido por todo lo demás. Compatible Dart ^3.x (repo usa 3.13). |
| **firebase_auth** | 6.5.7 (2026-08-03) | Auth email/password, `authStateChanges`, custom claims en idToken | Reemplaza login/registro/refresh/me + `auth_storage` + `token_provider`. `useAuthEmulator('127.0.0.1', 9099, automaticHostMapping: true)` verificado en 6.5.7. |
| **cloud_firestore** | 6.8.0 (2026-08-03) | CRUD, `runTransaction`, `onSnapshot`, agregaciones | Reemplaza dio+ws_client+polling. `useFirestoreEmulator('127.0.0.1', 8080)` verificado en 6.8.0 (mapea solo a 10.0.2.2 en Android). |

### Supporting — Dev/Testing (verificado pub.dev 2026-08-16)

| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| **fake_cloud_firestore** | 4.2.0 (2026-07-17) | Fake in-memory de Firestore para tests | Deps: `cloud_firestore ^6.7.1` ✓ compatible con 6.8.0. Soporta `runTransaction` y snapshots. Incluye `fake_firebase_security_rules` (evaluación básica de rules en Dart). |
| **firebase_auth_mocks** | 0.15.2 (2026-05-16) | Fake de FirebaseAuth | Deps: `firebase_auth ^6.0.0` + `firebase_core ^4.0.0` ✓. `MockFirebaseAuth` con `signInWithEmailAndPassword` fake. |

### Tooling (verificado npm 2026-08-16)

| Tool | Version | Purpose |
|------|---------|---------|
| **flutterfire_cli** | 1.4.1 | `flutterfire configure` → genera `lib/firebase_options.dart` por plataforma. Dart ^3.6.0 ✓. |
| **firebase-tools** | 15.27.0 | `firebase emulators:start`, `firebase deploy --only firestore:rules,firestore:indexes`. |
| **firebase-admin** (npm, solo scripts/) | 14.2.0 | Seed + custom claims desde script Node local. |

### Se mantiene del stack LOCKED (sin cambios)
flutter_riverpod 3.x + riverpod_annotation/generator, go_router 17.x, freezed 4.0.0-dev.3 + json_serializable (mismo pin de pubspec), intl, mobile_scanner (QR), qr_flutter (panel), data_table_2 (panel), flutter_secure_storage (**se elimina** — la sesión la persiste Firebase Auth), dio/web_socket_channel/flutter_dotenv (**se eliminan**).

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Colecciones planas + `restauranteId` | Subcolecciones `restaurantes/{id}/pedidos` | Subcolecciones obligan a conocer el restaurante antes de query (bien) pero complican "mis reservas/pedidos" del cliente cross-restaurante y los índices por query-type. **Default: plano** (matches queries reales: pedidos por restaurante+estado, reservas por usuario, etc.). |
| Custom claims para roles | Doc `usuarios/{uid}` leído con `get()` en cada regla | Cada `get()` cuesta 1 access-call y 1 read facturado; claims van gratis en el token. **Default: claims** + doc espejo para perfil/listados. |
| `firebase_auth_mocks`/`fake_cloud_firestore` | Emuladores en tests de widget | Emuladores requieren proceso externo + no funcionan en `flutter test` (entorno de test no soporta platform channels a red). **Default: fakes** en `flutter test`; emuladores para UAT manual. |
| Script seed Node (mjs) | Python firebase-admin | Ambos válidos; Node comparte `firebase.json`/rules tooling. **Default: Node mjs.** |

**Installation (por app, desde `app_cliente/` y `panel_admin/`):**
```bash
flutter pub add firebase_core firebase_auth cloud_firestore
flutter pub add --dev fake_cloud_firestore firebase_auth_mocks
# pubspec: ELIMINAR dio, web_socket_channel, flutter_dotenv, flutter_secure_storage, url_launcher*
# (*url_launcher solo en app_cliente — pagos diferidos; mantener si se reusa para otros links)

# Config por app (una vez; ya existen apps registradas en el proyecto):
dart pub global activate flutterfire_cli
flutterfire configure   # seleccionar p-gri-b5b40 + platforms android,web (cliente) / web (panel)
# → genera lib/firebase_options.dart; en Android sincroniza android/app/google-services.json existente
```

**Version verification:** Todas las versiones de la tabla fueron consultadas en el registry pub.dev/npm el 2026-08-16 (ver Sources). Las tres libs core publicaron juntas el 2026-08-03 (release train de FlutterFire).

## Architecture Patterns

### Arquitectura objetivo

```
app_cliente (Android+web dev)          panel_admin (web)
  ├─ FirebaseAuth ──── login/registro │  ├─ FirebaseAuth ──── login staff
  ├─ Firestore reads ── menú, mesas   │  ├─ onSnapshot ────── mapa mesas, cola cocina,
  ├─ onSnapshot ─────── pedido propio │  │                     reservas del día, cuenta aviso
  ├─ runTransaction ─── reserva/      │  ├─ CRUD ──────────── mesas/menú (rules: admin+super)
  │                     sesión/pedido │  └─ agregaciones ──── reportes (count/sum)
  └─ (pagos DEFERRED)                 │
            │                                        │
            └──────────► Firebase p-gri-b5b40 ◄──────┘
                        ├─ Auth (email/password + claims {role, rid})
                        ├─ Firestore + firestore.rules (TODO el authz)
                        └─ (futuro: Functions para pagos)

scripts/seed_firebase.mjs ── Admin SDK ──► crea restaurante demo, usuarios+claims, mesas, menú
firebase.json + firestore.rules + firestore.indexes.json (raíz del repo)
backend/ ── ARCHIVADO (referencia de lógica; nada de las apps lo importa)
```

### Modelo de datos Firestore (diseño propuesto — colecciones planas)

**Convenciones:** `restauranteId` es el doc ID del restaurante (slug corto, ej. `demo`). Estados como strings idénticos a los enums de Python (`disponible`, `reservada`, `ocupada`, `limpieza`; `enviado`→`pagado`; `activa`/`cerrada`/`expirada`; `confirmada`/`cancelada`). Precios en **int COP** (sin Decimal — MySQL usaba Decimal por floats; int de centavos/pesos COP exacto evita el problema). Fechas de negocio como `Timestamp` (comparables en rules vs `request.time`).

```
restaurantes/{slug}
  nombre, descripcion, tipoCocina, direccion, activo: bool,
  califProm: double, califCount: int        ← mantenidos en tx al calificar
  createdAt: Timestamp

mesas/{codigoQR}                             ← doc ID = código QR ("GRI-MESA-demo-001")
  restauranteId, numero: int, capacidad: int,
  estado: "disponible|reservada|ocupada|limpieza", updatedAt: Timestamp
  // QR→mesa es un get() directo por doc ID (O(1)); UNIQUE QR garantizado por construcción

categorias/{autoId}: restauranteId, nombre, orden, activo
productos/{autoId}:  restauranteId, categoriaId, nombre, descripcion, precio: int,
                    imagenUrl?, disponible: bool, activo: bool

usuarios/{uid}                               ← doc ID = Auth uid
  nombre, email, role: "super_admin|admin_restaurante|mesero|cocina|cliente",
  restauranteId: string|null, createdAt
  // ESPEJO de los claims — la autorización SIEMPRE usa claims, nunca este doc

sesiones/{mesaId}                            ← doc ID = doc ID de la mesa (UNA sesión por mesa)
  restauranteId, mesaId, usuarioId (dueño cliente), estado: "activa|cerrada|expirada",
  cuentaSolicitada: bool, cuentaPedidaAt?: Timestamp, inicioAt, cerradaAt?
  // doc ID determinista = la garantía "una sesión activa por mesa" (antes UNIQUE en MySQL).
  // Trade-off v1: se pierde historial de sesiones (los pedidos conservan el suyo).

pedidos/{autoId}
  restauranteId, mesaId, sesionId (=mesaId), usuarioId, clienteNombre,  ← denormalizado p/ panel
  estado: "enviado|aceptado|en_preparacion|servido|rechazado|pagado",
  items: [ {productoId, nombre, precio: int, cantidad: int} ],          ← SNAPSHOT embebido
  total: int, createdAt, updatedAt

reservas/{mesaId}_{yyyyMMdd}_{HH}            ← doc ID determinista = 1 reserva por mesa+slot
  restauranteId, mesaId, mesaNumero, usuarioId, fecha: Timestamp (inicio del slot),
  fechaStr: "2026-08-20", hora: int, numPersonas: int, estado: "confirmada|cancelada", createdAt
  // El doc ID determinista restaura el UNIQUE(mesa,fecha,slot) de MySQL sin backend

calificaciones/{pedidoId}                    ← doc ID = pedido → 1:1 garantizado
  restauranteId, usuarioId, pedidoId, estrellas: int (1..5), comentario: string, createdAt
```

**Why:** cada UNIQUE/lock de MySQL se mapea a un mecanismo Firestore: `UNIQUE mesa/slot` → doc ID determinista; `FOR UPDATE` → `runTransaction` sobre docs deterministas; `UNIQUE sesión activa` → doc `sesiones/{mesaId}` único. Las queries del dominio (cola cocina, mapa mesas, reservas del día, mis reservas) son todas `where restauranteId == X [+ filtro estado] orderBy ...` → índices compuestos simples.

### Auth y roles: custom claims

- **Claims:** `{ role: "...", rid: "demo" | null }` — los setea el seed script con Admin SDK (`setCustomUserClaims`). No hay backend: claims solo cambian corriendo el script de nuevo (documentado como operación de setup).
- **Cliente auto-registrado:** NO tiene claims → rules tratan ausencia de `role` como `cliente` (helper `isCliente()`). Registro escribe `usuarios/{uid}` con `role: 'cliente'` (rules lo fuerzan; no puede auto-asignarse staff).
- **Propagación:** claims entran al idToken en el próximo refresh. Como el seed corre ANTES del primer login del usuario, un login nuevo ya trae los claims — solo importa refrescar token si se cambian claims de un usuario logueado (`user.getIdToken(true)`).
- **Sesión persistente:** `authStateChanges()` + persistencia nativa del SDK (Android: local; Web: indexedDB). Reemplaza `auth_storage`/`token_provider`/interceptor de dio completo.
- **Perfil:** update de nombre = update `usuarios/{uid}`; cambio de password = `user.updatePassword(newPassword)` (requiere re-login reciente — `reauthenticateWithCredential`).

### Patrones de transacción (reemplazo de FOR UPDATE)

**Regla general:** la transacción debe leer y escribir SOLO docs deterministas (misma key para contendientes) — Firestore serializa transacciones que leen el mismo doc (retry automático del perdedor). Queries dentro de transacción NO bloquean docs futuros → nunca usar "query luego create con autoId" para unicidad.

**1. Reserva (anti sobre-reserva — port de reserva_service.py):**
```dart
// Source: patrón portado de backend/app/services/reserva_service.py + docs transactions
Future<void> crearReserva(FirebaseFirestore db, String uid, String rid,
    DateTime slot, int personas) async {
  await db.runTransaction((tx) async {
    // Candidatas: where restauranteId == rid, capacidad >= personas (leídas con get() por doc:
    // el mapa de mesas ya está en caché del panel/app tras el onSnapshot)
    final mesas = await db
        .collection('mesas').where('restauranteId', isEqualTo: rid)
        .where('capacidad', isGreaterThanOrEqualTo: personas)
        .orderBy('numero').get(); // lectura FUERA de la tx (no necesita lock)
    DocumentSnapshot? elegida;
    for (final m in mesas.docs) {
      final sid = '${m.id}_${fmt(slot)}'; // {mesaId}_{yyyyMMdd}_{HH}
      final exists = await tx.get(db.collection('reservas').doc(sid)); // DENTRO de la tx
      if (!exists.exists) { elegida = m; break; }
    }
    if (elegida == null) throw Exception('No hay mesas disponibles en ese horario');
    final mesa = elegida!;
    validarTransicion('mesa', mesa['estado'], 'reservada'); // state_machines.dart (idempotente si ya reservada)
    final sid = '${mesa.id}_${fmt(slot)}';
    tx.set(db.collection('reservas').doc(sid), {
      'restauranteId': rid, 'mesaId': mesa.id, 'mesaNumero': mesa['numero'],
      'usuarioId': uid, 'fecha': Timestamp.fromDate(slot), 'fechaStr': fmtFecha(slot),
      'hora': slot.hour, 'numPersonas': personas, 'estado': 'confirmada',
      'createdAt': FieldValue.serverTimestamp(),
    });
    if (mesa['estado'] == 'disponible') {
      tx.update(mesa.reference, {'estado': 'reservada', 'updatedAt': FieldValue.serverTimestamp()});
    }
  });
}
```

**2. Abrir sesión (sentarse en la mesa — una activa por mesa):** `runTransaction`: `tx.get(sesiones/{mesaId})` → debe no existir o `estado != 'activa'`; `tx.get(mesas/{codigo})` → `restauranteId` válido y `estado in ['disponible','reservada']` (transición→ocupada); `tx.set(sesiones/{mesaId}, {...estado: 'activa', usuarioId: uid})` + `tx.update(mesa, estado: 'ocupada')`. Dos clientes concurrentes leen el MISMO doc → uno reintenta y ve la sesión activa → error controlado.

**3. Crear pedido (sesión válida de ESA mesa):** `runTransaction`: `tx.get(sesiones/{mesaId})` → `estado == 'activa'` (y `usuarioId == uid` — paridad anti-spoofing de Phase 6); armar `items` con snapshot `nombre`/`precio` leídos del doc de producto ANTES de la tx (o dentro con get — máx ~10 por límite de access-calls); `tx.set(pedidos.doc(), {estado: 'enviado', ...})`.

**4. Cerrar sesión + liberar mesa (mesero/admin):** `runTransaction` batch: `sesion.estado → cerrada` + validarTransicion mesa `ocupada → limpieza`. "Solicitar la cuenta" = simple `update(sesiones/{mesaId}, {cuentaSolicitada: true, cuentaPedidaAt: serverTimestamp})` por el dueño.

**5. Calificar + agregado:** `runTransaction`: `tx.get(pedidos/{id})` (dueño, `estado == 'servido'`); `tx.get(sesiones/{mesaId})` (`estado == 'cerrada'` — decisión: con pagos diferidos se califica al cerrarse la sesión); `tx.set(calificaciones/{pedidoId}, {...})` + `tx.update(restaurantes/{rid}, {califProm: recomputado, califCount: +1})` leído en la misma tx (atómico).

### Realtime: onSnapshot → Riverpod StreamProvider

Reemplazo directo de ws_client + kick-to-refetch + polling. Los providers actuales (ej. `pedidosSession`) colapsan de ~80 líneas a un StreamProvider de query:

```dart
// Source: patrón docs "Get real-time updates" + reemplazo de pedidosSession (Phase 7)
@riverpod
Stream<List<Pedido>> pedidosSession(Ref ref) {
  final sesion = ref.watch(sesionProvider).value;
  if (sesion == null) return const Stream.empty();
  return FirebaseFirestore.instance
      .collection('pedidos')
      .where('sesionId', isEqualTo: sesion.mesaId)
      .orderBy('createdAt', QueryDirection.descending)
      .snapshots()
      .map((s) => s.docs.map(Pedido.fromDoc).toList());
}
```

| Pantalla (existente) | Query onSnapshot que la alimenta | Reemplaza a |
|---|---|---|
| Cliente: estado de pedido | `pedidos where sesionId == X orderBy createdAt` | WS pedido.creado/estado + polling 10s |
| Cliente: banner sesión | `sesiones/{mesaId}` (doc snapshot) | WS sesion.abierta/cerrada |
| Panel: mapa de mesas | `mesas where restauranteId == rid` | WS mesa.estado + polling |
| Panel: cola cocina | `pedidos where restauranteId == rid where estado in [enviado,aceptado,en_preparacion] orderBy createdAt` | WS pedido.* + polling |
| Panel: dashboard stats | derivado de los 3 streams anteriores (mesas/reservas/pedidos) | GET /staff/stats |
| Panel: reservas del día | `reservas where restauranteId == rid where fecha >= inicioHoy < inicioMañana` | GET /staff/reservas |
| Panel: aviso cuenta | `sesiones where restauranteId == rid where cuentaSolicitada == true where estado == activa` | WS cuenta:solicitada |

La resincronización post-desconexión es NATIVA (el SDK re-entrega el snapshot al reconectar) — todo el código de backoff/jitter/dedup-seq/resync de `ws_client.dart` se elimina.

### Security Rules — esqueleto completo (el corazón de la fase)

```javascript
// firestore.rules — reemplaza TenantScope + require_roles
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {

    // ---- Helpers (claims; cero access-calls) ----
    function signedIn()    { return request.auth != null; }
    function role()        { return request.auth.token.role; }
    function rid()         { return request.auth.token.rid; }
    function isSuper()     { return signedIn() && role() == 'super_admin'; }
    function isCliente()   { return signedIn() && (!('role' in request.auth.token) || role() == 'cliente'); }
    function staffOf(r)    { return signedIn() && r == rid()
                             && role() in ['admin_restaurante','mesero','cocina']; }
    function menuStaffOf(r){ return signedIn() && (isSuper() || (r == rid() && role() == 'admin_restaurante')); }
    function cocinaStaffOf(r){ return signedIn() && (isSuper() || (r == rid()
                             && role() in ['admin_restaurante','cocina','mesero'])); }
    function soloEstado()  { return request.resource.data.diff(resource.data).affectedKeys()
                             .hasOnly(['estado','updatedAt']); }
    function transMesa(a, b)  { return (a=='disponible' && b in ['reservada','ocupada'])
                             || (a=='reservada'  && b in ['ocupada','disponible'])
                             || (a=='ocupada'    && b=='limpieza')
                             || (a=='limpieza'   && b=='disponible'); }

    // ---- Descubrimiento (público) ----
    match /restaurantes/{rid} {
      allow read:   if true;                       // lista pública (query filtra activo==true)
      allow create, delete: if isSuper();
      allow update: if isSuper()
                    || (staffOf(rid) && request.resource.data.diff(resource.data)
                        .affectedKeys().hasOnly(['califProm','califCount'])); // agregado al calificar
    }

    // ---- Menú (público leer; admin+super escribir) ----
    match /categorias/{id} {
      allow read:  if resource.data.activo == true || menuStaffOf(resource.data.restauranteId);
      allow write: if menuStaffOf(resource.data.restauranteId); // create: valida restauranteId==rid() en request
    }
    match /productos/{id} {
      allow read:  if (resource.data.activo == true && resource.data.disponible == true)
                    || menuStaffOf(resource.data.restauranteId);
      allow write: if menuStaffOf(resource.data.restauranteId);
    }

    // ---- Mesas (staff lee; cliente lee la suya tras QR — leer mesa no es sensible) ----
    match /mesas/{codigo} {
      allow read: if signedIn();
      allow create, delete: if menuStaffOf(request.resource.data.restauranteId);
      allow update: if menuStaffOf(resource.data.restauranteId);      // CRUD completo (capacidad, numero)
                    // cambio de estado (mapa/mesero): transición válida, solo 'estado'
      allow update: if (staffOf(resource.data.restauranteId) && soloEstado()
                    && transMesa(resource.data.estado, request.resource.data.estado));
      // NOTA: dos bloques allow update = OR (permitido en rules).
    }

    // ---- Usuarios (perfil; espejo de claims — NUNCA fuente de authz) ----
    match /usuarios/{uid} {
      allow read:   if signedIn() && (request.auth.uid == uid || isSuper());
      allow create: if signedIn() && request.auth.uid == uid
                    && request.resource.data.role == 'cliente'
                    && request.resource.data.restauranteId == null;   // auto-registro SOLO cliente
      allow update: if request.auth.uid == uid
                    && request.resource.data.diff(resource.data).affectedKeys()
                       .hasOnly(['nombre']);                          // role/restauranteId INMUTABLES
      allow delete: if false;
    }

    // ---- Sesiones de mesa ----
    match /sesiones/{mesaId} {
      allow read:   if signedIn() && (resource.data.usuarioId == request.auth.uid
                    || staffOf(resource.data.restauranteId));
      allow create: if isCliente()
                    && request.resource.data.estado == 'activa'
                    && request.resource.data.usuarioId == request.auth.uid
                    && request.resource.data.cuentaSolicitada == false
                    && get(/databases/$(database)/documents/mesas/$(mesaId)).data.estado
                       in ['disponible','reservada'];                  // 1 access-call
      allow update: if (resource.data.usuarioId == request.auth.uid                   // dueño pide cuenta
                    && request.resource.data.diff(resource.data).affectedKeys()
                       .hasOnly(['cuentaSolicitada','cuentaPedidaAt'])
                    && request.resource.data.cuentaSolicitada == true)
                    || (staffOf(resource.data.restauranteId) && soloEstado()          // staff cierra
                    && resource.data.estado == 'activa'
                    && request.resource.data.estado in ['cerrada','expirada']);
    }

    // ---- Pedidos ----
    match /pedidos/{id} {
      allow read:   if signedIn() && (resource.data.usuarioId == request.auth.uid
                    || staffOf(resource.data.restauranteId) || isSuper());
      allow create: if isCliente()
                    && request.resource.data.estado == 'enviado'
                    && request.resource.data.usuarioId == request.auth.uid
                    && request.resource.data.usuarioId ==
                       get(/databases/$(database)/documents/sesiones/$(request.resource.data.sesionId)).data.usuarioId
                    && get(/databases/$(database)/documents/sesiones/$(request.resource.data.sesionId)).data.estado == 'activa'
                    && get(/databases/$(database)/documents/mesas/$(request.resource.data.mesaId)).data.restauranteId
                       == request.resource.data.restauranteId                          // 3 access-calls < 10 ✓
                    && request.resource.data.items is list
                    && request.resource.data.items.size() >= 1
                    && request.resource.data.items.size() <= 50
                    && request.resource.data.total >= 0;
      allow update: if cocinaStaffOf(resource.data.restauranteId) && soloEstado()
                    // matriz simplificada rol×transición (port de la matriz Phase 6):
                    && (
                      (resource.data.estado == 'enviado'
                        && request.resource.data.estado in ['aceptado','rechazado']
                        && (role() in ['admin_restaurante','cocina'] || isSuper()))
                      || (resource.data.estado == 'aceptado'
                        && request.resource.data.estado == 'en_preparacion'
                        && (role() in ['admin_restaurante','cocina'] || isSuper()))
                      || (resource.data.estado == 'en_preparacion'
                        && request.resource.data.estado == 'servido') // cocina/admin/mesero
                      // 'pagado' INALCANZABLE en v1 (llega con Functions/pagos)
                    );
      allow delete: if false;
    }

    // ---- Reservas ----
    match /reservas/{rid_} {
      allow read:   if signedIn() && (resource.data.usuarioId == request.auth.uid
                    || staffOf(resource.data.restauranteId) || isSuper());
      allow create: if isCliente()
                    && request.resource.data.usuarioId == request.auth.uid
                    && request.resource.data.estado == 'confirmada'
                    && request.resource.data.fecha > request.time      // slot futuro (Timestamp)
                    && request.resource.data.numPersonas >= 1
                    && request.resource.data.numPersonas <= 20
                    && get(/databases/$(database)/documents/mesas/$(request.resource.data.mesaId)).data.restauranteId
                       == request.resource.data.restauranteId;         // 1 access-call
      allow update: if soloEstado() && request.resource.data.estado == 'cancelada'
                    && ( (resource.data.usuarioId == request.auth.uid
                          && resource.data.fecha > request.time)       // dueño cancela futura
                      || staffOf(resource.data.restauranteId) );       // staff no-show
      allow delete: if false;
    }

    // ---- Calificaciones (doc ID = pedidoId → 1:1) ----
    match /calificaciones/{pedidoId} {
      allow read:   if true;                                          // visible en discover
      allow create: if isCliente()
                    && get(/databases/$(database)/documents/pedidos/$(pedidoId)).data.usuarioId
                       == request.auth.uid
                    && get(/databases/$(database)/documents/pedidos/$(pedidoId)).data.estado == 'servido'
                    && get(/databases/$(database)/documents/sesiones/
                        $(get(/databases/$(database)/documents/pedidos/$(pedidoId)).data.sesionId)).data.estado
                       == 'cerrada'                                   // 3 access-calls (get anidado cuenta 1) ✓
                    && request.resource.data.estrellas is int
                    && request.resource.data.estrellas >= 1
                    && request.resource.data.estrellas <= 5
                    && request.resource.data.usuarioId == request.auth.uid;
      allow update, delete: if false;
    }
  }
}
```

**Límites verificados que shaping este diseño** (docs oficiales, ver Sources): máximo **10 access-calls** (`get()`/`exists()`) por request de documento único y **20** por multi-doc/tx/batch (las llamadas cacheadas no cuentan); functions de rules: **sin loops**, una sola sentencia `return`, máx **10** `let`, stack depth 10. Por eso: precios por-item NO se validan con `get()` (imposible iterar + agotaría el budget) — se documenta como gap estructural.

### Patrón: port de state machines

`backend/app/core/state_machines.py` → `core/state_machines.dart` (por app o package compartido `packages/gri_domain`): mismos dicts `Map<String, Set<String>>` + `validarTransicion(String maquina, String actual, String nueva)` lanzando `TransicionInvalidaException`. Se usa en las transacciones del cliente (reserva, sesión, mesa) y en los botones del panel (solo transiciones válidas). Tests portados 1:1 desde `backend/tests` de state machines (son tests puros, corren en ms).

### Estructura final por app

```
app_cliente/lib/                      panel_admin/lib/
├── main.dart           (MOD: bootstrap Firebase + emulator flag)
├── firebase_options.dart              (NEW — generado flutterfire configure)
├── core/
│   ├── firebase_bootstrap.dart        (NEW: init + useAuth/FirestoreEmulator si --dart-define=USE_EMULATORS)
│   ├── firebase_providers.dart        (NEW: Provider<FirebaseAuth/FirebaseFirestore> — override point tests)
│   ├── state_machines.dart            (NEW: port Python)
│   ├── theme.dart / format.dart       (KEEP)
│   ├── api_client.dart                (DELETE)
│   ├── auth_storage.dart              (DELETE — Auth persiste solo)
│   ├── token_provider.dart(.g)        (DELETE → auth_provider stream)
│   ├── ws_client.dart                 (DELETE — onSnapshot nativo)
│   └── env.dart                       (DELETE — assets/.env fuera)
├── models/              (MOD: añadir fromDoc/toFirestore; DELETE token_pair; pago.dart DELETE)
└── features/            (MOD: controllers/providers → Firestore; screens casi intactas)
    └── cliente: pagos/pago_screen.dart+controller (DELETE — diferido; calificacion_sheet KEEP)
```

### Anti-Patterns to Avoid
- **Rules que leen `usuarios/{uid}` con get() para autorizar** — 1 read facturado por request, budget de 10, y desync claim/doc. Authz SIEMPRE por claims.
- **Unicidad vía "query + create con autoId"** — dos txns concurrentes pasan ambas la query (no bloquean docs futuros). SIEMPRE doc ID determinista.
- **Floats para COP** — int de pesos COP en todas partes (snapshot, total, precio).
- **Dejar el backend "medio vivo"** — si `backend/` queda, ninguna app lo importa; el compose dev ya no es prerequisito de las apps (dejar de referenciarlo en docs/run).
- **Confundir `set()` sobre doc existente con create** — en rules es un `update` (pasa por la rama update, no create). El "re-abrir" sesión se bloquea ex profeso.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Reconexión/resync tiempo real | Backoff+jitter+dedup-seq+resync (el ws_client.dart actual, ~200 líneas) | `snapshots()` del SDK | Reconexión, resync y entrega-1-vez son nativos del SDK. Phase 7 completa se elimina. |
| Persistencia de sesión | auth_storage + flutter_secure_storage | Persistencia nativa FirebaseAuth (local/indexedDB) | El SDK la maneja; refresh de token también. |
| Refresh token / interceptor 401 | token_provider + interceptor dio | `getIdToken()` automático del SDK | El SDK refresca solo. |
| Validación de unicidad | App-level check + pray | Doc IDs deterministas + rules | Ver patrón transacciones. |
| QR de mesa | Endpoint /m/{codigo} | `mesas/{codigoQR}` get directo | Doc ID = código; O(1), sin índice. |
| Hash de passwords | (ya no aplica) | FirebaseAuth | N/A (Admin SDK crea usuarios con password en seed). |
| Generación firebase_options | Copiar a mano configs de documentos/ | `flutterfire configure` | Genera y mantiene android+web por app; sincroniza google-services.json. |

**Key insight:** todo lo que en Phases 2-9 fue infraestructura propia (JWT, refresh, WS, tenant scoping, locks) lo provee la plataforma; el trabajo real se traslada a **diseño de docs + rules + transacciones**.

## Common Pitfalls

### Pitfall 1: Emuladores — datos volátiles y caché local
**What goes wrong:** el emulador de Firestore borra TODO al apagar; y la caché offline del SDK persiste → la app muestra datos fantasma de una sesión anterior del emulador.
**Why:** comportamiento documentado del emulador; en web la persistencia está off por defecto, en Android no.
**How to avoid:** arrancar emuladores con `--import=./emulator_data --export-on-exit=./emulator_data` (estado reproducible entre corridas) y en dev con emuladores deshabilitar persistencia local (`PersistenceSettings(enabled: false)`) o aceptar el flush manual. Seed script apuntando a emuladores vía `FIREBASE_AUTH_EMULATOR_HOST`/`FIRESTORE_EMULATOR_HOST`.
**Warning signs:** datos que "vuelven" tras reiniciar emulador; writes que no se ven.

### Pitfall 2: `useEmulator` debe llamarse ANTES de cualquier uso de la instancia
**What goes wrong:** `lateinit`/provider ya resolvió `FirebaseFirestore.instance` antes del `useFirestoreEmulator` → la app pega al proyecto real.
**How to avoid:** bootstrap secuencial en `main()`: `initApp → useAuthEmulator → useFirestoreEmulator → runApp`. Gate con `--dart-define=USE_EMULATORS=true` (o `demoProjectId` si se prefiere config de demo documentada). En Android el mapeo `localhost→10.0.2.2` es automático (verificado en fuente 6.8.0) — dispositivo físico necesita IP LAN manual.
**Warning signs:** "permission-denied" raro en dev = estás tocando el proyecto real con rules nuevas.

### Pitfall 3: `FieldValue.serverTimestamp()` dentro de transacciones
**What goes wrong:** al leer el doc DENTRO de la tx, `createdAt` aún es null (se resuelve al commit) — ordenar/filtrar por él dentro de la tx falla.
**How to avoid:** no tomar decisiones dentro de la tx basadas en serverTimestamp; para el doc ID de reserva usar la fecha del SLOT (dato del cliente), nunca serverTimestamp.

### Pitfall 4: Rules se evalúan por-doc en QUERIES (no por request)
**What goes wrong:** un listener de query que matchea aunque sea 1 doc sin permiso → permission-denied de TODA la query.
**How to avoid:** TODA query staff SIEMPRE con `where('restauranteId', isEqualTo: rid)` y todo doc lleva `restauranteId`. Igual que TenantScope pero declarativo.
**Warning signs:** "The query requires an index" o permission-denied en streams del panel.

### Pitfall 5: Límite 10/20 access-calls en rules
**What:** cada `get()`/`exists()` cuenta (10 por doc-request, 20 por multi-doc/tx/batch); exceder = permission-denied SIN mensaje claro. Las de calificaciones (3) y pedidos (3) ya están contadas.
**How to avoid:** nunca agregar más gets "por seguridad"; mover validaciones a estructura del doc (campos denormalizados como `clienteNombre`).

### Pitfall 6: Claims desactualizados
**What:** cambiar claims del seed NO expulsa sesiones ni refresca tokens ya emitidos (entra en el próximo refresh — hasta 1h).
**How to avoid:** seed antes del primer login (caso normal); si se cambian roles en caliente: `await user.getIdToken(true)` en la app tras re-login. Documentar en README de scripts.

### Pitfall 7: Índices compuestos faltantes
**What:** `where restauranteId + where estado in [...] + orderBy createdAt` (cola cocina) necesita índice compuesto; sin él, runtime error con link.
**How to avoid:** `firestore.indexes.json` completo desde el día 1 (lista abajo) + `firebase deploy --only firestore:indexes`. NOTA: `where estado in [...]` + orderBy usa el MISMO índice compuesto.

### Pitfall 8: offline persistence en Web del panel
**What:** Firestore Web persiste en indexedDB por defecto → tras cambiar rules/datos, states viejos en cache.
**How to avoid:** aceptable para v1 (mejora UX offline); para dev hard-refresh. No deshabilitar en prod ( listeners offline gratis).

### Pitfall 9: timezones en "reservas del día" / "fecha pasada"
**What:** MySQL usaba `func.curdate()` (TZ America/Bogota). En Firestore NO hay "hoy" server-side: el cliente computa inicioHoy en su TZ local y rules comparan `fecha > request.time` (request.time es UTC-server).
**How to avoid:** UI pasa `Timestamp` del slot en TZ Bogotá; panel computa inicioHoy/hora+1 con `DateTime.now(tz Bogotá)` (paquete `timezone` o intl si hace falta — evaluar en plan). Documentar que rules validan futuro vs server-time (suficiente: bloquea fechas pasadas groseras).

### Pitfall 10: borrar deps antes de terminar
**What:** quitar dio/ws_client del pubspec rompe N imports y los tests legacy (ws_client_test, pedidos_ws_test, mesas_ws_test).
**How to avoid:** orden: (1) bootstrap+providers nuevos, (2) migrar feature por feature, (3) DELETE masivo de core legacy + sus tests, (4) `flutter pub deps` limpio. Los tests WS se BORRAN con ws_client.

## Code Examples

### Bootstrap (main.dart pattern — ambas apps)
```dart
// Source: firebase.google.com/docs/flutter/setup + pub.dev 6.8.0/6.5.7 (verificado)
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  if (const bool.fromEnvironment('USE_EMULATORS', defaultValue: false)) {
    await FirebaseAuth.instance.useAuthEmulator('127.0.0.1', 9099);
    FirebaseFirestore.instance.useFirestoreEmulator('127.0.0.1', 8080);
  }
  runApp(const ProviderScope(child: GriApp()));
}
```

### Auth provider (reemplaza token_provider + auth_storage)
```dart
@riverpod
Stream<User?> authState(Ref ref) => FirebaseAuth.instance.authStateChanges();

// login:  FirebaseAuth.instance.signInWithEmailAndPassword(email: ..., password: ...)
// registro: createUser + updateDisplayName + set(usuarios/{uid}, {role:'cliente',...})
// claims leídos: idToken.claims['role'], claims['rid']  (para enrutar login cliente vs panel)
```

### firestore.indexes.json (lista inicial completa)
```json
{ "indexes": [
  {"collectionGroup":"pedidos","queryScope":"COLLECTION","fields":[
    {"fieldPath":"restauranteId","order":"ASCENDING"},
    {"fieldPath":"estado","order":"ASCENDING"},
    {"fieldPath":"createdAt","order":"DESCENDING"}]},
  {"collectionGroup":"pedidos","queryScope":"COLLECTION","fields":[
    {"fieldPath":"sesionId","order":"ASCENDING"},
    {"fieldPath":"createdAt","order":"ASCENDING"}]},
  {"collectionGroup":"pedidos","queryScope":"COLLECTION","fields":[
    {"fieldPath":"usuarioId","order":"ASCENDING"},
    {"fieldPath":"createdAt","order":"DESCENDING"}]},
  {"collectionGroup":"reservas","queryScope":"COLLECTION","fields":[
    {"fieldPath":"restauranteId","order":"ASCENDING"},
    {"fieldPath":"fecha","order":"ASCENDING"}]},
  {"collectionGroup":"reservas","queryScope":"COLLECTION","fields":[
    {"fieldPath":"usuarioId","order":"ASCENDING"},
    {"fieldPath":"fecha","order":"DESCENDING"}]},
  {"collectionGroup":"sesiones","queryScope":"COLLECTION","fields":[
    {"fieldPath":"usuarioId","order":"ASCENDING"},
    {"fieldPath":"estado","order":"ASCENDING"}]},
  {"collectionGroup":"sesiones","queryScope":"COLLECTION","fields":[
    {"fieldPath":"restauranteId","order":"ASCENDING"},
    {"fieldPath":"estado","order":"ASCENDING"}]},
  {"collectionGroup":"productos","queryScope":"COLLECTION","fields":[
    {"fieldPath":"restauranteId","order":"ASCENDING"},
    {"fieldPath":"categoriaId","order":"ASCENDING"}]},
  {"collectionGroup":"mesas","queryScope":"COLLECTION","fields":[
    {"fieldPath":"restauranteId","order":"ASCENDING"},
    {"fieldPath":"numero","order":"ASCENDING"}]}
], "fieldOverrides": [] }
```

### firebase.json (raíz del repo)
```json
{
  "firestore": { "rules": "firestore.rules", "indexes": "firestore.indexes.json" },
  "emulators": {
    "auth": {"port": 9099},
    "firestore": {"port": 8080},
    "ui": {"enabled": true, "port": 4000}
  }
}
```

### Seed script (scripts/seed_firebase.mjs — sketch)
```javascript
// Source: firebase.google.com/docs/auth/admin/custom-claims + docs/admin/setup
// Prod:  GOOGLE_APPLICATION_CREDENTIALS=./serviceAccountKey.json (GITIGNORED)
// Emuladores: FIREBASE_AUTH_EMULATOR_HOST=127.0.0.1:9099 FIRESTORE_EMULATOR_HOST=127.0.0.1:8080
//             (admin con projectId='demo-p-gri' funciona sin creds contra emuladores)
import { initializeApp, cert } from 'firebase-admin/app';
import { getAuth } from 'firebase-admin/auth';
import { getFirestore } from 'firebase-admin/firestore';

const app = initializeApp({ projectId: 'p-gri-b5b40' /*, credential: cert(...) en prod */ });
const auth = getAuth(app); const db = getFirestore(app);

const RID = 'demo';
// 1. restaurante
await db.doc(`restaurantes/${RID}`).set({ nombre: 'Restaurante Demo GRI', tipoCocina: 'Colombiana',
  direccion: 'Cra. 7 #63-44, Bogotá', activo: true, califProm: 0, califCount: 0, ... });
// 2. usuarios (mismo contenido que backend seed_service.py) + claims
const USERS = [
  { email: 'admin@gri.dev',   nombre: 'Super Admin',  role: 'super_admin',        rid: null },
  { email: 'admin@demo.gri.dev',  nombre: 'Admin Demo',  role: 'admin_restaurante', rid: RID },
  { email: 'mesero@demo.gri.dev', nombre: 'Mesero Demo', role: 'mesero',            rid: RID },
  { email: 'cocina@demo.gri.dev', nombre: 'Cocina Demo', role: 'cocina',            rid: RID },
  { email: 'carlos@demo.gri.dev', nombre: 'Carlos Cliente', role: 'cliente',       rid: null },
  { email: 'maria@demo.gri.dev',  nombre: 'María Cliente',  role: 'cliente',       rid: null },
];
for (const u of USERS) {
  const user = await auth.createUser({ email: u.email, password: 'Demo!1234', displayName: u.nombre })
    .catch(e => e.code === 'auth/email-already-exists' ? auth.getUserByEmail(u.email) : Promise.reject(e));
  await auth.setCustomUserClaims(user.uid, { role: u.role, rid: u.rid });
  await db.doc(`usuarios/${user.uid}`).set({ nombre: u.nombre, email: u.email,
    role: u.role, restauranteId: u.rid, createdAt: new Date() }, { merge: true });
}
// 3. 8 mesas (doc ID = QR determinista GRI-MESA-demo-001..008, capacidades [2,2,4,4,4,6,6,8])
// 4. 4 categorías + 16 productos COP (MISMOS datos que backend/app/services/seed_service.py)
```

### Inventario de archivos (para el planner)

**app_cliente — CREATE:** `lib/firebase_options.dart`, `lib/core/{firebase_bootstrap,firebase_providers,state_machines}.dart`, `test/state_machines_test.dart`, `test/helpers/firebase_fakes.dart`.
**MODIFY:** `pubspec.yaml` (deps), `lib/main.dart`, `lib/app.dart` (guard por claims), `lib/models/*` (fromDoc; ids String), `lib/features/auth/auth_controller.dart`, `features/restaurantes/restaurantes_provider.dart`, `features/reservas/{reservas_provider,reserva_controller}.dart`, `features/sesion_qr/sesion_provider.dart`, `features/pedidos/{pedidos_provider,carrito_controller}.dart`, `features/perfil/perfil_controller.dart`, `features/pagos/calificacion_sheet.dart` (movida o rewired), tests de auth/reservas/pedidos/sesion (override providers con fakes).
**DELETE:** `lib/core/{api_client,auth_storage,token_provider,token_provider.g,ws_client,env}.dart`, `lib/models/{token_pair,pago}.dart*` (*pago.dart se borra con la feature diferida), `lib/features/pagos/{pago_screen,pago_controller}.dart`, `assets/.env`, tests `ws_client_test.dart` y `pedidos_ws_test.dart`.

**panel_admin — CREATE:** ídem core (firebase_options web-only, bootstrap, providers, state_machines), `test/state_machines_test.dart`, helpers fakes.
**MODIFY:** `pubspec.yaml`, `main.dart`, `app.dart`, `models/*`, `features/auth/login_controller.dart`, `features/dashboard/{stats,mesas,restaurante,restaurantes_list}_provider.dart`, `features/cocina/pedidos_staff_provider.dart`, `features/reservas/reservas_provider.dart`, `features/menu/menu_provider.dart`, `features/clientes/clientes_provider.dart`, `features/mesas/*` (QR dialog: QR determinista ya no necesita endpoint), `features/reportes/*` (agregaciones), `features/configuracion/restaurantes_admin_provider.dart`, tests respectivos.
**DELETE:** `lib/core/{api_client,auth_storage,token_provider*,ws_client,env}.dart`, `lib/models/token_pair.dart`, `assets/.env`, `test/{ws_client,pedidos_ws,mesas_ws}_test.dart`.

**repo raíz — CREATE:** `firebase.json`, `firestore.rules`, `firestore.indexes.json`, `scripts/seed_firebase.mjs`, `scripts/package.json`, `.gitignore += serviceAccountKey.json, emulator_data/`, guía `docs/FIREBASE_SETUP.md` (emuladores, seed, deploy rules).

## State of the Art

| Old Approach (Phases 1-9) | Current Approach (Phase 10) | Impact |
|---------------------------|------------------------------|--------|
| JWT propio + refresh + secure_storage | FirebaseAuth + persistencia nativa | Se eliminan ~4 archivos core por app |
| WebSockets + backoff + dedup + polling safety-net | `snapshots()` onSnapshot nativo | Phase 7 completa se retira; resync gratis |
| TenantScope (dependencia FastAPI) | Firestore rules con claims `{role, rid}` | Authz declarativo, server-enforced, 0 código app |
| SELECT..FOR UPDATE + UNIQUE constraints | runTransaction + doc IDs deterministas | Concurrency model client-side, mismas garantías en los 3 flujos críticos |
| Polling dashboard 10s | listeners | Menos reads (solo cambios), UI en vivo |
| Endpoints /staff/stats, /reportes | Derivación de streams + aggregation queries (`count()`/`sum()`) en cliente | OJO coste reads en reportes grandes — v1 demo OK |

**Deprecated/outdated a evitar:** `cloud_firestore_mocks` (renombrado `fake_cloud_firestore`); `CocoaPods firebase pods` manuales (no aplica — solo android+web); inicializar Firebase sin `firebase_options.dart` (hardcodear config web manualmente funciona pero pierde el CLI).

## Open Questions

1. **`firebase-admin` 14.2.0 contra emuladores sin service account** — patrón `initializeApp({projectId})` + env `*_EMULATOR_HOST` es el documentado; verificar en el plan si 14.x requiere flag extra (MEDIUM confidence, testear en Wave 0 del seed).
2. **Rating agregado en lista de restaurantes** — propuesta: tx que recompute `califProm/califCount` al calificar (rules permiten update de SOLO esas 2 keys por el cliente). Alternativa: `average()` aggregation query por restaurante en el listado (N queries por render). Decidir en plan (demo: 1-2 restaurantes → cualquiera funciona; tx-recompute recomendado).
3. **Rules tests** — `@firebase/rules-unit-testing` 5.0.1 (verificado npm) contra emulador como suite node opcional; `fake_cloud_firestore` incluye evaluación básica de rules en Dart (fake_firebase_security_rules) — decidir alcance en plan (recomendado v1: tests Dart de fakes + UAT manual contra emulador; rules suite formal defer).
4. **Reportes con agregaciones** — `count()`/`sum()` soportados en cloud_firestore 6.x; el coste de reads escala con docs matcheados. Para v1 demo OK; si el volumen crece → Functions (fase futura).
5. **Sesión multi-cliente por mesa** — v1 mantiene paridad con Phase 6 (sesión vinculada al usuario que la abrió; solo él pide). Compañeros en la mesa: defer (documentado).

## Validation Architecture

> `workflow.nyquist_validation: true` en `.planning/config.json` → sección obligatoria.

### Test Framework
| Property | Value |
|----------|-------|
| Framework | `flutter_test` (SDK) + **fake_cloud_firestore 4.2.0** + **firebase_auth_mocks 0.15.2** (dev deps nuevos) |
| Config file | ninguno nuevo (convención `test/` por app); `scripts/package.json` para seed/rules-tooling node |
| Quick run (cliente) | `flutter test` (workdir `app_cliente/`) |
| Quick run (panel) | `flutter test` (workdir `panel_admin/`) |
| Full suite | `flutter test` en ambas apps + `flutter analyze` |
| UAT en vivo | `firebase emulators:start --import=./emulator_data` + apps con `--dart-define=USE_EMULATORS=true` + `node scripts/seed_firebase.mjs` |

### Fase 10 Behaviors → Test Map
*(Phase 10 no tiene REQ IDs aún en ROADMAP — "Requirements: TBD". Se mapean los comportamientos que la fase debe preservar de Phases 2-9; el planner puede promocionarlos a IDs al planear.)*

| Behavior (heredado de) | Test Type | Automated Command | File Exists? |
|---|---|---|---|
| State machines port 1:1 (MESA/PEDIDO/RESERVA/SESION) — mismas transiciones/terminales que `state_machines.py` | unit (puro) | `flutter test test/state_machines_test.dart` | ❌ Wave 0 |
| Registro cliente escribe usuarios/{uid} role cliente; login staff redirige por claims (AUTH-01/02) | widget w/ mocks | `flutter test test/auth/` | ✏️ reescribir (login_register_test.dart, login_form_test.dart) |
| Reserva: doc ID determinista previene doble reserva del mismo slot; sin capacidad → error (RESV-02) | unit w/ fake_cloud_firestore (runTransaction) | `flutter test test/reservas/` | ✏️ reescribir wizard_form/mis_reservas |
| Sesión: una activa por mesa; segunda apertura concurrente falla (MESA-05/06) | unit w/ fake tx | `flutter test test/sesion_qr/` | ✏️ reescribir scan_test |
| Pedido: requiere sesión activa propia de esa mesa; items con snapshot; cola cocina solo staff del restaurante (PEDI-01..05) | unit w/ fake + widget | `flutter test test/pedidos/` | ✏️ reescribir carrito/cuenta/estado |
| Estado pedido: matriz rol×transición en botones del panel (matriz simplificada) (PEDI-05) | widget | `flutter test test/cocina/cola_test.dart` | ✏️ reescribir |
| Cuenta: dueño marca cuentaSolicitada; panel la ve (PAGO-01 diferido) | unit w/ fake + widget | `flutter test test/pedidos/cuenta_test.dart` | ✏️ reescribir |
| Calificación: solo pedido servido propio con sesión cerrada; 1:1 por pedido (CALI-01) | unit w/ fake | `flutter test test/pagos/calificacion_sheet_test.dart` | ✏️ reescribir |
| Mapa mesas en vivo: colores por estado; solo transiciones válidas en actions sheet (MESA-04, ADMN-04) | widget | `flutter test test/dashboard/ test/mesas/` | ✏️ ajustar providers |
| Aislamiento tenant: queries panel siempre con restauranteId; rules deniegan cross (AUTH-03) | unit w/ fake rules + code review de queries | `flutter test` (negativo: staff A no lee docs B vía fakes) | ❌ Wave 0 (helper) |
| Menú CRUD + activo/disponible (MENU-01/02) | widget w/ fake | `flutter test test/menu/menu_screen_test.dart` | ✏️ reescribir |
| Rules: esqueleto sintácticamente válido y deploys | smoke (CLI) | `firebase deploy --only firestore:rules --dry-run` o `firebase emulators:exec "node scripts/rules_smoke.mjs"` | ❌ opcional v1 |

### Sampling Rate
- **Per task commit:** `flutter test` + `flutter analyze` de la app tocada (< 2 min con fakes — sin red, sin emuladores).
- **Per wave merge:** full suite de AMBAS apps + seed contra emuladores + smoke manual emulador UI (`localhost:4000`).
- **Phase gate:** suite verde en ambas apps + flujo E2E manual en emuladores: registro→reserva→QR→pedido→cocina avanza→servido→cuenta→cerrar mesa→calificar + login staff en panel con claims correctos. Deploy de rules+indexes al proyecto real al cierre.

### Wave 0 Gaps
- [ ] `flutter pub add --dev fake_cloud_firestore firebase_auth_mocks` en ambas apps (+ deps core) — habilita todo el resto
- [ ] `test/helpers/firebase_fakes.dart` (por app): helpers `FakeFirebaseFirestore` + `MockFirebaseAuth` + seed mínimo de docs (restaurante/mesas/menú) reutilizable — cubre aislamiento y flujos
- [ ] `lib/core/state_machines.dart` + `test/state_machines_test.dart` (port 1:1 — sin él, las tx no tienen qué validar)
- [ ] `firebase.json` + `firestore.rules` esqueleto + `firestore.indexes.json` (deployables; refinados durante la fase)
- [ ] `scripts/seed_firebase.mjs` mínimo (emuladores) — el UAT en vivo depende de él
- [ ] Borrar baseline: los tests `ws_client_test`, `pedidos_ws_test`, `mesas_ws_test` se ELIMINAN con sus fuentes (baselines 51/61 se renegocian en plan)

## Sources

### Primary (HIGH confidence)
- **pub.dev API** (consultado 2026-08-16): firebase_core 4.13.0 (2026-08-03), firebase_auth 6.5.7 (2026-08-03), cloud_firestore 6.8.0 (2026-08-03), fake_cloud_firestore 4.2.0 (2026-07-17, dep `cloud_firestore ^6.7.1`), firebase_auth_mocks 0.15.2 (2026-05-16, deps `firebase_auth ^6.0.0`/`firebase_core ^4.0.0`), flutterfire_cli 1.4.1.
- **pub.dev API docs** (código fuente inspeccionado): `cloud_firestore 6.8.0 useFirestoreEmulator` (host mapping automático Android verificado en la implementación), `firebase_auth 6.5.7 useAuthEmulator`.
- **firebase.google.com/docs/flutter/setup** (actualizada 2026-08-13): flujo `flutterfire configure` completo, `firebase_options.dart`, `Firebase.initializeApp(options:)`, modo `demoProjectId`, re-run tras agregar plugins.
- **firebase.google.com/docs/firestore/security/rules-conditions**: límites access-calls **10/20** (multi-doc/tx/batch), funciones sin loops/single return/10 let/depth 10, access-calls facturadas.
- **firebase.google.com/docs/emulator-suite/connect_firestore**: contenido volátil del emulador, recomendación de deshabilitar persistencia local, `10.0.2.2` en Android.
- **npm registry** (2026-08-16): firebase-admin 14.2.0, firebase-tools 15.27.0, @firebase/rules-unit-testing 5.0.1.
- **Repo local**: `backend/app/core/state_machines.py`, `backend/app/services/{reserva_service,seed_service}.py` (fuente del port), `app_cliente/pubspec.yaml`, `panel_admin/pubspec.yaml`, `flutter --version` = 3.47.0/Dart 3.13.0, `documentos/{google-services.json,firebase-config-web.js}`.

### Secondary (MEDIUM confidence)
- **Aggregation queries (`count()`/`sum()`/`average()`) en cloud_firestore 6.x** — feature estable desde 2023-2024, no re-verificada página por página en esta pasada; usar en reportes tras confirmar API exacta en pub.dev docs al implementar.
- **firebase-admin contra emuladores sin credenciales** (`initializeApp({projectId})` + `*_EMULATOR_HOST`) — patrón documentado y estable; validar con 14.2.0 en el primer run del seed.
- **Persistencia Firestore Web por defecto (indexedDB)** — comportamiento del JS SDK actual; suficiente para la decisión documentada (mantenerla).

### Tertiary (LOW confidence)
- **Cuota free tier (Spark) suficiente para demo** (50K reads/día, 1GB) — política de precios vigente no re-verificada en esta pasada; revisar en console al activar Firestore si preocupa.

## Metadata

**Confidence breakdown:**
- Standard stack: **HIGH** — todas las versiones y APIs críticas verificadas contra pub.dev/npm y docs oficiales el 2026-08-16.
- Modelo de datos + rules: **HIGH** en mecánica (límites, semántica de tx/create-vs-update verificada); **MEDIUM** en detalle fino del esqueleto de rules — es un borrador funcional que el planner debe refinar y validar contra emuladores (los helpers y el presupuesto de access-calls ya están contados).
- Pitfalls: **HIGH** — cada uno anclado en docs oficiales o en código fuente del paquete inspeccionado.
- Seed/tooling: **HIGH** en versiones; **MEDIUM** en detalles del flujo admin-vs-emuladores (Open Question 1).

**Research date:** 2026-08-16
**Valid until:** 2026-09-15 (stack Firebase se mueve rápido — release train mensual; re-verificar versiones si la fase se plane después)
