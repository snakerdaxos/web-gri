<!-- GSD:project-start source:PROJECT.md -->
## Project

GRI es una plataforma multi-restaurante para gestión y reservas. Los clientes usan una app móvil (Flutter) para descubrir restaurantes, reservar mesas, escanear el QR de la mesa, pedir del menú, seguir su pedido en tiempo real, solicitar la cuenta y pagar en línea. Los restaurantes administran su operación (mesas, reservas, pedidos, menú, clientes, reportes) desde un panel web (Flutter Web), y la plataforma GRI es gestionada por un super-admin que crea los restaurantes.

**Core Value:** Un cliente puede sentarse en una mesa, escanear su QR, pedir del menú y recibir su comida — con el pedido fluyendo en tiempo real hacia cocina — sin intermediarios.

### Constraints

- **Tech stack**: Flutter/Dart (cliente móvil + admin web) — decisión del usuario
- **Tech stack**: FastAPI (Python) para la API — decisión del usuario
- **Tech stack**: MySQL como base de datos — decisión del usuario
- **Infraestructura**: MySQL y API se despliegan en Docker sobre Ubuntu Server; la conexión a BD debe configurarse hacia ese servidor (no localhost en producción)
- **Tiempo real**: WebSockets para pedidos y estados de mesa — decisión del usuario
- **Pagos**: pago en línea incluido; pasarela concreta (Wompi/PayU/Mercado Pago/Stripe) se decide en su fase

> **SUPERSEDED (Fase 10, 2026-08-19):** las decisiones de stack de arriba marcadas como API propia
> + base de datos relacional en Docker fueron **reemplazadas por Firebase** (Auth + Cloud Firestore +
> Cloud Functions). El tiempo real ya no usa WebSockets propios sino `onSnapshot` de Firestore, y los
> pagos en línea quedaron diferidos. Ver `## Technology Stack` para el stack vivo.
<!-- GSD:project-end -->

<!-- GSD:stack-start source:research/STACK.md -->
## Technology Stack

> **Corregido en la Fase 11 (2026-08-19).** La versión anterior de esta sección describía el
> backend FastAPI + Python + base de datos relacional que se **ARCHIVÓ en la Fase 10**. Lo de
> abajo es el stack VIVO: dos apps Flutter hablando directo con Firebase. No hay backend propio.

### Apps (Flutter)

| Pieza | Versión | Notas |
|---|---|---|
| Flutter SDK / Dart | 3.47 / Dart 3.9+ | Un solo toolchain para ambas apps |
| `app_cliente` | — | App de cliente: Android + Web |
| `panel_admin` | — | Panel de gestión: Flutter Web |
| `flutter_riverpod` + `riverpod_generator` + `riverpod_lint` | 3.x | Estado y DI (code-gen con `@riverpod`) |
| `go_router` | 17.5 | Navegación declarativa, deep links del QR de mesa |
| `freezed` + `json_serializable` + `build_runner` | latest | Modelos inmutables y (de)serialización |
| `mobile_scanner` | 7.x | Escaneo del QR de mesa (`GRI-MESA-{rid}-{NNN}`) |
| `qr_flutter` | latest | Generación del QR en el panel |
| `flutter_secure_storage` / `shared_preferences` | latest | Sesión y preferencias |
| `intl` | latest | Formato COP y fechas |

### Backend: Firebase (no hay servidor propio)

| Servicio | Uso |
|---|---|
| **Firebase Auth** | Email/contraseña + custom claims `{ role, rid }`. Roles: `super_admin`, `admin_restaurante`, `mesero`, `cocina`, cliente (= ausencia de claim `role`) |
| **Cloud Firestore** | Única base de datos. Tiempo real con `onSnapshot`, concurrencia con `runTransaction` |
| **`firestore.rules`** | **La capa de autorización del sistema.** Se evalúa contra la QUERY, no contra los documentos devueltos: toda query del cliente debe replicar en sus filtros lo que la regla exige por documento |
| **`firestore.indexes.json`** | Índices compuestos declarados (cada `where` + `orderBy` nuevo exige revisar si hace falta uno) |
| **Cloud Functions** | Node 22, carpeta `functions/`. Para lo que el cliente no puede hacer con seguridad: bootstrap del primer `super_admin` y alta de usuarios staff con custom claims (Admin SDK) |

Proyecto Firebase: `p-gri-b5b40`. Alias `demo` → `demo-gri` (proyecto ficticio solo para emuladores).

### Paquetes Firebase pineados (Flutter)

| Paquete | Versión | Dónde |
|---|---|---|
| `firebase_core` | 4.13.0 | ambas apps |
| `firebase_auth` | 6.5.7 | ambas apps |
| `cloud_firestore` | 6.8.0 | ambas apps |
| `cloud_functions` | 6.3.6 | solo `panel_admin` |

La configuración se genera con `flutterfire configure` → `lib/firebase_options.dart`.
**No** se usa `google-services.json` (el que hay en `documentos/` es de otro registro; ignorarlo).

### Node (tooling y Cloud Functions)

| Pieza | Versión | Notas |
|---|---|---|
| `scripts/` | ESM, Node local 24 | Seed idempotente + `firebase-tools` **local** (no global) |
| `firebase-tools` | 15.27.0 | En `scripts/devDependencies` |
| `firebase-admin` | 14.2.0 | Misma versión exacta en `scripts/` y en `functions/` |
| `firebase-functions` | 7.3.2 | `functions/` |
| Runtime de Cloud Functions | **Node 22** | `engines.node` en `functions/package.json`. Node 24 NO es runtime soportado |

### Tests

| Capa | Herramienta |
|---|---|
| Apps Flutter | `flutter_test` + `fake_cloud_firestore` (91 en `app_cliente`, 84 en `panel_admin`) |
| `firestore.rules` | `node --test` + `@firebase/rules-unit-testing` 5.0.1 contra el emulador de Firestore |
| Cloud Functions callables | `node --test` contra los emuladores de Auth + Functions + Firestore |

Emuladores: auth `9099` · functions `5001` · firestore `8080` · UI `4000`.
El emulador de Firestore exige una JVM; `scripts/run_emulators.mjs` la resuelve sola
(`JAVA_HOME` → PATH → JBR de Android Studio). Entrada: `cd scripts && npm test`.

### NO USAR

- **`backend/` está ARCHIVADO** (Fase 10) y se conserva solo como referencia de lógica de negocio.
  No planificar, no extender y no ejecutar nada contra él. Su base de datos relacional, su ORM,
  sus migraciones, su driver async, su servidor ASGI y sus 215 tests quedaron **fuera del sistema
  vivo** — cualquier plan que los mencione como stack actual está equivocado.
- Sin API REST propia, sin WebSockets propios: el tiempo real lo da Firestore.
- Pagos en línea: **diferidos** (hoy solo se "solicita la cuenta").
<!-- GSD:stack-end -->

<!-- GSD:conventions-start source:CONVENTIONS.md -->
## Conventions

Conventions not yet established. Will populate as patterns emerge during development.
<!-- GSD:conventions-end -->

<!-- GSD:architecture-start source:ARCHITECTURE.md -->
## Architecture

Architecture not yet mapped. Follow existing patterns found in the codebase.
<!-- GSD:architecture-end -->

<!-- GSD:skills-start source:skills/ -->
## Project Skills

No project skills found. Add skills to any of: `.claude/skills/`, `.agents/skills/`, `.cursor/skills/`, `.github/skills/`, or `.codex/skills/` with a `SKILL.md` index file.
<!-- GSD:skills-end -->

<!-- GSD:workflow-start source:GSD defaults -->
## GSD Workflow Enforcement

Before using Edit, Write, or other file-changing tools, start work through a GSD command so planning artifacts and execution context stay in sync.

Use these entry points:
- `/gsd-quick` for small fixes, doc updates, and ad-hoc tasks
- `/gsd-debug` for investigation and bug fixing
- `/gsd-execute-phase` for planned phase work

Do not make direct repo edits outside a GSD workflow unless the user explicitly asks to bypass it.
<!-- GSD:workflow-end -->



<!-- GSD:profile-start -->
## Developer Profile

> Profile not yet configured. Run `/gsd-profile-user` to generate your developer profile.
> This section is managed by `generate-claude-profile` -- do not edit manually.
<!-- GSD:profile-end -->
