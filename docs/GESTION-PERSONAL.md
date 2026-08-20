# Gestión de personal de GRI desde la línea de comandos

> Manual de `scripts/gestion_staff.mjs`. Fase 11, plan 11-20.

## Por qué existe este script

Dar de alta a un mesero exige dos cosas que **ningún cliente puede hacer**:

1. Escribir custom claims (`setCustomUserClaims` es exclusivo del Admin SDK).
2. Crear una cuenta sin desloguear a quien la está creando (el SDK cliente inicia sesión
   con la cuenta recién creada).

Por eso el diseño original puso esa lógica en tres Cloud Functions —`bootstrapPlataforma`,
`crearUsuarioStaff` y `cambiarEstadoStaff`—. Pero **desplegar Cloud Functions exige el plan Blaze**,
y el propietario decidió el 2026-08-20 **no activarlo** (11-CONTEXT.md, «Blaze — REVERTIDO»): Blaze
pide tarjeta y el almacenamiento de los despliegues genera cargos pequeños pero no nulos.

Consecuencia: el código de las callables y sus **149 pruebas unitarias + 50 e2e se conservan en el
repo**, intactas, para el día que se decida desplegarlas. Lo que faltaba era una forma de
**ejecutar** esa lógica. Eso es este script: el mismo Admin SDK, con la clave de servicio del
propietario, corriendo en su máquina.

## ⚠️ Qué protege esto y qué NO (léelo antes de confiar en la matriz)

El script **no reimplementa** la autorización: importa las mismas matrices que usaban las callables.

| Módulo importado                    | Qué decide                                        |
| ----------------------------------- | ------------------------------------------------- |
| `functions/src/auth-matrix.js`      | quién puede crear a quién, y en qué restaurante    |
| `functions/src/baja-matrix.js`      | quién puede dar de baja o readmitir a quién        |
| `functions/src/password-policy.js`  | qué contraseña cumple la política del servidor     |

**Pero el significado de esa matriz ha cambiado, y conviene entenderlo:**

- **En la Cloud Function era una frontera de seguridad real.** Corría en un servidor, contra un
  llamador que no controlaba nada: aunque mintiera en el payload, la decisión se tomaba con los
  claims de su token y saltársela era imposible.
- **En este script es una barrera contra ERRORES, no contra un atacante.** Quien tiene la clave de
  servicio tiene el Admin SDK entero: puede abrir un `node` y escribir
  `setCustomUserClaims(uid, {role: 'super_admin'})` sin pasar por este archivo. La matriz aquí evita
  el dedazo —el admin que se equivoca de restaurante, el que se da de baja a sí mismo y deja el
  local sin administrador—, no un abuso deliberado.

**Consecuencia práctica: la seguridad del sistema pasa a depender de dónde está guardada la clave.**
Con las callables desplegadas, robar la clave era una vía más; ahora es *la* vía. Trátala como la
contraseña maestra de toda la plataforma: no la copies a otra máquina, no la mandes por chat ni por
correo, y si sospechas que se filtró, revócala en Firebase Console → Cuentas de servicio y genera
otra.

## La clave de servicio

- **Ruta por defecto:** `p-gri-b5b40-firebase-adminsdk.json`, en la **raíz del repo**.
- **De dónde sale:** Firebase Console → Configuración del proyecto → Cuentas de servicio →
  «Generar nueva clave privada».
- **Nunca se commitea.** Está ignorada por **patrón**, no por nombre exacto:
  `.gitignore:36` → `*firebase-adminsdk*.json`. Renombrarla no la desprotege.
  Compruébalo cuando quieras con:

  ```bash
  git check-ignore -v p-gri-b5b40-firebase-adminsdk.json
  ```

- **El script no la lee.** Comprueba que el archivo existe y le pasa la **ruta** al Admin SDK
  (`GOOGLE_APPLICATION_CREDENTIALS` + `applicationDefault()`). Su contenido no entra nunca en este
  proceso, así que no puede acabar en un log, en un mensaje de error ni en el volcado de una
  excepción.
- **Otra ubicación:** `--key <ruta>` o la variable `GOOGLE_APPLICATION_CREDENTIALS`.
- Si falta, el script se detiene con un mensaje que nombra la ruta esperada y sale con código 1.

## Quién ejecuta la operación: `--como`

Las callables sabían quién llamaba por el token de su sesión. Aquí no hay token, así que **el actor
se declara con `--como <email>`** y el script lee sus **custom claims reales** de Firebase Auth.

No es opcional y no tiene valor por defecto. Y no se acepta un rol por parámetro: si el operador
pudiera escribir `--rol-actor super_admin`, elegiría su propia autorización y la matriz sería
decorativa.

Si la cuenta no existe o no tiene claims, el script para con un mensaje claro y sale con 1.

## Los cinco comandos

Todos se ejecutan desde la **raíz del repo**. También hay atajo: `cd scripts && npm run staff -- <args>`.

### 1. `listar` — ver el equipo

```bash
node scripts/gestion_staff.mjs listar --como admin@demo.gri.dev
```

Por debajo: consulta `usuarios` filtrando por el restaurante del actor y, para cada persona, lee
además su cuenta en Auth. Muestra nombre, correo, rol, estado y **UID** (que es lo que piden `baja` y
`reactivar`).

Si Auth y Firestore no coinciden —la cuenta está deshabilitada pero la ficha dice «activo», o al
revés— lo marca como `⚠ DESINCRONIZADO` en vez de taparlo. Eso pasa si una operación murió entre los
dos sistemas; se arregla repitiendo la operación, que es idempotente.

Una cuenta de plataforma (`super_admin`) **debe pasar `--rid`**, porque no tiene restaurante propio:

```bash
node scripts/gestion_staff.mjs listar --como admin@gri.dev --rid demo
```

### 2. `crear` — dar de alta

```bash
node scripts/gestion_staff.mjs crear --como admin@demo.gri.dev \
    --email ana@demo.gri.dev --nombre "Ana Mesera" --rol mesero
```

Roles asignables: `admin_restaurante`, `mesero`, `cocina`. **`super_admin` no es asignable por esta
vía, a propósito y para nadie** (ver `promover-super` más abajo).

Sin `--password`, el script **genera una contraseña temporal** que cumple la política y la imprime
**una sola vez, al final**. Dictásela a esa persona y pídele que la cambie desde su perfil. Con
`--password <...>` la fijas tú, y se valida con la misma política del servidor **antes** de tocar
Auth: si no cumple, no se crea nada a medias.

Una cuenta de plataforma debe indicar el restaurante:

```bash
node scripts/gestion_staff.mjs crear --como admin@gri.dev --rid demo \
    --email jefe@demo.gri.dev --nombre "Jefe de Cocina" --rol cocina --password "Cocina!2026"
```

Por debajo hace exactamente lo mismo que `crearUsuarioStaff`: valida la forma del payload y la
contraseña, le pregunta a la matriz, comprueba que el restaurante existe, crea la cuenta en Auth
(idempotente por correo), aplica el **anti-secuestro de tres ramas** (no toca cuentas de plataforma,
ni de otro restaurante, ni de un cliente de la app móvil), escribe los claims `{role, rid}` y el doc
espejo `usuarios/{uid}` con `merge`.

**Repetir el alta con el mismo correo no duplica nada: repara.** Es la vía de arreglo si una
ejecución murió entre Auth y Firestore.

### 3. `baja` — retirar el acceso, sin borrar nada

```bash
node scripts/gestion_staff.mjs baja --como admin@demo.gri.dev --uid AbC123...
# o por correo:
node scripts/gestion_staff.mjs baja --como admin@demo.gri.dev --email-objetivo ana@demo.gri.dev
```

Muestra a quién va a afectar (nombre, correo, rol, restaurante, uid) y **pide confirmación `s/N`**.
Responder cualquier otra cosa aborta sin tocar nada. Para guiones, `--si` la salta y deja constancia
de que se saltó.

Por debajo: `disabled: true` en Auth, claims a `null`, refresh tokens revocados y la ficha marcada
`activo: false` **conservando `role` y `restauranteId`** — esos dos campos son lo único que permite
readmitir después, y también lo que leen los reportes históricos por mesero. No se borra la cuenta:
borrarla dejaría pedidos huérfanos.

La matriz rechaza tres cosas aquí: dar de baja a una cuenta de plataforma, darse de baja a uno mismo,
y (siendo `admin_restaurante`) tocar a alguien de otro restaurante.

Aviso conocido: un token ya emitido vive hasta ~1 hora, así que una sesión abierta puede sobrevivir
ese rato. No puede renovarse ni volver a entrar.

### 4. `reactivar` — readmitir

```bash
node scripts/gestion_staff.mjs reactivar --como admin@demo.gri.dev --uid AbC123...
```

No pide confirmación: no es destructivo. Restaura `disabled: false` y **los claims leídos de la
ficha**, que es donde sobrevivieron a la baja. Entra con su contraseña de siempre.

Si la ficha no tiene rol (un alta que murió a medias hace tiempo), el script lo dice y te indica la
salida: volver a hacer `crear` con el mismo correo para repararla.

> Para readmitir usa **`reactivar`**, no `crear`: `crear` reescribe claims y ficha, pero —igual que
> la callable— no toca `disabled` ni `activo: false`, así que la persona seguiría sin poder entrar.

### 5. `promover-super` — la vía de recuperación

```bash
node scripts/gestion_staff.mjs promover-super --email snakerdaxos@gmail.com --confirmo-promover-super
```

**Este comando se salta la matriz, y es deliberado.** `ROLES_ASIGNABLES` prohíbe asignar
`super_admin` de forma absoluta —ni siquiera otra cuenta de plataforma puede crear una—, así que
concederlo exige salir de la matriz. Por eso lleva nombre propio, un aviso destacado, la bandera
explícita `--confirmo-promover-super` **y** una segunda confirmación interactiva en la que hay que
reescribir el correo completo. Con `--si` no se salta: es intencionado.

Existe porque es **la única forma de recuperar la plataforma si el propietario pierde su cuenta de
`super_admin`**. `bootstrapPlataforma` (11-07) ya no sirve: es de un solo uso y quedó inerte en
cuanto nació el primer super_admin. Vive en este mismo archivo, y no escondido en otro, por dos
razones: concentra el manejo de la clave de servicio en un solo sitio, y esconderlo lo haría
inencontrable justo el día que haga falta.

Deja constancia en la ficha (`promovidoAt`, `promovidoPor: 'script:promover-super'`).

La cuenta promovida **debe cerrar sesión y volver a entrar**: los claims viajan dentro del token.

## Contra los emuladores (para probar sin tocar el proyecto real)

Si `FIREBASE_AUTH_EMULATOR_HOST` y `FIRESTORE_EMULATOR_HOST` están definidos, el script usa los
emuladores y **ni siquiera mira la clave de servicio**. Es la precedencia correcta: apuntando a
emuladores no hay razón para tocar la clave real.

```bash
cd scripts && npm run test:staff   # levanta auth+firestore y corre la suite del CLI
```

## Qué pasa cuando se despliegue Blaze

Nada de esto se tira. El script seguirá funcionando, pero dejará de ser la vía normal:

1. `firebase deploy --only functions` publica `crearUsuarioStaff` y `cambiarEstadoStaff`.
2. La pantalla **`/equipo`** del panel recupera sus botones de alta y baja, que ya están escritos y
   probados: llaman a esas mismas callables.
3. Las callables usan **las mismas tres matrices** que importa este script, así que el comportamiento
   —quién puede hacer qué, qué contraseñas valen, qué pasa con un correo repetido— es idéntico. No
   hay que revalidar la autorización: son literalmente el mismo módulo.
4. El script queda como herramienta de administración y, sobre todo, `promover-super` **sigue siendo
   la vía de recuperación**: eso no lo cubre ninguna callable, por diseño.

Mientras tanto: la limitación aceptada es que **esto no es autoservicio**. Un restaurante no puede
gestionar su equipo solo; tiene que pedírselo a quien tiene la clave. Es viable mientras el
propietario gestione sus propios restaurantes. Si algún día vende la plataforma a terceros, hará
falta Blaze.

## Referencias

- Decisiones bloqueadas: `.planning/phases/11-*/11-CONTEXT.md` («Blaze — REVERTIDO», «Gestión de
  personal sin Cloud Functions»).
- Lógica replicada: `functions/src/crear-usuario-staff.js`, `functions/src/cambiar-estado-staff.js`.
- Gate que impide reimplementar la autorización: `scripts/test/staff-cli/contrato-matrices.test.mjs`.
- Comportamiento verificado contra emuladores: `scripts/test/staff-cli/gestion-staff.e2e.mjs`.
