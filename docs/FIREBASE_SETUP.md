# Firebase Setup — GRI (Opción B)

> Guía única de operación Firebase del proyecto. Cubre el ciclo completo:
> **emuladores → seed → claims → deploy**. Proyecto: `p-gri-b5b40`.
> Las apps Flutter (app_cliente + panel_admin) hablan DIRECTO a Firebase Auth +
> Firestore; la autorización vive 100% en `firestore.rules` (raíz del repo).
> Fuentes de configuración: `documentos/google-services.json` (Android) y
> `documentos/firebase-config-web.js` (Web).

## 0. ¿Plataforma nueva? Empieza por `/bootstrap`, no por el seed

**El camino de producto para arrancar una plataforma desde cero es la pantalla
`/bootstrap` del panel** (§4.1): crea el primer `super_admin` sin scripts, sin
consola y sin que nadie tenga que manejar una clave de servicio. A partir de
ahí, todo —restaurante, equipo, mesas y menú— se da de alta desde el panel.

Ruta completa, con verificación paso a paso: **[`docs/SMOKE-E2E-v2.md`](SMOKE-E2E-v2.md)**.

> `scripts/seed_firebase.mjs` (§3) **no** es el mecanismo de arranque: es una
> utilidad para plantar **datos de demostración** en un entorno de pruebas.
> Usarlo para inicializar una plataforma real te deja seis cuentas ficticias con
> una contraseña conocida y publicada en esta misma guía.

## 1. Requisitos

| Requisito | Versión | Para qué | Notas |
|---|---|---|---|
| Node + npm | 18+ (verificado v24) | Seed, firebase-tools | — |
| Java JRE | 11+ | SOLO emuladores (`firebase emulators:*` corre sobre Java) | Verificar con `java -version`. Sin Java no hay emuladores locales (ver §3, gate 10-07) |
| Flutter SDK | 3.47 (`C:\src\flutter\bin` en PATH) | Apps | Solo para app_cliente/panel_admin |
| firebase-tools | 15.27.0 | Emuladores + deploy | Vía `scripts/package.json` — NO instalar global |
| firebase-admin | 14.2.0 | Seed + claims | Vía `scripts/package.json` |

Instalación del tooling (una vez):

```powershell
# En Windows `npm install --prefix scripts` puede fallar (resuelve mal el
# package.json) — correr DESDE scripts/:
cd scripts
npm install
cd ..
# Verificar (desde la RAÍZ del repo):
npx --prefix scripts firebase --version   # → 15.27.0
```

## 2. Emuladores (auth 9099, firestore 8080, UI 4000)

Configurados en `firebase.json` (raíz). UI: **http://localhost:4000**.

```powershell
# Primera corrida (emulator_data/ aún no existe — sin --import):
npx --prefix scripts firebase emulators:start --only auth,firestore --export-on-exit=./emulator_data

# Corridas siguientes (estado reproducible entre sesiones):
npx --prefix scripts firebase emulators:start --only auth,firestore --import=./emulator_data --export-on-exit=./emulator_data
```

- **Datos volátiles por defecto:** sin `--import/--export-on-exit` el emulador
  borra TODO al apagar. Con esos flags el estado sobrevive en
  `emulator_data/` (gitignored).
- **Android:** el SDK de Firebase mapea `localhost → 10.0.2.2`
  automáticamente dentro del emulador de Android (`useFirestoreEmulator` /
  `useAuthEmulator` con host mapping). En dispositivo físico usar la IP LAN
  manualmente.
- Requiere Java 11+ (`java -version`).

## 2.1 Java y emuladores (wrapper `run_emulators.mjs`)

El emulador de **Firestore exige una JVM**. Los de **Auth y Functions no**. En esta máquina
`java` **no está en el PATH**, así que ejecutar `firebase emulators:exec` a pelo falla.

`scripts/run_emulators.mjs` resuelve el problema sin que nadie toque variables de entorno:

1. Busca Java en `JAVA_HOME/bin/java` → `java` del PATH → rutas conocidas del **JBR de
   Android Studio** (`C:Program FilesAndroidAndroid Studiojbr`, OpenJDK 21.0.10 verificado).
2. Si el Java resuelto no vino del PATH, inyecta `JAVA_HOME` y prependea su `bin/` al `PATH`
   **del proceso hijo únicamente** — nunca muta el entorno de la máquina.
3. Corre siempre con `cwd` en la raíz del repo (para que resuelvan `firebase.json`, `.firebaserc`,
   `firestore.rules` y `firestore.indexes.json`) y propaga el exit code del comando.
4. Si no encuentra ninguna JVM, sale con código 1 e imprime cómo arreglarlo. No falla en silencio.

```powershell
cd scripts
npm run test:rules       # emulador firestore + node --test test/rules/
npm run test:functions   # emuladores auth+functions+firestore + node --test test/functions/
npm test                 # los dos

# Uso directo:  [--set-env K=V ...] <opciones firebase> -- <comando>
node run_emulators.mjs --only firestore --project demo-gri -- node -e "console.log(1)"
```

- Todos los scripts de test usan **`--project demo-gri`**. El prefijo `demo-` hace que el CLI y los
  SDK rechacen credenciales reales por diseño: es imposible que un test toque `p-gri-b5b40`.
  **Prohibido usar el alias `default` en cualquier script de test.**
- `--set-env CLAVE=VALOR` (cero o más, antes del resto) inyecta variables en el proceso de test.
  ⚠️ **No llega al emulador de Functions**: ese carga su config de `functions/.env` y
  `functions/.env.{projectId}` AL ARRANCAR. La config determinista de las funciones en emulador
  vive versionada en `functions/.env.demo-gri`.

**Fallback manual** (si el wrapper no encontrara Java o se quiere usar el CLI a pelo):

```powershell
$env:JAVA_HOME = "C:Program FilesAndroidAndroid Studiojbr"
$env:PATH = "$env:JAVA_HOMEin;$env:PATH"
java -version   # debe imprimir openjdk 21.x
```

## 3. Seed — utilidad de DATOS DE DEMOSTRACIÓN (no es el bootstrap)

> ⚠️ **Qué es y qué no es.** `seed_firebase.mjs` planta un restaurante de
> ejemplo con datos realistas para poder trastear sin teclear nada. **No es la
> forma de inicializar la plataforma** — eso es `/bootstrap` (§0 y §4.1). Sus
> seis cuentas comparten una contraseña publicada aquí abajo: son de PRUEBA.
> No lo ejecutes contra un entorno con datos reales, y **no lo ejecutes** si
> vas a recorrer `docs/SMOKE-E2E-v2.md`, que exige base vacía.

### 3.1 Qué siembra

`scripts/seed_firebase.mjs` siembra (port 1:1 del seed del backend):
restaurante `demo` ("Restaurante Demo GRI"), 6 usuarios Auth con claims
`{role, rid}` + doc espejo `usuarios/{uid}`, 8 mesas con doc ID determinista
`GRI-MESA-demo-001..008`, 4 categorías y 16 productos (precios int COP).

**Usuarios sembrados** (password `Demo!1234` para todos):

| Email | Rol (claim `role`) | Claim `rid` |
|---|---|---|
| admin@gri.dev | super_admin | null |
| admin@demo.gri.dev | admin_restaurante | demo |
| mesero@demo.gri.dev | mesero | demo |
| cocina@demo.gri.dev | cocina | demo |
| carlos@demo.gri.dev | cliente | null |
| maria@demo.gri.dev | cliente | null |

### Modo emuladores (sin credenciales)

```powershell
# Con los emuladores corriendo (§2), en OTRA terminal:
$env:FIREBASE_AUTH_EMULATOR_HOST="127.0.0.1:9099"
$env:FIRESTORE_EMULATOR_HOST="127.0.0.1:8080"
node scripts/seed_firebase.mjs
```

Alternativa one-shot (arranca emuladores, corre el seed y apaga):

```powershell
npx --prefix scripts firebase emulators:exec --only auth,firestore --export-on-exit=./emulator_data "node scripts/seed_firebase.mjs"
```

**Doble corrida = prueba de idempotencia:** correr el seed DOS veces y
verificar en el log de la segunda que usuarios/categorías/productos figuran
todos como `existente` (6/6, 4/4, 16/16) y no hay duplicados.
> ⚠️ **Gate 10-07:** la máquina de desarrollo que produjo este plan NO tiene
> Java, por lo que la doble corrida contra emuladores queda como verificación
> pendiente del plan 10-07 (o correrla en cualquier máquina con Java 11+).

### Modo proyecto real (con service account)

1. Habilitar el proveedor **Email/Password**: Firebase Console →
   Authentication → Sign-in method → Email/Password → Enable.
2. Generar la service account key: Firebase Console → Project Settings →
   Service Accounts → **Generate new private key** → guardar como
   `scripts/serviceAccountKey.json`.
   > 🔴 Este archivo es un SECRETO — está GITIGNORED. NUNCA commitearlo.
3. Correr:

```powershell
$env:GOOGLE_APPLICATION_CREDENTIALS="./scripts/serviceAccountKey.json"
node scripts/seed_firebase.mjs
```

El script loguea claramente el modo activo (`EMULADORES` o `PROYECTO REAL`).
Contra el proyecto real también se necesita Firestore creado (Console →
Firestore Database → Create database).

## 4. Custom claims `{role, rid}`

- Los claims viajan DENTRO del idToken: `request.auth.token.role` y
  `request.auth.token.rid` en las rules (cero lecturas a Firestore para
  autorizar — reemplazan a TenantScope + require_roles del backend).
- **Quién los setea: SOLO el seed (Admin SDK).** Ningún cliente puede
  escribir sus propios claims — son inmutables client-side por diseño.
- El doc `usuarios/{uid}` es un ESPEJO de perfil (nombre/email/rol para
  display). NUNCA autoriza nada: las rules no lo leen para permisos.
- **Pitfall de propagación:** los claims entran al idToken en el próximo
  refresh (un token viejo vive hasta 1h). Como el seed corre ANTES del primer
  login de cada usuario, el caso normal no tiene problema. Si se cambian
  claims de un usuario YA logueado: cerrar sesión y re-loguearse, o llamar
  `await user.getIdToken(true)` para forzar el refresh.

## 4.1 Inicializar una plataforma nueva (`/bootstrap`)

Para arrancar una plataforma **desde cero** ya no hace falta el seed ni una
clave de servicio: la callable `bootstrapPlataforma`
(`functions/src/bootstrap-plataforma.js`) crea el PRIMER `super_admin` y
después queda inerte para siempre.

> ⚠️ **Las dos variables deben fijarse ANTES del despliegue.** Si faltan, la
> función no promueve a nadie (*fail closed*) y responde
> `failed-precondition`. Cambiarlas después exige un nuevo `deploy`.

**1. Configurar el secreto del despliegue.**

```bash
cp functions/.env.example functions/.env
```

Rellenar en `functions/.env` (este archivo **NO se commitea**):

| Variable | Qué es |
|---|---|
| `BOOTSTRAP_EMAIL` | Correo exacto de la persona que será el primer `super_admin`. Debe ser un buzón que esa persona **pueda verificar**: la función exige `email_verified == true`. |
| `BOOTSTRAP_SECRET` | Cadena larga y aleatoria. Es el segundo factor. NUNCA reutilizar el de `.env.demo-gri`. Generar, p. ej., con `openssl rand -base64 48`. |

**Por qué el correo NO basta.** El registro con email/contraseña está ABIERTO
(lo usa la app cliente): cualquiera que conozca el correo del fundador podría
registrarlo primero. Por eso hacen falta los dos factores —correo verificado y
secreto de despliegue— y no uno.

**2. Desplegar la función y las rules.**

```bash
cd scripts
npx firebase deploy --only functions,firestore:rules --project p-gri-b5b40
```

**3. Abrir `/bootstrap` en el panel** (hay un enlace discreto en el login:
*"¿Primera vez? Inicializar plataforma"*).

**4. Crear la cuenta con el correo autorizado** y pegar el secreto. La pantalla
crea la cuenta, invoca la callable, refresca los claims y entra al panel ya como
`super_admin`.

**5. Verificar el correo.** Sin `email_verified == true` la función responde
`No puedes inicializar esta plataforma.`

> 🔴 **La pantalla `/bootstrap` NO envía el correo de verificación** — no llama
> a `sendEmailVerification()`. Y si la callable deniega, el controlador **borra
> la cuenta** que acababa de crear, así que tampoco queda nada que verificar
> después. Consecuencias prácticas:
>
> * **Cuenta de Google:** llega con `email_verified: true` de fábrica. Es el
>   camino sin fricción, y es el que corresponde al `BOOTSTRAP_EMAIL` elegido.
> * **Cuenta de email/contraseña:** hay que dejarla creada y verificada ANTES de
>   abrir `/bootstrap`. Entonces la pantalla recibe `email-already-in-use`,
>   inicia sesión con ella y la callable ve el token ya verificado.
> * **Contra emuladores** (el emulador tampoco envía correos), lo resuelve
>   `node scripts/verificar_email_emulador.mjs <correo> --crear <password>`.
>   Ese script está fijado a `127.0.0.1:9099` y al proyecto `demo-gri`: no puede
>   tocar producción.

**Qué pasa si algo falla.** Los cinco motivos de denegación devuelven el MISMO
mensaje y el mismo código a propósito (no revelar cuál falló). Revisar, en
orden: que el correo coincida exactamente, que esté verificado, que el secreto
sea el del despliegue, y que la plataforma no tenga ya un `super_admin`.

**Cierre de la puerta.** El centinela `plataforma/bootstrap` marca la
plataforma como inicializada. Está bloqueado en `firestore.rules`
(`allow read, write: if false`): **ningún** cliente puede leerlo ni borrarlo,
ni siquiera el `super_admin`. Borrarlo re-abriría el bootstrap.

## 5. Deploy de rules + índices

> ⚠️ **Advertencia:** reglas mal desplegadas cortan TODO el acceso a Firestore
> (todas las apps, incluido el panel). Probar primero contra emuladores y
> revisar `firestore.rules` antes de deployar. La validación sintáctica real
> de las rules ocurre server-side en el deploy (por eso `--dry-run` también
> pide login).

```powershell
# 1. Login OAuth interactivo (lo hace el USUARIO una vez):
npx --prefix scripts firebase login

# 2. Deploy:
npx --prefix scripts firebase deploy --only firestore:rules,firestore:indexes
```

Los 9 índices compuestos de `firestore.indexes.json` se crean solos con ese
comando (tarda unos minutos en construirse).

## 6. Flag `USE_EMULATORS`

Las apps conectan a emuladores SOLO con el flag (dev):

```powershell
flutter run --dart-define=USE_EMULATORS=true          # app_cliente
flutter run -d chrome --dart-define=USE_EMULATORS=true  # panel_admin
```

- **Sin el flag, las apps tocan el proyecto REAL** `p-gri-b5b40`.
- Síntoma clásico de estar tocando el proyecto real sin querer:
  `permission-denied` inesperado en dev (Pitfall 2 del research).
- El bootstrap (`useAuthEmulator`/`useFirestoreEmulator`) debe ejecutarse en
  `main()` ANTES de cualquier uso de las instancias.

## 7. `firebase_options.dart`

**Primera opción — `flutterfire configure`** (genera y mantiene el archivo):

```powershell
dart pub global activate flutterfire_cli
cd app_cliente   # (o panel_admin)
flutterfire configure   # seleccionar p-gri-b5b40 + android,web (cliente) / web (panel)
```

**Fallback manual** (si no hay acceso al CLI / OAuth del browser) — shape
exacto de `DefaultFirebaseOptions` con los valores reales del proyecto
(fuentes: `documentos/google-services.json` y `documentos/firebase-config-web.js`):

```dart
// lib/firebase_options.dart — fallback manual (primera opción: flutterfire configure)
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) return webOptions;
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return androidOptions;
      default:
        throw UnsupportedError('Plataforma no soportada en GRI v1');
    }
  }

  // Fuente: documentos/firebase-config-web.js (app grip.web)
  static const FirebaseOptions webOptions = FirebaseOptions(
    apiKey: 'AIzaSyAXPPuBMkMUgt_piyLg6uvWiEY0ff4kiC4',
    appId: '1:703827387403:web:08ae995e35ce9516e6d30e',
    messagingSenderId: '703827387403',
    projectId: 'p-gri-b5b40',
    authDomain: 'p-gri-b5b40.firebaseapp.com',
    storageBucket: 'p-gri-b5b40.firebasestorage.app',
    measurementId: 'G-8H4SQ9ZHV5',
  );

  // App Android `com.gri.gri_cliente` — el appId DEBE ser el del registro
  // cuyo packageName coincide con el `applicationId` de build.gradle.kts.
  // ⚠️ NO tomar este bloque de documentos/google-services.json: ese archivo es
  // del registro viejo `gri.app` (ver §9.5). Corregido en 11-17.
  static const FirebaseOptions androidOptions = FirebaseOptions(
    apiKey: 'AIzaSyBZe8QtDCsv3RTZc9ykoQ9wBJskboyOzwk',
    appId: '1:703827387403:android:1f0746d200e4e12ce6d30e',
    messagingSenderId: '703827387403',
    projectId: 'p-gri-b5b40',
    storageBucket: 'p-gri-b5b40.firebasestorage.app',
  );
}
```

> La `apiKey` es pública by design (identifica el proyecto, no autentica): la
> seguridad real la imponen Auth + `firestore.rules`.

**Fuente de verdad para estos valores** (no hace falta la consola):

```bash
npx --prefix scripts firebase apps:list --project p-gri-b5b40
npx --prefix scripts firebase apps:sdkconfig ANDROID <appId> --project p-gri-b5b40
```

El gate `app_cliente/test/core/firebase_options_coherencia_test.dart` ata el
`applicationId` de Gradle al `appId` de Dart y falla si vuelven a divergir.

**Las dos apps comparten UN solo registro web** (`gri.web`,
`1:703827387403:web:08ae995e35ce9516e6d30e`) a propósito: el registro web no
aporta aislamiento —la autorización vive en claims + `firestore.rules`, que son
del proyecto— y un segundo registro solo separaría métricas de Analytics.

## 8. Formato del QR de mesas

El código QR de cada mesa **es el doc ID** de `mesas/`:

```
GRI-MESA-{restauranteId}-{numero:3 dígitos}   →   GRI-MESA-demo-001 .. GRI-MESA-demo-008
```

- **Panel admin** genera el QR con `qr_flutter` (contenido = el código).
- **App cliente** escanea con `mobile_scanner` y resuelve la mesa con un
  `get()` directo a `mesas/{codigo}` — O(1), sin endpoint ni índice.
- Unicidad garantizada por construcción (doc ID único en la colección).

## 9. Ingreso con Google — solo app cliente (11-17)

El **panel admin NO** tiene ingreso con Google: el staff se crea con la callable
`crearUsuarioStaff` y no se auto-registra. Esto es solo de `app_cliente`.

### 9.1 El Web client ID es público y vive versionado

```
703827387403-o05u1u7gffibbfqo4419ds3pjcul12g2.apps.googleusercontent.com
```

Vive como constante en **`app_cliente/lib/core/google_auth.dart`**, no en
`--dart-define` ni en `.env`. Es una credencial **pública**: viaja en el cliente
por diseño y el client **secret** no interviene en este flujo (ni debe entrar al
repo). Versionarla elimina una fuente de deriva y un test afirma su valor exacto
(`test/auth/google_signin_test.dart`), porque un carácter mal copiado solo se
manifiesta en runtime como `DEVELOPER_ERROR` o como un `idToken` nulo.

**NO** se añade `<meta name="google-signin-client_id">` a `web/index.html`: ese
meta lo lee `google_sign_in_web`, y la rama Web usa `signInWithPopup`, que
resuelve el client ID desde la configuración de la app Web del propio proyecto.
Añadirlo crearía una segunda copia del valor con riesgo de deriva y sin ningún
consumidor.

### 9.2 Dos ramas de plataforma

| Plataforma | Mecanismo | ¿Necesita trámite? |
|---|---|---|
| **Web** | `FirebaseAuth.signInWithPopup(GoogleAuthProvider())` | **No.** Funciona con el proveedor Google habilitado en Authentication |
| **Android / iOS** | `google_sign_in` 7.x → `idToken` → `GoogleAuthProvider.credential` → `signInWithCredential` | **Sí:** la huella SHA-1 |

### 9.3 Android exige la huella SHA-1

Sin ella Google Sign-In falla con `DEVELOPER_ERROR` (**código 10**), un error
opaco que no dice qué falta.

1. Firebase Console → ⚙ Configuración del proyecto → General → Tus apps.
2. Elegir la app Android **`com.gri.gri_cliente`** (ID terminado en
   `1f0746d200e4e12ce6d30e`). **NO** la de `gri.app` — ver §9.5.
3. "Añadir huella digital" y pegar la SHA-1 de la máquina de desarrollo.

> **Al firmar una release hay que registrar TAMBIÉN la SHA-1 del keystore de
> producción**, o el ingreso con Google fallará solo en el APK firmado, que es
> el peor momento para descubrirlo.

### 9.4 El emulador de Auth NO implementa el flujo de Google

No hay forma de probar el handshake real contra emuladores: hay que apuntar al
proyecto **real** (`p-gri-b5b40`). Por eso la cobertura automatizada de
`test/auth/google_signin_test.dart` se detiene deliberadamente en la costura
`googleAuthAccionProvider` (espejo, traducción de errores, estado del botón) y
**el handshake queda para verificación manual** — el runbook de smoke E2E lo
recoge marcado como "solo contra el proyecto real".

### 9.5 ⚠️ `documentos/google-services.json` NO debe copiarse

El proyecto tiene **DOS** apps Android registradas:

| packageName | appId | Estado |
|---|---|---|
| `com.gri.gri_cliente` | `1:703827387403:android:1f0746d200e4e12ce6d30e` | **la buena** — coincide con el `applicationId` de `android/app/build.gradle.kts` |
| `gri.app` | `1:703827387403:android:b55b9ee758dc5108e6d30e` | registro viejo, **sin** `oauth_client` |

`documentos/google-services.json` es del registro **viejo** (`gri.app`). Hoy no
está conectado a nada, pero **copiarlo a `app_cliente/android/app/` rompería
Firebase en Android** de una forma muy difícil de diagnosticar (el plugin Gradle
de google-services lo leería y sobreescribiría la configuración correcta).

**La configuración de las apps vive en `lib/firebase_options.dart`
(`flutterfire configure`), NO en `google-services.json`.**

## 10. Troubleshooting

| Síntoma | Causa | Solución |
|---|---|---|
| `permission-denied` en una query entera | Rules se evalúan **por-doc**: si UN doc matcheado no pasa la regla, toda la query falla | Querys públicas de menú filtran `activo == true` (+ `disponible == true` en productos); querys de staff SIEMPRE filtran `restauranteId == <su rid>` |
| `The query requires an index` (link en el error) | Falta un índice compuesto | `npx --prefix scripts firebase deploy --only firestore:indexes` |
| Datos que "vuelven"/desaparecen tras reiniciar emulador | Datos volátiles del emulador + caché local del SDK | Arrancar con `--import/--export-on-exit` (§2); en web hacer hard-refresh |
| Cambios de claims no se reflejan | Token viejo (hasta 1h) | Re-login o `await user.getIdToken(true)` (§4) |
| Emuladores no arrancan | Falta Java | Usar `node scripts/run_emulators.mjs` (resuelve Java solo, §2.1) o definir `JAVA_HOME` |
| `npm install --prefix scripts` falla en Windows | npm resuelve mal el package.json | `cd scripts; npm install` |
| Seed contra proyecto real falla con permisos | Service account sin roles / Firestore no creado | Regenerar key (§3) y crear Firestore en Console |
| `/bootstrap` responde `failed-precondition` | `BOOTSTRAP_EMAIL` o `BOOTSTRAP_SECRET` no llegaron al despliegue | Rellenar `functions/.env` y **re-desplegar** la función (§4.1) |
| `/bootstrap` responde `No puedes inicializar esta plataforma.` | Correo distinto, correo sin verificar, secreto incorrecto, o la plataforma YA está inicializada | El mensaje es el mismo para los 4 casos **a propósito**; revisarlos en ese orden (§4.1) |
