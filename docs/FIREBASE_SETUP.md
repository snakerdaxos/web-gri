# Firebase Setup — GRI (Opción B)

> Guía única de operación Firebase del proyecto. Cubre el ciclo completo:
> **emuladores → seed → claims → deploy**. Proyecto: `p-gri-b5b40`.
> Las apps Flutter (app_cliente + panel_admin) hablan DIRECTO a Firebase Auth +
> Firestore; la autorización vive 100% en `firestore.rules` (raíz del repo).
> Fuentes de configuración: `documentos/google-services.json` (Android) y
> `documentos/firebase-config-web.js` (Web).

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

## 3. Seed (restaurante demo + 6 usuarios + claims + 8 mesas + menú)

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

  // Fuente: documentos/google-services.json (app Android gri.app)
  static const FirebaseOptions androidOptions = FirebaseOptions(
    apiKey: 'AIzaSyBZe8QtDCsv3RTZc9ykoQ9wBJskboyOzwk',
    appId: '1:703827387403:android:b55b9ee758dc5108e6d30e',
    messagingSenderId: '703827387403',
    projectId: 'p-gri-b5b40',
    storageBucket: 'p-gri-b5b40.firebasestorage.app',
  );
}
```

> La `apiKey` es pública by design (identifica el proyecto, no autentica): la
> seguridad real la imponen Auth + `firestore.rules`.

## 8. Formato del QR de mesas

El código QR de cada mesa **es el doc ID** de `mesas/`:

```
GRI-MESA-{restauranteId}-{numero:3 dígitos}   →   GRI-MESA-demo-001 .. GRI-MESA-demo-008
```

- **Panel admin** genera el QR con `qr_flutter` (contenido = el código).
- **App cliente** escanea con `mobile_scanner` y resuelve la mesa con un
  `get()` directo a `mesas/{codigo}` — O(1), sin endpoint ni índice.
- Unicidad garantizada por construcción (doc ID único en la colección).

## 9. Troubleshooting

| Síntoma | Causa | Solución |
|---|---|---|
| `permission-denied` en una query entera | Rules se evalúan **por-doc**: si UN doc matcheado no pasa la regla, toda la query falla | Querys públicas de menú filtran `activo == true` (+ `disponible == true` en productos); querys de staff SIEMPRE filtran `restauranteId == <su rid>` |
| `The query requires an index` (link en el error) | Falta un índice compuesto | `npx --prefix scripts firebase deploy --only firestore:indexes` |
| Datos que "vuelven"/desaparecen tras reiniciar emulador | Datos volátiles del emulador + caché local del SDK | Arrancar con `--import/--export-on-exit` (§2); en web hacer hard-refresh |
| Cambios de claims no se reflejan | Token viejo (hasta 1h) | Re-login o `await user.getIdToken(true)` (§4) |
| Emuladores no arrancan | Falta Java | Usar `node scripts/run_emulators.mjs` (resuelve Java solo, §2.1) o definir `JAVA_HOME` |
| `npm install --prefix scripts` falla en Windows | npm resuelve mal el package.json | `cd scripts; npm install` |
| Seed contra proyecto real falla con permisos | Service account sin roles / Firestore no creado | Regenerar key (§3) y crear Firestore en Console |
