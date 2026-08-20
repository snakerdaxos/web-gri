---
phase: 11-correcci-n-cr-tica-y-profesionalizaci-n-bootstrap-reglas-ndi
plan: 22
subsystem: seguridad
tags: [contrasenas, politica, validacion, cloud-functions, app_cliente, panel_admin, unicode, gate-estatico]

# Dependency graph
requires:
  - phase: 11-06
    provides: "el PasswordField de las dos apps, cuyo parámetro `validator` es por donde entra la política en tres de los cuatro puntos"
  - phase: 11-07
    provides: "la pantalla /bootstrap (punto 4) y la callable bootstrapPlataforma, que NO fija contraseñas y por eso no cambia"
  - phase: 11-08
    provides: "crearUsuarioStaff y el patrón matriz-pura + e2e contra emuladores reales; el criterio de qué mensaje puede viajar al cliente"
  - phase: 11-23
    provides: "el criterio de mensaje honesto (decir QUÉ pasó, no un genérico) aplicado aquí a la validación"
  - phase: 11-24
    provides: "el patrón de contrato ESTÁTICO sobre la fuente de una callable, reutilizado para fijar el ORDEN validación→createUser"
provides:
  - "scripts/password_policy_vectors.json: 22 vectores canónicos, fuente ÚNICA que leen los tests de los tres runtimes"
  - "app_cliente/lib/core/password_policy.dart y panel_admin/lib/core/password_policy.dart: IDÉNTICOS byte a byte, con gate que lo comprueba"
  - "functions/src/password-policy.js: la misma regla y la MISMA redacción en el servidor"
  - "faltantes(password) / validarPassword(password) / ayudaPolitica: el contrato que consumen los cuatro formularios"
  - "password_policy_gate_test.dart (x2): gate estático que prohíbe reescribir la regla en una pantalla, con exenciones DECLARADAS (POLICY-LOGIN-OK)"
  - "MEDICIÓN: el <verify> de grep de la Tarea 2 del plan es INSATISFACIBLE (undécimo gate defectuoso de la fase)"
  - "MEDICIÓN: aplicar la política al LOGIN dejaba la suite ENTERA verde en las dos apps"
  - "MEDICIÓN: con los vectores acentuados del plan, cambiar \\p{Ll} por [a-z] dejaba los 53 casos verdes"
affects: [11-15, 11-16, 11-20]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Duplicación deliberada entre runtimes + VECTORES únicos: no se comparte código (Dart/Node no pueden), se comparte el conjunto de casos. Añadir un vector ejercita las tres implementaciones sin tocar ningún test"
    - "Los dos archivos Dart duplicados se comparan BYTE A BYTE en un test, en vez de pedir la sincronía en un comentario (evolución de password_field.dart y design_tokens.dart)"
    - "Mayúscula/minúscula se reconocen por categoría Unicode (\\p{Lu}/\\p{Ll}), nunca por [A-Z]/[a-z]: en español la Á es mayúscula y la ñ minúscula"
    - "Un vector con acentos NO basta para probar el punto anterior: tiene que ser un vector donde la letra acentuada sea la ÚNICA de su caja"
    - "La política se aplica al FIJAR contraseña, JAMÁS al iniciar sesión; la excepción se declara en el código con POLICY-LOGIN-OK y hay un test que entra con una contraseña antigua"
    - "Un gate estático sobre fuentes debe probar su propio DETECTOR contra las líneas reales de antes del cambio"

key-files:
  created:
    - scripts/password_policy_vectors.json
    - app_cliente/lib/core/password_policy.dart
    - panel_admin/lib/core/password_policy.dart
    - functions/src/password-policy.js
    - app_cliente/test/core/password_policy_test.dart
    - panel_admin/test/core/password_policy_test.dart
    - functions/test/password-policy.test.js
    - app_cliente/test/core/password_policy_gate_test.dart
    - panel_admin/test/core/password_policy_gate_test.dart
  modified:
    - app_cliente/lib/features/auth/register_screen.dart
    - app_cliente/lib/features/auth/auth_controller.dart
    - app_cliente/lib/features/auth/login_screen.dart
    - app_cliente/lib/features/perfil/perfil_screen.dart
    - app_cliente/lib/features/perfil/perfil_controller.dart
    - panel_admin/lib/features/equipo/staff_form_dialog.dart
    - panel_admin/lib/features/bootstrap/bootstrap_screen.dart
    - panel_admin/lib/features/auth/login_screen.dart
    - panel_admin/lib/features/auth/login_controller.dart
    - functions/src/crear-usuario-staff.js
    - functions/test/crear-usuario-staff.contrato.test.js
    - scripts/test/functions/crear-usuario-staff.e2e.mjs
    - app_cliente/test/auth/login_register_test.dart
    - app_cliente/test/perfil/perfil_edit_test.dart
    - panel_admin/test/equipo/equipo_screen_test.dart
    - panel_admin/test/bootstrap/bootstrap_screen_test.dart
    - panel_admin/test/auth/login_form_test.dart
    - docs/ICONOS-panel_admin.md

decisions:
  - "Los vectores canónicos son la fuente de verdad, no el código: quien cambie la política edita el JSON PRIMERO y luego arregla las tres implementaciones hasta que sus tests vuelvan a verde"
  - "'Número' significa dígito ASCII [0-9], no \\p{Nd}, y hay un vector con dígito arábigo-índico que lo fija para que ninguna implementación derive al default de su runtime"
  - "La política NO se aplica al login ni a la contraseña ACTUAL del perfil (T-11-22-04); las exenciones se declaran con POLICY-LOGIN-OK y hay tests que entran con una contraseña antigua"
  - "Los CONTROLADORES (RegisterController y PerfilController.cambiarPassword) también aplican la política, no solo las pantallas: es la última línea de defensa del cliente"
  - "El mensaje del servidor viaja al usuario y es idéntico palabra por palabra al de los formularios; los mismos vectores lo fijan en los tres runtimes"

metrics:
  duration: "~2h"
  completed: "2026-08-20"
  tasks: 3
  commits: 6
---

# Phase 11 Plan 22: Política de contraseñas — Summary

Mínimo 8 con mayúscula, minúscula y número, aplicada en los **cuatro** puntos donde se fija una
contraseña **y en el servidor**, con una implementación por runtime, vectores canónicos únicos y un
gate que impide que las tres se desincronicen o que una pantalla vuelva a escribir la regla.

## Qué se construyó

### Una sola fuente de verdad, con tres implementaciones vigiladas

`scripts/password_policy_vectors.json` (22 vectores) es el único sitio donde vive la definición de
la regla en forma de casos. Lo leen los tests de los tres runtimes:

| Runtime | Implementación | Test que lee los vectores |
|---|---|---|
| app_cliente | `lib/core/password_policy.dart` | `test/core/password_policy_test.dart` (57) |
| panel_admin | `lib/core/password_policy.dart` | `test/core/password_policy_test.dart` (57) |
| Cloud Functions | `src/password-policy.js` | `test/password-policy.test.js` (49) |

Los dos archivos Dart son **idénticos byte a byte** y hay un test en cada app que lo comprueba
(verificado: divergirlos en UN espacio pone rojo el caso en las dos suites). Añadir un vector al
JSON ejercita las tres implementaciones sin tocar ningún test — comprobado borrando `12345678` del
JSON: rojo en Dart y en Node a la vez.

El contrato es el mismo en los tres: `faltantes(password)` devuelve las claves en orden fijo
(`longitud, mayuscula, minuscula, numero`) y `validarPassword(password)` devuelve `null` o el mensaje
concreto, con concordancia:

- `abcdefg1` → *«Te falta una mayúscula.»*
- `ABCDEFGH` → *«Te faltan una minúscula y un número.»*
- `12345678` → *«Te faltan una mayúscula y una minúscula.»*
- `Abcdefg` → *«Debe tener al menos 8 caracteres y te falta un número.»*
- `''` → *«Debe tener al menos 8 caracteres y te faltan una mayúscula, una minúscula y un número.»*

### Los cuatro puntos

| # | Punto | Antes | Ahora |
|---|---|---|---|
| 1 | Registro del cliente | `length >= 8` | `validarPassword` en el `validator` **y** en `_canSubmit`, + `helperText` con la política |
| 2 | Cambio en el perfil | **nada** | `Form` nuevo + validador en los dos campos + guarda en `_guardar` |
| 3 | Alta de staff | `length < _minPassword` | `_validarPassword` delega entera; `_minPassword` eliminada; `helperText` completo |
| 4 | Bootstrap | `length >= 8` | `validarPassword` en `validator` y `_canSubmit`; confirmación intacta |
| S | **Servidor** | `MIN_PASSWORD = 8` | `validarPassword` de `password-policy.js`, **antes** de tocar Auth |

Y, fuera de lo que pedía el plan (Regla 2), los **controladores**: `RegisterController.submit` y
`PerfilController.cambiarPassword` solo miraban la longitud. Son la última línea de defensa del
cliente y, en el caso del perfil, eran *la única* que había.

### La política es del servidor, no solo del cliente — verificado, no afirmado

`crearUsuarioStaff` ya no tiene `MIN_PASSWORD`: importa `validarPassword` de
`functions/src/password-policy.js`. Hay **tres casos e2e nuevos contra emuladores reales** que
invocan la callable **directamente**, saltándose por completo el formulario del panel:

- `12345678` → `functions/invalid-argument`, el mensaje nombra mayúscula y minúscula, **y
  `getUserByEmail` del objetivo lanza `auth/user-not-found`** — es decir, no queda cuenta a medias.
- `Abcdef1` (7 con los tres tipos) → `invalid-argument` con «8 caracteres», sin cuenta creada.
- `Abcdefg1` → sigue creando el usuario (contrapeso obligatorio: sin él, una validación que
  rechazara SIEMPRE dejaría los dos negativos en verde).

Medido: **quitar la validación del servidor pone rojos 3 casos e2e**; moverla *después* de
`createUser` pone rojos 3 e2e + 1 contrato estático; poner un mensaje genérico, 2 e2e + 1 contrato.

`bootstrapPlataforma` **no cambia**, y no por descuido: su fuente tiene **0 coincidencias** de
`password`, `createUser` y `updateUser`. La cuenta del primer `super_admin` la crea el SDK cliente
desde `/bootstrap`, así que para ese punto la única aplicación posible es la del formulario (Tarea 2).
`cambiarEstadoStaff` tampoco toca contraseñas (0 coincidencias).

## Hallazgos

### 1. VERDE POR EL MOTIVO EQUIVOCADO — los vectores acentuados del plan no probaban la minúscula

El plan pedía vectores con acento y con `ñ` para que `[A-Z]`/`[a-z]` no colara. Con esos vectores
exactos (`Ábcdefg1`, `añoNuev0`, `Ñandu1ño`), cambiar `\p{Lu}` por `[A-Z]` tumba 6 casos —
correcto—, pero **cambiar `\p{Ll}` por `[a-z]` dejaba los 53 casos VERDES**. Motivo: los tres
vectores llevan además letras ASCII minúsculas (`bcdefg`, `oueva`, `andu`), así que `[a-z]` las
encuentra igual. No había ni un caso donde la letra acentuada fuera la **única** de su caja.

Se añadieron dos vectores que lo aíslan: `ÑOÑO123ñ` (la única minúscula es la ñ) y `ÁÉÍÓÚ12á`. Con
ellos, esa misma rotura tumba 4 casos. La lección quedó escrita en la cabecera del JSON.

### 2. El `<verify>` de grep de la Tarea 2 es INSATISFACIBLE (undécimo gate defectuoso de la fase)

El plan pedía:

```
cd app_cliente && test $(grep -rn "length >= 8\|length < 8" lib/features | wc -l) -eq 0
cd panel_admin && test $(grep -rn "length >= 8\|length < 8\|_minPassword" lib/features | wc -l) -eq 0
```

Medido antes de tocar nada: **7 coincidencias en el cliente y 9 en el panel**, y de ellas **4 y 3
están en el camino de INICIAR SESIÓN** (`login_screen.dart` ×2 en cada app, `LoginController.submit`
en cada app). Llevar el contador a 0 exige aplicar la política al login, que es exactamente la
denegación de servicio contra los usuarios existentes que **el propio plan declara fuera de alcance
en T-11-22-04**. Cumplir el grep al pie de la letra habría dejado sin entrar a toda cuenta creada
antes de la política.

El gate se sustituyó por `password_policy_gate_test.dart` en cada app, que hace la distinción que
importa (FIJAR vs. INICIAR SESIÓN) y obliga a **declarar** cada excepción con `POLICY-LOGIN-OK`,
mismo patrón que `// AUDIT-STAFF` (11-03) y `// TOKEN-IGNORE` (11-19). Verificado en las dos
direcciones: escribir una regla nueva sin marcador lo pone rojo, y usar el marcador para tapar una
regla que **no** es del login también (la exención tiene que estar en un archivo de login).

### 3. VERDE POR EL MOTIVO EQUIVOCADO — aplicar la política al LOGIN no lo notaba nadie

Con todo el plan implementado, se rompió deliberadamente el login de las dos apps sustituyendo su
`validator` por `validarPassword` (la DoS de T-11-22-04). Resultado **medido**: la suite entera
seguía verde. Ninguno de los 345 + 423 casos entraba con una contraseña que incumpliera la política
nueva; todos usaban `Demo!1234`.

Se añadió un caso por app que inicia sesión con `contrasena` (sin mayúscula ni dígito) y exige que el
botón quede **habilitado**. Con ese caso puesto, la misma rotura pone rojo **exactamente un** caso en
cada app — y es ese. El riesgo aceptado del plan pasa de afirmado a vigilado.

### 4. El detector del gate estático era ciego justo en el punto más débil

La primera versión buscaba `.length <op> <número>` en líneas que mencionaran una contraseña. No veía
`if (nueva.length < 8)` de `perfil_controller.dart`: el identificador se llama `nueva` y quien dice
«contraseña» es la firma, dos líneas más arriba. Tampoco veía `if (s.length < _minPassword)` del
panel, porque el operando derecho es un identificador, no un dígito.

Se corrigió con una ventana de contexto de 5 líneas y aceptando identificadores a la derecha. El
propio gate lleva un caso que le da los **cinco fragmentos reales** del árbol de antes del plan y
exige que los reconozca — con tres contraejemplos para que no se vuelva un «marca todo».

### 5. Cambiar la contraseña en el perfil no tenía dónde validarse

El plan decía «los dos `PasswordField` reciben `validator`». Poner solo el `validator` **no habría
hecho nada**: `PerfilScreen` no tenía `Form`, así que nadie ejecuta esos validadores y el aviso no
aparecería jamás. Hubo que añadir el `Form` con `GlobalKey` y una guarda en `_guardar`.

Y la guarda tenía que ir **al principio**: el método guardaba el nombre *antes* de tocar la
contraseña, así que sin ella una contraseña inválida dejaba el nombre ya escrito y el perfil a
medias. El test lo afirma cambiando el nombre y comprobando que sigue siendo el viejo.

### 6. La política NO se aplica a la contraseña ACTUAL del perfil

Es la otra cara de T-11-22-04, y no estaba escrita en el plan: exigirle la política nueva a la
contraseña **actual** de alguien equivale a negarle el acceso a su propia cuenta. El validador de ese
campo solo comprueba coherencia («escribe tu contraseña actual para poder cambiarla»). Verificado por
rotura: aplicarle `validarPassword` pone rojos 4 casos.

### 7. Un `<verify>` del plan que SÍ funciona

El de la Tarea 3 (`node --check` + `grep -c "MIN_PASSWORD" | -eq 0`) se probó en las dos direcciones:
imprime `POLITICA_EN_SERVIDOR` con la política puesta y sale con 1 al reintroducir `MIN_PASSWORD`.
Es el primero de la fase que no falla.

### 8. Detalle menor: el borde de 7 caracteres estaba probado por el motivo equivocado

El caso preexistente del panel usaba `'1234567'`, que incumple **tres** cosas a la vez: seguiría
rechazándose aunque la comprobación de longitud desapareciera. Se añadió `Abcdef1` (7 caracteres con
mayúscula, minúscula y dígito), que solo puede fallar por longitud. Mismo tratamiento en el e2e.

## Roturas deliberadas

**36 aplicadas y revertidas.** Resumen por bloque:

| Bloque | Roturas | Efecto |
|---|---|---|
| Política Dart | `[A-Z]` (6 rojos) · `[a-z]` (**0 → 4** tras el hallazgo 1) · `\p{Nd}` (2) · mínimo 7 (10) · mensaje genérico (21) · siempre plural (4) · orden cambiado (6) · divergencia de un espacio entre los dos archivos (1 en cada app) · borrar un vector (1 Dart + 1 Node) | 10 |
| Política JS | sin bandera `u` en `\p{Lu}` (37) y en `\p{Ll}` (33) · `[A-Z]` (8) · `[a-z]` (4) · redacción divergente (1) · `\p{Nd}` (2) · mínimo 6 (8) · sin normalizar el tipo (1) | 8 |
| Formularios | registro a `length>=8` (3) · perfil sin guarda del `Form` (2) · perfil aplicando la política a la contraseña vacía (4) · y a la ACTUAL (4) · `PerfilController` a longitud (3) · `RegisterController` a longitud (2) · **política aplicada al login** en cliente (1) y panel (1) · regla nueva sin marcador (1) · staff a longitud (3) · staff sin el `helperText` (2) · bootstrap `validator` (2) · bootstrap `_canSubmit` (2) · marcador usado para tapar una regla que no es de login (1) | 14 |
| Callable | quitar la validación (3 e2e) · moverla tras `createUser` (1 contrato + 3 e2e) · mensaje genérico (1 contrato + 2 e2e) · reintroducir `MIN_PASSWORD` para probar el gate del plan | 4 |

## Desviaciones respecto al plan

**1. [Regla 2 — funcionalidad crítica ausente] Los controladores también aplican la política.**
El plan solo listaba pantallas. `RegisterController.submit` y `PerfilController.cambiarPassword`
comprobaban `length < 8` y son el punto por el que `12345678` llegaba de verdad a Firebase en el
perfil. Ficheros: `auth_controller.dart`, `perfil_controller.dart`. Commit `8d36736`.

**2. [Regla 3 — el gate del plan no es ejecutable] El `<verify>` de grep de la Tarea 2 se sustituyó.**
Ver hallazgo 2. No se relajó: el gate nuevo cubre más (detecta reglas escritas con identificadores y
con literales de copy) y obliga a declarar cada excepción. Commit `b75cfe9`.

**3. [Regla 2] `PerfilScreen` necesitaba un `Form` que no existía.** Ver hallazgo 5.

**4. [Regla 2] La contraseña ACTUAL del perfil queda fuera de la política, con validador propio.**
Ver hallazgo 6. El plan decía «los dos `PasswordField` reciben `validator`» sin distinguirlos.

**5. [Regla 2] Dos vectores añadidos sobre los que pedía el plan** para aislar la minúscula no-ASCII
(hallazgo 1), más `aB1`, `Abcdefg1!`, `8 espacios`, `Abcdefg`, `aA1bbbbb` y el dígito arábigo-índico.
22 vectores en total frente a los ~12 del plan.

**6. [Regla 2] Un caso de login por app** que entra con una contraseña antigua (hallazgo 3).

**7. Ruta del JSON.** El plan decía `../../scripts/…` desde `app_cliente/test/core/`. `flutter test`
corre con el directorio de trabajo en la **raíz del paquete**, así que la ruta correcta es
`../scripts/…`. Documentado en la cabecera de los dos tests.

**8. Contraseña por defecto del helper `_rellenar` del panel.** Era `'clave1234'` (sin mayúscula), que
la política nueva rechaza. Pasó a `'Clave1234'`. No relaja nada: lo que esos casos verifican es el
flujo del alta, y con la contraseña vieja habrían pasado a medir el validador.

**9. `docs/ICONOS-panel_admin.md`.** Dos referencias `archivo:línea` quedaron desfasadas al insertar
comentarios en `login_screen.dart` y `bootstrap_screen.dart`; el gate `sin_emojis_test` de 11-21 las
cazó y se corrigieron (208→212 y 290→294).

**10. Un error propio, corregido.** Al revertir las primeras roturas de la Tarea 2 usé
`git checkout --` con el trabajo **aún sin commitear**, y perdí los cambios de `register_screen.dart`
y `perfil_screen.dart`. Se reconstruyeron y desde entonces las roturas se aplicaron solo sobre código
ya commiteado. No hay pérdida en el resultado final; queda anotado porque es un modo de fallo real
del método de rotura deliberada.

## Verificado vs. afirmado

**Verificado (ejecutado y medido):**
- Los tres runtimes coinciden vector a vector (57 + 57 + 49 casos leyendo el mismo JSON).
- Los dos archivos Dart son idénticos byte a byte (comprobado rompiéndolo con un espacio).
- `12345678` es rechazada en los cuatro formularios y en la callable, con el mensaje concreto.
- La callable **no crea la cuenta** cuando rechaza (comprobado con el Admin SDK tras la llamada).
- El login sigue aceptando contraseñas antiguas en las dos apps.
- Los 36 controles se rompieron uno a uno y cada rotura puso rojo lo que decía proteger.

**Afirmado, no verificado:**
- Que `12345678` deje de aceptarse **en producción** depende de `firebase deploy --only functions`.
  `crearUsuarioStaff` **no está desplegada** en `p-gri-b5b40` (igual que en 11-08 y 11-24): hasta ese
  despliegue, el proyecto real sigue corriendo la versión anterior de la función o ninguna.
- Que la política no rompa el flujo real de alta de staff **contra Firebase real** — el e2e corre
  contra emuladores. Es parte del smoke humano pendiente de la fase.
- Que el texto de ayuda se lea bien en móvil real: se afirma que existe y que dice lo que dice; no se
  midió su layout en un dispositivo.

## Gates — salida real

| Gate | Antes | Después | Salida |
|---|---|---|---|
| `cd app_cliente && flutter analyze` | 0 | 0 | `No issues found!` |
| `cd app_cliente && flutter test` | 273 | **345** | `+345: All tests passed!` |
| `cd panel_admin && flutter analyze` | 0 | 0 | `No issues found!` |
| `cd panel_admin && flutter test` | 354 | **423** | `+423: All tests passed!` |
| `cd functions && npm test` | 96 | **149** | `pass 149 · fail 0` |
| `cd scripts && npm run test:functions` | 47 | **50** | `pass 50 · fail 0` |
| `cd scripts && npm run test:rules` | 221 | 221 | `pass 221 · fail 0` (el plan no toca rules) |
| `cd scripts && npm run audit:indexes` | ok | ok | `22 queries · 5 sujetas a paridad · 0 fallos` |
| `cd scripts && npm run audit:branding` | ok | ok | `2 apps · 4 archivos · 0 rastros de plantilla` |
| `cd scripts && npm run verify:shell` | ok | ok | `2 apps · shell retirado en 1530ms / 930ms` |
| `functions`: `node --check` + `grep -c MIN_PASSWORD -eq 0` | — | ok | `POLITICA_EN_SERVIDOR` |

**Desglose de los tests nuevos**

- app_cliente **273 → 345 (+72)**: `test/core/password_policy_test.dart` **+57** (nuevo),
  `test/core/password_policy_gate_test.dart` **+3** (nuevo), `test/auth/login_register_test.dart`
  23→30 **(+7)**, `test/perfil/perfil_edit_test.dart` 10→15 **(+5)**.
- panel_admin **354 → 423 (+69)**: `test/core/password_policy_test.dart` **+57** (nuevo),
  `test/core/password_policy_gate_test.dart` **+3** (nuevo), `test/equipo/equipo_screen_test.dart`
  14→18 **(+4)**, `test/bootstrap/bootstrap_screen_test.dart` 13→17 **(+4)**,
  `test/auth/login_form_test.dart` 15→16 **(+1)**.
- functions unitarios **96 → 149 (+53)**: `test/password-policy.test.js` **+49** (nuevo),
  `test/crear-usuario-staff.contrato.test.js` **+4**.
- functions e2e **47 → 50 (+3)**: los tres casos de política en `crear-usuario-staff.e2e.mjs`.

## Commits

| Hash | Qué |
|---|---|
| `70d7f64` | `test(11-22)` vectores canónicos + los tres tests que los leen (RED) |
| `dd5b44b` | `feat(11-22)` la política en los tres runtimes, con gate de sincronía (GREEN) |
| `b75cfe9` | `test(11-22)` los cuatro formularios bajo la política + gate de regla suelta (RED) |
| `8d36736` | `feat(11-22)` los cuatro puntos aplican la política, controladores incluidos (GREEN) |
| `757bf4f` | `test(11-22)` e2e que invoca la callable directamente con `12345678` (RED) |
| `0d75309` | `feat(11-22)` la callable aplica la misma política (GREEN) |

## Threat model — estado

| Threat ID | Disposición | Estado |
|---|---|---|
| T-11-22-01 · política solo en el cliente | mitigate | **Cerrada y verificada.** 3 e2e invocan la callable directamente; quitar la validación del servidor pone rojos 3 casos |
| T-11-22-02 · desincronización entre implementaciones | mitigate | **Cerrada.** Vectores únicos leídos por los tres tests + comparación byte a byte de los dos Dart, ambos verificados por rotura |
| T-11-22-03 · mensajes que nombran lo que falta | accept | Decisión del usuario. El mensaje solo describe la política pública, que además está en el texto de ayuda |
| T-11-22-04 · bloquear a usuarios existentes | accept | **Ahora vigilada, no solo aceptada.** El login conserva su comprobación con `POLICY-LOGIN-OK` y hay un caso por app que entra con una contraseña antigua |
| T-11-22-05 · regla ingenua que rechaza acentos | mitigate | **Cerrada, y más fuerte que en el plan.** Ver hallazgo 1: los vectores del plan no bastaban para la minúscula |

## Deuda y avisos para quien siga

- **`crearUsuarioStaff` sigue sin desplegar.** Mientras no se haga `firebase deploy --only functions`,
  la política del servidor existe en el repo pero no en `p-gri-b5b40`.
- **El gate de sincronía es por-repo.** Si algún día las apps se separan en repos distintos, la
  comparación byte a byte deja de poder ejecutarse y hay que sustituirla por otra cosa (paquete
  compartido o generación desde el JSON).
- **`_lineasDeContexto = 5`** en el gate estático es un heurístico. Una comprobación de longitud de
  contraseña separada más de 5 líneas de cualquier palabra que suene a contraseña pasaría
  desapercibida. No es un agujero de seguridad (la política real la aplica el servidor), pero sí un
  límite conocido del gate.
- **La política no toca las cuentas existentes.** Nadie está obligado a cambiar su contraseña vieja;
  se le exigirá la nueva regla la primera vez que la cambie. Es la decisión del plan, no un olvido.

## Self-Check: PASSED
