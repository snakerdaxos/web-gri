# SMOKE E2E v2 — GRI desde una base de datos VACÍA · Gate final Fase 11

> Runbook paso a paso que lleva un despliegue **sin un solo documento** hasta un
> comensal calificando el pedido que acaba de comerse. Sustituye a
> [`docs/SMOKE-E2E.md`](SMOKE-E2E.md) (Fase 10), que partía del seed y por tanto
> **nunca ejercitaba el arranque**.
>
> **Por qué existe.** La Fase 10 cerró con 175 tests verdes y aun así envió tres
> bugs P0: no había ninguna ruta de producto para crear el primer `super_admin`,
> la query del menú del cliente estaba denegada por las rules de forma
> incondicional, y faltaba el índice compuesto de `categorias`. Ninguno lo ve un
> linter y ninguno lo veía la suite, porque **nadie había recorrido el flujo
> entero contra Firebase de verdad partiendo de cero**. El checkpoint humano que
> debía cazarlo (`docs/SMOKE-E2E.md` §5) nunca se ejecutó. Este documento es lo
> que hace que saltárselo vuelva a ser imposible.
>
> **Escrito para alguien que no construyó esto.** Cada paso dice qué hacer, qué
> tiene que pasar, **cómo comprobarlo en los datos** y qué mirar si falla.
>
> Los comandos son **PowerShell** desde la raíz del repo salvo indicación.

---

## 0. Requisitos previos

| Requisito | Verificación | Nota |
|---|---|---|
| Node 20+ | `node --version` | Probado en Node 24 |
| Java JRE 11+ | `java -version` | Solo el emulador de **Firestore** lo exige. Si falta, ver §1 |
| Flutter 3.35+ | `flutter --version` | En esta máquina el SDK está en `C:\src\flutter\bin` |
| Tooling instalado | `cd scripts; npm install; cd ..` | Una vez. En Windows `npm install --prefix scripts` falla: hay que entrar en la carpeta |
| Deps de las funciones | `cd functions; npm install; cd ..` | El emulador de Functions no arranca sin ellas |

### 0.1 La base tiene que estar VACÍA

Es el punto entero de este runbook. Antes de empezar:

```powershell
Remove-Item -Recurse -Force .\emulator_data -ErrorAction SilentlyContinue
```

- **NO** ejecutes `node scripts/seed_firebase.mjs`. Ese script es la utilidad de
  **datos de demostración**, no el mecanismo de arranque. Si lo corres, este
  runbook deja de probar lo único que vino a probar.
- **NO** arranques los emuladores con `--import`. Sin `--import`, el emulador
  nace vacío.

### 0.2 `BOOTSTRAP_EMAIL` / `BOOTSTRAP_SECRET` — cuál se usa aquí

`bootstrapPlataforma` lee dos valores de configuración y los carga **al arrancar
el emulador**, no al invocarla; escribirlos después llega tarde.

| Archivo | Se commitea | Lo usa |
|---|---|---|
| `functions/.env.demo-gri` | **Sí**, a propósito | Los emuladores, porque todo va con `--project demo-gri` |
| `functions/.env` | **No** (gitignored) | Solo el proyecto real, en el despliegue del plan 11-20 |

Para este runbook **no hay que tocar nada**: `functions/.env.demo-gri` ya está
versionado con valores ficticios y deterministas:

```
BOOTSTRAP_EMAIL=fundador@demo.gri.dev
BOOTSTRAP_SECRET=secreto-solo-para-emulador-no-usar-en-produccion
```

> 🔴 Estos dos valores son de EMULADOR y solo de emulador. El
> `BOOTSTRAP_EMAIL`/`BOOTSTRAP_SECRET` reales viven en `functions/.env` y **su
> valor no se escribe en ningún documento versionado** — ni aquí, ni en un
> SUMMARY, ni en un plan. Si necesitas consultarlos, ábrelos en esa ruta.

### 0.3 Credenciales de EJEMPLO que usa este runbook

Todas son ficticias y solo existen dentro del emulador. **No reutilices ninguna
en el proyecto real.**

| Correo | Papel en el runbook | Contraseña |
|---|---|---|
| `fundador@demo.gri.dev` | Primer `super_admin` (paso [A]) | `Demo!1234` |
| `admin@brasa.gri.dev` | `admin_restaurante` de La Brasa | `Brasa!2026` |
| `mesero@brasa.gri.dev` | `mesero` de La Brasa | `Mesero!2026` |
| `cocina@brasa.gri.dev` | `cocina` de La Brasa | `Cocina!2026` |
| `ana@cliente.gri.dev` | Cliente que se auto-registra | `Cliente!2026` |

La política de contraseñas de la plataforma (11-22) es **mínimo 8, con
mayúscula, minúscula y número**; las de arriba la cumplen a propósito.

---

## 1. Arrancar los emuladores (Auth + Firestore + Functions)

Este runbook es interactivo, así que hacen falta emuladores que **queden
corriendo**. `scripts/run_emulators.mjs` (que resuelve Java solo) envuelve
`emulators:exec`, que es de un solo disparo — para una sesión interactiva se usa
`emulators:start` directamente, resolviendo Java a mano:

```powershell
# Terminal 1 — se queda ocupada. Java solo si `java -version` falla:
$env:JAVA_HOME = 'C:\Program Files\Android\Android Studio\jbr'
$env:PATH = "$env:JAVA_HOME\bin;$env:PATH"

npx --prefix scripts firebase emulators:start --only auth,functions,firestore --project demo-gri
```

**Esperado:** UI de emuladores en <http://localhost:4000>; Auth en 9099,
Firestore en 8080, Functions en 5001. En la pestaña Firestore **no hay ni una
colección**, y en Authentication **no hay ni un usuario**. Si ves algo, la base
no está vacía: vuelve a §0.1.

> Para correr un comando puntual contra emuladores (sin sesión interactiva) el
> wrapper sigue siendo la vía cómoda:
> `cd scripts && node run_emulators.mjs --only auth,functions,firestore --project demo-gri -- <cmd>`

---

## 2. Arrancar las dos apps contra los emuladores

```powershell
# Terminal 2 — panel admin (workdir panel_admin):
$env:Path += ";C:\src\flutter\bin"
flutter run -d chrome --dart-define=USE_EMULATORS=true

# Terminal 3 — app cliente (workdir app_cliente):
$env:Path += ";C:\src\flutter\bin"
flutter run -d chrome --dart-define=USE_EMULATORS=true
```

> 🔴 **Regla de oro.** `--dart-define=USE_EMULATORS=true` es lo ÚNICO que separa
> "estoy probando" de "estoy escribiendo en producción". Sin el flag ambas apps
> hablan con `p-gri-b5b40` **real** (`defaultValue: false` en el bootstrap).
> Síntoma de haberlo olvidado: `permission-denied` inesperado, o datos que
> aparecen sin haberlos creado.
>
> ⚠️ El lanzador `run_app.bat` de la raíz **sí** lleva el flag y apunta al
> emulador Android (`-d emulator-5554`). Si lo usas para probar contra el
> proyecto real, no funcionará como esperas: quita el `--dart-define`.

**Si `flutter run -d chrome` falla** con
`Couldn't resolve the package 'flutter_secure_storage_web'`: hay un
`.dart_tool/flutter_build/` obsoleto (dependencia retirada en la Fase 10).
`flutter pub get` NO lo arregla — hay que borrar `<app>/.dart_tool/flutter_build/`.

---

## 3. Flujo completo — pasos [A]…[O]

> En cada paso: 🖥️ = panel admin · 📱 = app cliente. **Ningún paso debe requerir
> refrescar el navegador**: todo va por `onSnapshot`.

### [A] Crear el primer `super_admin` desde `/bootstrap`

Este paso NO existía en el runbook de la Fase 10 y es el bug P0 que cierra.

**Antes de nada — verificar el correo del fundador.** `bootstrapPlataforma`
exige `email_verified === true` en el idToken (11-07: el correo del fundador no
es un secreto, así que el control del buzón es uno de los dos factores). La
pantalla `/bootstrap` **no envía correo de verificación** y el emulador de Auth
**no envía correos**, así que contra emuladores hay que hacer a mano lo que en
producción hace la persona al pulsar el enlace:

```powershell
# Terminal 4, con los emuladores arriba (§1):
node scripts\verificar_email_emulador.mjs fundador@demo.gri.dev --crear "Demo!1234"
```

**Esperado:** `cuenta creada · localId=…` y
`OK · fundador@demo.gri.dev queda con emailVerified=true`. El script solo habla
con `127.0.0.1:9099` y con el proyecto `demo-gri`: no puede tocar producción.

> Se crea la cuenta AQUÍ, antes de abrir `/bootstrap`, a propósito. Si la
> pantalla la creara ella y la callable denegara, el controlador **borra la
> cuenta** al revertir y te quedarías sin nada que verificar. Con la cuenta ya
> existente, `/bootstrap` recibe `email-already-in-use`, inicia sesión con ella
> y la callable ve un token ya verificado.

**Qué se hace:** 🖥️ en el panel, login → enlace discreto
**"¿Primera vez? Inicializar plataforma"** (o navegar a `/bootstrap`). Rellenar:

| Campo | Valor |
|---|---|
| Nombre | `Fundador GRI` |
| Correo autorizado | `fundador@demo.gri.dev` |
| Contraseña / Confirmar | `Demo!1234` |
| Secreto de inicialización | `secreto-solo-para-emulador-no-usar-en-produccion` |

→ **Crear super admin**.

**Qué debe pasar:** entra directo al panel ya como `super_admin`, sin pasar por
el login. El dashboard muestra el **estado vacío guiado** (no hay restaurantes).

**Cómo verificarlo en los datos** (UI del emulador, <http://localhost:4000>):
- Firestore → `plataforma/bootstrap` **existe** (el centinela que cierra la
  puerta para siempre).
- Firestore → `usuarios/{uid}` con `role: 'super_admin'`.
- Authentication → `fundador@demo.gri.dev` con el custom claim `role`.

**Contraprueba obligatoria:** cierra sesión y vuelve a `/bootstrap` con los
mismos datos. **Debe fallar.** El mensaje es el mismo genérico que dan los otros
cuatro motivos de denegación: es deliberado, para no revelar cuál falló.

**Si falla:**
- `failed-precondition` → `functions/.env.demo-gri` no llegó al emulador de
  Functions. Reinicia el emulador (carga la config **al arrancar**).
- Mensaje genérico a la primera → el correo no está verificado (repite el
  script de arriba y **vuelve a iniciar sesión**: el token viejo sigue diciendo
  `false`), o el secreto no coincide carácter a carácter.
- `internal` / 404 → desajuste de región. Cliente y servidor declaran
  `us-central1` explícitamente; en Flutter Web un 404 de callable parece un
  error de CORS.

### [B] Crear el restaurante como `super_admin` — el identificador es un slug

**Qué se hace:** 🖥️ `/configuracion` → pestaña **Restaurantes** (solo la ve un
`super_admin`) → crear restaurante. Nombre: `La Brasa Roja`.

**Qué debe pasar:** el formulario muestra **una vista previa del identificador**
antes de confirmar: `la-brasa-roja`. Al guardar, el restaurante aparece en la
lista y queda seleccionado en el desplegable del topbar.

**Cómo verificarlo en los datos:** Firestore → `restaurantes/la-brasa-roja`
(el **doc ID** es el slug, no un autogenerado) con `activo: true`.

**Por qué importa el slug, y no es cosmético:** el doc ID de cada mesa deriva de
él (`GRI-MESA-la-brasa-roja-001`) y el escáner del cliente valida
`^GRI-MESA-[a-z0-9-]+-\d{3}$`. Un identificador con mayúsculas o acentos deja
**todas las mesas de ese restaurante inescaneables**, con los QR ya impresos.

**Contraprueba:** intenta crear otro con el mismo nombre. Debe decir
*identificador ya en uso*, no `permission-denied`.

**Si falla:** `permission-denied` en el create → o no eres `super_admin` (mira
los claims en la UI de Auth), o las apps no llevan el flag de emuladores.

### [C] Política de contraseñas (bis de [B], antes de dar de alta a nadie)

**Qué se hace:** 🖥️ `/equipo` → **Nuevo usuario** → escribe `12345678` como
contraseña.

**Qué debe pasar:** se rechaza diciendo **qué falta concretamente** ("te falta
una mayúscula"), no un genérico *contraseña inválida*. Repite lo mismo en 📱 el
registro del cliente ([H]) y en el cambio de contraseña del perfil.

**Cómo verificarlo:** los vectores canónicos están en
`scripts/password_policy_vectors.json` y los leen las tres implementaciones
(las dos apps y la callable). La regla es: **mínimo 8, mayúscula, minúscula y
número**.

**La comprobación con dientes va en el servidor.** La política también vive en
`crearUsuarioStaff` y se aplica **antes** de tocar Auth, así que no se puede
saltar invocando la callable directamente. Eso lo cubren 3 tests e2e; aquí solo
se comprueba el formulario.

### [D] Crear el equipo del restaurante desde `/equipo`

**Qué se hace:** 🖥️ `/equipo` → **Nuevo usuario**, tres veces:

| Nombre | Correo | Rol | Contraseña |
|---|---|---|---|
| Ana Admin | `admin@brasa.gri.dev` | Administrador | `Brasa!2026` |
| Beto Mesero | `mesero@brasa.gri.dev` | Mesero | `Mesero!2026` |
| Caro Cocina | `cocina@brasa.gri.dev` | Cocina | `Cocina!2026` |

Como `super_admin` tendrás que **elegir el restaurante de destino**; un
`admin_restaurante` no lo elige (la callable lo deriva de su propio claim).

**Qué debe pasar:** cada alta aparece en la tabla con Nombre / Correo / Rol /
Estado / Acción.

**Cómo verificarlo en los datos:**
- Authentication → los tres correos, cada uno con claims `{role, rid}` y
  `rid: 'la-brasa-roja'`.
- Firestore → `usuarios/{uid}` espejo con el mismo `role` y `restauranteId`.

**Contraprueba de escalada:** no existe la opción de asignar `super_admin` en el
desplegable, y tampoco puede hacerlo un `super_admin` por esta vía — el único
super nace de `/bootstrap`.

> ⚠️ **No hay correo de invitación.** Quien da de alta **escribe la contraseña
> de su empleado** y se la comunica por fuera. Es deuda declarada de la fase.

**Si falla:** `unauthenticated`/`permission-denied` → el emulador de Functions no
está levantado (`--only auth,functions,firestore`). Correo ya usado por un
cliente auto-registrado → es el anti-secuestro de 11-08 y está bien que falle.

### [E] Baja y readmisión de personal (bis de [D])

**Qué se hace:** 🖥️ `/equipo` → fila de **Beto Mesero** → **Desactivar** →
confirmar.

**Qué debe pasar:** la insignia de estado pasa a inactivo. 📱/🖥️ Beto **ya no
puede iniciar sesión** (pruébalo en otra ventana del panel).

**Cómo verificarlo en los datos:** Authentication → la cuenta de Beto figura
**disabled** y **sin claims**; Firestore → su `usuarios/{uid}` **conserva**
`role` y `restauranteId`. Esa conservación es lo único que permite reactivarlo.

**Reactivar:** misma fila → activar. Recupera el rol y vuelve a entrar.

**Los dos intentos que DEBEN fallar:**
1. Desactivar a un `super_admin`.
2. Desactivarte a ti mismo (dejaría al restaurante sin administrador).

En `/equipo` esas dos acciones ni siquiera se ofrecen — pero eso es UX. La
decisión real vive en la callable y tiene 22 casos e2e con tokens reales.

> ⚠️ **Ventana residual declarada (~1 h).** Lo verificado es que la cuenta queda
> deshabilitada y que se revocan los refresh tokens. **No** se ha medido qué
> hace un idToken ya emitido durante su hora de vida restante. Riesgo aceptado
> y documentado; no lo des por cerrado en este runbook.

### [F] Crear las mesas — doc ID `GRI-MESA-{rid}-{NNN}` y QR escaneable

**Qué se hace:** 🖥️ `/mesas` → crear tres mesas:

| Número | Capacidad |
|---|---|
| 1 | 2 |
| 2 | 4 |
| 3 | 4 |

**Qué debe pasar:** las tres aparecen en el mapa en estado **disponible**.

**Cómo verificarlo en los datos:** Firestore → colección `mesas` con **exactamente**
estos doc ID:

```
GRI-MESA-la-brasa-roja-001
GRI-MESA-la-brasa-roja-002
GRI-MESA-la-brasa-roja-003
```

Cada uno debe casar con `^GRI-MESA-[a-z0-9-]+-\d{3}$` — **cópialo y compáralo
carácter a carácter**, es la misma expresión que usa el escáner del cliente. Y
cada doc con `estado: 'disponible'`, `restauranteId: 'la-brasa-roja'`.

**Verificación del QR (el pedido explícito del usuario):**
1. 🖥️ En la mesa 1 → **ver QR**. El diálogo pinta el QR sobre fondo blanco y
   debajo, seleccionable, el código en texto.
2. El texto de debajo **tiene que ser idéntico al doc ID**. El QR codifica ese
   mismo string: si coinciden, lo que se imprima es escaneable.
3. 📱 App cliente → **Escanear mesa** → **Escanear con la cámara** → apunta a la
   pantalla del panel. `mobile_scanner` funciona en Chrome sobre `localhost`
   (es contexto seguro).
4. **Sin cámara**: la sección de **código manual** está SIEMPRE visible, fuera
   del bloque de cámara. Escribe `GRI-MESA-la-brasa-roja-001` a mano. Es
   equivalente y es la vía por defecto en un portátil sin webcam.

**Contraprueba:** crear otra mesa con el número 1 debe decir *ya existe una mesa
con ese número*. El doc ID es determinista: dos mesas nunca comparten QR.

**Si falla:** el escáner responde *el código no tiene el formato…* → el slug del
restaurante lleva mayúsculas o acentos. Vuelve a [B].

### [G] Crear el menú: categorías y productos

**Qué se hace:** 🖥️ `/configuracion` → pestaña **Menú**.

Categorías (con su **Orden**): `Entradas` (1), `Fuertes` (2), `Bebidas` (3).
Productos:

| Categoría | Nombre | Precio (COP) |
|---|---|---|
| Fuertes | Bandeja Paisa | 32000 |
| Fuertes | Trucha al ajillo | 28000 |
| Bebidas | Limonada de Coco | 9000 |

**Qué debe pasar:** el menú se lista agrupado por categoría y ordenado por
`orden`.

**Cómo verificarlo en los datos:** Firestore → `categorias` (3 docs con
`restauranteId`, `orden`, `activo: true`) y `productos` (3 docs con `activo:
true`, `disponible: true`, `precio` **entero** en COP).

> ⚠️ Que esta pantalla cargue **en el emulador no demuestra que el índice
> compuesto `categorias(restauranteId, orden)` exista**: el emulador de
> Firestore no evalúa índices compuestos. Ver §4.

### [H] Cliente: registro → descubrir → ver el menú (la regresión del bug P0)

**Prepara la trampa ANTES de mirar el menú.** Esta es la comprobación en vivo
del bug que la Fase 10 envió:

1. 🖥️ Menú → **Trucha al ajillo** → activa el switch **Agotado**.
2. 🖥️ Menú → categoría **Entradas** → desactiva el switch **Activa**.

**Qué se hace:** 📱 app cliente → **Crear cuenta** → `ana@cliente.gri.dev` /
`Cliente!2026` (con el campo de confirmar contraseña y el ojo de ver/ocultar) →
en el discover, tocar **La Brasa Roja** → ver el menú.

**Qué debe pasar:**
- El restaurante **aparece** en el discover (la query pública filtra
  `activo == true`).
- El menú **carga sin ningún error**.
- **No** se ve la categoría `Entradas` (inactiva) ni el producto
  `Trucha al ajillo` (agotado).
- Sí se ven `Fuertes` y `Bebidas` con sus productos y precios en COP.

**Cómo verificarlo en los datos:** Firestore → `usuarios/{uid}` de Ana con
`role: 'cliente'` y `restauranteId: null`. Que el auto-registro **no** produzca
claims es correcto: cliente es la ausencia de claim.

**Si falla con `permission-denied`:** es exactamente el bug P0. Las queries del
cliente deben replicar en sus `where` lo que la regla exige por documento —
`categorias` lleva `where('activo')`, `productos` lleva `activo` **y**
`disponible`. Firestore evalúa las rules contra la **consulta**, no contra los
documentos devueltos. `cd scripts && npm run audit:indexes` lo comprueba
estáticamente.

**Si la pantalla queda en blanco:** el estado vacío guiado de 11-09 no se está
montando. En blanco ≠ vacío.

### [I] Cliente: ingreso con Google — ⚠️ SOLO CONTRA EL PROYECTO REAL

**Este paso NO se puede ejecutar contra emuladores.** El emulador de Auth no
implementa el flujo real de Google: fabrica cuentas de mentira. Ejecutarlo aquí
daría un verde que no significa nada. Su verificación es el **checkpoint humano
del plan 11-20**, contra `p-gri-b5b40`.

**Qué se hace (allí):** 📱 login o registro → **Continuar con Google** → elegir
una cuenta de Google que **no** exista aún en la plataforma.

**Qué debe pasar:** entra directo, sin pedir contraseña, con el nombre del perfil
de Google.

**Cómo verificarlo en los datos:** Firestore → `usuarios/{uid}` con
`role: 'cliente'` y `restauranteId: null` — la misma forma exacta que produce el
auto-registro con contraseña. Y ese usuario debe poder **descubrir, reservar y
pedir** como cualquier otro cliente: repite [H], [J], [K] y [O] con él.

**Caso de colisión (obligatorio):** con un correo **ya registrado con
contraseña**, pulsa *Continuar con Google*. Debe salir
*"Ya tienes una cuenta con ese correo y contraseña. Inicia sesión con tu
contraseña."* — un mensaje que dice qué hacer, no un error crudo de Firebase.

> ⚠️ **En Android exige la huella SHA-1 registrada** en la app
> `com.gri.gri_cliente` del proyecto. Sin ella, Google Sign-In falla con
> `DEVELOPER_ERROR` (código 10). Registrarla es el checkpoint pendiente del plan
> 11-17. En Chrome no hace falta: la rama Web usa el Web client ID versionado.

### [J] Cliente: escanear el QR → abrir sesión → la mesa pasa a `ocupada`

**Qué se hace:** 📱 **Escanear mesa** → `GRI-MESA-la-brasa-roja-001` (cámara o
manual).

**Qué debe pasar:** banner **"Estás en la Mesa 1"** y, debajo, el menú del
restaurante.

**Cómo verificarlo en los datos:**
- `mesas/GRI-MESA-la-brasa-roja-001` tiene `estado: 'ocupada'`.
- `sesiones/GRI-MESA-la-brasa-roja-001` existe con `estado: 'activa'` y el uid
  de Ana.
- 🖥️ el mapa de mesas cambia de color **al instante**, sin refrescar.

**Las cinco formas de fallar y su mensaje propio** (11-23 — cada una dice algo
distinto, y eso es la corrección):

| Qué escribes / qué pasa | Mensaje esperado |
|---|---|
| `MESA-1` (formato malo) | el código no tiene el formato de un QR de mesa |
| `GRI-MESA-la-brasa-roja-099` (bien formado, no existe) | la mesa no existe |
| Una mesa con sesión activa de otro | la mesa ya está ocupada |
| Mesa en `limpieza` | la mesa no está disponible |
| Emuladores apagados | fallo de conexión, **no** "verifica el código" |

Ese último es el que le costó tiempo real al usuario: un `permission-denied`
que decía *verifica el código*.

### [K] Cliente: pedir del menú → pedido en `enviado`

**Qué se hace:** 📱 añadir **Bandeja Paisa** ($32.000) y **Limonada de Coco**
($9.000) al carrito → **Enviar pedido**.

**Qué debe pasar:** pantalla de estado del pedido en vivo, chip **Enviado**,
total **$41.000**.

**Cómo verificarlo en los datos:** Firestore → `pedidos/{id}` con
`estado: 'enviado'`, `mesaId: 'GRI-MESA-la-brasa-roja-001'`, `total: 41000`
(entero) y los ítems con cantidad.

**En paralelo:** 🖥️ inicia sesión como `cocina@brasa.gri.dev` en otra ventana →
**Pedidos**. El pedido aparece **solo**, sin refrescar, con el badge `Mesa 1`.

### [L] Cocina: `enviado` → `aceptado` → `en_preparacion` → `servido`

**Qué se hace:** 🖥️ (como `cocina@brasa.gri.dev`) sobre la tarjeta del pedido:
**Aceptar** → **En preparación** → **Servido**.

**Qué debe pasar:** 📱 el chip del cliente cambia en cada avance, en vivo y sin
refrescar. Al quedar `servido`, la tarjeta sale de la cola.

**Cómo verificarlo en los datos:** `pedidos/{id}.estado` recorre exactamente
`enviado → aceptado → en_preparacion → servido`. Las transiciones inválidas ni
siquiera se ofrecen en la UI, y además las deniegan las rules.

**Contraprueba de tenant:** con el `super_admin` NO se puede avanzar el pedido
de otra forma que la prevista, y **no** puede cambiar el estado de una mesa ni
cerrar sesiones: la regla compara contra su `rid`, y un `super_admin` no tiene
`rid`. Es una asimetría conocida y declarada, no un fallo del runbook.

### [M] Cliente pide la cuenta → el staff la entrega → mesa a `limpieza` → `disponible`

**Qué se hace:**
1. 📱 **Pedir la cuenta**.
2. 🖥️ (como `mesero@brasa.gri.dev` o `admin@brasa.gri.dev`) badge del header de
   **Pedidos** → sheet *Mesas que pidieron la cuenta* → **Entregar cuenta**.
3. 🖥️ `/mesas` → mesa 1 → **Liberar**.

**Qué debe pasar:** 📱 banner *Cuenta solicitada* + aviso de que el mesero viene
en camino; 🖥️ el badge amarillo aparece al instante y desaparece **solo** al
entregar.

**Cómo verificarlo en los datos:**
- Tras [1]: `sesiones/GRI-MESA-la-brasa-roja-001.cuentaSolicitada` en `true`.
- Tras [2], **en una sola transacción**: la sesión pasa a `cerrada` **y** la
  mesa a `estado: 'limpieza'`.
- Tras [3]: `mesas/GRI-MESA-la-brasa-roja-001.estado` vuelve a `'disponible'`.

**Si falla:** *no se pudo entregar la cuenta* → probablemente estás como
`super_admin`, que no puede cerrar sesiones (ver [L]).

### [N] Cliente: calificar el pedido servido

**Qué se hace:** 📱 en la pantalla de pedidos, la tarjeta `servida` **con la
sesión ya cerrada** muestra **Calificar** → 5★ + comentario → **Enviar
calificación**.

**Qué debe pasar:** confirmación. El botón deja de ofrecerse: la calificación es
1:1 por pedido.

**Cómo verificarlo en los datos:**
- `calificaciones/{pedidoId}` — el **doc ID es el id del pedido**, que es lo que
  hace imposible calificar dos veces — con `estrellas: 5`.
- `restaurantes/la-brasa-roja` con `califProm: 5` y `califCount: 1`
  (recomputados en la **misma** transacción).
- 📱 vuelve al discover: **La Brasa Roja** muestra ★ 5.0 (1).

**Contraprueba:** intentar calificar el mismo pedido otra vez debe estar
bloqueado.

### [O] Reservas: crear, anti-sobre-reserva y cancelar

**Qué se hace (📱 como Ana):**
1. Detalle del restaurante → **Reservar una mesa** → 2 personas, **mañana**,
   19:00 → confirmar.
2. Repite **exactamente la misma fecha y hora** hasta agotar las mesas con
   capacidad suficiente (con las tres mesas de [F] y 2 personas: la 4.ª intentona
   debe fallar).
3. En **Mis reservas** → cancelar la primera.

**Qué debe pasar:**
1. Reserva **confirmada**, visible en Mis reservas.
2. La que sobra falla con **"No hay mesas disponibles en ese horario"**. Eso es
   el anti-sobre-reserva: el doc ID de la reserva deriva de `mesa + franja`, así
   que la colisión la impide el propio Firestore, no una comprobación optimista.
3. La reserva desaparece y la mesa vuelve a `disponible`.

**Cómo verificarlo en los datos:**
- `reservas/{mesaId}{YYYYMMDD}_{HH}` (p. ej.
  `GRI-MESA-la-brasa-roja-00120260821_19`) con `estado: 'confirmada'` y el
  `fechaStr` de mañana.
- La mesa asignada pasó a `estado: 'reservada'`.
- Tras cancelar: la reserva queda `cancelada` y la mesa **vuelve a
  `disponible`** — pero solo si seguía en `reservada` (si el cliente ya la había
  ocupado por QR, no se toca).

**Contraprueba:** intentar reservar para 8 personas debe decir *no hay mesas con
capacidad suficiente* (la mayor de [F] es de 4). Es un mensaje distinto del de
franja agotada, a propósito.

---

## 4. Lo que este runbook NO puede demostrar contra emuladores

Dos cosas, y las dos importan. No las des por verificadas al terminar.

### 4.1 Los índices compuestos — checkpoint del plan 11-16

**El emulador de Firestore no evalúa índices compuestos.** Una query que en
producción devolvería `FAILED_PRECONDITION` aquí pasa verde. Ese fue
literalmente el tercer bug P0 de la Fase 10: `categorias` con
`where('restauranteId') + orderBy('orden')` sin índice declarado.

La mitigación que sí corre aquí es **estática**: `npm run audit:indexes`
clasifica las queries del código y comprueba la paridad rules↔query. Un OK ahí
**no** sustituye a `firebase deploy --only firestore:indexes` contra el proyecto
real y abrir el menú del panel. Eso es el plan **11-16**.

### 4.2 El ingreso con Google — checkpoint del plan 11-20

El emulador de Auth no implementa el flujo real de Google (ver [I]). La
verificación exige `p-gri-b5b40`, y en Android además la huella SHA-1 registrada.

---

## 5. Deudas declaradas que verás al ejecutar esto

No son fallos del runbook. Están reconocidas y algunas esperan una decisión.

| Deuda | Dónde se nota | Estado |
|---|---|---|
| **Sin correo de invitación**: quien crea una cuenta de staff teclea la contraseña de esa persona | [D] | Aceptado en v1 |
| **Ventana de ~1 h del idToken** tras desactivar a alguien | [E] | Riesgo aceptado, **no medido** |
| **Contraste**: blanco sobre el naranja de marca `#FF4C05` da 3.34:1 en etiquetas de 14px normal (wizard de reserva, 404) | [O] | **Pendiente de decisión del usuario**: arreglarlo exige oscurecer la paleta (bloqueada) o subir esas etiquetas a 16 bold |
| **Contraste de la paleta de mesas**: 3 de 4 pares estado/etiqueta no llegan a AA | [F], [M] | **Pendiente de decisión del usuario** |
| **Reportes agregan en cliente**: no escalan a años de datos | fuera de este flujo | Aceptado en v1 |
| **App Check diferido**: las callables no distinguen una app legítima de un `curl` con un idToken válido | [A], [D], [E] | Diferido |
| **Pagos en línea**: solo se *solicita* la cuenta, no se cobra | [M] | Diferido desde la Fase 10 |
| **Sin pantalla de error si `Firebase.initializeApp` falla**: el shell de carga se queda en "Cargando" | §2 | Deuda conocida |

---

## 6. Contra el proyecto real (`p-gri-b5b40`) — leer antes de intentarlo

Estado del proyecto real comprobado el **2026-08-20**, fuera de este runbook:

- **Los índices están TODOS desplegados**, incluido `categorias(restauranteId,
  orden)`. Diez en total. No hay nada que desplegar ahí.
- **Las rules desplegadas son las de la Fase 10.** Les faltan dos cosas de esta
  fase: el match del centinela `plataforma` (11-07) y la lectura acotada de
  `usuarios` para listar el equipo (11-10). **Sin la segunda, `/equipo` responde
  `permission-denied` en producción aunque el código sea correcto.**
- **No hay ninguna Cloud Function desplegada.** Hasta que las haya,
  `/bootstrap`, el alta de staff y la baja de personal **no funcionan** en
  producción. Blaze está aprobado por el usuario pero puede no estar activado.
- **La base NO está vacía**: conserva el seed de demostración de la Fase 10
  (restaurante `demo`, 9 mesas, categorías, productos y 9 cuentas de Auth, dos
  de ellas clientes auto-registrados sin claims). Ya existe además un
  `super_admin` concedido a mano, así que **`/bootstrap` allí ya está cerrado**:
  el paso [A] no es reproducible contra el proyecto real, y no debe serlo.

El despliegue de rules e índices es el plan **11-16**; el de funciones y la
verificación de Google, el plan **11-20**. Este runbook no los sustituye.

---

## 7. Los gates automatizados

Antes y después de recorrer el flujo:

```powershell
cd scripts
npm run gates
```

Corre en una pasada las seis suites y las tres auditorías, sigue aunque una
falle, imprime una tabla y **sale con 1 si algo falla**. Falla también si el
número de tests **baja** respecto al baseline aunque el runner devuelva 0: un
test borrado es una regresión que ningún runner reporta.

`npm run verify:shell` queda fuera de esa pasada a propósito: exige
`flutter build web --release` previo en las dos apps.

---

## 8. Checklist final del checkpoint (resume-signal)

- [ ] §0.1 La base arrancó **vacía** (sin `emulator_data/`, sin `seed_firebase.mjs`)
- [ ] [A] Primer `super_admin` creado desde `/bootstrap`; el centinela `plataforma/bootstrap` existe y **la segunda llamada falla**
- [ ] [B] Restaurante creado con doc ID **slug** (`la-brasa-roja`)
- [ ] [C] `12345678` rechazado nombrando lo que le falta, en panel y en app
- [ ] [D] Tres cuentas de staff con claims `{role, rid}` correctos
- [ ] [E] Baja: no entra, historial intacto, y reactivación recupera el rol. Los dos intentos prohibidos fallan
- [ ] [F] Los tres doc ID casan con `^GRI-MESA-[a-z0-9-]+-\d{3}$` y el QR de la mesa 1 se **escaneó** (o se tecleó a mano)
- [ ] [G] Categorías y productos creados desde el panel
- [ ] [H] Con un producto **agotado** y una categoría **inactiva**, el menú del cliente carga sin errores y no los muestra
- [ ] [J] Sesión abierta por QR; la mesa pasó a `ocupada` en vivo
- [ ] [K] Pedido en `enviado` con el total correcto, visible en cocina sin refrescar
- [ ] [L] `enviado → aceptado → en_preparacion → servido`, reflejado en vivo en el cliente
- [ ] [M] Cuenta solicitada → entregada → sesión `cerrada` + mesa `limpieza` → `disponible`
- [ ] [N] Calificación 1:1 y ★ visible en el discover
- [ ] [O] Reserva creada, **anti-sobre-reserva** disparado y cancelación revierte la mesa
- [ ] §7 `npm run gates` en verde, con los conteos iguales o mayores que el baseline
- [ ] [I] Ingreso con Google → **NO aplica aquí**: queda para el checkpoint del plan 11-20
- [ ] §4.1 Índices compuestos → **NO aplica aquí**: queda para el checkpoint del plan 11-16
- [ ] `git status` no muestra `scripts/serviceAccountKey.json`, `functions/.env` ni `emulator_data/`
- [ ] Responder **"approved"** si todo lo aplicable pasó, o listar el paso que falló **con lo observado**, no con lo esperado

Troubleshooting adicional: §9 de [`docs/FIREBASE_SETUP.md`](FIREBASE_SETUP.md).
