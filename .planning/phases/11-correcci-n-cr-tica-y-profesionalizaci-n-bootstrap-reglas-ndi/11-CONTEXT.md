# Phase 11: Corrección Crítica y Profesionalización - Context

**Gathered:** 2026-08-19
**Status:** Ready for planning
**Source:** Auditoría del sistema (gsd-deep-map + auditores UI) — ver `SCOPE.md` en este directorio

<domain>
## Phase Boundary

Esta fase repara lo que la auditoría del 2026-08-19 encontró tras la migración a Firebase de la
Fase 10, y lleva ambas apps de "funciona en tests" a "un restaurante puede usarla".

**Estado de partida verificado:** `flutter analyze` da 0 issues en `app_cliente` y `panel_admin`,
y los 175 tests pasan. Ninguno de los defectos de abajo es detectable por linter o por la suite
actual — todos viven en el contrato con Firestore real o en la capa visual.

**Entra en la fase:**
- Que la plataforma arranque desde una base de datos vacía (crear restaurante y staff desde producto).
- Los tres bugs que rompen funciones con datos reales (query vs rules, índice faltante, bootstrap).
- Cerrar el punto ciego de tests que dejó pasar esos bugs.
- Quick wins de usabilidad y branding en ambas apps.
- Sistema de diseño: tokens, espaciado, responsive real, accesibilidad.
- Verificación E2E del flujo completo partiendo de cero.

**No entra:**
- Rediseño visual (se conserva la identidad actual — ver decisión bloqueada abajo).
- Pagos en línea (diferidos desde la Fase 10).
- Tiempo real más allá de lo que ya existe con `onSnapshot`.
- Reescribir el backend FastAPI archivado.
</domain>

<decisions>
## Implementation Decisions

### Alta de staff — LOCKED (decisión del usuario, 2026-08-19)
- Los usuarios staff se crean mediante una **Cloud Function callable** que ejecuta el Admin SDK
  del lado servidor y asigna los custom claims `{role, rid}`.
- Motivo: es la única opción que hace el producto autosuficiente — el `super_admin` da de alta un
  restaurante y su equipo desde el panel, sin consola ni scripts ni clave de servicio en manos de nadie.
- Implica añadir Cloud Functions (Node) al stack y el plan Blaze en Firebase.

**Delegación de roles — LOCKED (decisión del usuario, 2026-08-19):** la función acepta DOS tipos de
llamador con alcances distintos, y debe validar el claim del llamador antes de crear nada:

| Llamador | Puede crear usuarios de | Roles que puede asignar |
|---|---|---|
| `super_admin` | cualquier restaurante | `admin_restaurante`, `mesero`, `cocina` |
| `admin_restaurante` | **solo su propio** `rid` | `admin_restaurante`, `mesero`, `cocina` |

- El `super_admin` da de alta el restaurante y su `admin_restaurante` inicial.
- A partir de ahí, ese admin gestiona su propio equipo sin depender del super_admin — pero el
  super_admin conserva la capacidad de hacerlo también.
- **RESUELTO (decisión del usuario, 2026-08-19): sí.** Un `admin_restaurante` puede crear otro
  `admin_restaurante`, siempre acotado a su propio `rid`. Permite tener dos socios o gerentes y evita
  que el restaurante quede bloqueado si esa única persona pierde el acceso. Nunca puede crear un
  `super_admin` ni tocar otro `rid`.
- Escalada de privilegios prohibida en todos los casos: nadie puede asignar `super_admin`, y un
  `admin_restaurante` nunca puede tocar un `rid` distinto al suyo. Esto se valida **en la función**,
  no en el cliente, y debe tener tests dedicados.
- El panel necesita la pantalla de gestión de equipo correspondiente, visible según el rol del que
  ha iniciado sesión.

### Alcance visual — LOCKED (decisión del usuario, 2026-08-19)
- Se **conserva la identidad visual actual** (naranja `#FF4C05`, layout del mockup).
- El trabajo es de consistencia, no de rediseño: centralizar en tokens, aplicar escala de espaciado,
  hacer responsive de verdad y cumplir accesibilidad básica.
- No se rediseñan pantallas ni se cambia la paleta.

### Primer super_admin — LOCKED (decisión del usuario, 2026-08-19)
- Nace de una **Cloud Function de bootstrap única**: crea el primer `super_admin` **solo si no existe
  ninguno**, y a partir de ahí queda inerte para siempre.
- Motivo: cumple la decisión de producto autosuficiente — la plataforma se arranca desde una pantalla,
  sin scripts ni clave de servicio en manos de nadie.
- **Riesgo a mitigar explícitamente en el plan:** es una puerta de escalada de privilegios si se
  diseña mal. Requisitos mínimos: comprobar la inexistencia de cualquier `super_admin` de forma
  atómica (no una lectura seguida de una escritura), dejar rastro auditable de la invocación, y
  tests dedicados que verifiquen que una segunda llamada siempre falla, incluidas llamadas
  concurrentes.

### Lectura del equipo — cambio necesario en las rules
- Hoy `usuarios/{uid}` solo lo lee el propio usuario o el `super_admin`
  (`firestore.rules`, match `/usuarios/{uid}`). Un `admin_restaurante` **no puede listar su propio
  equipo**, así que la pantalla de gestión de personal no puede existir sin tocar la regla.
- Corrección al CONTEXT previo: cuando se dijo "no hay que tocar las rules", eso aplicaba solo a
  `restaurantes`. Esta regla sí cambia.
- La lectura debe quedar acotada al `rid` del llamador, sin abrir `usuarios` a más de lo necesario.

### Login con Google (Gmail) en la app cliente — LOCKED (decisión del usuario, 2026-08-19)
- La app cliente debe permitir **registrarse e iniciar sesión con Google**, además del email/contraseña
  actual. El proveedor ya está habilitado en el proyecto Firebase (`p-gri-b5b40`, número `703827387403`).
- Solo aplica a la app **cliente**. El panel sigue con email/contraseña — el staff se crea por la
  callable y no se auto-registra.

**Estado verificado del proyecto (2026-08-19) — hay prerrequisitos SIN cumplir:**
- Las apps usan `firebase_options.dart` (flutterfire configure), **no** `google-services.json`.
  El `documentos/google-services.json` del repo es de otro registro (`package_name: gri.app`),
  no del real (`com.gri.gri_cliente`), y **no tiene ni una entrada `oauth_client`**. No usarlo.
- La ausencia de `oauth_client` confirma que **la huella SHA-1 no está registrada** en Firebase para
  la app Android. Sin ella, Google Sign-In falla en Android con `DEVELOPER_ERROR` (código 10).
  SHA-1 de depuración de esta máquina: `31:E5:A7:1F:21:66:7D:C4:42:90:DB:2C:25:43:2D:C5:48:BD:8F:E2`
  SHA-256: `82:6F:00:51:09:9D:F4:EF:9A:91:C3:37:E6:0E:53:26:81:36:03:54:E1:58:BA:67:4D:D6:86:82:2C:6D:8A:9A`
- **Web client ID (entregado por el usuario 2026-08-19):**
  `703827387403-o05u1u7gffibbfqo4419ds3pjcul12g2.apps.googleusercontent.com`
  Se usa como `serverClientId` en Android (para obtener el idToken) y como client ID en Flutter Web.
  Es una credencial **pública** (viaja en el cliente) — versionarla es correcto; el client *secret*
  no se necesita y no debe entrar al repo.
- `google_sign_in` no está en `app_cliente/pubspec.yaml`. `firebase_auth` es 6.5.7.

**Requisitos funcionales:**
- Al entrar con Google por primera vez hay que crear el doc espejo `usuarios/{uid}` respetando la
  regla vigente: `role == 'cliente'` y `restauranteId == null`. Un usuario de Google **no obtiene
  claims** — es cliente, igual que un auto-registro.
- **Colisión de cuentas:** si un correo ya existe con email/contraseña y luego entra con Google,
  Firebase lanza `account-exists-with-different-credential`. Debe manejarse con un mensaje claro,
  no con un error crudo.
- El nombre del perfil se toma del displayName de Google cuando exista.
- Efecto colateral útil: las cuentas de Google llegan con `email_verified: true`, lo que encaja con
  el endurecimiento del bootstrap.

### Bootstrap del restaurante
- El doc ID del restaurante **debe ser un slug `[a-z0-9-]+`**. Restricción dura, no negociable:
  el escáner valida `^GRI-MESA-[a-z0-9-]+-\d{3}$` (`app_cliente/lib/features/sesion_qr/scan_screen.dart:41`)
  y el doc ID de mesa deriva del rid. Un rid con mayúsculas o acentos deja las mesas inescaneables.
- El formulario de crear restaurante debe generar el slug y mostrarlo al usuario antes de confirmar.
- Las rules ya permiten `create` de `restaurantes` a `isSuper()` — falta la función y la pantalla,
  no hay que tocar la regla.

### Query vs rules
- Toda query del cliente debe replicar en sus filtros lo que la regla exige por documento.
  Firestore evalúa las rules contra la consulta, no contra los documentos devueltos.
- `categorias` → `where('activo', isEqualTo: true)`. `productos` → `activo` **y** `disponible`.
- El filtrado client-side actual se elimina (queda redundante).
- Cada query nueva exige revisar si necesita índice compuesto.

### Tests
- La suite de rules usa `@firebase/rules-unit-testing` contra el emulador de Firestore.
- Los tests de app siguen con `fake_cloud_firestore`, pero se añade cobertura del caso
  **base vacía / primer arranque**, que hoy no existe porque `buildFakeFirestoreConSeed()`
  siempre pre-siembra.

### Entorno — bloqueos previos detectados en la investigación
- **Java no está en el PATH.** El emulador de Firestore lo exige (el de Functions no). Existe un
  OpenJDK 21.0.10 verificado funcional en el JBR de Android Studio.
- **Falta `.firebaserc`.** `firebase emulators:exec` lo necesita.
- Ambos son bloqueantes para cualquier test contra emulador, así que van primero.

### CLAUDE.md desactualizado
- Toda la sección "Technology Stack" de `CLAUDE.md` describe el backend FastAPI + MySQL que se
  **archivó en la Fase 10**. Cualquier agente futuro planeará contra un stack inexistente.
- Se corrige en esta fase (tarea barata, alto retorno).

### Claude's Discretion
- Estructura de carpetas de las Cloud Functions y su configuración de despliegue.
- Forma concreta de los tokens de diseño (extensión de `ThemeData`, clase de constantes, etc.)
  y cómo se comparten o duplican entre las dos apps.
- Elección de breakpoints concretos para móvil y web.
- Organización de los tests de rules por colección o por rol.
- Cómo se estructura el runbook E2E del bloque 4.
</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Alcance de la fase
- `.planning/phases/11-correcci-n-cr-tica-y-profesionalizaci-n-bootstrap-reglas-ndi/SCOPE.md` — los 4 bloques con evidencia file:line

### Evidencia de la auditoría
- `.planning/codebase/CONCERNS.md` — riesgos rankeados por severidad
- `.planning/codebase/ARCHITECTURE.md` — traza del bootstrap y modelo de datos
- `.planning/codebase/TESTING.md` — por qué la suite actual no detectó los bugs
- `.planning/codebase/audit/UI-REVIEW-app_cliente.md` — móvil, 19/60
- `.planning/codebase/audit/UI-REVIEW-panel_admin.md` — panel, 2 críticos y 8 altos

### Contratos del sistema
- `firestore.rules` — capa de autorización completa; sus comentarios documentan los presupuestos de access-calls y las transiciones de estado
- `firestore.indexes.json` — índices declarados
- `scripts/seed_firebase.mjs` — cómo se asignan hoy los claims con Admin SDK
- `docs/SMOKE-E2E.md` — runbook E2E de la Fase 10, base del bloque 4
- `docs/FIREBASE_SETUP.md` — configuración del proyecto y emuladores
</canonical_refs>

<specifics>
## Specific Ideas

Puntos exactos a tocar, con archivo y línea:

**Bugs funcionales**
- `app_cliente/lib/features/restaurantes/restaurantes_provider.dart:46-53` — queries sin filtro
- `panel_admin/lib/features/menu/menu_provider.dart:35-39` — `where` + `orderBy` sin índice
- `panel_admin/lib/features/configuracion/restaurantes_admin_provider.dart` — solo lista y toggle, falta crear
- `firestore.indexes.json` — cero índices de `categorias`

**Quick wins**
- Toggles de contraseña: `app_cliente` login:144, register:142, perfil:131 y 143; `panel_admin` login:142
- `app_cliente/lib/features/pedidos/menu_mesa_screen.dart:116-141` — pantalla en blanco con menú vacío
- `panel_admin/web/manifest.json`, `index.html` (título "A new Flutter project", theme-color `#0175C2`), `favicon.png`
- Ícono y splash por defecto de Flutter en móvil

**Diseño**
- `app_cliente/lib/features/shared/app_shell.dart:31-35` — `maxWidth: 480` fijo, sin un solo `LayoutBuilder` en 68 fuentes
- `app_cliente/lib/models/pedido.dart:78-95` — colores duplicados
- `panel_admin` — 36 hex crudos fuera de paleta, 6 de 9 pantallas sin responsive
- `app_cliente/lib/features/reservas/reserva_wizard_screen.dart:340-361` y `panel_admin/.../reservas_screen.dart` — overflow
- `app_cliente/lib/features/home/home_screen.dart:308-310` — target de 45dp (mínimo 48)

**Flujo E2E (pedido explícito del usuario)**
Desde base vacía: crear restaurante → staff → mesas con QR → menú → registro cliente →
descubrir → ver menú → escanear QR → abrir sesión → pedir → cocina avanza estados →
solicitar cuenta → cerrar sesión → calificar → reservas con anti-sobre-reserva.
</specifics>

<deferred>
## Deferred Ideas

- Pagos en línea (diferidos desde la Fase 10 — solo se solicita la cuenta).
- Validación fuerte de totales de pedido y del agregado de calificaciones vía Cloud Functions
  (gap estructural aceptado en v1, documentado en `firestore.rules`).
- Rediseño visual completo — descartado explícitamente por el usuario en esta fase.
- Multi-idioma / i18n.
</deferred>

---

*Phase: 11-correcci-n-cr-tica-y-profesionalizaci-n-bootstrap-reglas-ndi*
*Context gathered: 2026-08-19 — derivado de la auditoría del sistema, con dos decisiones bloqueadas por el usuario*
