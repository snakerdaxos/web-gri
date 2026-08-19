# Fase 11: Corrección Crítica y Profesionalización — Investigación

**Investigado:** 2026-08-19
**Dominio:** Firebase Cloud Functions (callable + custom claims) · Firestore rules/queries/índices · Sistema de diseño y responsive en Flutter
**Confianza global:** ALTA

---

<user_constraints>
## Restricciones del Usuario (de 11-CONTEXT.md)

### Decisiones bloqueadas

**Alta de staff — LOCKED (2026-08-19)**
- Los usuarios staff se crean mediante una **Cloud Function callable** que ejecuta el Admin SDK
  del lado servidor y asigna los custom claims `{role, rid}`.
- Motivo: es la única opción que hace el producto autosuficiente — el `super_admin` da de alta un
  restaurante y su equipo desde el panel, sin consola ni scripts ni clave de servicio en manos de nadie.
- Implica añadir Cloud Functions (Node) al stack y el plan Blaze en Firebase.

**Delegación de roles — LOCKED (2026-08-19):** la función acepta DOS tipos de llamador con alcances
distintos, y debe validar el claim del llamador antes de crear nada:

| Llamador | Puede crear usuarios de | Roles que puede asignar |
|---|---|---|
| `super_admin` | cualquier restaurante | `admin_restaurante`, `mesero`, `cocina` |
| `admin_restaurante` | **solo su propio** `rid` | `admin_restaurante`, `mesero`, `cocina` |

- El `super_admin` da de alta el restaurante y su `admin_restaurante` inicial.
- A partir de ahí, ese admin gestiona su propio equipo sin depender del super_admin — pero el
  super_admin conserva la capacidad de hacerlo también.
- **CERRADO (2026-08-19):** sí, un `admin_restaurante` puede crear otro `admin_restaurante`, siempre
  acotado a su propio `rid`.
- Prohibiciones absolutas, con tests de escalada dedicados:
  1. Nadie puede asignar el rol `super_admin` por esta vía.
  2. Un `admin_restaurante` nunca puede crear usuarios con un `rid` distinto al suyo.
- Esto se valida **en la función**, no en el cliente.
- El panel necesita la pantalla de gestión de equipo correspondiente, visible según el rol del que
  ha iniciado sesión.

**Alcance visual — LOCKED (2026-08-19)**
- Se **conserva la identidad visual actual** (naranja `#FF4C05`, layout del mockup).
- El trabajo es de consistencia, no de rediseño: centralizar en tokens, aplicar escala de espaciado,
  hacer responsive de verdad y cumplir accesibilidad básica.
- No se rediseñan pantallas ni se cambia la paleta.

**Bootstrap del restaurante**
- El doc ID del restaurante **debe ser un slug `[a-z0-9-]+`**. Restricción dura, no negociable.
- El formulario de crear restaurante debe generar el slug y mostrarlo al usuario antes de confirmar.
- Las rules ya permiten `create` de `restaurantes` a `isSuper()` — falta la función y la pantalla,
  no hay que tocar la regla.

**Query vs rules**
- Toda query del cliente debe replicar en sus filtros lo que la regla exige por documento.
- `categorias` → `where('activo', isEqualTo: true)`. `productos` → `activo` **y** `disponible`.
- El filtrado client-side actual se elimina (queda redundante).
- Cada query nueva exige revisar si necesita índice compuesto.

**Tests**
- La suite de rules usa `@firebase/rules-unit-testing` contra el emulador de Firestore.
- Los tests de app siguen con `fake_cloud_firestore`, pero se añade cobertura del caso
  **base vacía / primer arranque**.

### Discreción de Claude
- Estructura de carpetas de las Cloud Functions y su configuración de despliegue.
- Forma concreta de los tokens de diseño (extensión de `ThemeData`, clase de constantes, etc.)
  y cómo se comparten o duplican entre las dos apps.
- Elección de breakpoints concretos para móvil y web.
- Organización de los tests de rules por colección o por rol.
- Cómo se estructura el runbook E2E del bloque 4.

### Ideas diferidas (FUERA DE ALCANCE)
- Pagos en línea (diferidos desde la Fase 10 — solo se solicita la cuenta).
- Validación fuerte de totales de pedido y del agregado de calificaciones vía Cloud Functions
  (gap estructural aceptado en v1, documentado en `firestore.rules`).
- Rediseño visual completo — descartado explícitamente por el usuario en esta fase.
- Multi-idioma / i18n.
</user_constraints>

---

## Restricciones del Proyecto (de CLAUDE.md)

| Directiva | Estado | Nota para el planner |
|---|---|---|
| Enrutar todo trabajo por un comando GSD antes de Edit/Write | Vigente | Esta fase se ejecuta con `/gsd-execute-phase` |
| Flutter/Dart para app cliente + panel admin | Vigente | Se mantiene |
| `flutter_riverpod` (nunca Provider), `go_router`, `dio`… | Parcial | El repo ya NO usa `dio` (habla directo a Firebase). Riverpod 3.x + go_router 17.5 sí están vigentes |
| **FastAPI + MySQL + SQLAlchemy + asyncmy + PyJWT…** | **OBSOLETO** | ⚠️ Toda la sección "Technology Stack" de `CLAUDE.md` describe el backend **ARCHIVADO** en la Fase 10. El sistema vivo es Firebase Auth + Firestore + rules. **El planner NO debe planear nada de FastAPI/MySQL.** Ver `.planning/STATE.md` |
| `flutter_secure_storage` para JWT | No aplica | El SDK de Firebase Auth gestiona la persistencia del token; no hay JWT propio |
| Sin `print()` en backend | Aplica ahora a Functions | Usar `firebase-functions/logger` en vez de `console.log` |

**Acción recomendada:** la fase debería incluir una tarea de bajo costo que actualice la sección
"Technology Stack" de `CLAUDE.md` para reflejar Firebase + Cloud Functions. Hoy contradice la
realidad del repo y es una fuente de errores para cualquier agente futuro. `[VERIFIED: lectura de CLAUDE.md vs .planning/STATE.md y pubspec.yaml]`

---

## Resumen

Esta fase tiene tres dominios técnicos con muy distinta madurez de conocimiento. El primero
—**Cloud Functions callable con custom claims**— es territorio nuevo para este repo pero está
completamente documentado por Firebase; la única sorpresa relevante es que **el plan Blaze solo se
exige para *desplegar*, no para *emular*** (`"You can emulate functions in any Firebase project, but
to deploy functions, your project must be on the Blaze pricing plan"` [CITED: firebase.google.com/docs/functions/get-started]),
lo cual desbloquea desarrollar y testear la fase entera sin tocar la facturación. El segundo
—**query vs rules e índices**— está confirmado al 100% por la documentación oficial y el hallazgo
de la auditoría es incluso **peor** de lo que dice `CONCERNS.md`: la query del menú del cliente no
falla "cuando algún producto está agotado", falla **siempre**, porque Firestore evalúa la regla
contra la consulta y nunca mira los documentos. El tercero —**sistema de diseño y responsive**— no
requiere ninguna dependencia nueva; el repo ya tiene el patrón correcto (`LayoutBuilder` en 3 de 9
pantallas del panel) y sólo falta extraerlo, nombrarlo y aplicarlo.

Un hallazgo de entorno que condiciona el orden de ejecución: **la suite de tests de rules exige el
emulador de Firestore, que exige Java, que hoy no está en el PATH** (aunque sí existe el JBR de
Android Studio en `C:\Program Files\Android\Android Studio\jbr`). El emulador de Functions, en
cambio, no necesita Java. Y una limitación estructural que hay que aceptar y compensar: **el
emulador de Firestore no valida índices compuestos** — ninguna suite automatizada local puede
detectar el bug 1c; sólo un audit estático query↔índice o el proyecto real.

Sobre la matriz de autorización de la callable: dado que ambos llamadores asignan exactamente el
mismo conjunto de roles (`admin_restaurante | mesero | cocina`) y sólo difieren en el alcance del
`rid`, la lógica se reduce a **una sola decisión** (`ridEfectivo`) y **una sola prohibición de rol**
(`≠ super_admin`). Eso inclina claramente la balanza hacia **una única callable** con validación de
alcance interna, no hacia dos callables separadas.

**Recomendación principal:** ejecutar en tres olas — (0) infraestructura de test y emulador (Java en
PATH, `functions/`, suite de rules), (1) los tres bugs funcionales + su cobertura, (2) UI/diseño en
paralelo. El bloque de diseño no comparte ningún archivo con el bloque funcional salvo
`core/theme.dart`, así que puede paralelizarse desde el minuto cero.

---

## Mapa de Responsabilidad Arquitectónica

| Capacidad | Tier primario | Tier secundario | Justificación |
|---|---|---|---|
| Crear usuario en Auth + asignar `{role, rid}` | **Cloud Function (Admin SDK)** | — | `setCustomUserClaims` es exclusivo del Admin SDK; ningún cliente puede escribir sus propios claims [CITED: firebase.google.com/docs/auth/admin/custom-claims] |
| Validar quién puede crear a quién (matriz de roles) | **Cloud Function** | — | El cliente puede mentir; la validación en Flutter es solo UX. Locked en CONTEXT: "se valida en la función, no en el cliente" |
| Autorización de lectura/escritura de datos | **firestore.rules** | Cloud Function (bypass) | Rules es la capa de autorización del sistema. El Admin SDK dentro de la función **salta las rules por diseño** |
| Crear el doc `restaurantes/{slug}` | **Cliente (panel) directo a Firestore** | — | Las rules ya lo permiten a `isSuper()`; añadir una Function aquí sería complejidad sin beneficio |
| Escribir el doc espejo `usuarios/{uid}` del staff | **Cloud Function** | — | Las rules solo permiten crear `usuarios/{uid}` con `uid == request.auth.uid` y `role == 'cliente'`; el staff no puede autocrearse su espejo |
| Filtrar menú público por `activo`/`disponible` | **Query del cliente** | firestore.rules | La regla NO filtra: es all-or-nothing. El filtro debe estar en la query |
| Ordenar categorías del menú | **Firestore (`orderBy` + índice)** o cliente | — | Decisión de plan: `orderBy` server-side exige índice compuesto nuevo; el sort client-side ya funciona hoy y evita el índice |
| Tokens de color/tipografía/espaciado | **Flutter `ThemeData` + `ThemeExtension`** | clase de constantes | Ver "Pattern 4" |
| Adaptación por ancho de viewport | **Flutter `LayoutBuilder`** | `MediaQuery` | `LayoutBuilder` mide el espacio *del padre*, no de la ventana — es lo correcto dentro de un shell con sidebar |
| Verificación de accesibilidad | **`flutter_test` + `meetsGuideline`** | revisión humana | `androidTapTargetGuideline` / `labeledTapTargetGuideline` son automáticos |

---

## Stack Estándar

### Nuevo — Cloud Functions (Node, carpeta `functions/`)

| Librería | Versión | Propósito | Por qué es la estándar |
|---|---|---|---|
| `firebase-functions` | **7.3.2** | SDK de definición de funciones (`onCall`, `HttpsError`) | SDK oficial. v7 expone las funciones v2 en la raíz: `require("firebase-functions/https")` [VERIFIED: npm registry + tarball `package.json` exports] |
| `firebase-admin` | **14.2.0** | Admin SDK: `createUser`, `setCustomUserClaims`, Firestore server-side | Ya es la dependencia exacta de `scripts/package.json` — **misma versión, sin divergencia** [VERIFIED: npm registry + scripts/package.json] |
| Runtime Node | **22** (`engines: {"node": "22"}`) | Runtime desplegado | Cloud Functions soporta 20 y 22; 18 deprecado; **24 NO soportado** [CITED: firebase.google.com/docs/functions/manage-functions] |

### Nuevo — Tests de rules y de la callable (carpeta `scripts/` o `tests/`)

| Librería | Versión | Propósito | Cuándo usarla |
|---|---|---|---|
| `@firebase/rules-unit-testing` | **5.0.1** | Suite de `firestore.rules` contra el emulador | Siempre para rules. Peer dep: `firebase ^12.0.0`. `engines: node >=20` [VERIFIED: npm registry + tarball package.json] |
| `firebase` (JS client SDK) | **12.17.1** | Peer de rules-unit-testing + cliente para llamar la callable en tests de integración | Requerido por el anterior; reutilizable para el test e2e de la callable |
| `firebase-tools` | **15.27.0** | `firebase emulators:exec`, `deploy` | Ya está en `scripts/package.json` como devDependency — **no añadir nada** [VERIFIED: scripts/package.json] |
| `node --test` (builtin) | Node ≥20 | Runner de tests JS | **Recomendado sobre Jest/Vitest**: cero dependencias nuevas, ya disponible (Node 24 local), soporta `describe/it/before/after` y `--test-concurrency=1`. El repo no tiene ningún runner JS hoy — no hay inercia que respetar |
| `firebase-functions-test` | 3.5.0 | Wrapper "offline" de firebase-functions | **NO recomendado aquí** — ver "Alternativas consideradas" |

### Nuevo — Flutter (ambas apps)

| Paquete | Versión | Propósito | Notas |
|---|---|---|---|
| `cloud_functions` | **6.3.6** (pub.dev, 2026-08-03) | Llamar la callable desde Flutter | Requiere `firebase_core ^4.13.0` → **compatible exacto con el pin 4.13.0 del repo**. Requiere `flutter >=3.27.0` (repo: 3.47.0) y `sdk ^3.6.0` (repo: `^3.13.0`). Publisher verificado firebase.google.com, Flutter Favorite [VERIFIED: pub.dev API] |

**Instalación:**
```bash
# Panel admin (el que llama la callable). app_cliente NO la necesita.
cd panel_admin && flutter pub add cloud_functions

# Tooling JS (en scripts/, que ya tiene package.json)
cd scripts && npm i -D @firebase/rules-unit-testing@5.0.1 firebase@12.17.1

# Cloud Functions (carpeta nueva, package.json propio)
cd functions && npm i firebase-admin@14.2.0 firebase-functions@7.3.2
```

### Alternativas consideradas

| En vez de | Se podría usar | Compensación |
|---|---|---|
| `node --test` | Jest / Vitest / Mocha | Jest tiene fricción notoria con ESM y `@firebase/rules-unit-testing` (que es ESM/CJS dual). Vitest funciona bien pero añade ~40 MB de deps para 2 suites. `node --test` es suficiente y no introduce config. **Default: `node --test`** |
| Tests de integración con emulador | `firebase-functions-test` (modo offline) | `firebase-functions-test` *envuelve* la función y te deja inyectar un `context.auth` falso — pero eso **no prueba nada de la verificación real del token** y es exactamente el mismo tipo de "fake" que ya dejó pasar los bugs de la Fase 10 (ver `TESTING.md`). Para la matriz de escalada de privilegios hace falta el emulador con tokens reales del Auth emulator. **Default: emulador** (con `node --test` puro para las funciones *puras* de autorización) |
| Una sola callable `crearUsuarioStaff` | Dos callables separadas (`superCrearStaff` / `adminCrearStaff`) | Con la matriz cerrada, ambos llamadores asignan **el mismo conjunto de roles** y sólo difieren en el `rid` efectivo. Dos callables duplicarían la validación de rol, el hash de idempotencia y el escritor del espejo, y crearían dos superficies de ataque donde hoy hay una. **Default: una sola callable** (ver Pattern 1) |
| `LayoutBuilder` + constantes propias | `responsive_framework` 1.5.1 / `flutter_adaptive_scaffold` 0.3.3+1 | Ambos paquetes llevan >1 año sin release (2024-08 y 2025-05 respectivamente) y `flutter_adaptive_scaffold` sigue en 0.x. El repo ya tiene el patrón `LayoutBuilder` funcionando en `dashboard_screen.dart` y `app_shell.dart`. Añadir un paquete implicaría *rediseñar* el shell — prohibido por la decisión LOCKED. **Default: sin paquete** [VERIFIED: pub.dev API] |
| Paquete Dart compartido en `packages/gri_design` | Duplicación deliberada de `core/theme.dart` | Ver "Pattern 4" — recomendación: **duplicación deliberada + comentario de sincronización**, por las razones ahí explicadas |
| `diacritic` 0.1.6 para el slug | Mapa de acentos a mano (~15 líneas) | `diacritic` lleva desde 2024-09 sin release y sólo aporta una tabla de reemplazo. El dominio es español: `áéíóúüñ` + mayúsculas. **Default: función propia** (ver Code Examples) |

---

## Auditoría de Legitimidad de Paquetes

Ejecutado con `slopcheck scan --pkg npm <name> --json` (modo no-instalador) el 2026-08-19.

| Paquete | Registro | Repo fuente | postinstall | slopcheck | Disposición |
|---|---|---|---|---|---|
| `firebase-functions` 7.3.2 | npm | github.com/firebase/firebase-functions | ninguno | `OK` | Aprobado |
| `firebase-admin` 14.2.0 | npm | github.com/firebase/firebase-admin-node | ninguno | `OK` | Aprobado (ya en uso) |
| `@firebase/rules-unit-testing` 5.0.1 | npm | github.com/firebase/firebase-js-sdk | ninguno | `OK` | Aprobado |
| `firebase` 12.17.1 | npm | github.com/firebase/firebase-js-sdk | ninguno | `OK` | Aprobado |
| `firebase-tools` 15.27.0 | npm | github.com/firebase/firebase-tools | ninguno | `OK` (flag informativo: "Name ends with '-tools' — looks like LLM bait but package is established") | Aprobado (ya en uso) |
| `firebase-functions-test` 3.5.0 | npm | github.com/firebase/firebase-functions-test | ninguno | `OK` | No se adopta (ver alternativas) |
| `cloud_functions` 6.3.6 | pub.dev | firebase/flutterfire | n/a | no aplica (slopcheck no cubre pub.dev) | Aprobado — publisher **verificado** `firebase.google.com`, Flutter Favorite [VERIFIED: pub.dev] |

**Paquetes eliminados por veredicto `[SLOP]`:** ninguno.
**Paquetes marcados `[SUS]`:** ninguno.

> ⚠️ **Aviso al usuario (efecto colateral de esta investigación):** al ejecutar la verificación,
> `slopcheck install` autodetectó el ecosistema como **PyPI** e instaló paquetes de Python no
> solicitados en el entorno del usuario (`firebase`, `firebase-admin` 7.5.0, `firebase-functions`
> 0.6.0, `functions-framework`, `google-cloud-firestore`, `flask-cors`, `cloudevents`, `h2`,
> `pyyaml`…) y **actualizó `starlette` de 1.0.0 a 1.6.0**. No tienen relación con este proyecto
> (que es Node + Flutter). Comando de reversión sugerido, a ejecutar sólo con confirmación:
> `pip uninstall -y firebase firebase-admin firebase-functions functions-framework google-cloud-firestore google-cloud-storage google-cloud-core google-events google-resumable-media google-crc32c cloudevents flask-cors cachecontrol deprecation uvicorn-worker h2 hpack hyperframe && pip install starlette==1.0.0`

---

## Patrones de Arquitectura

### Diagrama del sistema (con Cloud Functions)

```
┌──────────────────┐                       ┌───────────────────┐
│  app_cliente     │                       │   panel_admin     │
│  (Android/Web)   │                       │   (Flutter Web)   │
└────────┬─────────┘                       └─────┬───────┬─────┘
         │                                        │       │
         │ Auth + Firestore SDK                   │       │ cloud_functions SDK
         │ (lectura pública + escritura           │       │ (solo super_admin
         │  como cliente)                         │       │  y admin_restaurante)
         │                                        │       │
         ▼                                        ▼       ▼
  ┌──────────────────────────────────────────────────┐  ┌──────────────────────────┐
  │        Firebase Auth  (custom claims {role,rid}) │  │  Cloud Function callable │
  │   el token viaja en CADA request de Firestore    │◄─┤   crearUsuarioStaff      │
  └────────────────────┬─────────────────────────────┘  │  ─────────────────────   │
                       │                                 │ 1. request.auth?        │
                       ▼                                 │    → unauthenticated    │
  ┌──────────────────────────────────────────────────┐  │ 2. validar payload      │
  │            firestore.rules                        │  │    → invalid-argument   │
  │  evalúa la CONSULTA, no los documentos            │  │ 3. MATRIZ de rol/rid    │
  │  ────────────────────────────────────────────     │  │    → permission-denied  │
  │  read categorias : activo == true  ← la query     │  │ 4. createUser (idemp.)  │
  │  read productos  : activo && disponible ← DEBE    │  │ 5. setCustomUserClaims  │
  │  restaurantes    : create if isSuper()   filtrar  │  │ 6. set usuarios/{uid}   │
  │  usuarios        : create solo rol 'cliente'      │  └───────────┬──────────────┘
  └────────────────────┬─────────────────────────────┘              │ Admin SDK
                       │                                             │ (BYPASSEA rules)
                       ▼                                             ▼
  ┌──────────────────────────────────────────────────────────────────────────────┐
  │                              Cloud Firestore                                  │
  │  restaurantes/{slug}  categorias  productos  mesas/GRI-MESA-{slug}-{NNN}      │
  │  usuarios/{uid}  sesiones/{mesaId}  pedidos  reservas  calificaciones         │
  │  ── índices compuestos declarados en firestore.indexes.json ──                │
  └──────────────────────────────────────────────────────────────────────────────┘
```

Flujo de bootstrap desde base vacía (el que hoy no existe):

```
seed/Console crea el 1er super_admin  →  panel: login super_admin
   → crear restaurante (slug)  →  escribe restaurantes/{slug} DIRECTO (rules: isSuper)
   → crear admin_restaurante   →  callable crearUsuarioStaff(rid=slug, rol=admin_restaurante)
   → [logout / login como admin_restaurante]
   → crear mesero+cocina       →  callable crearUsuarioStaff(rid=SU PROPIO, rol=mesero|cocina)
   → crear mesas GRI-MESA-{slug}-{NNN}  →  crear categorías/productos
   → app_cliente: registro cliente → descubrir → menú → escanear QR → …
```

### Estructura de carpetas recomendada

```
cel/
├── firebase.json               # + bloque "functions" + emulators.functions
├── .firebaserc                 # ⚠️ NO EXISTE HOY — crear (o usar --project siempre)
├── firestore.rules
├── firestore.indexes.json
├── functions/                  # ← NUEVO codebase Node
│   ├── package.json            # engines.node = "22", type: module o commonjs
│   ├── index.js                # export de las callables
│   ├── src/
│   │   ├── auth-matrix.js      # ← lógica PURA de autorización (sin firebase-functions)
│   │   └── crear-usuario-staff.js
│   └── test/
│       └── auth-matrix.test.js # node --test, sin emulador, instantáneo
├── scripts/                    # ← ya existe (seed + firebase-tools)
│   ├── package.json            # + @firebase/rules-unit-testing, firebase, scripts test:*
│   ├── seed_firebase.mjs
│   └── test/
│       ├── rules/              # suite de firestore.rules por colección
│       │   ├── categorias.test.mjs
│       │   ├── productos.test.mjs
│       │   ├── mesas.test.mjs
│       │   ├── sesiones-pedidos.test.mjs
│       │   └── reservas-calificaciones.test.mjs
│       └── functions/
│           └── crear-usuario-staff.e2e.mjs   # emulador Auth+Functions+Firestore
├── app_cliente/
└── panel_admin/
```

**Razón de separar `functions/test/auth-matrix.test.js` de `scripts/test/functions/`:** la matriz de
autorización es una función pura `(callerRole, callerRid, targetRole, targetRid) → Decision`. Testearla
sin emulador da 20+ casos en milisegundos y hace trivial cubrir la combinatoria completa de escalada.
El test e2e con emulador cubre luego los 4-5 caminos representativos y, sobre todo, que el token real
llega decodificado a `request.auth.token`.

---

### Pattern 1 — Una sola callable con resolución de alcance

**Qué:** `crearUsuarioStaff` acepta `{email, password, nombre, rol, restauranteId?}` y decide el
`rid` efectivo a partir del claim del llamador.

**Cuándo usarlo:** siempre en esta fase. Reemplaza dos callables separadas.

**Por qué:** cerrada la matriz, ambos llamadores asignan el mismo set `{admin_restaurante, mesero,
cocina}`. La única diferencia es de dónde sale el `rid`. Esa asimetría cabe en 6 líneas.

```javascript
// functions/src/auth-matrix.js — LÓGICA PURA, cero imports de firebase.
// Testeable con `node --test` sin emulador. Esta es la pieza que debe tener
// cobertura exhaustiva de escalada de privilegios.

/** Roles que la callable puede ASIGNAR. 'super_admin' y 'cliente' NUNCA. */
export const ROLES_ASIGNABLES = ['admin_restaurante', 'mesero', 'cocina'];

/** Roles que pueden LLAMAR la callable. */
export const ROLES_LLAMADORES = ['super_admin', 'admin_restaurante'];

export const SLUG_RE = /^[a-z0-9]+(-[a-z0-9]+)*$/;

/**
 * Decide si el llamador puede crear al usuario pedido y con qué rid.
 * @returns {{ok: true, rid: string} | {ok: false, code: string, msg: string}}
 */
export function autorizarAlta({ callerRole, callerRid, rolPedido, ridPedido }) {
  // 1. ¿Es un llamador válido?
  if (!ROLES_LLAMADORES.includes(callerRole)) {
    return { ok: false, code: 'permission-denied',
             msg: 'Solo super_admin o admin_restaurante pueden dar de alta staff.' };
  }
  // 2. ¿El rol pedido es asignable? (bloquea super_admin y cualquier basura)
  if (!ROLES_ASIGNABLES.includes(rolPedido)) {
    return { ok: false, code: 'invalid-argument',
             msg: `rol debe ser uno de: ${ROLES_ASIGNABLES.join(', ')}.` };
  }
  // 3. Alcance del rid.
  if (callerRole === 'super_admin') {
    if (typeof ridPedido !== 'string' || !SLUG_RE.test(ridPedido)) {
      return { ok: false, code: 'invalid-argument',
               msg: 'restauranteId es obligatorio y debe ser un slug [a-z0-9-].' };
    }
    return { ok: true, rid: ridPedido };
  }
  // admin_restaurante: SIEMPRE su propio rid. Si mandó otro, es escalada.
  if (typeof callerRid !== 'string' || !callerRid) {
    return { ok: false, code: 'failed-precondition',
             msg: 'Tu cuenta no tiene restaurante asignado.' };
  }
  if (ridPedido !== undefined && ridPedido !== callerRid) {
    return { ok: false, code: 'permission-denied',
             msg: 'No puedes crear usuarios de otro restaurante.' };
  }
  return { ok: true, rid: callerRid };
}
```

```javascript
// functions/src/crear-usuario-staff.js
import { onCall, HttpsError } from 'firebase-functions/https';
import { logger } from 'firebase-functions';
import { getAuth } from 'firebase-admin/auth';
import { getFirestore, FieldValue } from 'firebase-admin/firestore';
import { autorizarAlta } from './auth-matrix.js';

export const crearUsuarioStaff = onCall(
  { region: 'us-central1', maxInstances: 5 },   // cors: true por defecto en onCall
  async (request) => {
    // --- 1. Autenticación ---
    if (!request.auth) {
      throw new HttpsError('unauthenticated', 'Debes iniciar sesión.');
    }
    const token = request.auth.token;           // DecodedIdToken con los custom claims

    // --- 2. Validación de payload ---
    const { email, password, nombre, rol, restauranteId } = request.data ?? {};
    if (typeof email !== 'string' || !email.includes('@')) {
      throw new HttpsError('invalid-argument', 'email inválido.');
    }
    if (typeof password !== 'string' || password.length < 6) {
      throw new HttpsError('invalid-argument', 'La contraseña debe tener al menos 6 caracteres.');
    }
    if (typeof nombre !== 'string' || nombre.trim().length === 0) {
      throw new HttpsError('invalid-argument', 'nombre es obligatorio.');
    }

    // --- 3. MATRIZ de autorización (lógica pura, testeada aparte) ---
    const d = autorizarAlta({
      callerRole: token.role,
      callerRid:  token.rid,
      rolPedido:  rol,
      ridPedido:  restauranteId,
    });
    if (!d.ok) throw new HttpsError(d.code, d.msg);

    // --- 4. El restaurante debe existir (evita crear staff huérfano) ---
    const db = getFirestore();
    const rDoc = await db.doc(`restaurantes/${d.rid}`).get();
    if (!rDoc.exists) {
      throw new HttpsError('not-found', `El restaurante ${d.rid} no existe.`);
    }

    // --- 5. Alta idempotente por email (MISMO patrón que seed_firebase.mjs) ---
    const auth = getAuth();
    let user, creado = false;
    try {
      user = await auth.createUser({
        email, password, displayName: nombre.trim(), emailVerified: true,
      });
      creado = true;
    } catch (e) {
      if (e.code === 'auth/email-already-exists') {
        user = await auth.getUserByEmail(email);
        // Anti-secuestro: no repisar claims de un usuario de OTRO tenant.
        const prev = user.customClaims ?? {};
        if (prev.role === 'super_admin') {
          throw new HttpsError('permission-denied', 'Esa cuenta es de plataforma.');
        }
        if (prev.rid && prev.rid !== d.rid) {
          throw new HttpsError('already-exists',
            'Ese correo ya pertenece a otro restaurante.');
        }
      } else {
        throw new HttpsError('internal', 'No se pudo crear la cuenta.', e.code);
      }
    }

    // --- 6. Claims + doc espejo (set/merge SIEMPRE, como el seed) ---
    await auth.setCustomUserClaims(user.uid, { role, rid: d.rid });
    await db.doc(`usuarios/${user.uid}`).set({
      nombre: nombre.trim(), email, role, restauranteId: d.rid,
      updatedAt: FieldValue.serverTimestamp(),
      ...(creado ? { createdAt: FieldValue.serverTimestamp() } : {}),
    }, { merge: true });

    logger.info('staff alta', { uid: user.uid, rol: rol, rid: d.rid,
                                por: request.auth.uid, creado });
    return { uid: user.uid, creado, rol: rol, restauranteId: d.rid };
  },
);
```

**Códigos de error `HttpsError` — cuál usar** (lista completa verificada en el `.d.ts` de
firebase-functions 7.3.2 [VERIFIED: tarball npm `lib/common/providers/https.d.ts:174`]):

| Situación | Código | Motivo |
|---|---|---|
| Sin sesión (`!request.auth`) | `unauthenticated` | HTTP 401 |
| Rol del llamador no autorizado / rid ajeno / intento de `super_admin` | `permission-denied` | HTTP 403. **Este es el código de la escalada** |
| Payload malformado (email, password corta, rol desconocido, slug inválido) | `invalid-argument` | HTTP 400 |
| El restaurante destino no existe | `not-found` | HTTP 404 |
| El admin no tiene `rid` en su claim (cuenta mal aprovisionada) | `failed-precondition` | HTTP 400 |
| Email ya usado por otro tenant | `already-exists` | HTTP 409 |
| Fallo inesperado del Admin SDK | `internal` | HTTP 500. **Nunca filtrar el stack al cliente** |

> Regla: **`permission-denied` para "sé quién eres y no puedes"**, `invalid-argument` para "lo que
> me mandaste no tiene sentido". No mezclar: un atacante distingue los dos y la señal es útil para
> depurar, pero el mensaje nunca debe revelar el estado interno (p.ej. no decir "ese restaurante
> tiene 3 admins").

---

### Pattern 2 — Llamada desde Flutter Web con errores tipados

```dart
// panel_admin/lib/core/firebase_providers.dart (añadir)
@Riverpod(keepAlive: true)
FirebaseFunctions firebaseFunctions(Ref ref) =>
    FirebaseFunctions.instanceFor(region: 'us-central1');
```

```dart
// panel_admin/lib/features/equipo/equipo_controller.dart
Future<void> crearStaff({
  required String email,
  required String password,
  required String nombre,
  required String rol,
  String? restauranteId,          // solo lo manda el super_admin
}) async {
  try {
    final callable = ref.read(firebaseFunctionsProvider)
        .httpsCallable('crearUsuarioStaff');
    final res = await callable.call<Map<String, dynamic>>({
      'email': email, 'password': password, 'nombre': nombre, 'rol': rol,
      if (restauranteId != null) 'restauranteId': restauranteId,
    });
    // res.data => {uid, creado, rol, restauranteId}
  } on FirebaseFunctionsException catch (e) {
    // e.code es el string del HttpsError ('permission-denied', …)
    throw EquipoException(switch (e.code) {
      'permission-denied' => 'No tienes permiso para crear ese usuario.',
      'invalid-argument'  => e.message ?? 'Datos inválidos.',
      'already-exists'    => 'Ese correo ya está registrado en otro restaurante.',
      'not-found'         => 'El restaurante no existe.',
      'unauthenticated'   => 'Tu sesión expiró. Vuelve a iniciar sesión.',
      _                   => 'No se pudo crear el usuario. Intenta de nuevo.',
    });
  }
}
```

**Emulador de Functions en el bootstrap** (patrón idéntico al de Auth/Firestore ya existente):

```dart
// core/firebase_bootstrap.dart — añadir DENTRO del if (useEmulators)
FirebaseFunctions.instanceFor(region: 'us-central1')
    .useFunctionsEmulator('127.0.0.1', 5001);
```

`useFunctionsEmulator(String host, int port, {bool automaticHostMapping = true})` mapea
`127.0.0.1`/`localhost` → `10.0.2.2` en Android exactamente igual que `useAuthEmulator` y
`useFirestoreEmulator` — **el comentario ya presente en `firebase_bootstrap.dart` sigue siendo
correcto para las tres** [VERIFIED: fuente de `cloud_firestore-6.8.0/lib/src/firestore.dart:142-148`
en el pub cache local + fuente de `firebase_functions.dart` en flutterfire/main].

⚠️ **Región:** hay que usar la MISMA región en la función (`region: 'us-central1'`) y en el cliente
(`instanceFor(region: 'us-central1')`). Un desajuste produce un 404 opaco. `us-central1` es el
default y no requiere `instanceFor`, pero **declararlo explícitamente en ambos lados** elimina toda
una clase de bug.

---

### Pattern 3 — Suite de `firestore.rules`, con foco en QUERIES denegadas

Éste es el patrón más importante de la fase: es el único modo de fallo que los fakes
(`fake_cloud_firestore`) no reproducen nunca, porque no tienen motor de rules.

```javascript
// scripts/test/rules/categorias.test.mjs
import { readFileSync } from 'node:fs';
import { after, before, beforeEach, describe, it } from 'node:test';
import {
  initializeTestEnvironment, assertSucceeds, assertFails,
} from '@firebase/rules-unit-testing';
import { collection, doc, getDocs, query, setDoc, where, orderBy } from 'firebase/firestore';

let testEnv;

before(async () => {
  testEnv = await initializeTestEnvironment({
    projectId: 'demo-gri-rules',          // prefijo demo- => nunca toca un proyecto real
    firestore: { rules: readFileSync('../firestore.rules', 'utf8') },
  });
});
after(() => testEnv.cleanup());

beforeEach(async () => {
  await testEnv.clearFirestore();
  // Semilla con rules DESACTIVADAS: una categoría activa y una inactiva.
  await testEnv.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    await setDoc(doc(db, 'categorias/c-activa'),
      { restauranteId: 'demo', nombre: 'Bebidas', orden: 1, activo: true });
    await setDoc(doc(db, 'categorias/c-inactiva'),
      { restauranteId: 'demo', nombre: 'Oculta', orden: 2, activo: false });
  });
});

// ── Contextos por rol: los custom claims van en el 2º argumento ──────────────
const cliente = () => testEnv.authenticatedContext('uid-cliente');           // sin claims
const adminDemo = () => testEnv.authenticatedContext('uid-admin', {
  role: 'admin_restaurante', rid: 'demo',
});
const adminOtro = () => testEnv.authenticatedContext('uid-admin-b', {
  role: 'admin_restaurante', rid: 'otro',
});
const superAdmin = () => testEnv.authenticatedContext('uid-super', {
  role: 'super_admin',
});

describe('categorias — query pública vs rules', () => {
  // ⛔ EL BUG 1b. Esta query se deniega SIEMPRE, no "cuando hay una inactiva".
  it('query SIN where(activo) del cliente → DENEGADA', async () => {
    const db = cliente().firestore();
    await assertFails(getDocs(query(
      collection(db, 'categorias'), where('restauranteId', '==', 'demo'),
    )));
  });

  // ✅ El arreglo. El filtro replica exactamente lo que exige la regla.
  it('query CON where(activo == true) → PERMITIDA', async () => {
    const db = cliente().firestore();
    await assertSucceeds(getDocs(query(
      collection(db, 'categorias'),
      where('restauranteId', '==', 'demo'),
      where('activo', '==', true),
    )));
  });

  // Regresión: prueba que el filtro no es cosmético — la inactiva no sale.
  it('la query filtrada NO devuelve la categoría inactiva', async () => {
    const db = cliente().firestore();
    const snap = await getDocs(query(
      collection(db, 'categorias'),
      where('restauranteId', '==', 'demo'), where('activo', '==', true),
    ));
    if (snap.docs.length !== 1) throw new Error(`esperaba 1, vino ${snap.docs.length}`);
  });

  // El staff del tenant SÍ puede ver los inactivos (rama menuStaffOf de la regla).
  it('admin del tenant: query sin where(activo) → PERMITIDA', async () => {
    const db = adminDemo().firestore();
    await assertSucceeds(getDocs(query(
      collection(db, 'categorias'),
      where('restauranteId', '==', 'demo'), orderBy('orden'),
    )));
  });

  // Aislamiento multi-tenant.
  it('admin de OTRO tenant: misma query → DENEGADA', async () => {
    const db = adminOtro().firestore();
    await assertFails(getDocs(query(
      collection(db, 'categorias'), where('restauranteId', '==', 'demo'),
    )));
  });
});
```

**Por qué la primera query falla siempre.** Documentación oficial, textual:
`"When writing queries to retrieve documents, keep in mind that security rules are not filters —
queries are all or nothing."` y `"Cloud Firestore evaluates a query against its potential result set
instead of the actual field values for all of your documents. If a query could potentially return
documents that the client does not have permission to read, the entire request fails."` El ejemplo
oficial es tajante: `"Even if the user authored every story in the database, the query is rejected"`
[CITED: firebase.google.com/docs/firestore/security/rules-query].

> 📌 **Corrección a `CONCERNS.md`:** ese documento describe el bug 1b como "se rompe *en cuanto*
> alguien marca un producto agotado". Es más grave: **está roto desde el día uno, incluso con el
> seed prístino donde todo está activo.** El planner debe reflejarlo así porque cambia la
> prioridad y hace el test de regresión trivial de escribir.

**Cómo se corre:** el emulador es prerequisito y `firebase emulators:exec` lo levanta, ejecuta y lo
apaga.

```jsonc
// scripts/package.json — scripts a añadir
{
  "scripts": {
    "seed": "node seed_firebase.mjs",
    "test:rules": "firebase emulators:exec --only firestore --project demo-gri-rules \"node --test test/rules/\"",
    "test:functions": "firebase emulators:exec --only auth,functions,firestore --project demo-gri \"node --test test/functions/\"",
    "test": "npm run test:rules && npm run test:functions"
  }
}
```

**Organización recomendada de la suite:** *por colección* (un archivo por `match` de las rules), no
por rol. Razón: cada archivo de rules cambia por colección; con esta organización, tocar
`match /pedidos` te dice exactamente qué archivo de test revisar. Los roles se cubren dentro de cada
archivo con los helpers `cliente()/adminDemo()/adminOtro()/superAdmin()` compartidos desde un
`test/rules/_contexts.mjs`.

**Cobertura mínima que el planner debe exigir** (una prueba `assertSucceeds` + una `assertFails` por
rama):

| Colección | Casos que NO pueden faltar |
|---|---|
| `categorias` / `productos` | query sin filtro → falla · query con filtro → pasa · staff del tenant ve inactivos · staff de otro tenant denegado |
| `mesas` | transiciones válidas de `transMesa` (4) · transiciones inválidas (p.ej. `disponible→limpieza`) · update que toca más que `estado`+`updatedAt` → falla · cliente moviendo a `limpieza` → falla |
| `sesiones` | create de cliente con mesa `ocupada` → falla · `set()` sobre sesión cerrada (se evalúa como update) → falla · dueño pide cuenta → pasa · otro cliente pide la cuenta ajena → falla |
| `pedidos` | create con `sesionId` de otra persona → falla (anti-spoofing) · matriz rol×transición: `mesero` intentando `enviado→aceptado` → falla; `en_preparacion→servido` por mesero → pasa |
| `reservas` | `fecha` pasada → falla · `numPersonas > capacidad` de la mesa → falla · cancelar reserva ajena → falla |
| `calificaciones` | pedido no servido → falla · sesión no cerrada → falla · update/delete → siempre falla |
| `usuarios` | auto-registro con `role: 'admin_restaurante'` → **falla (escalada)** · update de `role` propio → falla |
| `restaurantes` | create por no-super → falla · update de super tocando algo distinto de `activo` → falla |

---

### Pattern 4 — Tests de la matriz de autorización de la callable

Dos niveles, y ambos hacen falta.

**Nivel A — unitario puro (rápido, exhaustivo).** Cubre la combinatoria de escalada sin emulador:

```javascript
// functions/test/auth-matrix.test.js
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { autorizarAlta } from '../src/auth-matrix.js';

const CASOS = [
  // [callerRole, callerRid, rolPedido, ridPedido, esperado]
  ['super_admin',       null,   'admin_restaurante', 'pizza-uno', {ok:true, rid:'pizza-uno'}],
  ['super_admin',       null,   'mesero',            'pizza-uno', {ok:true, rid:'pizza-uno'}],
  ['super_admin',       null,   'cocina',            'pizza-uno', {ok:true, rid:'pizza-uno'}],
  ['admin_restaurante', 'demo', 'mesero',            undefined,   {ok:true, rid:'demo'}],
  ['admin_restaurante', 'demo', 'mesero',            'demo',      {ok:true, rid:'demo'}],
  ['admin_restaurante', 'demo', 'admin_restaurante', 'demo',      {ok:true, rid:'demo'}], // LOCKED: permitido
  ['admin_restaurante', 'demo', 'cocina',            'demo',      {ok:true, rid:'demo'}],

  // ── ESCALADA 1: nadie asigna super_admin ────────────────────────────────
  ['super_admin',       null,   'super_admin',       'demo',      {ok:false, code:'invalid-argument'}],
  ['admin_restaurante', 'demo', 'super_admin',       'demo',      {ok:false, code:'invalid-argument'}],

  // ── ESCALADA 2: admin tocando OTRO rid ──────────────────────────────────
  ['admin_restaurante', 'demo', 'mesero',            'otro',      {ok:false, code:'permission-denied'}],
  ['admin_restaurante', 'demo', 'admin_restaurante', 'otro',      {ok:false, code:'permission-denied'}],

  // ── Llamadores no autorizados ───────────────────────────────────────────
  ['mesero',            'demo', 'cocina',            'demo',      {ok:false, code:'permission-denied'}],
  ['cocina',            'demo', 'mesero',            'demo',      {ok:false, code:'permission-denied'}],
  ['cliente',           null,   'mesero',            'demo',      {ok:false, code:'permission-denied'}],
  [undefined,           null,   'mesero',            'demo',      {ok:false, code:'permission-denied'}],

  // ── Payload basura ──────────────────────────────────────────────────────
  ['super_admin',       null,   'MESERO',            'demo',      {ok:false, code:'invalid-argument'}],
  ['super_admin',       null,   'mesero',            'Demo Café', {ok:false, code:'invalid-argument'}],
  ['super_admin',       null,   'mesero',            undefined,   {ok:false, code:'invalid-argument'}],
  ['admin_restaurante', undefined, 'mesero',         undefined,   {ok:false, code:'failed-precondition'}],
];

for (const [callerRole, callerRid, rolPedido, ridPedido, esperado] of CASOS) {
  test(`${callerRole}(${callerRid}) → ${rolPedido}@${ridPedido}`, () => {
    const r = autorizarAlta({ callerRole, callerRid, rolPedido, ridPedido });
    assert.equal(r.ok, esperado.ok);
    if (esperado.ok) assert.equal(r.rid, esperado.rid);
    else assert.equal(r.code, esperado.code);
  });
}
```

**Nivel B — integración con emulador (pocos casos, alta fidelidad).** Prueba que el token real llega
decodificado con los claims y que el Admin SDK escribe lo que debe. Patrón:

```javascript
// scripts/test/functions/crear-usuario-staff.e2e.mjs
// Requiere: firebase emulators:exec --only auth,functions,firestore
import { initializeApp } from 'firebase/app';
import { getAuth, connectAuthEmulator, signInWithEmailAndPassword } from 'firebase/auth';
import { getFunctions, connectFunctionsEmulator, httpsCallable } from 'firebase/functions';
import { initializeApp as initAdmin } from 'firebase-admin/app';
import { getAuth as adminAuth } from 'firebase-admin/auth';

// El Admin SDK detecta FIREBASE_AUTH_EMULATOR_HOST/FIRESTORE_EMULATOR_HOST,
// que emulators:exec inyecta automáticamente en el proceso hijo.
const admin = initAdmin({ projectId: 'demo-gri' });

// 1. Sembrar el llamador CON claims (esto es lo que ningún fake puede hacer).
const u = await adminAuth(admin).createUser({ email: 'a@demo.dev', password: 'Demo!1234' });
await adminAuth(admin).setCustomUserClaims(u.uid, { role: 'admin_restaurante', rid: 'demo' });

// 2. Cliente JS contra los emuladores.
const app = initializeApp({ apiKey: 'fake-api-key', projectId: 'demo-gri' });
const auth = getAuth(app);  connectAuthEmulator(auth, 'http://127.0.0.1:9099',
                                                { disableWarnings: true });
const fns  = getFunctions(app, 'us-central1');
connectFunctionsEmulator(fns, '127.0.0.1', 5001);

// 3. Login DESPUÉS de setCustomUserClaims → el token nace con los claims.
await signInWithEmailAndPassword(auth, 'a@demo.dev', 'Demo!1234');

const crear = httpsCallable(fns, 'crearUsuarioStaff');

// ✅ camino feliz
await crear({ email:'m@demo.dev', password:'Demo!1234', nombre:'Mesero', rol:'mesero' });

// ⛔ escalada de tenant: debe rechazar con permission-denied
await assert.rejects(
  () => crear({ email:'x@otro.dev', password:'Demo!1234', nombre:'X',
                rol:'mesero', restauranteId:'otro' }),
  (e) => e.code === 'functions/permission-denied',
);
```

Datos que hacen viable este patrón: el Auth emulator emite **tokens sin firmar** que
`"are only accepted by other Firebase emulators, or the Firebase Admin SDK when configured"`, y
`"No additional setup is needed to prototype and test interactions between Authentication and Cloud
Functions or Firebase Security Rules"` [CITED: firebase.google.com/docs/emulator-suite/connect_auth].
El Admin SDK sí soporta `setCustomUserClaims` contra el emulador — es lo que ya hace hoy
`scripts/seed_firebase.mjs` en modo emuladores [VERIFIED: scripts/seed_firebase.mjs:158-182].

> ⚠️ **No usar `firebase-functions-test` en modo offline para esta matriz.** Ese modo te deja
> inventar el `context.auth`, lo que convierte el test en una tautología: estarías probando tu propio
> mock de los claims, no la verificación del token. Es exactamente el patrón de fake que dejó pasar
> los bugs de la Fase 10 (`TESTING.md`: *"fakes have no rules engine at all"*).

---

### Pattern 5 — Tokens de diseño: `ThemeExtension` + constantes, sin paquete compartido

**Recomendación: duplicación deliberada, NO paquete compartido.** Razones concretas:

1. Las dos paletas **ya divergen a propósito** y está documentado en el código:
   `app_cliente` usa `background #f7f7f7` / `text #222222`; `panel_admin` usa `#f5f6f8` / `#252525`,
   porque vienen de dos mockups distintos (`documentos/indexcliente.html` vs `documentos/index.html`).
   Un paquete compartido obligaría a parametrizar esa divergencia — más complejidad que la que evita.
2. Los tokens específicos no se solapan: `mesaDisponibleBg`/`sidebar`/`statIcon*` sólo existen en el
   panel; `chipConfirmada*`/`primaryTint` sólo en el cliente. La intersección real es
   `primary`, `primaryDark`, `gray`, `green` — 4 constantes.
3. Un paquete `path:` en `pubspec.yaml` funciona (`gri_design: {path: ../packages/gri_design}`) pero
   introduce: un tercer `pubspec` que mantener, `flutter pub get` en cascada, y riesgo en
   `flutter build web` si el path se resuelve mal en CI. Coste desproporcionado para 4 constantes.
4. La decisión LOCKED dice explícitamente *"conservar la identidad visual actual"*. Un refactor a
   paquete compartido es justo el tipo de cambio estructural que puede producir drift visual.

**Qué SÍ hacer:** en cada app, tres piezas.

```dart
// core/design_tokens.dart  (uno por app — con un comentario de sincronización)
//
// SINCRONIZAR con panel_admin/lib/core/design_tokens.dart:
// primary, primaryDark, gray, green y TODA la escala GriSpacing son idénticos.
// Los demás tokens son propios de esta app (mockups distintos).

/// Escala de espaciado 4-pt. Sustituye los literales sueltos (16/18/20/24…).
abstract final class GriSpacing {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
  static const double xxl = 48;
}

/// Radios y breakpoints ya usados de facto en el repo — sólo se les da nombre.
abstract final class GriRadius {
  static const double card = 15;    // == griTheme.cardTheme (ya vigente)
  static const double chip = 999;
}

abstract final class GriBreakpoints {
  /// Panel: sidebar colapsa a 70px (valor YA vigente en app_shell.dart:72).
  static const double compact  = 750;
  /// Panel: grids pasan a 4 columnas (valor YA vigente en dashboard_screen.dart:37).
  static const double expanded = 1100;
  /// Cliente: ancho de columna de contenido en pantallas grandes
  /// (== el maxWidth 480 actual, ahora como techo y no como jaula).
  static const double contenidoMax = 480;
}
```

**`ThemeExtension` vs clase de constantes — cuál para qué.** No es un o-lo-uno-o-lo-otro:

| Token | Vehículo | Por qué |
|---|---|---|
| Colores de marca (`primary`, `background`, `text`, `gray`) | **`ColorScheme` de `ThemeData`** (ya existe vía `ColorScheme.fromSeed`) + `GriColors` | Ya funciona; no tocar |
| Colores **semánticos de dominio** (estado de mesa, chip de reserva, estado de pedido) | **`ThemeExtension<GriSemanticColors>`** | Son "colores del tema" que hoy están dispersos en `theme.dart` **y** duplicados en `models/pedido.dart:78-95`. Un `ThemeExtension` los unifica bajo `Theme.of(context).extension<GriSemanticColors>()!` y elimina la segunda paleta |
| Tipografía | **`ThemeData.textTheme`** | Hoy 0 usos y 49 `FontWeight.bold` literales. Definir `titleLarge/titleMedium/bodyLarge/bodyMedium/labelSmall` en `griTheme` y migrar |
| Espaciado, radios, breakpoints | **clase de constantes** (`abstract final class`) | No dependen del tema ni se interpolan; meterlos en `ThemeExtension` obliga a un `BuildContext` para leer un `16.0`. Sobre-ingeniería |

`ThemeExtension<T>` exige implementar `copyWith()` y `lerp()`, se registra en
`ThemeData(extensions: [...])` y se lee con `Theme.of(context).extension<T>()`
[CITED: api.flutter.dev/flutter/material/ThemeExtension-class.html].

```dart
// core/theme.dart — la extensión semántica
@immutable
class GriSemanticColors extends ThemeExtension<GriSemanticColors> {
  const GriSemanticColors({
    required this.pedidoEnviadoFg, required this.pedidoEnviadoBg,
    required this.pedidoAceptadoFg, required this.pedidoAceptadoBg,
    // …
  });
  final Color pedidoEnviadoFg, pedidoEnviadoBg, pedidoAceptadoFg, pedidoAceptadoBg;

  @override
  GriSemanticColors copyWith({Color? pedidoEnviadoFg, /*…*/}) =>
      GriSemanticColors(
        pedidoEnviadoFg: pedidoEnviadoFg ?? this.pedidoEnviadoFg, /*…*/);

  @override
  GriSemanticColors lerp(ThemeExtension<GriSemanticColors>? other, double t) {
    if (other is! GriSemanticColors) return this;
    return GriSemanticColors(
      pedidoEnviadoFg: Color.lerp(pedidoEnviadoFg, other.pedidoEnviadoFg, t)!, /*…*/);
  }
}

final ThemeData griTheme = ThemeData(
  useMaterial3: true,
  colorScheme: ColorScheme.fromSeed(seedColor: GriColors.primary),
  extensions: const <ThemeExtension<dynamic>>[ _semanticos ],
  textTheme: const TextTheme(/* …la escala tipográfica única… */),
  // …lo ya existente…
);
```

---

### Pattern 6 — Quitar el `maxWidth: 480` global sin romper nada

El error a evitar es borrar el `ConstrainedBox` de `app_shell.dart:31-35`: eso estira la app a todo
el ancho del navegador y **empeora** el desorden. El patrón correcto es convertir la jaula en un
techo con adaptación.

```dart
// app_cliente/lib/features/shared/app_shell.dart
body: LayoutBuilder(
  builder: (context, c) {
    // < 480: móvil real → sin restricción, ocupa todo (hoy también lo hace).
    // 480–840: web/tablet estrecho → columna centrada de 480 (comportamiento actual).
    // >= 840: tablet ancho / desktop → columna más generosa, NO 480.
    final maxW = c.maxWidth < GriBreakpoints.contenidoMax
        ? double.infinity
        : (c.maxWidth < 840 ? GriBreakpoints.contenidoMax : 720);
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxW),
        child: navigationShell,
      ),
    );
  },
),
```

**Por qué esto no rompe los tests existentes:** los 91 tests de `app_cliente` pumpean pantallas
sueltas dentro de `MaterialApp(home: …)`, **no dentro del `AppShell`** (verificado en
`TESTING.md`: el patrón es `ProviderScope(overrides: …, child: MaterialApp(home: SomeScreen()))`).
El `AppShell` sólo se ejercita en producción. Aun así, el plan debe añadir un test de widget que
pumpee el shell a 3 anchos distintos y compruebe el `maxWidth` resultante — es la única red
de seguridad de este cambio.

**Breakpoints — qué valores usar.** Material 3 define compact 0–599 / medium 600–839 / expanded
840–1199 / large 1200–1599 / extra-large ≥1600 dp [CITED: m3.material.io/foundations/layout/breakpoints/overview
vía búsqueda; ASUMIDO el límite exacto de extra-large]. Pero **el panel ya usa 750 y 1100 de facto**
en `app_shell.dart:72` y `dashboard_screen.dart:37-42`. Cambiarlos a 600/840/1200 desplazaría el
punto de colapso del sidebar y de las columnas del grid → es un cambio *visual*, prohibido por la
decisión LOCKED.

> **Recomendación:** nombrar los valores existentes (750 / 1100) en `GriBreakpoints` y propagarlos a
> las 6 pantallas del panel que hoy no adaptan. Documentar en un comentario que difieren de M3 a
> propósito para preservar la identidad actual. En `app_cliente`, que hoy no tiene ninguno, sí usar
> los de M3 (600 / 840) porque no hay nada que preservar.

---

### Pattern 7 — Accesibilidad verificable en tests

El repo ya tiene 175 tests de widget con `tester.pumpWidget`. Añadir a11y cuesta 3 líneas por test:

```dart
testWidgets('login cumple tap targets Android (48dp)', (tester) async {
  final handle = tester.ensureSemantics();
  await tester.pumpWidget(_login());
  await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
  await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
  handle.dispose();
});
```

Guidelines integradas en `flutter_test`: `androidTapTargetGuideline` (mínimo **48×48**),
`iOSTapTargetGuideline` (44×44), `textContrastGuideline` (ratio WCAG),
`labeledTapTargetGuideline` (todo nodo con acción de tap debe tener label)
[CITED: api.flutter.dev/flutter/flutter_test/AccessibilityGuideline-class.html].

Esto convierte tres hallazgos de la auditoría en gates automatizados:
- `home_screen.dart:308-310` con target de 45dp → lo caza `androidTapTargetGuideline`.
- 5 de 6 `IconButton` sin tooltip y los emoji-como-icono → los caza `labeledTapTargetGuideline`.
- `#777777` sobre blanco (≈4.48:1, bajo el 4.5:1 de WCAG AA) → lo caza `textContrastGuideline`.

⚠️ `textContrastGuideline` es el más ruidoso: si al aplicarlo salen decenas de fallos, el plan debe
aplicarlo **solo a las pantallas del camino crítico** (login, registro, menú, carrito) y dejar el
resto anotado, en vez de bloquear la fase. `#777777` es el caso conocido: subirlo a `#6E6E6E` da
≈5.0:1 sin cambio perceptible de identidad.

---

### Anti-patrones a evitar

- **Filtrar client-side lo que la regla exige server-side.** Es literalmente el bug 1b. Regla mental:
  *si la rule menciona `resource.data.X`, la query DEBE tener `where('X', …)`*.
- **Poner la validación de la matriz de roles en Flutter.** El panel debe ocultar lo que el usuario
  no puede hacer (UX), pero la decisión vive en la función. Prohibido explícitamente en CONTEXT.
- **Devolver el error crudo del Admin SDK al cliente.** `throw new HttpsError('internal', 'mensaje genérico', e.code)`
  — nunca `e.message` completo (puede filtrar emails, uids, estructura interna).
- **Usar `console.log` en la función.** Usar `logger` de `firebase-functions` (structured logging en
  Cloud Logging). Coherente con la directiva "no print en backend" de CLAUDE.md.
- **Confiar en el emulador para validar índices.** No los valida. Ver Pitfall 3.
- **Borrar el `ConstrainedBox(maxWidth: 480)` sin reemplazo.** Ver Pattern 6.
- **Un `ThemeExtension` para el espaciado.** Obliga a `BuildContext` para leer una constante.
- **Regenerar `firebase.json` con `firebase init functions` sin revisar el diff.** Ver Pitfall 5.

---

## No lo Construyas a Mano

| Problema | No construyas | Usa en su lugar | Por qué |
|---|---|---|---|
| Asignar roles a usuarios | Un campo `role` en Firestore consultado por las rules con `get()` | **Custom claims en el token** (ya vigente) | Cada `get()` cuenta contra el presupuesto de 10 access-calls y crea desync. El header de `firestore.rules` ya lo documenta y lo prohíbe |
| Crear usuarios en Auth desde el cliente | `createUserWithEmailAndPassword` en el panel | **Admin SDK en la callable** | Crear el usuario desde el cliente **desloguea al admin actual** (el SDK cambia la sesión activa) y no puede escribir claims |
| Probar rules | Aserciones a mano contra el emulador con `fetch` | **`@firebase/rules-unit-testing`** | Gestiona proyectos aislados, `clearFirestore()`, contextos con claims, y `withSecurityRulesDisabled` para sembrar |
| Sembrar datos de test saltándose las rules | Un segundo proyecto o rules "de test" | **`testEnv.withSecurityRulesDisabled()`** | Mismo proyecto, mismas rules reales, solo el setup exento |
| Comparar errores de la callable en Flutter | Parsear `e.toString()` | **`FirebaseFunctionsException.code`** | Códigos estables y tipados |
| Layout adaptativo | Cálculos con `MediaQuery.of(context).size` | **`LayoutBuilder`** | `MediaQuery` da el tamaño de la *ventana*; dentro de un shell con sidebar de 250px eso es el número equivocado |
| Verificar tamaño de tap targets | Medir `RenderBox` a mano | **`meetsGuideline(androidTapTargetGuideline)`** | Recorre el árbol de semántica completo |
| Interpolar colores del tema al cambiar de tema | `Color.lerp` disperso | **`ThemeExtension.lerp`** | Es el contrato del framework |

**Idea clave:** en esta fase, casi todo lo que parece "hay que escribir código" ya tiene una
primitiva oficial. El único código genuinamente propio y no trivial es (a) la matriz de autorización
—40 líneas puras y muy testeables— y (b) el generador de slug.

---

## Inventario de Estado en Runtime

Aunque no es una fase de rename, sí introduce infraestructura nueva sobre un proyecto Firebase vivo.
Estado que **no vive en el repo** y que la fase toca o necesita:

| Categoría | Encontrado | Acción requerida |
|---|---|---|
| **Proyecto Firebase activo** | `.firebaserc` **NO EXISTE** en la raíz. `PROJECT_ID = 'p-gri-b5b40'` está hardcodeado en `scripts/seed_firebase.mjs:41`. `firebase-tools` no está global (solo en `scripts/node_modules/.bin`) | Crear `.firebaserc` con alias `default: p-gri-b5b40` **y** un alias `demo` para tests, o pasar `--project` en todos los scripts npm. Sin esto, `emulators:exec` falla o usa el proyecto equivocado |
| **Plan de facturación** | El proyecto está (presumiblemente) en Spark. Cloud Functions exige **Blaze para desplegar** | Checkpoint humano: subir a Blaze antes del deploy. **No bloquea desarrollo ni tests** (el emulador funciona en cualquier plan) |
| **Custom claims de usuarios existentes** | 6 usuarios sembrados por `seed_firebase.mjs` con `{role, rid}` en Auth del proyecto real. Ninguno se toca en esta fase | Ninguna migración. La callable escribe claims **nuevos**, no reescribe los del seed |
| **Índices desplegados en producción** | `firestore.indexes.json` tiene 9 índices; **cero de `categorias`**. Estado real en el proyecto: desconocido (el deploy de la Fase 10 quedó como checkpoint humano pendiente según `STATE.md`) | Verificar con `firebase firestore:indexes` antes de asumir. Los índices nuevos requieren `firebase deploy --only firestore:indexes` y **tardan minutos en construirse** |
| **Rules desplegadas** | Idem: `firestore.rules` está en el repo pero el deploy quedó pendiente (checkpoint humano Fase 10) | El E2E del bloque 4 absorbe ese checkpoint |
| **APIs de GCP** | Cloud Functions v2 requiere habilitar Cloud Build, Artifact Registry, Cloud Run y Eventarc | El CLI las habilita en el primer deploy, pero puede fallar por permisos. Prever en el runbook |
| **Java para el emulador** | **No está en PATH.** Existe el JBR de Android Studio: `C:\Program Files\Android\Android Studio\jbr\bin\java.exe` (OpenJDK 21.0.10) | Wave 0: script que exporte `JAVA_HOME`/PATH, o instalar un JDK. Sin esto la suite de rules no corre |
| **Node local vs runtime desplegado** | Local: **v24.13.1**. Cloud Functions soporta **20 y 22** | Poner `engines: {"node": "22"}` en `functions/package.json`. El emulador avisará del desajuste pero funciona |
| **`scripts/firestore-debug.log`** | Artefacto de la corrida del emulador del 2026-08-16, sin `.gitignore` aparente | Añadir `*-debug.log` y `functions/node_modules/` al `.gitignore` |

---

## Trampas Comunes

### Trampa 1 — "La query del menú falla sólo cuando hay algo agotado"

**Qué sale mal:** se planifica el arreglo del bug 1b como un edge case de baja prioridad.
**Por qué pasa:** `CONCERNS.md` lo describe así, y es intuitivo pensar que Firestore filtra.
**Realidad:** la query se deniega **siempre**, incluso con todos los documentos activos, porque
Firestore evalúa la regla contra la *consulta*. `"Even if the user authored every story in the
database, the query is rejected."` [CITED: firebase.google.com/docs/firestore/security/rules-query]
**Cómo evitarlo:** tratarlo como bloqueante P0. El test de regresión es de 6 líneas (Pattern 3).
**Señal de alerta:** cualquier plan que diga "reproducir marcando un producto como agotado".

### Trampa 2 — Los claims no llegan al usuario recién creado

**Qué sale mal:** se crea el `admin_restaurante` desde el panel, el usuario inicia sesión y el panel
lo rechaza o lo trata como cliente.
**Por qué pasa:** `setCustomUserClaims` sólo se refleja `"the next time a new [ID token] is issued"`;
un token vivo dura ~1 h [CITED: firebase.google.com/docs/auth/admin/custom-claims].
**Cómo evitarlo:** tres capas.
1. La callera crea la cuenta **antes** de su primer login → el token nace con claims. Es el caso
   normal y por eso el seed ya lo documenta ("correr el seed ANTES del primer login").
2. `claimsProvider` de `panel_admin` ya llama `getIdTokenResult(true)` (force refresh) — verificado
   en `panel_admin/lib/core/firebase_providers.dart`. **Mantener ese `true`.**
3. Si un `admin_restaurante` se promueve a sí mismo… no puede (nadie se asigna rol a sí mismo). Pero
   si el super_admin cambia el rid de alguien logueado, ese usuario necesita
   `FirebaseAuth.instance.currentUser!.getIdToken(true)` o un re-login. **Recomendación:** el panel
   muestra "pídele que cierre sesión y vuelva a entrar" tras un cambio de rol.
**Señal de alerta:** un test que crea el usuario y hace login en el mismo `it` sin `getIdToken(true)`.

### Trampa 3 — El emulador de Firestore no valida índices compuestos

**Qué sale mal:** la suite de rules pasa en verde, el E2E contra emulador pasa en verde, y el panel
sigue roto en producción con `FAILED_PRECONDITION`.
**Por qué pasa:** `"The Firestore emulator does not track composite indexes and will instead execute
any valid query. You should test your app against a real Firestore instance to determine which
indexes you require."` [CITED: docs.cloud.google.com/firestore/native/docs/emulator]
**Cómo evitarlo:** no existe herramienta oficial de detección estática. Compensar con **las dos**:
1. Un **audit script** (Node, ~60 líneas) que haga grep de `.where(` / `.orderBy(` en
   `app_cliente/lib` y `panel_admin/lib`, derive la firma de cada query y la contraste contra
   `firestore.indexes.json`, fallando el build si falta alguna. Esto es la tarea 1d "chequeo de que
   cada query del código tenga su índice declarado" del SCOPE.
2. Un paso explícito en el runbook E2E que corra el flujo contra el **proyecto real** tras
   `firebase deploy --only firestore:indexes` y espere a que los índices terminen de construirse.
**Señal de alerta:** un plan que dé por cerrado el bug 1c sólo con tests de emulador.

### Trampa 4 — Región desalineada entre función y cliente

**Qué sale mal:** `httpsCallable` devuelve `not-found` / `internal` sin explicación.
**Por qué pasa:** la función se despliega en `us-central1` (default) y el cliente la busca en otra,
o al revés. En Flutter Web el síntoma se disfraza de error de CORS.
**Cómo evitarlo:** declarar `region: 'us-central1'` en `onCall` **y** usar
`FirebaseFunctions.instanceFor(region: 'us-central1')` en Dart. Nunca uno solo de los dos.
**Señal de alerta:** un `FirebaseFunctions.instance` sin región junto a un `onCall` con `region`.

### Trampa 5 — `firebase init functions` reescribiendo la configuración existente

**Qué sale mal:** el `firebase.json` de la raíz —que hoy sólo tiene `firestore` y `emulators`— sale
del init con puertos cambiados, un bloque `hosting` que nadie pidió, o `.firebaserc` apuntando a
otro proyecto.
**Por qué pasa:** `firebase init` es un asistente interactivo que reescribe el archivo completo.
**Cómo evitarlo:** **no correr `firebase init functions`.** Crear `functions/` a mano (son 3
archivos) y editar `firebase.json` quirúrgicamente:

```jsonc
{
  "firestore": { "rules": "firestore.rules", "indexes": "firestore.indexes.json" },
  "functions": [                      // array => codebase con nombre, extensible
    {
      "source": "functions",
      "codebase": "default",
      "ignore": ["node_modules", ".git", "*-debug.log", "test/**"]
    }
  ],
  "emulators": {
    "auth":      { "port": 9099 },
    "functions": { "port": 5001 },    // ← NUEVO
    "firestore": { "port": 8080 },
    "ui":        { "enabled": true, "port": 4000 }
  }
}
```
El CLI acepta `functions` como objeto único o como array de codebases
[CITED: firebase.google.com/docs/functions/organize-functions]. Puerto 5001 es el default del
emulador de Functions [CITED: firebase.google.com/docs/emulator-suite/install_and_configure].
**Señal de alerta:** un diff de `firebase.json` con más de 10 líneas cambiadas.

### Trampa 6 — Crear el usuario staff con el SDK cliente "porque es más rápido"

**Qué sale mal:** al llamar `createUserWithEmailAndPassword` desde el panel, **el admin actual queda
deslogueado** porque el SDK cliente cambia la sesión activa al usuario recién creado.
**Por qué pasa:** es el comportamiento documentado del SDK cliente; una sola sesión por instancia.
**Cómo evitarlo:** es exactamente la razón por la que la decisión LOCKED es la callable. No hay
atajo. (El workaround histórico —una `FirebaseApp` secundaria— sigue sin poder escribir claims.)

### Trampa 7 — Slug de restaurante que rompe el escáner de QR

**Qué sale mal:** se crea "Pizzería Doña Ana" → slug `pizzería-doña-ana` o `Pizzeria-Dona-Ana`, el
doc ID de mesa queda `GRI-MESA-pizzería-doña-ana-001`, y el escáner lo rechaza con
`^GRI-MESA-[a-z0-9-]+-\d{3}$` [VERIFIED: app_cliente/lib/features/sesion_qr/scan_screen.dart:41].
Las mesas quedan permanentemente inescaneables.
**Cómo evitarlo:** (a) generar el slug con la función del Code Example de abajo, (b) **mostrarlo al
usuario antes de confirmar** (exigido por CONTEXT), (c) validarlo con la MISMA regexp en el panel y
en la callable, (d) comprobar que `restaurantes/{slug}` no exista antes de crear —la lectura de
`restaurantes` es pública, así que el check es barato.
**Nota sutil:** un `.set()` sobre un slug ya existente se evalúa como **update**, no como create, y
las rules sólo permiten al super cambiar `activo` → error críptico de `permission-denied` en vez de
"ese slug ya existe". El check previo evita el mensaje confuso.

### Trampa 8 — Claims escritos, doc espejo no (o al revés)

**Qué sale mal:** la callable hace `setCustomUserClaims` y luego falla el `set` del espejo → usuario
con permisos pero invisible en la lista de equipo; o al revés.
**Por qué pasa:** Auth y Firestore son sistemas distintos; no hay transacción entre ambos.
**Cómo evitarlo:** asumir la no-atomicidad y hacer la función **idempotente y re-ejecutable**: el
mismo email dos veces converge al mismo estado (patrón ya probado en `seed_firebase.mjs`). Si falla
a mitad, reintentar el alta con el mismo email lo repara. Documentarlo en la UI ("volver a crear con
el mismo correo repara una alta incompleta").

### Trampa 9 — Node 24 local vs runtime 22

**Qué sale mal:** el emulador avisa `Your requested "node" version "22" doesn't match your global
version "24"` y se ignora; luego una API de Node 24 usada en la función falla al desplegar.
**Cómo evitarlo:** ceñirse a APIs de Node 22. Node 24 **no** es runtime soportado
[CITED: firebase.google.com/docs/functions/manage-functions].

---

## Ejemplos de Código

### Generación de slug (Dart, sin dependencias)

```dart
// panel_admin/lib/features/configuracion/slug.dart
//
// El doc ID del restaurante DEBE casar con ^[a-z0-9]+(-[a-z0-9]+)*$ porque
// el doc ID de mesa es GRI-MESA-{slug}-{NNN} y el escáner del cliente valida
// ^GRI-MESA-[a-z0-9-]+-\d{3}$ (scan_screen.dart:41).

const _acentos = {
  'á':'a','à':'a','ä':'a','â':'a','ã':'a','å':'a',
  'é':'e','è':'e','ë':'e','ê':'e',
  'í':'i','ì':'i','ï':'i','î':'i',
  'ó':'o','ò':'o','ö':'o','ô':'o','õ':'o',
  'ú':'u','ù':'u','ü':'u','û':'u',
  'ñ':'n','ç':'c',
};

final _slugValido = RegExp(r'^[a-z0-9]+(-[a-z0-9]+)*$');

String generarSlug(String nombre) {
  var s = nombre.toLowerCase().trim();
  _acentos.forEach((k, v) => s = s.replaceAll(k, v));
  s = s.replaceAll(RegExp(r'[^a-z0-9]+'), '-')   // todo lo demás → guion
       .replaceAll(RegExp(r'-+'), '-')            // colapsar guiones
       .replaceAll(RegExp(r'^-|-$'), '');         // sin guiones en los extremos
  return s;
}

bool slugEsValido(String s) => s.isNotEmpty && s.length <= 40 && _slugValido.hasMatch(s);

// "Pizzería Doña Ana"  → "pizzeria-dona-ana"   ✓
// "  El  Fogón--47  "  → "el-fogon-47"         ✓
// "★★★"                → ""                    ✗ → pedir slug manual al usuario
```

### Crear el restaurante (cliente directo, rules ya lo permiten)

```dart
Future<void> crearRestaurante({
  required String slug, required String nombre, required String direccion,
}) async {
  final db = ref.read(firestoreProvider);
  if (!slugEsValido(slug)) {
    throw RestauranteException('El identificador debe ser letras, números y guiones.');
  }
  // Lectura pública (rules: allow read: if true) — check barato de colisión.
  if ((await db.doc('restaurantes/$slug').get()).exists) {
    throw RestauranteException('Ya existe un restaurante con el identificador "$slug".');
  }
  await db.doc('restaurantes/$slug').set({
    'nombre': nombre, 'direccion': direccion, 'activo': true,
    'califProm': 0.0, 'califCount': 0,
    'createdAt': FieldValue.serverTimestamp(),
  });   // rules: allow create if isSuper()
}
```

### Las queries corregidas (bug 1b)

```dart
// app_cliente/lib/features/restaurantes/restaurantes_provider.dart:46-53 → sustituir por:

// categorias: replica EXACTAMENTE `resource.data.activo == true` de la rule.
final catsSnap = await db
    .collection('categorias')
    .where('restauranteId', isEqualTo: id)
    .where('activo', isEqualTo: true)
    .get();

// productos: replica `activo == true && disponible == true`.
final prodsSnap = await db
    .collection('productos')
    .where('restauranteId', isEqualTo: id)
    .where('activo', isEqualTo: true)
    .where('disponible', isEqualTo: true)
    .get();

// El filtrado client-side (líneas 60 y 68) se ELIMINA — ya es redundante.
// El sort de categorías por `orden` se MANTIENE client-side (ver nota de índices).
```

### Menú del panel (bug 1c)

```dart
// panel_admin/lib/features/menu/menu_provider.dart:35-39 — la query NO cambia,
// lo que falta es el índice.
db.collection('categorias')
  .where('restauranteId', isEqualTo: rid)
  .orderBy('orden')
  .snapshots();
```

```jsonc
// firestore.indexes.json — añadir a "indexes":
{
  "collectionGroup": "categorias",
  "queryScope": "COLLECTION",
  "fields": [
    { "fieldPath": "restauranteId", "order": "ASCENDING" },
    { "fieldPath": "orden",         "order": "ASCENDING" }
  ]
}
```

---

## Índices: qué se necesita exactamente

Regla oficial: varios filtros de **igualdad** sobre campos distintos se resuelven con los índices
automáticos de campo único (`citiesRef.where("state","==","CO").where("name","==","Denver")`).
Hace falta índice compuesto manual `"if you need to run a compound query that uses a range
comparison (<, <=, >, or >=) or if you need to sort by a different field"`
[CITED: firebase.google.com/docs/firestore/query-data/index-overview].

Aplicado a esta fase:

| Query | ¿Índice compuesto? | Definición | Estado |
|---|---|---|---|
| `categorias` where `restauranteId` + `orderBy('orden')` — **panel, bug 1c** | **SÍ** (igualdad + orden por otro campo) | `(restauranteId ASC, orden ASC)` | ❌ **FALTA — añadir** |
| `productos` where `restauranteId` + `activo` + `disponible` — **cliente, bug 1b** | **NO** (solo igualdades) | — | ✅ nada que hacer |
| `categorias` where `restauranteId` + `activo` — **cliente, bug 1b** | **NO** (solo igualdades) | — | ✅ nada que hacer |
| `categorias` where `restauranteId` + `activo` + `orderBy('orden')` — **si** el plan decide ordenar server-side | **SÍ** | `(restauranteId ASC, activo ASC, orden ASC)` | ⚠️ solo si se elige esa vía |

> **Decisión que el plan debe tomar explícitamente:** en `restauranteDetalle` (cliente), ¿ordenar
> las categorías server-side o client-side?
> **Recomendación: client-side** (como hoy). El N por restaurante es pequeño (4 categorías en el
> seed), el `..sort((a,b) => a.orden.compareTo(b.orden))` ya existe y funciona, y evitar el índice
> `(restauranteId, activo, orden)` elimina un punto de fallo más (índices que tardan en construirse
> y que el emulador no valida). El comentario de `restaurantes_provider.dart:33-36` ya razonaba así
> y sigue siendo correcto.

**Total de índices a añadir en esta fase: 1.**

---

## Panel: qué pantalla de equipo se muestra según el claim

**Recomendación: UNA sola pantalla adaptativa `/equipo`, no dos.**

Justificación: cerrada la matriz, el super_admin y el admin_restaurante hacen exactamente lo mismo
—crear usuarios con rol `admin_restaurante | mesero | cocina`— y sólo difieren en **un campo del
formulario**: el selector de restaurante. Dos pantallas duplicarían el formulario, la validación, la
tabla y el manejo de errores para ahorrar un `if`.

```dart
// Gating: el claim ya está disponible vía claimsProvider (existe hoy).
final claims = await ref.watch(claimsProvider.future);   // ({role, rid})
final puedeGestionarEquipo =
    claims.role == 'super_admin' || claims.role == 'admin_restaurante';
```

Tres puntos de aplicación, en este orden:

1. **Ítem del sidebar** (`panel_admin/lib/features/shared/app_shell.dart`): mostrar "Equipo" solo si
   `puedeGestionarEquipo`. Es UX, no seguridad.
2. **`redirect` del `GoRouter`** (`panel_admin/lib/app.dart:31`): si la ruta es `/equipo` y el rol no
   califica → redirigir a `/`. Impide llegar por URL directa en web. Sigue siendo UX.
3. **Selector de restaurante dentro del formulario**: visible **solo** para `super_admin`. Para
   `admin_restaurante` el campo no existe y el cliente **no manda `restauranteId`**; la función usa
   su claim. (Aunque lo mandara, la función lo rechaza — Pattern 1.)

Añadir también un **404 con go_router** (pedido del SCOPE bloque 2): `errorBuilder` está disponible
en `GoRouter(...)` de go_router 17.5.0 [VERIFIED: pub cache `go_router-17.5.0/lib/src/router.dart:180-181`].

```dart
GoRouter(
  initialLocation: '/',
  errorBuilder: (context, state) => NotFoundScreen(uri: state.uri),
  // …
)
```

> ⚠️ Ni el sidebar ni el `redirect` son seguridad. La seguridad es (a) la matriz dentro de la
> callable y (b) `firestore.rules`. Los tests de escalada deben ejercitar la **función**, no la UI.

---

## Estado del Arte

| Enfoque antiguo | Enfoque actual | Cuándo cambió | Impacto en esta fase |
|---|---|---|---|
| `functions.https.onCall((data, context) => …)` (v1) | `onCall((request) => …)` con `request.data` / `request.auth` (v2) | firebase-functions v4+; v2 es el default de la raíz en v7 | Todo el código de esta fase debe ser v2. Cualquier snippet con `context.auth` es v1 y NO aplica |
| `require('firebase-functions')` monolítico | Subpath exports: `firebase-functions/https`, `/firestore`, `/params` | v6→v7 | `import { onCall, HttpsError } from 'firebase-functions/https'` [VERIFIED: exports del tarball 7.3.2] |
| `@firebase/testing` con `initializeTestApp` / `initializeAdminApp` | `@firebase/rules-unit-testing` con `initializeTestEnvironment` + `RulesTestContext` | v2 del paquete (2021); hoy en v5.0.1 | Ignorar todo tutorial que use `initializeAdminApp` — es la API muerta. Muchos blogposts (incluido el de DEV que aparece en las búsquedas) siguen en la vieja |
| Runtime Node 18 | Node 20 / 22 | Node 18 deprecado a inicios de 2025; 14 y 16 decomisionados | `engines: {"node": "22"}` |
| Provider (Flutter) | Riverpod 3.x | — | Ya vigente en el repo, sin cambios |

**Obsoleto / a no usar:**
- `context.auth` en callables → `request.auth`.
- `initializeAdminApp` / `initializeTestApp` de `@firebase/testing` → `initializeTestEnvironment`.
- `firebase-functions-test` en modo offline para probar autorización → emulador (razones arriba).
- `responsive_framework` / `flutter_adaptive_scaffold` para este caso → `LayoutBuilder`.

---

## Registro de Suposiciones

| # | Afirmación | Sección | Riesgo si es incorrecta |
|---|---|---|---|
| A1 | El proyecto `p-gri-b5b40` está hoy en plan Spark (no Blaze) | Inventario runtime | Bajo. Si ya está en Blaze, una tarea del runbook se vuelve no-op |
| A2 | El límite superior de la clase "extra-large" de M3 es ≥1600 dp | Pattern 6 | Nulo — la recomendación es conservar 750/1100, no usar M3 en el panel |
| A3 | `firebase emulators:exec` inyecta `FIREBASE_AUTH_EMULATOR_HOST` y `FIRESTORE_EMULATOR_HOST` en el proceso hijo | Pattern 4 | Bajo. Lo afirma el propio comentario de `seed_firebase.mjs:14-16`, escrito tras usarlo en la Fase 10. Si fallara, se exportan a mano |
| A4 | Los 175 tests Flutter actuales no pumpean `AppShell` directamente | Pattern 6 | Medio. Si alguno lo hace, el cambio de `maxWidth` podría romperlo. **Verificar con `grep -rn "AppShell" */test/` antes de planear la tarea** |
| A5 | El super_admin no lleva claim `rid` (es `null`) | Pattern 1 | Bajo — confirmado en `seed_firebase.mjs:47` (`rid: null`) y en el comentario de `claimsProvider` |
| A6 | `#777777` sobre blanco da ≈4.48:1 | Pattern 7 | Nulo — dato de la auditoría UI, y el gate automatizado lo confirmará o refutará |
| A7 | El usuario acepta que el primer `super_admin` siga naciendo del seed/Console | Bootstrap | **Medio-alto.** La cadena de bootstrap sigue teniendo un eslabón manual: alguien debe crear el super_admin inicial. La callable resuelve del segundo escalón para abajo. **El planner debería confirmarlo con el usuario** — ver Preguntas Abiertas |
| A8 | La región elegida es `us-central1` | Patterns 1-2 | Bajo. `southamerica-east1` daría menos latencia en Colombia pero la callable se invoca pocas veces al día (altas de staff) |

---

## Preguntas Abiertas

1. **¿Cómo nace el primer `super_admin` en un proyecto Firebase nuevo?**
   - Qué sabemos: la callable exige un llamador con claim `super_admin`. Ese primer claim no puede
     salir de la callable (huevo y gallina), y las rules impiden que nadie se autoascienda
     (`usuarios/{uid}` create fuerza `role: 'cliente'`).
   - Qué falta: decidir la vía. Tres opciones: (a) mantener `scripts/seed_firebase.mjs` como paso de
     despliegue documentado —status quo, requiere `serviceAccountKey.json`—; (b) una segunda callable
     `bootstrapPlataforma` que solo funcione si **no existe ningún super_admin** y luego se
     autoinhabilite; (c) hacerlo desde la Firebase Console a mano.
   - Recomendación: **(a) para esta fase**, porque es lo que ya existe y funciona, y el SCOPE dice
     que la fase debe arrancar "desde base vacía" **con el super_admin ya presente** (paso 1 del
     runbook es "Crear restaurante como super_admin"). Documentar (b) como mejora futura. **Pero
     esto debe confirmarse con el usuario antes de planear**, porque roza la decisión LOCKED de "sin
     scripts ni clave de servicio en manos de nadie".

2. **¿Se envía email de bienvenida / el staff cambia su contraseña?**
   - Qué sabemos: la callable fija una contraseña que el admin teclea. No hay flujo de invitación.
   - Recomendación: v1 con contraseña temporal escrita por el admin, más el flujo de "cambiar
     contraseña" que **ya existe** en `perfil_screen.dart:131,143`. Un email de invitación
     (`generatePasswordResetLink`) es alcance nuevo — probablemente diferido.

3. **¿Se puede desactivar/eliminar staff desde el panel?**
   - El SCOPE pide crear, no borrar. `firestore.rules` prohíbe `delete` en `usuarios`.
   - Recomendación: fuera de alcance en esta fase; anotarlo como deuda.

4. **¿La pantalla de equipo lista los usuarios existentes?**
   - Requiere leer `usuarios` filtrando por `restauranteId`, pero la regla actual es
     `allow read: if signedIn() && (request.auth.uid == uid || isSuper())` — **un
     `admin_restaurante` NO puede listar a su propio equipo.**
   - Esto sería un **cambio de rules** (añadir `|| staffOf(resource.data.restauranteId)` o similar),
     que el CONTEXT no contempla ("las rules ya lo permiten — no hay que tocar la regla" se refería
     solo a `restaurantes`). **Decisión requerida:** o se amplía la regla de `usuarios` para lectura
     por el admin del tenant, o la pantalla de equipo es solo de alta (sin listado), o el listado lo
     devuelve una segunda callable. Recomendación: **ampliar la regla** (es el cambio más pequeño y
     coherente con el modelo) y añadir sus tests de rules correspondientes.

---

## Disponibilidad del Entorno

| Dependencia | Requerida por | Disponible | Versión | Fallback |
|---|---|---|---|---|
| Node.js | Functions, tests JS, seed | ✓ | v24.13.1 | — (pero `engines` debe decir 22) |
| npm | instalación de deps | ✓ | 10.9.7 | — |
| Flutter SDK | ambas apps | ✓ | 3.47.0 stable (2026-08-11) | — |
| `firebase-tools` | emuladores, deploy | ✓ (local) | 15.27.0 en `scripts/node_modules/.bin/firebase` | Invocar vía `npm run` desde `scripts/`, o `npx firebase` |
| **Java (JDK ≥11)** | **emulador Firestore** | **✗ no está en PATH** | JBR 21.0.10 en `C:\Program Files\Android\Android Studio\jbr` | **Exportar `JAVA_HOME` a la ruta del JBR** o instalar Temurin 21 |
| Emulador de Functions | tests e2e de la callable | ✓ (no necesita Java) | parte de firebase-tools | — |
| Emulador de Auth | tests e2e de la callable | ✓ (no necesita Java) | parte de firebase-tools | — |
| `.firebaserc` | `emulators:exec`, `deploy` | **✗ no existe** | — | Pasar `--project` explícito en cada script npm |
| Plan Blaze | **deploy** de Functions | ✗ (presumiblemente Spark) | — | **Emular funciona en cualquier plan** — solo bloquea el deploy final |
| `serviceAccountKey.json` | seed contra proyecto real | ✗ (gitignored, no presente) | — | Emuladores para todo el desarrollo |
| Dispositivo/emulador Android | E2E del escáner QR real | desconocido | — | `mobile_scanner` funciona en Chrome sobre localhost (contexto seguro); además existe el input manual del código |

**Dependencias faltantes que BLOQUEAN:**
- **Java en PATH** — sin esto no corre ni un solo test de `firestore.rules`. Debe ser lo primero
  del Wave 0. Comando de verificación:
  `"/c/Program Files/Android/Android Studio/jbr/bin/java.exe" -version` (probado ✓).
- **`.firebaserc`** — trivial de crear, pero sin él `emulators:exec` no sabe qué proyecto usar.

**Dependencias faltantes con fallback:**
- **Blaze**: no bloquea desarrollo ni tests. Bloquea únicamente el paso final del runbook E2E
  contra el proyecto real. Es un checkpoint humano, igual que el que quedó pendiente en la Fase 10.

---

## Arquitectura de Validación

### Frameworks de test

| Suite | Framework | Config | Comando rápido | Comando completo |
|---|---|---|---|---|
| `app_cliente` | `flutter_test` (SDK) | ninguna | `flutter test test/<file>` | `flutter test` (91 tests hoy) |
| `panel_admin` | `flutter_test` (SDK) | ninguna | `flutter test test/<file>` | `flutter test` (84 tests hoy) |
| rules | `node --test` + `@firebase/rules-unit-testing` | **no existe — Wave 0** | `node --test test/rules/categorias.test.mjs` | `npm run test:rules` (desde `scripts/`) |
| matriz de auth (pura) | `node --test` | **no existe — Wave 0** | `node --test functions/test/` | idem (instantáneo, sin emulador) |
| callable e2e | `node --test` + `firebase` JS SDK | **no existe — Wave 0** | — | `npm run test:functions` |

### Mapa requisito → test

| Bloque | Comportamiento | Tipo | Comando automatizado | ¿Existe? |
|---|---|---|---|---|
| 1a | Slug se genera y valida correctamente | unit | `flutter test test/configuracion/slug_test.dart` | ❌ Wave 0 |
| 1a | Crear restaurante escribe `restaurantes/{slug}` y rechaza duplicado | widget+fake | `flutter test test/configuracion/crear_restaurante_test.dart` | ❌ Wave 0 |
| 1a | Matriz de autorización: 18 casos incl. escalada | unit puro | `node --test functions/test/auth-matrix.test.js` | ❌ Wave 0 |
| 1a | Callable rechaza admin de A creando en B (token real) | e2e emulador | `npm run test:functions` | ❌ Wave 0 |
| 1a | Callable rechaza `rol: 'super_admin'` de cualquier llamador | e2e emulador | `npm run test:functions` | ❌ Wave 0 |
| 1a | Callable es idempotente (mismo email 2× → mismo uid) | e2e emulador | `npm run test:functions` | ❌ Wave 0 |
| 1b | Query sin `where(activo)` es DENEGADA por rules | rules | `npm run test:rules` | ❌ Wave 0 |
| 1b | Query con filtros es PERMITIDA y no devuelve inactivos | rules | `npm run test:rules` | ❌ Wave 0 |
| 1b | `restauranteDetalle` construye el menú con las queries nuevas | widget+fake | `flutter test test/restaurantes/list_test.dart` | ⚠️ existe, ampliar |
| 1c | El índice `categorias(restauranteId, orden)` está declarado | audit script | `node scripts/audit_indexes.mjs` | ❌ Wave 0 |
| 1d | **Base vacía**: ambas apps no crashean y muestran guía | widget+fake | `flutter test test/**/vacio_test.dart` (`FakeFirebaseFirestore()` **sin** seed) | ❌ Wave 0 |
| 1d | Rules: cobertura por colección (tabla del Pattern 3) | rules | `npm run test:rules` | ❌ Wave 0 |
| 2 | Toggle de contraseña alterna `obscureText` en los 5 campos | widget | `flutter test test/auth/` `test/perfil/` | ⚠️ ampliar |
| 2 | Confirmar contraseña valida coincidencia | widget | `flutter test test/auth/login_register_test.dart` | ⚠️ ampliar |
| 2 | Menú vacío muestra estado guiado, no pantalla en blanco | widget | `flutter test test/pedidos/menu_vacio_test.dart` | ❌ Wave 0 |
| 2 | 404 de go_router renderiza `NotFoundScreen` | widget | `flutter test test/router_404_test.dart` | ❌ Wave 0 |
| 3 | `AppShell` adapta `maxWidth` a 3 anchos | widget | `flutter test test/shared/app_shell_responsive_test.dart` | ❌ Wave 0 |
| 3 | Pantallas críticas cumplen `androidTapTargetGuideline` | widget a11y | `flutter test test/a11y/` | ❌ Wave 0 |
| 3 | Pantallas críticas cumplen `labeledTapTargetGuideline` | widget a11y | `flutter test test/a11y/` | ❌ Wave 0 |
| 3 | Sin overflow en `reserva_wizard` / `reservas_screen` con texto largo | widget | pumpear con nombre de 60 chars a 320px de ancho | ❌ Wave 0 |
| 4 | Flujo completo desde base vacía | **manual** | `docs/SMOKE-E2E-v2.md` | ❌ Wave 0 (runbook) |

### Frecuencia de muestreo

- **Por commit de tarea:** el archivo de test tocado (`flutter test test/<file>` o `node --test <file>`).
- **Por merge de ola:** `flutter test` de la app afectada + `npm test` desde `scripts/`.
- **Gate de fase:** los 4 en verde — `app_cliente` (91+N), `panel_admin` (84+N), `npm run test:rules`,
  `npm run test:functions` — más `flutter analyze` 0 issues en ambas, más el runbook manual del bloque 4.

### Huecos de Wave 0

- [ ] `JAVA_HOME` / PATH apuntando al JDK — **bloquea todo lo de rules**
- [ ] `.firebaserc` con alias `default` y `demo`
- [ ] `functions/package.json` + `functions/index.js` + `engines.node = "22"`
- [ ] `firebase.json`: bloque `functions` + `emulators.functions.port = 5001`
- [ ] `scripts/package.json`: deps de test + scripts `test:rules` / `test:functions` / `test`
- [ ] `scripts/test/rules/_contexts.mjs` — helpers de contexto por rol (fixture compartido)
- [ ] `functions/test/auth-matrix.test.js`
- [ ] `scripts/audit_indexes.mjs` — audit estático query↔índice
- [ ] Helper `buildFakeFirestoreVacio()` en ambos `test/helpers/firebase_fakes.dart`
- [ ] `.gitignore`: `functions/node_modules/`, `*-debug.log`, `functions/lib/`

---

## Dominio de Seguridad

### Categorías ASVS aplicables

| Categoría ASVS | Aplica | Control estándar en esta fase |
|---|---|---|
| V2 Autenticación | **sí** | Firebase Auth (email/password). La callable exige `request.auth`; contraseña mínima 6 (mínimo de Firebase). Considerar exigir 8+ en el formulario del panel |
| V3 Gestión de sesión | sí | Gestionada por el SDK. Relevante: propagación de claims tras cambio de rol (Trampa 2) |
| V4 Control de acceso | **sí — el núcleo de la fase** | `firestore.rules` (datos) + matriz de la callable (alta de usuarios). **Ambas capas requieren tests dedicados** |
| V5 Validación de entrada | **sí** | Validar en la callable: email, longitud de password, `rol ∈ ROLES_ASIGNABLES`, `rid` contra `SLUG_RE`. **No confiar en la validación del formulario Flutter** |
| V6 Criptografía | no directamente | Firebase gestiona hash de password y firma de tokens. Nada que implementar |
| V7 Manejo de errores y logging | sí | `HttpsError` con mensajes genéricos hacia el cliente; `logger.info/error` con `uid` del llamador para auditoría. Nunca devolver stacks |
| V13 API y servicios web | sí | CORS: `onCall` pone `cors: true` por defecto [VERIFIED: `lib/v2/providers/https.js:111-115` del tarball 7.3.2] — Flutter Web funciona sin configuración extra |

### Patrones de amenaza conocidos para este stack

| Patrón | STRIDE | Mitigación estándar |
|---|---|---|
| **Escalada horizontal**: admin de A crea staff en B | Elevation of Privilege | `autorizarAlta` fuerza `rid = callerRid` para `admin_restaurante`. Test dedicado obligatorio |
| **Escalada vertical**: cualquiera se asigna `super_admin` | Elevation of Privilege | `ROLES_ASIGNABLES` es allow-list sin `super_admin`. Test dedicado obligatorio |
| **Auto-ascenso vía Firestore**: cliente escribe `usuarios/{uid}` con `role:'admin_restaurante'` | Elevation of Privilege | Ya mitigado por `firestore.rules:169-176` — **pero sin ningún test hoy**. Añadir a la suite de rules |
| **Secuestro de cuenta por email**: admin de B "crea" un email que ya es admin de A y le reescribe los claims | Elevation of Privilege / Tampering | El paso 5 de la callable comprueba `prev.rid !== d.rid` → `already-exists`. **Esta protección no es obvia y debe estar en el plan explícitamente** |
| **Enumeración de emails** vía respuestas distintas de la callable | Information Disclosure | Los mensajes de `already-exists` revelan que el email existe. Aceptable: el llamador ya es staff autenticado, no un anónimo |
| **Fuga de datos por query no filtrada** | Information Disclosure | Las rules son all-or-nothing; el riesgo real aquí es de *disponibilidad* (bug 1b), no de fuga |
| **Abuso de la callable** (creación masiva de usuarios) | Denial of Service | `maxInstances: 5` en las opciones. App Check daría defensa real — **DEFERRED**, documentar |
| **Callable invocada sin App Check** (bot con token robado) | Spoofing | `enforceAppCheck: true` es el control. Requiere configurar App Check en ambas apps → alcance nuevo. **Recomendación: diferir y documentar como deuda de seguridad conocida** |

---

## Riesgos y Orden de Ejecución

### Qué va primero (dependencias duras)

```
WAVE 0 — Infraestructura (BLOQUEA todo lo demás de tests)
  0.1  JAVA_HOME/PATH → JDK          ─┐
  0.2  .firebaserc                    ├─ sin esto no corre ni un test de rules
  0.3  scripts: deps + npm scripts   ─┘
  0.4  functions/ (package.json, index.js) + firebase.json
  0.5  helpers: _contexts.mjs, buildFakeFirestoreVacio()

WAVE 1 — Funcional (secuencial dentro, pero independiente del WAVE 3)
  1.1  Suite de rules: categorias + productos          ← prueba el bug 1b ANTES de arreglarlo
  1.2  Fix queries en restaurantes_provider.dart        ← el test 1.1 pasa a verde
  1.3  Índice categorias(restauranteId, orden) + audit_indexes.mjs
  1.4  auth-matrix.js + su test unitario                ← lógica pura, sin emulador
  1.5  crearUsuarioStaff callable + test e2e emulador   ← depende de 1.4
  1.6  Panel: pantalla crear restaurante (slug)         ← independiente de 1.4/1.5
  1.7  Panel: pantalla /equipo + gating + cloud_functions ← depende de 1.5 y 1.6
  1.8  Resto de la suite de rules (mesas, sesiones, pedidos, reservas, calificaciones, usuarios)
  1.9  Tests de base vacía en ambas apps

WAVE 2 — Quick wins UI (paralelizable con WAVE 1 y 3)
  2.1  Toggles de contraseña (5 campos) + confirmar contraseña
  2.2  Estados vacíos (crítico: menu_mesa_screen)
  2.3  Branding: manifest, index.html, favicon, ícono, splash
  2.4  404 go_router + confirmación al desactivar restaurante

WAVE 3 — Diseño y responsive (paralelizable con WAVE 1)
  3.1  design_tokens.dart (spacing/radius/breakpoints) en ambas apps
  3.2  textTheme + ThemeExtension semántica; unificar pedido.dart:78-95
  3.3  Migrar hex crudos a tokens (36 en panel, 9+4+4 en cliente)
  3.4  AppShell: maxWidth adaptativo + test de 3 anchos
  3.5  Responsive en las 6 pantallas del panel sin breakpoints
  3.6  Fix de overflows (reserva_wizard 340-361, reservas_screen)
  3.7  A11y: Semantics, tooltips, 48dp, contraste + tests meetsGuideline

WAVE 4 — Verificación E2E (al final, requiere todo lo anterior)
  4.1  docs/SMOKE-E2E-v2.md desde base VACÍA (11 pasos del SCOPE)
  4.2  [CHECKPOINT HUMANO] Blaze + deploy rules/indexes/functions + smoke real
```

### Qué se puede paralelizar

- **WAVE 2 y WAVE 3 son totalmente independientes del WAVE 1** salvo un punto de contacto:
  `core/theme.dart` de ambas apps. Si el WAVE 1 no toca temas (no debería), no hay conflicto.
- Dentro del WAVE 1, **1.6 (crear restaurante) no depende de 1.4/1.5** (la callable): el restaurante
  se crea directo contra Firestore. Puede ir en paralelo con la Function.
- 1.1/1.2/1.3 (los tres bugs) son mutuamente independientes entre sí.
- **`config.parallelization` está en 1** — el planner debe decidir si vale la pena subirlo o dejar
  el orden secuencial. Con paralelización 1, priorizar WAVE 1 (bloqueante para el usuario) sobre
  WAVE 3 (cosmético).

### Qué exige el emulador corriendo

| Requiere emulador | No lo requiere |
|---|---|
| Toda la suite de `firestore.rules` (Firestore emulator + **Java**) | `functions/test/auth-matrix.test.js` (lógica pura) |
| Test e2e de la callable (Auth + Functions + Firestore emulators) | Todos los `flutter test` (usan fakes in-memory) |
| Runbook E2E manual con las apps (`--dart-define=USE_EMULATORS=true`) | `audit_indexes.mjs` (lee archivos) |
| | Todo el WAVE 2 y WAVE 3 |

### Riesgos ordenados por severidad

| # | Riesgo | Prob. | Impacto | Mitigación |
|---|---|---|---|---|
| R1 | Java no configurable en el entorno → suite de rules imposible | Baja | **Alto** (mata el objetivo 1d) | JBR de Android Studio confirmado presente y funcional. Fallback: Temurin 21 |
| R2 | Blaze no aprobado por el usuario → la callable nunca se despliega | Media | Alto | Emular cubre desarrollo y tests. El plan debe aislar el deploy en un checkpoint humano separado, no como bloqueante de la fase |
| R3 | El bug 1c queda "verificado" solo contra emulador y sigue roto en prod | **Alta** | Alto | El `audit_indexes.mjs` es la mitigación real. No aceptar "tests verdes" como cierre del 1c |
| R4 | El listado de equipo exige un cambio de rules no previsto (Pregunta 4) | Alta | Medio | Resolver en `/gsd-discuss-phase` antes de planear |
| R5 | Quitar el `maxWidth: 480` produce drift visual y viola la decisión LOCKED | Media | Medio | Solo se relaja **por encima de 840px**; de 0 a 840 el comportamiento es idéntico al de hoy |
| R6 | `textContrastGuideline` genera decenas de fallos y bloquea el WAVE 3 | Media | Medio | Aplicarlo solo al camino crítico; el resto se anota |
| R7 | Migrar 36 hex crudos a tokens introduce cambios de color no intencionados | Media | Medio | Tarea mecánica 1:1 (hex → constante del MISMO valor). Prohibido "aprovechar y ajustar" ningún color |
| R8 | La cadena de bootstrap sigue teniendo un eslabón manual (super_admin inicial) | **Alta** | Medio | Pregunta Abierta 1 — confirmar con el usuario antes de planear |

---

## Fuentes

### Primarias (confianza ALTA)
- `firebase.google.com/docs/firestore/security/rules-query` — "rules are not filters"; query evaluada contra el potential result set
- `firebase.google.com/docs/functions/callable` — `onCall`, `request.auth.token`, `HttpsError`
- `firebase.google.com/docs/functions/get-started` — requisito de Blaze **solo para desplegar**; layout de `functions/`; runtimes 20/22
- `firebase.google.com/docs/functions/manage-functions` — runtimes soportados; `engines`; Node 24 no soportado
- `firebase.google.com/docs/functions/organize-functions` — `functions` como array de codebases en `firebase.json`
- `firebase.google.com/docs/rules/unit-tests` — API de `@firebase/rules-unit-testing` (`initializeTestEnvironment`, `authenticatedContext` con claims, `withSecurityRulesDisabled`, `clearFirestore`, `assertFails/Succeeds`, `emulators:exec`)
- `firebase.google.com/docs/emulator-suite/install_and_configure` — qué emuladores exigen Java; puertos default (auth 9099, functions 5001, firestore 8080, ui 4000)
- `firebase.google.com/docs/emulator-suite/connect_auth` — tokens sin firmar; interoperabilidad Auth↔Functions↔Rules; `FIREBASE_AUTH_EMULATOR_HOST`
- `firebase.google.com/docs/auth/admin/custom-claims` — `setCustomUserClaims`, límite 1000 bytes, propagación y `getIdToken(true)`
- `firebase.google.com/docs/firestore/query-data/index-overview` — igualdades múltiples sin índice compuesto; índice manual con orderBy en otro campo
- `docs.cloud.google.com/firestore/native/docs/emulator` — el emulador **no** valida índices compuestos
- `api.flutter.dev/flutter/material/ThemeExtension-class.html` — `copyWith`/`lerp`, registro y lectura
- `api.flutter.dev/flutter/flutter_test/AccessibilityGuideline-class.html` — guidelines integradas y tamaños mínimos
- **Tarball npm `firebase-functions@7.3.2`** (descargado y leído): `exports` con `./https`; `FunctionsErrorCode` completo (`lib/common/providers/https.d.ts:174`); `CallableRequest`; `cors: true` por defecto en `onCall` (`lib/v2/providers/https.js:111-115`)
- **Tarball npm `@firebase/rules-unit-testing@5.0.1`**: `peerDependencies: {firebase: ^12.0.0}`, `engines: node >=20`
- **pub cache local**: `cloud_firestore-6.8.0/lib/src/firestore.dart:120-160` (mapeo 10.0.2.2), `firebase_auth-6.5.7`, `go_router-17.5.0/lib/src/router.dart:180` (`errorBuilder`)
- **pub.dev API**: `cloud_functions` 6.3.6 (2026-08-03), deps y constraints
- **Repositorio** (leído directamente): `firestore.rules`, `firestore.indexes.json`, `firebase.json`, `scripts/package.json`, `scripts/seed_firebase.mjs`, ambos `pubspec.yaml`, ambos `core/theme.dart`, ambos `core/firebase_bootstrap.dart`, `panel_admin/lib/core/firebase_providers.dart`, `panel_admin/lib/app.dart`, `panel_admin/lib/features/dashboard/dashboard_screen.dart`, `panel_admin/lib/features/shared/app_shell.dart`, `app_cliente/lib/features/shared/app_shell.dart`, `app_cliente/lib/features/restaurantes/restaurantes_provider.dart`, `panel_admin/lib/features/menu/menu_provider.dart`, `app_cliente/lib/features/sesion_qr/scan_screen.dart`
- **Artefactos de la auditoría**: `.planning/codebase/CONCERNS.md`, `TESTING.md`, `audit/UI-REVIEW-app_cliente.md`, `audit/UI-REVIEW-panel_admin.md`

### Secundarias (confianza MEDIA)
- `raw.githubusercontent.com/firebase/flutterfire/main/.../firebase_functions.dart` — `useFunctionsEmulator` con `automaticHostMapping`
- `m3.material.io/foundations/layout/breakpoints/overview` (vía búsqueda) — clases compact/medium/expanded/large/extra-large
- `developer.android.com/develop/adaptive-apps/guides/use-window-size-classes` — valores dp de las clases
- `github.com/firebase/firebase-tools/issues/3103`, `issues/1475` — limitaciones históricas de callables + emulador (contexto, no base de decisión)

### Terciarias (confianza BAJA — no usadas como base de ninguna recomendación)
- `dev.to/zenika/firebase-callable-functions-tests-with-emulator-suite-42ik` — **descartada**: usa la API muerta `@firebase/testing` con `initializeAdminApp` y mocks de `firebase-functions`. Se incluye aquí como advertencia: es el resultado que más sube en las búsquedas y llevaría al patrón equivocado.

---

## Metadata

**Desglose de confianza:**
- Stack estándar: **ALTA** — todas las versiones verificadas contra npm/pub.dev en esta sesión; compatibilidad de `cloud_functions` con el pin `firebase_core 4.13.0` verificada contra la API de pub.dev
- Bugs de query/rules/índices: **ALTA** — citas textuales de docs oficiales, contrastadas con el código real del repo línea a línea
- Patrón de la callable y su matriz: **ALTA** para la API (typings leídos del tarball), **MEDIA-ALTA** para el diseño (es una recomendación razonada, no una cita)
- Testing de rules: **ALTA** — API verificada en la doc oficial y en el `package.json` del paquete
- Testing e2e de la callable: **MEDIA** — el patrón está compuesto a partir de las docs de Auth emulator + Functions emulator; no se encontró un ejemplo oficial completo de callable autenticada contra emulador. Se recomienda que la primera tarea que lo implemente sea un spike corto
- Diseño/responsive/a11y: **ALTA** — APIs de Flutter verificadas; los valores de breakpoint son decisión de proyecto, no de framework
- Entorno: **ALTA** — todo probado con comandos reales en esta máquina

**Fecha de investigación:** 2026-08-19
**Válido hasta:** 2026-09-18 (30 días). Excepción: las versiones de `firebase-functions`, `firebase-tools` y `cloud_functions` se mueven rápido (12 releases de firebase-tools en el último mes) — reverificar con `npm view` / pub.dev antes de fijar pins en el plan.
