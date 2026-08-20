---
phase: 11-correcci-n-cr-tica-y-profesionalizaci-n-bootstrap-reglas-ndi
plan: 29
subsystem: reservas
tags: [p0, reservas, mensajes-honestos, estado-mesa, firestore, app_cliente, panel_admin, rules]

# Dependency graph
requires:
  - phase: 11-23
    provides: "el clasificador único `core/firebase_error_mapper.dart` y el criterio de mensaje honesto — aquí se REUTILIZA con dos contextos nuevos, no se reinventa"
  - phase: 11-27
    provides: "la regla de `read` que permite leer el SLOT AUSENTE — sin ella el bucle de asignación no existe"
  - phase: 10-03
    provides: "la transacción determinista `crearReserva` y el doc ID `{mesaId}_{yyyyMMdd}_{HH}`"
provides:
  - "crearReserva salta la mesa ocupada en vez de abortar la búsqueda (bug A)"
  - "el estado de la mesa solo lo mueve una reserva de HOY, en create y en cancel (bug B)"
  - "los tres motivos de 'no hay mesa' tienen tres mensajes distintos y ciertos"
  - "Contexto.crearReserva y Contexto.cancelarReserva en el mapeador de 11-23"
  - "los dos catch (_) MUDOS de reservas dejan traza (deuda que 11-23 dejó anotada)"
  - "MEDICIÓN: la rama esHoy es HOY INALCANZABLE desde la UI (firstDate = mañana)"
  - "barrido completo de los 36 catch de las dos apps"
affects: [panel_admin/dashboard (mapa de mesas — deuda declarada), docs/SMOKE-E2E-v2.md]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "El estado de un recurso describe ESTE momento: una reserva futura no lo escribe, y por tanto tampoco lo consulta (el guard existía solo para proteger la escritura)"
    - "Un bucle de búsqueda descarta candidatas CONTANDO el motivo; el fallo final se redacta con los motivos reales, no con uno elegido a dedo"
    - "Cada `catch` de dominio hace rethrow; lo que no es de dominio pasa por `mensajeDeFallo` — el `catch` nunca redacta"

key-files:
  created:
    - app_cliente/test/reservas/asignacion_mesa_test.dart
    - app_cliente/test/reservas/errores_honestos_reserva_test.dart
  modified:
    - app_cliente/lib/features/reservas/reserva_controller.dart
    - app_cliente/lib/core/firebase_error_mapper.dart
    - app_cliente/test/reservas/wizard_form_test.dart
    - app_cliente/test/reservas/mis_reservas_render_test.dart
    - panel_admin/lib/features/reservas/reservas_provider.dart
    - panel_admin/lib/features/reservas/reservas_screen.dart
    - panel_admin/test/reservas/reservas_screen_test.dart
    - scripts/test/rules/reservas.test.mjs
    - scripts/gates.mjs
    - docs/SMOKE-E2E-v2.md
    - docs/ICONOS-panel_admin.md
    - .planning/PENDIENTE-POST-FASE-11.md

decisions:
  - "Bug B con la opción MÍNIMA que eligió el usuario: tocar el estado solo si el slot es de hoy. No se rediseña el mapa de mesas"
  - "COROLARIO aplicado (desviación): para un slot futuro el estado tampoco se CONSULTA. El guard existía solo para proteger la escritura que ya no ocurre"
  - "SIMÉTRICO aplicado (desviación): cancelarReserva solo revierte la mesa si la reserva era de hoy — si no, liberaría una mesa que reservó OTRA reserva"
  - "El texto 'No hay mesas disponibles en ese horario' se CONSERVA: para su causa (todos los slots tomados) siempre fue correcto"
  - "No se toca `firestore.rules`. Las rules nunca gatearon el estado de la mesa: el guard era del cliente"
  - "NO se cambia `firstDate: mañana` del wizard. Que hoy no se pueda reservar para hoy es una decisión de producto, no un bug que me toque arreglar de tapadillo"

metrics:
  duration: "~2 h"
  tasks: 5
  files: 14
  completed: 2026-08-20
  gates: 9/9 OK
  tests: "app_cliente 348→371 · panel_admin 445→446 · rules 282→285 · functions 149 + 50 e2e"
---

# Fase 11 Plan 29: Reservas — dos bugs de lógica y el mensaje que los tapaba

El usuario intentó reservar **para una fecha futura** contra el proyecto real y la app le dijo
*«Ese horario acaba de ser reservado, elige otro»* con **cero reservas** en la base. Tres defectos
encadenados: uno abortaba la búsqueda, otro bloqueaba mesas por adelantado y el tercero descartaba
el mensaje preciso que la lógica interna ya producía.

---

## Lo que se arregló

### BUG A — una mesa ocupada abortaba la búsqueda entera

`reserva_controller.dart`. El bucle era incoherente: un **slot** tomado hacía `continue`, pero una
**mesa** ocupada lanzaba y mataba la búsqueda con el resto de candidatas sin mirar.
`GRI-MESA-demo-001` (capacidad 2) estaba `ocupada` porque el propio usuario había abierto sesión
en ella, y es la primera candidata para 2 personas.

Ahora se salta y solo se falla cuando se han examinado **todas**. Y se cuenta *por qué* se descartó
cada una, para poder decirlo.

### BUG B — reservar para el futuro bloqueaba la mesa hoy

`tx.update(mesa, {'estado': 'reservada'})` corría fuera cual fuera la fecha del slot. Reservar para
el martes que viene marcaba la mesa reservada **ahora**, quitándola de la circulación.

Arreglado con **la opción mínima que eligió el usuario**: el estado solo se toca si el slot es de
hoy. Dos consecuencias que van con ella y que NO estaban en el enunciado (ver *Desviaciones*): para
un slot futuro el estado tampoco se **consulta**, y `cancelarReserva` solo revierte la mesa si la
reserva era **de hoy**.

### BUG C — el mensaje destruía la verdad

```dart
} on ReservaException {
  // 409-equivalentes del port (capacidad/slot tomado/estado mesa)
  throw const ReservaException('Ese horario acaba de ser reservado, elige otro');
```

El comentario enumera **tres** causas y elige el texto de **una** — falso para dos de ellas. Ahora
el error de dominio sube con `rethrow` y lo que no es de dominio pasa por el clasificador único de
11-23, con dos contextos nuevos: `crearReserva` y `cancelarReserva`.

**Los mensajes, ahora (verificados ejecutándolos):**

| Situación | Mensaje |
|---|---|
| Ninguna mesa con capacidad | «No hay mesas con capacidad suficiente» *(sin cambios)* |
| Todos los slots tomados | «No hay mesas disponibles en ese horario» *(sin cambios: para ESTA causa siempre fue cierto)* |
| Todas las mesas ocupadas (solo posible reservando para hoy) | «Todas las mesas para N personas están ocupadas en este momento. Prueba más tarde o reserva para otro día.» |
| Mezcla de las dos | «No queda ninguna mesa para ese horario: X con la franja ya reservada y Y ocupada(s) en este momento.» |
| `permission-denied` / `unauthenticated` | «Tu cuenta no puede reservar mesas. Entra con una cuenta de cliente para reservar.» |
| `unavailable` / red caída | «No pudimos conectar con el servidor para crear tu reserva. Revisa tu conexión e inténtalo de nuevo.» |
| Cualquier otra cosa | «No pudimos crear la reserva. Vuelve a intentarlo; si sigue igual, llama al restaurante.» |

Y los dos `catch (_)` **mudos** que 11-23 dejó anotados como deuda («se tragan la excepción sin
dejar traza») ahora registran el código de Firebase **y** cómo se clasificó.

---

## ⚠️ HALLAZGO QUE CAMBIA EL ALCANCE REAL DEL ARREGLO B

**Desde la app, hoy NO se puede reservar para hoy.** `reserva_wizard_screen.dart:271` fija
`firstDate: mañana`, y la app cliente es el **único** escritor de la colección `reservas` (el panel
solo cancela; el seed no crea ninguna). Comprobado con un barrido de las dos apps.

Consecuencia medida, no supuesta:

- La rama `esHoy == true` —la que marca la mesa `reservada` y la que salta las mesas ocupadas— es
  **inalcanzable desde el producto tal y como está hoy**. Se conserva porque es la lógica correcta
  el día que el selector permita reservar para hoy, y está cubierta por tests.
- En la práctica, **el cliente ya nunca pone una mesa en `reservada`**. Ese estado (el amarillo del
  mapa) solo lo produce ahora el staff a mano desde `mesa_actions_sheet` («Marcar reservada»).
- Lo que de verdad arregló el fallo que sufrió el usuario es el **corolario**: para un slot futuro
  ya no se consulta el estado de la mesa. Con la lectura literal del enunciado («saltar la mesa»)
  también habría funcionado —le habría tocado la mesa 2 en vez de la 1— pero seguiría descartando
  candidatas por un motivo que no aplica a una fecha futura.

**No he tocado `firstDate`.** Permitir reservar para hoy es una decisión de producto (¿con cuánta
antelación mínima? ¿la mesa se marca al confirmar o al llegar el cliente?) y merece decidirse, no
colarse dentro de un arreglo de bugs.

---

## Barrido completo de los `catch` de las dos apps

Los **36** `catch` de `app_cliente/lib` y `panel_admin/lib` (excluidos los `.g.dart`), uno a uno.
El criterio es el que fijó 11-23: **se corrige el `catch` que afirma una causa concreta que no
conoce.** Un «no se pudo hacer X» es incompleto, pero no miente.

### Corregidos en este plan (3)

| Sitio | Antes | Ahora |
|---|---|---|
| `reserva_controller.dart` `create` · `on ReservaException` | «Ese horario acaba de ser reservado» para capacidad, slot y estado de mesa | `rethrow`: el dominio ya trae la causa |
| `reserva_controller.dart` `create` · `on TransicionInvalida` + `catch (_)` | el mismo texto ciego / `catch` **mudo** | `mensajeDe(noDisponible)` y `mensajeDeFallo`, con `debugPrint` de la causa |
| `reserva_controller.dart` `cancel` · `on TransicionInvalida` + `catch (_)` | texto fijo / `catch` **mudo** | mapeador + traza |

### Revisados y DEJADOS COMO ESTÁN, con el motivo (33)

**app_cliente**

| Sitio | Texto / conducta | Veredicto |
|---|---|---|
| `google_auth.dart:64,91` | reconocen la cancelación del usuario y `rethrow` el resto | **Correcto.** No inventa nada; el `StateError` del `idToken == null` incluso nombra la causa exacta (serverClientId/SHA-1) |
| `tx_mutex.dart:37` | convierte un throw síncrono en `Future.error` y libera el mutex | **Correcto.** No es un `catch` de presentación: preserva el error original |
| `auth_controller.dart:109,175,237` | `authErrorMessage(e, fallback: …)` por código de Auth | **Correcto.** Mapea por código; el fallback no atribuye causa |
| `login_screen.dart:58,75` · `register_screen.dart:77,93` | pasan el `StateError`/`ArgumentError` y caen a «Error al iniciar sesión» | **Incompleto, no falso.** Dice qué no se pudo hacer, no por qué. Fuera del flujo de este plan |
| `perfil_controller.dart:68` | `permission-denied` → permisos; `unavailable` → conexión; resto genérico | **Correcto**, y ya distingue causas. *Nota menor:* usa voseo («verificá») frente al tuteo del resto de la app |
| `perfil_controller.dart:111` | `wrong-password`/`invalid-credential` → «Contraseña actual incorrecta» | **Correcto** y específico |
| `perfil_screen.dart:92` | passthrough del mensaje + «Error al guardar el perfil» | **Incompleto, no falso** |
| `scan_screen.dart:71` | `catch (_)` al parar la cámara, documentado | **Legítimo**: la cámara ya estaba detenida |
| `scan_screen.dart:97,106` · `sesion_provider.dart:245,247,252` · `menu_mesa_screen` · `pedido_estado_screen` · `calificacion_sheet` | pasan por el mapeador | **Ya arreglados en 11-23** |
| `mis_reservas_screen.dart:276` · `reserva_wizard_screen.dart:323` | fallback para lo que no sea `ReservaException` | **No falso.** Además ahora es prácticamente **inalcanzable**: el controller siempre lanza `ReservaException`. Se deja como red de seguridad |

**panel_admin**

| Sitio | Texto / conducta | Veredicto |
|---|---|---|
| `login_controller.dart:101` · `login_screen.dart:60` | mapeo por código + «Error al iniciar sesión» | **Incompleto, no falso** |
| `bootstrap_controller.dart:135` | `_mensajeCallable(e.code)` | **Correcto**, mapea por código |
| `bootstrap_controller.dart:138` · `bootstrap_screen.dart:109` | «No se pudo inicializar la plataforma. Intenta de nuevo.» | **Incompleto, no falso** |
| `bootstrap_controller.dart:167,172` | `catch (_)` mudos en la reversión, documentados | **Legítimo**: el error que debe verse es el original |
| `cocina_screen.dart:246` | `TransicionInvalida` → «Alguien ya movió este pedido» | **Correcto.** Los botones se derivan del estado actual: la única forma de fallar la transición es la carrera |
| `cocina_screen.dart:215,219,254,261` | `StateError` passthrough + «No se pudo entregar la cuenta» / genérico | **Incompleto, no falso** |
| `equipo_controller.dart:185,288` | `mensajeAltaStaff(e.code, e.message)` — **incluye el arreglo de 11-26** (distingue «callable no desplegada» de «el restaurante no existe») | **Correcto y ya endurecido** |
| `equipo_controller.dart:187,290` · `equipo_screen.dart:302` · `staff_form_dialog.dart:132` | «No se pudo crear el usuario / cambiar el estado» | **Incompleto, no falso** |
| `restaurante_form_dialog.dart:147` | «No se pudo crear el restaurante» | **Correcto:** ese `try` solo llama a `crearRestaurante` (comprobado) — no hay rama de edición a la que mentir |
| `categoria_form_dialog.dart:93` · `producto_form_dialog.dart:145` · `mesa_form_dialog.dart:128,182` | «No se pudo guardar / eliminar X» | **Incompleto, no falso** |
| `mesa_actions_sheet.dart:169` | `TransicionInvalida` → «otro usuario la actualizó» | **Correcto** |
| `app_shell.dart:60` | `catch (_)` al elegir restaurante por defecto, documentado | **Legítimo** |
| `reservas_screen.dart:48,73` | «Error al marcar la mesa» / «No se pudo cancelar la reserva» | **Incompleto, no falso.** Ver el hallazgo de abajo |

### Hallazgo del barrido (no corregido, y por qué)

`panel_admin/.../reservas_provider.dart::cancelarReservaNoShow` valida la transición contra
`reserva.estado` **del modelo que tiene la pantalla**, no contra el servidor. La rama
`on TransicionInvalidaException` de la pantalla es por tanto **inalcanzable en la práctica**: si
otro operador cancela primero, el modelo local sigue diciendo `pendiente`, la validación pasa y el
update se aplica otra vez (las rules lo permiten: `soloEstado` + `cancelada` + `staffOf`). El
resultado no miente al usuario —la reserva queda cancelada, que es lo que pidió—, así que no se
toca. Queda anotado porque es un guard que **parece** proteger de una carrera y no lo hace.
Contraste: `app_cliente` sí re-lee el doc **dentro** de la transacción, así que allí la rama es
real y está probada.

---

## Efecto en el panel: comprobado, con un caso nuevo

**Las vistas de reservas del panel NO leen el `estado` de la mesa** — `reservasHoyProvider`
consulta la colección `reservas`. No hay misreport ahí.

Donde sí hay consecuencia es en el **botón «Marcar ocupada»**: antes la mesa estaba *siempre*
`reservada` al llegar el cliente; ahora una reserva de hoy creada **ayer** la deja `disponible`.
`disponible → ocupada` es válida en la máquina y en `transMesa`, así que el botón funciona — pero
**no había ni un test que lo fijara**. Se añade el caso `(b2)`, y se verificó que tiene dientes:
metiendo un guard que exija `reservada`, se pone rojo. Los comentarios de las dos fuentes del panel
prometían «transición `reservada → ocupada`» y se han corregido.

**DEUDA DECLARADA, NO RESUELTA** (es la que el usuario aceptó al elegir la opción mínima): el mapa
de mesas del dashboard y el contador `mesasReservadas` pintan el campo `estado`, así que una
reserva para más tarde hoy creada en un día anterior no tiñe la mesa de amarillo. Correcto respecto
del momento presente; el operador pierde el aviso. El modelo correcto es que el mapa lea las
reservas del día.

---

## Tareas y commits

| # | Tarea | Commits |
|---|---|---|
| 1 | Bugs A y B (+ simetría de cancelar) | `ffc0978` (RED), `bca0232` (GREEN) |
| 2 | Bug C + contextos del mapeador + trazas | `4d6d00f` (RED), `76cebcb` (GREEN) |
| 3 | Rules: la forma NUEVA de la tx | `e443646` |
| 4 | Panel: «Marcar ocupada» con la mesa disponible | `24c6dfe` |
| 5 | Runbook, baselines y cola de pendientes | `add70a8` |

Los 7 commits auditados uno a uno con `git show --name-only`: **ninguno lleva archivos ajenos**
(hay otro ejecutor trabajando en el mismo árbol; se usó `git commit -- <rutas>` en todos, que es la
lección del incidente de 11-23).

---

## Gates (salida real, pasada completa sobre el árbol)

```
 GATE                                   RES.   TESTS     DETALLE
 app_cliente: flutter test              OK     401       401 (baseline 348, +53)
 app_cliente: flutter analyze           OK     0 issues  0 issues
 panel_admin: flutter test              OK     446       446 (baseline 445, +1)
 panel_admin: flutter analyze           OK     0 issues  0 issues
 functions: npm test (unitarios)        OK     149       149 = baseline
 scripts: npm run test:rules            OK     285       285 (baseline 282, +3)
 scripts: npm run test:functions (e2e)  OK     50        50 = baseline
 scripts: npm run audit:indexes         OK     —         exit 0
 scripts: npm run audit:branding        OK     —         exit 0

 9 gates · 9 OK · 0 fallo(s) · 1.6 min
```

**El 401 de `app_cliente` NO es todo mío.** Medido antes de tocar nada: `+348`. Tras mis dos
tandas: `+371` (**+23**: 10 de `asignacion_mesa_test.dart` y 13 de
`errores_honestos_reserva_test.dart`). Los ~30 restantes son de **11-30**, que está trabajando en
el mismo árbol sobre las fotos del menú. La baseline se subió a **371**, mi cifra medida y
verificada, no a 401.

Ningún índice nuevo: no se añadió ni se modificó ninguna consulta. `audit:indexes` en verde.

---

## Roturas deliberadas: 16, todas ROJAS

Ningún gate se da por bueno sin romper lo que protege. Cada mutación se aplicó, se corrió la suite
y se revirtió acto seguido (script en el scratchpad).

**Sobre el código del cliente (12/12 rojas):**

| Se rompió | Resultado |
|---|---|
| La mesa ocupada vuelve a **abortar** el bucle (bug A restaurado) | ROJA `+39 -5` |
| El estado se toca sea cual sea la fecha (bug B restaurado) | ROJA `+40 -4` |
| Cancelar revierte la mesa siempre (simetría deshecha) | ROJA `+43 -1` |
| Vuelve el mensaje ciego en `create` (bug C restaurado) | ROJA `+38 -6` |
| Se borra el `debugPrint` de `create` | ROJA `+43 -1` |
| El `debugPrint` de `create` pierde la clasificación | ROJA `+43 -1` |
| Se borra el `debugPrint` de `cancel` | ROJA `+43 -1` |
| «ocupación» y «slot tomado» comparten texto | ROJA `+40 -4` |
| El mensaje mixto deja de contar los slots tomados | ROJA `+43 -1` |
| `permisoDenegado` de `crearReserva` habla del HORARIO | ROJA `+42 -2` |
| `desconocido` de `crearReserva` culpa a la conexión | ROJA `+43 -1` |
| Dos causas de `cancelarReserva` comparten texto | ROJA `+43 -1` |

**Sobre los tests de rules (3/3 rojas)** — se mutaron los tests, **no las rules**:

| Se rompió | Resultado |
|---|---|
| El caso de «no toca la mesa» espera `reservada` | ROJA (`fail 1`) |
| La futura sobre mesa ocupada manda 20 personas en una mesa de 4 | ROJA (`fail 1`) — **prueba que las rules se están evaluando de verdad**, no que el test pase solo |
| Cancelar pone `confirmada` en vez de `cancelada` | ROJA (`fail 1`) — ídem |

**Sobre el panel (1/1 roja):** añadir a `marcarMesaOcupada` un guard que exija `reservada` deja el
caso `(b2)` (y otro) en rojo.

### Cazados: dos casos que habrían quedado VERDES por la razón equivocada

1. **`mis_reservas_render_test.dart` — «mesa OCUPADA no se revierte».** Usaba un slot de **mañana**.
   Con el arreglo B, ese caso pasa **sin llegar a mirar la mesa** (la reserva futura no la toca),
   así que dejaría de custodiar el guard de estado que dice custodiar. Movido a un slot de **hoy**.
2. **`mis_reservas_render_test.dart` — «Cancelar en futura confirmada: mesa liberada».** Afirmaba
   que la mesa acababa en `disponible`. Tras el arreglo eso es cierto **porque nunca se reservó**:
   el `expect` pasaría igual si la reversión desapareciera del código. Se le añadió una
   **precondición explícita** antes del tap, de modo que el caso ahora afirma «sin tocar», no
   «liberada».

---

## Desviaciones (no había PLAN.md; el diagnóstico era la especificación)

**1. [Regla 1 — Bug] Para un slot futuro el estado de la mesa tampoco se CONSULTA.**
El enunciado de A dice «saltar la mesa, no abortar». Aplicado al pie de la letra junto con B, una
reserva para el martes que viene seguiría descartando mesas por su estado de **hoy** — el mismo
defecto que B, con otra cara. El guard de estado existía solo para proteger el `tx.update` que ya
no ocurre. Lo he hecho así y lo declaro: la unicidad mesa+slot la garantiza el doc ID, y las rules
nunca miraron el estado de la mesa (hay un test nuevo que lo demuestra). La rama «saltar» sigue
implementada y probada para los slots de hoy.

**2. [Regla 1 — Bug] `cancelarReserva` solo revierte la mesa si la reserva era de hoy.**
Sin esto, cancelar una reserva del martes ponía la mesa `disponible` **hoy** — pudiendo borrar del
mapa una reserva de esta tarde que sí la había marcado. Es el simétrico exacto de B; dejarlo fuera
habría convertido el arreglo en una fuga de estado.

**3. [Regla 2 — Funcionalidad crítica ausente] Test del panel para «Marcar ocupada» desde
`disponible`.** Mi cambio altera el estado de partida de esa transición y no existía ningún test.
El código ya lo soportaba: es un caso de caracterización, **verde a la primera** (lo digo porque no
es un ciclo TDD honesto), con los dientes verificados por mutación.

**4. [Regla 1 — Documentación que miente] `docs/SMOKE-E2E-v2.md` §[O].** Decía «la mesa asignada
pasó a `estado: 'reservada'`» tras reservar para **mañana**. Comprobarlo ahora daría un **falso
fallo** al humano que corra el runbook. Reescrito, con el paso nuevo de la mesa ocupada y la
contraprueba de los tres mensajes.

**5. [Regla 3 — Bloqueante] `docs/ICONOS-panel_admin.md`.** El gate de iconos del panel valida
`archivo:línea`; mis comentarios desplazaron `reservas_screen.dart` de la 99 a la 108 y la suite se
puso roja. Actualizado. **Es un gate frágil por diseño**: cualquier comentario añadido por encima
de un icono lo rompe, y lo que verifica (que la tabla apunte a donde dice) podría hacerse buscando
el símbolo en el archivo en vez de fijando el número de línea.

---

## Verificado vs. afirmado — leer antes de dar esto por cerrado

**Verificado por mí, ejecutando:**

- Que una mesa ocupada ya no aborta la búsqueda, y que la siguiente candidata gana (slot de hoy).
- Que una reserva para mañana **no** modifica el doc de la mesa, y que una de hoy **sí**.
- Que cancelar una futura no toca la mesa y cancelar una de hoy la revierte.
- Que las tres causas de «no hay mesa» producen tres textos distintos, comparados entre sí y contra
  el mensaje ciego, en dos niveles: el servicio y el controller real.
- Que un `permission-denied` y un `unavailable` inyectados en la transacción producen el mensaje de
  su causa y **dejan traza** con el código y la clasificación.
- Que la forma nueva de la transacción (sin `update` de mesa) pasa las rules reales en el emulador,
  y que esos tests fallan si se les cambia el contenido (las rules se evalúan de verdad).
- Que el botón «Marcar ocupada» del panel funciona con la mesa `disponible`.
- Los 9 gates en verde en una pasada completa.
- Que la app cliente es el **único** escritor de `reservas` y que su selector empieza mañana
  (barrido de las dos apps + lectura de `firstDate`).

**Afirmado, NO verificado — hace falta el proyecto real y una persona:**

- **Que el usuario pueda ya reservar contra `p-gri-b5b40`.** Todo lo de arriba corre contra
  `fake_cloud_firestore` (sin motor de rules) y contra el emulador (sin índices compuestos). El
  escenario exacto que falló —`GRI-MESA-demo-001` ocupada, 2 personas, fecha futura— **no lo he
  reproducido contra producción**; no despliego ni consumo lecturas reales. Es el paso 3 del
  runbook §[O].
- **Que los textos nuevos se lean bien.** Un test prueba que una cadena se renderiza; no que un
  comensal entienda qué hacer. Los siete están en la tabla de arriba para poder revisarlos de un
  vistazo. Ninguno lo ha revisado el usuario todavía.
- **Que la rama `esHoy` se comporte en producción**: hoy es inalcanzable desde la UI (ver el
  hallazgo). Está probada, no observada en vivo.
- **El efecto en el mapa de mesas del panel.** Razonado y declarado como deuda; no lo he mirado con
  datos reales.

---

## Known Stubs

Ninguno. No se dejó ningún valor vacío, texto de relleno ni componente sin cablear.

## Threat Flags

Ninguna nueva. No se tocó `firestore.rules` ni ninguna consulta; el cambio **reduce** las
escrituras que el cliente hace sobre `mesas` (una reserva futura ya no escribe nada allí), y no
añade superficie de red, de autenticación ni de esquema.

## Self-Check: PASSED
