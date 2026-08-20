---
phase: 11-correcci-n-cr-tica-y-profesionalizaci-n-bootstrap-reglas-ndi
plan: 23
subsystem: ux
tags: [errores, mensajes, firebase, permission-denied, emuladores, app_cliente, diagnostico]

# Dependency graph
requires:
  - phase: 11-14
    provides: "la suite de a11y y el token #6E6E6E que los mensajes nuevos no podían romper (no se tocó ni un color)"
  - phase: 11-19
    provides: "el gate sin_hex_crudos_test y los tokens del cliente (los archivos nuevos no declaran ni un hex)"
  - phase: 11-09
    provides: "la convención de estados de error y la lección de que un CTA no debe mentir sobre lo que pasó"
  - phase: 11-04
    provides: "la regla `isCliente()` del create de sesiones — la causa REAL del permission-denied del incidente"
provides:
  - "app_cliente/lib/core/firebase_error_mapper.dart: CausaFallo, Contexto, clasificarFallo, mensajeDe, mensajeDeFallo"
  - "codigoMesaRegExp como fuente ÚNICA del formato del código de mesa, ahora en el DOMINIO"
  - "app_cliente/test/core/firebase_error_mapper_test.dart: 22 casos, incluido el caso NO CONFUSIÓN"
  - "app_cliente/test/pedidos/errores_honestos_test.dart: 10 casos sobre pedido, cuenta y calificación + gate estático sobre las fuentes del flujo"
  - "MEDICIÓN: el `<verify>` de grep del plan es defectuoso en LAS DOS direcciones (décimo de la fase)"
  - "MEDICIÓN: en `testWidgets`, restaurar `debugPrint` en un `addTearDown` llega TARDE"
affects: [11-16, 11-25]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "La causa de un fallo se CLASIFICA en un módulo puro y sin imports de UI; la redacción se elige por (causa, contexto). Mismo papel que functions/src/auth-matrix.js"
    - "Nunca importar `dart:io` en `lib/` de esta app (se compila a web): los fallos de red de io se reconocen por el PREFIJO de `toString()`, que sobrevive a la minificación — `runtimeType.toString()` no"
    - "Una pista de desarrollo se pone tras `const bool.fromEnvironment`, para que el compilador la pode del binario de producción"
    - "Cuando la expectativa de un test depende de un define, la expectativa entra por un define DISTINTO: comparar contra el mismo flag que lee la implementación es tautológico"
    - "La validación de formato vive en el DOMINIO, no en el validator de la pantalla: la cámara no pasa por el formulario"

key-files:
  created:
    - app_cliente/lib/core/firebase_error_mapper.dart
    - app_cliente/test/core/firebase_error_mapper_test.dart
    - app_cliente/test/pedidos/errores_honestos_test.dart
  modified:
    - app_cliente/lib/features/sesion_qr/sesion_provider.dart
    - app_cliente/lib/features/sesion_qr/sesion_provider.g.dart
    - app_cliente/lib/features/sesion_qr/scan_screen.dart
    - app_cliente/lib/features/pedidos/menu_mesa_screen.dart
    - app_cliente/lib/features/pedidos/pedido_estado_screen.dart
    - app_cliente/lib/features/pagos/calificacion_sheet.dart
    - app_cliente/test/sesion_qr/scan_test.dart

decisions:
  - "Un `permission-denied` y un `unauthenticated` se agrupan en `permisoDenegado`: para el usuario el problema es el MISMO (su cuenta) y en ninguno de los dos casos es el código"
  - "`aborted` y `failed-precondition` caen a `desconocido` A PROPÓSITO: no son de red ni de permisos, y meterlos en un saco concreto reproduciría el bug con otro texto"
  - "`codigoMesaRegExp` se muda de la pantalla al dominio; scan_screen reutiliza el MISMO objeto"
  - "El texto de `noDisponible/abrirMesa` queda CONGELADO con su redacción anterior: ya era correcto"
  - "El mensaje describe la CONDICIÓN de la cuenta, nunca la regla concreta ni el rol (T-11-23-01)"

metrics:
  duration: "~2h 05min"
  tasks: 3
  files: 10
  completed: 2026-08-19
---

# Phase 11 Plan 23: Mensajes honestos en el flujo de mesa — Summary

Clasificador único de fallos de Firebase que separa las cinco causas del escaneo y les da su
mensaje, cerrando el bug que hizo al usuario revisar durante un rato un QR que era correcto.

## Qué se construyó

`app_cliente/lib/core/firebase_error_mapper.dart` traduce cualquier excepción a una `CausaFallo`
y ésta, junto con el `Contexto` de la operación, a un texto. Es lógica pura: no importa pantallas,
ni providers, ni `dart:io`. El flujo entero de mesa —abrir, pedir, pedir la cuenta y calificar—
pasa ahora por él en lugar de por cuatro `catch` que afirmaban una causa que no conocían.

### Las cinco causas y su mensaje (contexto `abrirMesa`, verificado ejecutándolo)

| Causa | Detección | Mensaje |
|---|---|---|
| `formatoInvalido` | `codigoMesaRegExp` no casa | «Ese código no parece el de una mesa GRI. Revisa que estés escaneando el QR de la mesa.» |
| `noEncontrado` | el doc `mesas/{codigo}` no existe | «Esa mesa no existe. Puede que el QR sea de otro restaurante o que la mesa se haya eliminado.» |
| `noDisponible` | `TransicionInvalidaException` | «La mesa no está disponible en este momento» |
| `permisoDenegado` | `code: permission-denied` / `unauthenticated` | «Tu cuenta no puede abrir mesas. Entra con una cuenta de cliente para pedir desde la mesa.» |
| `sinConexion` | `unavailable`, `deadline-exceeded`, `cancelled`, `internal`, `SocketException`, `TimeoutException` | «No pudimos conectar con el servidor. Revisa tu conexión e inténtalo de nuevo.» |

Y el sexto, que existe para no mentir: `desconocido` → «No pudimos abrir la mesa. Vuelve a
intentarlo; si sigue igual, avisa al mesero.» — no culpa al código ni a la red.

Con `--dart-define=USE_EMULATORS=true`, el mensaje de `sinConexion` añade «¿Están corriendo los
emuladores?». Es el segundo tropiezo del incidente real, y el texto se poda del binario de
producción porque la condición es `const bool.fromEnvironment`.

## Tareas y commits

| # | Tarea | Commits |
|---|---|---|
| 1 | Clasificador único de fallos de Firebase | `ccada96` (RED), `2ada353` (GREEN) |
| 2 | El flujo de escaneo distingue las cinco causas | `6064faf` (RED), `562be15` (GREEN) |
| 3 | Mismo criterio en los demás catch genéricos | `4401b4d` (RED), `82eae56` (GREEN) |

## Gates ejecutados (salida real)

| Gate | Resultado |
|---|---|
| `flutter analyze` (app_cliente) | `No issues found!` — 0 issues |
| `flutter test` (app_cliente) | `00:12 +273: All tests passed!` |
| `flutter test test/core/firebase_error_mapper_test.dart` | `+22: All tests passed!` |
| Idem con `--dart-define=USE_EMULATORS=true --dart-define=ESPERA_PISTA_EMULADORES=true` | `+22: All tests passed!` |
| `flutter test test/sesion_qr/` | `+22: All tests passed!` |
| `flutter test test/pedidos/errores_honestos_test.dart` | `+10: All tests passed!` |
| `<verify>` 2 del plan (grep del mensaje ciego) | `SIN_MENSAJE_CIEGO`, exit 0 |

**Base de tests: 230 → 273 (+43).** Desglose: +22 `firebase_error_mapper_test.dart` (nuevo),
+10 `errores_honestos_test.dart` (nuevo), +11 en `scan_test.dart` (11 → 22; un caso preexistente
se reescribió, no se añadió). Medida antes de tocar nada: `00:08 +230`, analyze 0.

## Roturas deliberadas: 34, y 3 VERDES cazadas

Ningún gate se da por bueno sin romper lo que protege. Se aplicaron 34 mutaciones, cada una
revertida acto seguido.

- **Tarea 1 — 12 roturas, 12 rojas.** Incluye desclasificar `permission-denied`, colar `aborted`
  como fallo de red, unificar dos mensajes y devolver el texto del incidente real.
- **Tarea 2 — 9 roturas, 7 rojas + 2 VERDES.**
- **Tarea 3 — 13 roturas, 12 rojas + 1 VERDE** (9 de mensaje/contexto + 4 de traza).

### VERDE 1 — borrar el `debugPrint` no lo notaba nadie (T-11-23-04)

El registro de amenazas del plan dice «se conserva el `debugPrint` de trazado; ninguno queda
mudo». **Borrando la línea entera de `sesion_provider.dart` la suite quedaba en verde**, y lo mismo
en las tres pantallas de la Tarea 3. La mitigación estaba AFIRMADA, no verificada.

Cerrado interceptando `debugPrint` de verdad (es una variable global reasignable) y afirmando que
la traza lleva el `code` de Firebase **y** cómo se clasificó. Con eso, borrar la traza en
cualquiera de los cuatro puntos pone rojo el caso correspondiente (roturas D, J, K), y quitarle el
`$e` para dejar solo la clasificación también (rotura L).

**MEDICIÓN que costó un rato:** en `testWidgets` la restauración NO puede ir en un `addTearDown`.
`TestWidgetsFlutterBinding._verifyInvariants` llama a `debugAssertAllFoundationVarsUnset` **antes**
de ejecutar los tearDown, así que el caso falla con «The value of a foundation debug variable was
changed by the test» aunque la restauración esté escrita. Va en el cuerpo del caso. En un `test()`
normal (el de `scan_test.dart`) el `addTearDown` sí vale, porque esa comprobación no existe.

### VERDE 2 — la regexp «compartida» no estaba verificada

`scan_screen.dart` pasa a usar `codigoMesaRegExp` del dominio en vez de su copia. Deshacerlo y
volver a escribir la expresión a mano —perdiendo el guion del slug, `[a-z0-9-]+` → `[a-z0-9]+`—
**dejaba la suite ENTERA en verde**, porque ningún caso usaba un slug con guion y ese es
justamente el carácter que se pierde al copiar mal. Cerrado con un caso que escribe
`GRI-MESA-mi-resto-001` en el campo y afirma que el validator NO lo rechaza y que el mensaje que
sale es el del dominio («esa mesa no existe»).

### VERDE 3 — la pista de emuladores comparada consigo misma

La forma natural de escribir el caso es
`expect(texto.contains(pistaEmuladores), usandoEmuladores)`. Es tautológica: si alguien escribiera
`bool.fromEnvironment('USE_EMULATORS', defaultValue: true)`, la pista aparecería en el binario de
producción y los dos lados de la igualdad se moverían a la vez, dejando el caso verde. Se detectó
antes de commitear y la expectativa entra por un define INDEPENDIENTE
(`ESPERA_PISTA_EMULADORES`), que solo conoce quien lanza la suite. La rotura G (cambiar el
`defaultValue` a `true`) confirma que ahora sí pone rojo.

## HALLAZGO: el `<verify>` 2 del plan es defectuoso en LAS DOS direcciones

Es el **décimo gate de grep defectuoso de la fase** (11-06, 11-08 ×2, 11-13 ×2, 11-19, 11-12,
11-14, y este). El comando es:

```
test $(grep -rn "Error de conexión. Intenta de nuevo." lib/features | wc -l) -eq 0
```

Probado en vivo con tres mutaciones:

| Prueba | Coincidencias | Gate | Debería |
|---|---|---|---|
| El mensaje ciego vuelve como CÓDIGO | 1 | FALLA | FALLAR ✓ |
| El mensaje aparece solo en un COMENTARIO | 1 | FALLA | PASAR ✗ falso positivo |
| Mensaje ciego con OTRA redacción (`'Sin conexión. Reintenta.'`) | 0 | PASA | FALLAR ✗ punto ciego |

Tiene dientes para la cadena exacta, pero confunde documentación con código y no ve ninguna
variante. Se ejecutó igualmente (exit 0, `SIN_MENSAJE_CIEGO`) y se acompaña de dos cosas que sí
cubren los huecos: el **gate estático** de `errores_honestos_test.dart`, que lee las fuentes de los
6 archivos del flujo y **salta las líneas de comentario**; y los **casos de comportamiento**, que
son los que cazan la redacción distinta — verificado: con `'Sin conexión. Reintenta.'` puesto, la
suite se pone roja (2 casos).

## Barrido del resto de `catch` de `lib/features/` (lo pedía la Tarea 3)

Se revisaron los 26 `catch` del árbol. Los que se dejan SIN TOCAR y por qué:

| Sitio | Texto genérico | Por qué se deja |
|---|---|---|
| `reserva_controller.dart:245,268` | «No se pudo crear/cancelar la reserva» | Fuera de este flujo (el plan lo nombra explícitamente). Además NO atribuye causa: dice qué no se pudo hacer, no por qué. **Deuda real:** son `catch (_)` **mudos**, sin traza |
| `mis_reservas_screen.dart:276`, `reserva_wizard_screen.dart:323` | fallback de `ReservaException` | Fuera de flujo; mismo criterio |
| `login_screen.dart:57,74`, `register_screen.dart:76,92` | «Error al iniciar sesión» | Flujo de auth, fuera de alcance. No atribuye causa |
| `perfil_screen.dart:61` | «Error al guardar el perfil» | Fuera de flujo. No atribuye causa |
| `scan_screen.dart:71` | `catch (_)` al parar la cámara | Legítimo y documentado: la cámara ya estaba detenida |

El criterio aplicado: se corrige el `catch` que **afirma una causa concreta** («es tu código», «es
tu conexión»). Un «no se pudo hacer X» es incompleto, pero no miente.

## Deviations from Plan

**1. [Regla 1 — Realidad contradice el plan] `pedidos_provider.dart` no tiene ningún `catch` genérico**

- **Encontrado en:** Tarea 3.
- **El plan dice:** «más los `catch` equivalentes de `pedidos_provider.dart`», y lo lista en
  `files_modified`.
- **Realidad medida:** ese archivo **no contiene ni un solo `catch`**. `crearPedido` y
  `solicitarCuenta` lanzan `PedidoException` de dominio y `PedidosController.enviar` usa
  `try/finally` sin `catch`. Los fallos crudos suben tal cual hasta las pantallas, que es donde
  estaban los `catch` ciegos y donde se han corregido.
- **Decisión:** NO se modifica. Inventarle un `catch` sería añadir una capa sin motivo. El
  comportamiento que el plan pedía (un `permission-denied` al crear pedido produce un mensaje sobre
  el permiso) está verificado igualmente, en `errores_honestos_test.dart`.

**2. [Regla 1 — Bug] Un caso preexistente afirmaba el mensaje que este plan separa**

- **Encontrado en:** Tarea 2.
- **Issue:** `scan_test.dart` afirmaba `'Código de mesa inválido'` para
  `GRI-MESA-demo-999` — un código **bien formado** cuya mesa no existe. Ese era exactamente el
  síntoma: dos causas, un mensaje.
- **Fix:** reescrito conscientemente al mensaje de `noEncontrado`, con un caso hermano nuevo para
  el formato roto y una aserción de que los dos textos difieren.
- **Commit:** `6064faf`.

**3. [Regla 2 — Funcionalidad crítica ausente] La validación de formato no cubría la cámara**

- **Encontrado en:** Tarea 2.
- **Issue:** la regexp vivía SOLO en el validator del campo manual. `_onDetect` entrega el texto
  crudo del QR directamente al dominio, así que un QR de otra app (una URL, por ejemplo) llegaba a
  Firestore, no encontraba documento y salía por «mesa inexistente» — que es falso.
- **Fix:** `codigoMesaRegExp` se muda al dominio y se comprueba antes de la transacción; la
  pantalla reutiliza el mismo objeto. Ahorra además un viaje a Firestore.
- **Commit:** `562be15`.

**4. [Regla 2] Documentación que describía el comportamiento eliminado**

- El doc comment de `SesionController` seguía diciendo «Los errores de dominio ('Código de mesa
  inválido' / 'Mesa ocupada')». Actualizado en `sesion_provider.dart` **y a mano en las 4
  apariciones de `sesion_provider.g.dart`**, que es exactamente lo que emitiría `build_runner`. No
  se ejecutó `build_runner` a propósito: otros ejecutores tenían archivos abiertos en el mismo
  árbol y regenerar todos los `.g.dart` habría mezclado trabajo ajeno. Es un cambio de comentario:
  cero impacto funcional.

## Threat model — estado de las cuatro mitigaciones

| ID | Estado |
|---|---|
| T-11-23-01 (fuga por el mensaje) | **Mitigado.** Los 4 textos de `permisoDenegado` hablan de la condición de la cuenta; ninguno nombra la regla, el rol ajeno ni la estructura de datos |
| T-11-23-02 (usuario bloqueado por diagnóstico erróneo) | **Mitigado y verificado.** Cinco causas, cinco mensajes, comparados dos a dos en dos niveles: la tabla del mapeador y el flujo REAL a través del controller |
| T-11-23-03 (pista de emuladores en producción) | **Mitigado.** `const bool.fromEnvironment`; verificado ejecutando la suite en las dos ramas y con la rotura G |
| T-11-23-04 (fallos silenciados) | **Mitigado — y era la VERDE 1.** Ahora verificado en los 4 puntos interceptando `debugPrint` |

## Verificado vs afirmado — leerlo antes de dar esto por cerrado

**Verificado por ejecución:**
- Que las cinco causas producen cinco cadenas distintas, y que las de `permisoDenegado` y
  `sinConexion` no contienen «código», «QR» ni «verifica». Afirmado en el mapeador y, otra vez,
  ejecutando el flujo real con cada causa montada.
- Que la pantalla de escaneo no muestra ninguna de esas palabras ante un `permission-denied`
  (aserción sobre el `data` de **todos** los `Text` del árbol, no solo el SnackBar).
- Que el botón vuelve a habilitarse y se puede reintentar.
- Que los mensajes de dominio ya correctos NO cambiaron.

**Afirmado, NO verificado (requiere persona):**
- **Que los textos nuevos SE LEAN bien y de verdad ayuden.** Un widget test prueba que una cadena
  se renderiza ante un fallo simulado; no prueba que un comensal con el móvil en la mano entienda
  qué hacer. Los seis textos de `abrirMesa` están en la tabla de arriba para que se puedan revisar
  de un vistazo.
- **El incidente real de punta a punta**, que es la comprobación manual que pide el plan: entrar
  con una cuenta de staff/super_admin **contra Firebase real** y escanear un QR válido. Aquí se
  reprodujo inyectando el `permission-denied` en el fake; `fake_cloud_firestore` **no tiene motor de
  rules** (decisión de 11-04), así que lo que está probado es la REACCIÓN al código de error, no
  que las rules lo emitan en ese preciso caso.
- **El segundo tropiezo**: arrancar con `--dart-define=USE_EMULATORS=true` y los emuladores
  apagados. Lo verificado es que la pista aparece si y solo si el define está activo; que un
  emulador caído produzca `unavailable` y no otro código no se ha observado en vivo.

## Known Stubs

Ninguno. No se dejó ningún valor vacío, texto de relleno ni componente sin cablear.

## Incidente de árbol compartido: mi commit se llevó trabajo de 11-24

Hay que decirlo aunque no deje bien: **el commit `2ada353` (Tarea 1) contiene 8 archivos de
`panel_admin/` y `docs/` que son de 11-24**, no míos.

- **Qué pasó:** 11-24 había ejecutado su `git add` pero su `git commit` no llegó a correr (una
  opción inexistente rompió su cadena `&&`). Sus archivos quedaron en el índice. Yo hice
  `git add app_cliente/lib/core/firebase_error_mapper.dart && git commit -m "..."` y me los llevé.
- **Causa raíz, que es la lección:** `git commit -m` **sin pathspec committea el ÍNDICE ENTERO**, no
  solo lo que acabas de añadir. Estagear únicamente lo propio —que es lo que hice— **no basta** en
  un árbol compartido. Lo correcto es `git commit -- <rutas>` o comprobar
  `git diff --cached --name-only` justo antes.
- **Alcance, auditado:** revisados los 6 commits de este plan uno a uno con `git show --name-only`.
  **Solo `2ada353` está contaminado**; los otros cinco llevan exactamente sus archivos y nada más.
- **No se reescribió el historial.** Es destructivo con otros ejecutores activos en el mismo árbol,
  y 11-24 ya tomó la misma decisión desde su lado. El contenido de los 8 archivos está intacto en
  HEAD y verificado por su propia suite.

## Notas para quien siga

- **Los mensajes de `Contexto.crearPedido`, `solicitarCuenta` y `calificar` se redactaron aquí sin
  que el usuario los revisara.** Los de `abrirMesa` sí vienen de la tabla que él enumeró. Si hay
  que retocar wording, se toca en un solo sitio: `mensajeDe`.
- **`codigoMesaRegExp` cambió de ARCHIVO, no de valor.** Hay cuatro comentarios que la citan
  apuntando a `app_cliente/.../scan_screen.dart`: `panel_admin/lib/features/configuracion/slug.dart`,
  `panel_admin/test/configuracion/slug_test.dart`, `functions/src/auth-matrix.js` y
  `scripts/test/rules/mesas.test.mjs`. Son de otros ejecutores y no se tocaron; el puntero está
  desactualizado en la ubicación, no en la regla. `slug_test.dart` sigue llevando su COPIA literal
  (decisión de 11-05) y sigue siendo correcta.
- **Deuda detectada y NO corregida:** los dos `catch (_)` de `reserva_controller.dart` son mudos —
  se tragan la excepción sin dejar traza. Mismo defecto que T-11-23-04 pero en el flujo de
  reservas, fuera del alcance de este plan.
- `test:rules`, `test:functions`, `audit:indexes` y `audit:branding` NO se ejecutaron: este plan no
  toca rules, índices, functions ni assets de marca, y 11-24/11-25 tenían `functions/` y
  `panel_admin/` abiertos en el mismo árbol.
- **AJENO, sigue sin commitear** (ya declarado por 11-13, 11-19 y 11-14):
  `app_cliente/lib/features/restaurantes/restaurantes_provider.g.dart` sigue regenerado sin que
  ningún plan lo reclame, y `android/app/src/main/AndroidManifest.xml` + `android/.../res/xml/`
  siguen modificados desde antes de esta sesión. 11-23 no los estageó.

## Self-Check: PASSED
