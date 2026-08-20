---
phase: 11-correcci-n-cr-tica-y-profesionalizaci-n-bootstrap-reglas-ndi
plan: 31
subsystem: reservas
tags: [reservas, margen-4h, app_cliente, firestore-rules, reloj-inyectable, esHoy]

# Dependency graph
requires:
  - phase: 11-29
    provides: "el bucle que salta la mesa ocupada, el estado que solo mueve una reserva de HOY, y la MEDICIÓN de que la rama esHoy era inalcanzable — este plan la vuelve alcanzable"
  - phase: 11-27
    provides: "la regla de read del SLOT AUSENTE, sin la cual la asignación no existe"
  - phase: 10-03
    provides: "la tx determinista y el doc ID {mesaId}_{yyyyMMdd}_{HH}"
provides:
  - "reservar para HOY con margen mínimo de 4 h (decisión del usuario 2026-08-20)"
  - "un ÚNICO predicado `slotRespetaMargen` del que salen calendario, desplegable y validación"
  - "el margen también en firestore.rules: `fecha >= request.time + duration.value(4, 'h')`"
  - "`core/reloj.dart` — relojProvider, el 'ahora' inyectable de la app"
  - "la rama esHoy probada DESDE LA UI por primera vez (mesa ocupada incluida)"
  - "el efecto del cambio sobre el mapa de mesas del panel, medido leyendo el código"
affects: [panel_admin/dashboard (deuda declarada, ahora más visible), .planning/PENDIENTE-POST-FASE-11.md]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Un solo predicado para la regla; lo que el usuario VE se deriva de él (la lista de horas es un filtro sobre el predicado, no una segunda aritmética)"
    - "El 'ahora' es una dependencia inyectable, no una llamada estática: sin eso los tests de lógica temporal están verdes o rojos según la hora del día"
    - "Los tests de tiempo se escriben con instantes literales ('son las 14:30'), nunca recalculando el valor esperado con la expresión del código"

key-files:
  created:
    - app_cliente/lib/core/reloj.dart
    - app_cliente/test/reservas/margen_reserva_test.dart
    - app_cliente/test/reservas/wizard_hoy_test.dart
  modified:
    - app_cliente/lib/features/reservas/reserva_controller.dart
    - app_cliente/lib/features/reservas/reserva_wizard_screen.dart
    - app_cliente/test/reservas/asignacion_mesa_test.dart
    - app_cliente/test/reservas/errores_honestos_reserva_test.dart
    - app_cliente/test/reservas/mis_reservas_render_test.dart
    - app_cliente/test/reservas/wizard_form_test.dart
    - app_cliente/test/a11y/a11y_test.dart
    - firestore.rules
    - scripts/test/rules/reservas.test.mjs
    - scripts/gates.mjs
    - .planning/PENDIENTE-POST-FASE-11.md
    - .planning/phases/11-.../deferred-items.md

decisions:
  - "La regla es `slot >= ahora + 4 h` con la IGUALDAD incluida. A las 14:00 clavadas las 18:00 valen"
  - "El redondeo a hora en punto NO es una segunda regla: es lo que emerge de filtrar la rejilla de horas con el mismo predicado. Por eso no hay una función `primerSlotReservable` que pueda desincronizarse"
  - "La rejilla de horas se muda de la pantalla al dominio, para que el texto del error nombre el primer horario válido sacado de LA MISMA lista que se pinta"
  - "`relojProvider` en vez de `DateTime.now()` disperso: sin él, ni el picker y el validador leen el mismo instante ni los tests son deterministas"
  - "En las rules `>=` y no `>`: el borde inclusivo es el mismo del cliente. La igualdad exacta se custodia en el cliente porque `request.time` no es inyectable en el emulador"
  - "El mapa de mesas del panel NO se rediseña: sigue siendo la deuda declarada en 11-29 (decisión de arquitectura, no un arreglo colado aquí). Se documenta que ahora es más visible"

metrics:
  duration: "~2 h"
  tasks: 4
  files: 15
  completed: 2026-08-20
  gates: "8/9 OK — `app_cliente: flutter analyze` en FALLO por 3 issues de un archivo de 11-32, ajeno a este plan (ver Deferred)"
  tests: "app_cliente +31 (baseline 408 → 439) · rules 285 → 290 · panel_admin 446 = · functions 149 + 50 ="
---

# Fase 11 Plan 31: reservar para HOY, con cuatro horas de margen

`reserva_wizard_screen.dart:271` fijaba `firstDate` en **mañana**: hoy no era una fecha
difícil de elegir, era una fecha **inexistente**. El usuario lo decidió el 2026-08-20:

> «sí [permitir reservar el mismo día] **pero con un margen de 4 horas**, ya que no se puede
> reservar para la misma hora.»

---

## La regla, enunciada de una vez

> **Un slot se puede reservar si empieza al menos 4 horas después de ahora:
> `slot >= ahora + 4 h`. La igualdad cuenta.**

Los slots son horas en punto (12:00..21:00), así que el efecto práctico es subir `ahora + 4 h`
a la hora en punto siguiente, salvo que ya caiga en punto:

| Son las… | Límite (`+4 h`) | Primer slot de HOY |
|---|---|---|
| 08:00 clavadas | 12:00 | **12:00** (la rejilla entera) |
| 08:01 | 12:01 | 13:00 |
| 14:00 clavadas | 18:00 | **18:00** |
| 14:00:01 | 18:00:01 | 19:00 |
| 14:30 | 18:30 | **19:00** |
| 17:00 clavadas | 21:00 | **21:00** (la última) |
| 17:01 | 21:01 | **ninguno** → el calendario abre en mañana |

**El redondeo a hora en punto no es una segunda regla, y ese es el punto.** No hay una función
`primerSlotReservable` que pueda desincronizarse del validador: la lista de horas es
literalmente `horasSlotReserva.where(slotRespetaMargen)`. Un solo predicado, tres consumidores.

```
                     slotRespetaMargen(slot, ahora)          ← LA regla
                        ▲            ▲            ▲
      horasReservablesEn│  primeraFechaReservable │  _crearReserva (validación)
              ▲         │            ▲            │
     desplegable de horas       firstDate del calendario
              ▲
     _horaEsValida → botón «Confirmar reserva» + aviso en el resumen
```

### Cómo se demuestra que el picker y el validador no pueden contradecirse

Dos comprobaciones, no una:

1. **Estructural** — el wizard no reimplementa nada: llama a `horasReservablesEn` /
   `primeraFechaReservable`, que llaman a `slotRespetaMargen`, que es lo que aplica
   `crearReserva`.
2. **Empírica** — el caso *«CONSISTENCIA rejilla↔validador»* recorre la rejilla **completa**
   para seis instantes fijos y afirma, hora por hora,
   `ofrecidas.contains(h) == slotRespetaMargen(slot(h), ahora)`. **Tiene dientes:** la mutación 7
   (la rejilla filtra con 5 h mientras el validador usa 4 h) deja **11 casos en rojo**.

### El borde de verdad: qué pasa con el reloj del servidor

Las rules evalúan `request.time`, que es **posterior** al `DateTime.now()` con el que decidió el
cliente. Consecuencia honesta, que declaro en vez de esconder: un slot a **exactamente** 4 h,
elegido en el último segundo antes de la hora en punto, lo aceptaría el cliente y lo denegaría el
servidor (y el mensaje que saldría sería el de `permission-denied`, que hablaría de la cuenta, no
del margen). No lo he tapado con un colchón de N segundos porque **no cerraría el agujero**: el
desfase del reloj del dispositivo no está acotado, así que el colchón sería un número mágico que
compra una falsa sensación de rigor. Lo que **sí** está garantizado por construcción es lo que
pidió el enunciado: que la UI nunca ofrezca algo que su propia validación rechace.

---

## El servidor también, o el margen es decoración

`firestore.rules`, `match /reservas` · create:

```diff
- && request.resource.data.fecha > request.time  // slot futuro
+ && request.resource.data.fecha
+    >= request.time + duration.value(4, 'h')
```

La condición vieja era cierta para un slot **a un minuto vista**: con un token de cliente
—que cualquier usuario registrado tiene— se escribía el doc a mano y la cocina se enteraba al
sonar la campana.

### Husos horarios, y cómo lo comprobé

`fecha` se escribe como `Timestamp.fromDate(slot)`, o sea **un instante absoluto** derivado de la
hora de pared local del dispositivo. `request.time` es también un instante absoluto (UTC).
**Comparar dos instantes absolutos no depende del huso: no hay conversión que hacer ni que
olvidar.** América/Bogotá (UTC-5, sin horario de verano) solo interviene en dos sitios que la
regla no evalúa: la hora de **pared** del slot y el `yyyyMMdd` del doc ID.

Comprobado, no razonado a secas: los tests de rules construyen `fecha` como
`new Date(Date.now() + N*3600e3)` — un desplazamiento en **milisegundos absolutos**, sin tocar
componentes de calendario— y corren en el emulador, cuyo `request.time` es UTC, desde una máquina
en horario local español (UTC+2 en agosto). Si la comparación tuviera una conversión de huso
implícita, el caso de las 3 h y el de las 5 h no podrían salir a la vez del lado correcto: siete
horas de desfase se los llevarían a los dos al mismo lado. Salen cada uno del suyo.

*Salvedad honesta, no verificada:* si el móvil del comensal está en un huso distinto al del
restaurante, «las 19:00» significa otro instante. Eso es una propiedad del diseño entero (el doc
ID usa la fecha local), no algo que este plan introduzca; no lo he tocado.

### Los casos de borde, y por qué el borde exacto no se puede afirmar aquí

| Caso | Veredicto |
|---|---|
| slot a **3 h** | DENEGADO |
| slot a **5 h** | PERMITIDO |
| **30 s antes** del borde (3 h 59 min 30 s) | DENEGADO |
| **30 s después** del borde (4 h 0 min 30 s) | PERMITIDO |
| slot **dentro de 1 minuto** | DENEGADO ← *el que la regla vieja dejaba pasar* |

`request.time` es el reloj del emulador y **no se puede inyectar**. Una `fecha` a exactamente 4 h
del `Date.now()` del test llega siempre un pelo corta y sería denegada **por la latencia, no por
la regla**: ese test sería intermitente y estaría rojo o verde por la razón equivocada. Por eso el
borde se acota a ±30 s, y **la igualdad estricta (`>=` y no `>`) se custodia en el cliente**,
donde el reloj sí es inyectable (`margen_reserva_test.dart`, caso «son las 14:00 EN PUNTO»).

---

## La rama `esHoy` deja de ser teoría

11-29 midió y declaró que la rama `esHoy == true` —la que marca la mesa `reservada` y la que salta
las mesas ocupadas— era **inalcanzable desde el producto**. Este plan la enciende. Ahora está
cubierta en los dos niveles:

| Caso | Nivel |
|---|---|
| reserva de HOY → la mesa asignada queda `reservada` | servicio **y UI** |
| la misma para MAÑANA → ninguna mesa se toca | servicio |
| mesa 001 **ocupada** ahora → se salta, gana la 002, la 001 sigue `ocupada` | servicio |
| **todas** ocupadas hoy → el mensaje habla de ocupación, y **no** menciona el margen | servicio |
| cancelar una reserva de HOY → la mesa vuelve a `disponible` | servicio |
| reservar hoy **desde el wizard** → doc con `fechaStr` de hoy, `hora: 19` y mesa `reservada` | **UI, de punta a punta** |

---

## El panel: qué encontré (tarea 4)

**Leído en el código, no observado con datos reales.**

`stats_provider.dart` tiene **dos** contadores que suenan parecido y no lo son:

- `reservasHoy` consulta la colección `reservas` con la ventana del día → cuenta **todas** las de
  hoy, se hayan creado cuando se hayan creado. **Este nunca estuvo afectado por la deuda y sigue
  bien.**
- `mesasReservadas` (línea 71) y el mapa de mesas cuentan `mesa.estado == reservada`.

Y aquí está el hallazgo: **el cambio no rompe nada nuevo, pero empeora la interpretabilidad.**

| Reserva | ¿tiñe la mesa de amarillo? | ¿desde cuándo? |
|---|---|---|
| Creada HOY para más tarde HOY | **Sí** | **nuevo en 11-31** |
| Creada AYER para HOY | No | desde 11-29 |
| Creada hoy para mañana o más allá | No (correcto) | desde 11-29 |

Antes de este plan el amarillo lo ponía **solo el staff** a mano (11-29 lo midió: el cliente ya
nunca escribía `reservada`). Era incompleto, pero **uniforme**: el operador sabía qué significaba.
Ahora es «a veces», y el operador no puede deducir de dónde viene el amarillo. **Es estrictamente
más confuso que antes**, aunque cada dato individual siga siendo correcto respecto del momento
presente.

Dos efectos secundarios más, anotados:

- Con el margen de 4 h, una mesa reservada para hoy queda amarilla **al menos 4 horas** antes del
  turno. Antes de 11-29 quedaba amarilla desde el momento de reservar (peor); entre 11-29 y hoy,
  nunca.
- Nada la devuelve a `disponible` si el cliente no aparece: el operador tiene que moverla a mano.
  No es nuevo —ya pasaba con el «Marcar reservada» del staff— pero ahora hay una fuente más que lo
  produce.

**No lo he arreglado.** Que el mapa lea las reservas del día en vez de un campo en vivo es la
deuda que el usuario aceptó explícitamente al elegir la opción mínima en 11-29, y rediseñarlo es
una decisión de arquitectura (Regla 4), no algo que se cuela dentro de un cambio de producto.
Queda actualizado en `PENDIENTE-POST-FASE-11.md` con la tabla de arriba.

Comprobado además que **no rompo el panel**: `panel_admin: flutter test` sigue en 446, su
`analyze` en 0 issues, y las pantallas de reservas del panel no leen el `estado` de la mesa.

---

## Tareas y commits

| # | Tarea | Commit |
|---|---|---|
| 1 | RED: la regla con instantes fijos + el wizard + `relojProvider` | `9e5e3e3` |
| 2 | GREEN cliente: dominio, wizard y los tests que dependían del reloj | `d223768` |
| 3 | Rules: el margen server-side + 5 casos de borde | `b8a4d6d` |
| 4 | Baselines, cola de pendientes, deferred y este SUMMARY | *(commit final)* |

### ⚠️ Incidente de coordinación entre ejecutores (no es una desviación mía, pero hay que saberlo)

El commit **`9b799a7` («test(11-32): la cuenta EN PANTALLA del comensal (RED)»), del ejecutor de
11-32, arrastró mis ocho archivos de `features/reservas`** — estaba usando un `git add -A` /
`commit -a` sobre el árbol compartido. Lo detecté porque mi propio `git commit -- <rutas>`
respondió *«no changes added to commit»*. **Ningún trabajo se perdió**: el contenido definitivo
quedó después en `d223768`, con su mensaje propio y solo con mis rutas
(`git show --name-only d223768` lo confirma). No he reescrito historia: `9b799a7` es de otro
ejecutor y está vivo. Es la tercera vez en la fase que el `git add -A` cuesta algo (11-23, 11-29,
esta); yo he usado `git commit -- <rutas>` y `git diff --cached --name-only` en los tres commits.

---

## Gates (salida real, pasada completa)

```
 GATE                                   RES.   TESTS     DETALLE
 app_cliente: flutter test              OK     466       466 (baseline 439, +27)
 app_cliente: flutter analyze           FALLO  3 issues  3 issue(s) — se exigen 0
 panel_admin: flutter test              OK     446       446 = baseline
 panel_admin: flutter analyze           OK     0 issues  0 issues
 functions: npm test (unitarios)        OK     149       149 = baseline
 scripts: npm run test:rules            OK     290       290 = baseline
 scripts: npm run test:functions (e2e)  OK     50        50 = baseline
 scripts: npm run audit:indexes         OK     —         exit 0
 scripts: npm run audit:branding        OK     —         exit 0

 9 gates · 8 OK · 1 fallo(s) · 1.9 min
```

**El fallo de `analyze` NO es mío y lo digo con la comprobación delante.** Los 3 issues son
`prefer_interpolation_to_compose_strings` en `test/pedidos/cuenta_vista_test.dart:129,147,172`, el
archivo que el ejecutor de **11-32** tenía en fase RED en el mismo árbol. `flutter analyze` no
reporta **nada** de `features/reservas/` ni de `core/reloj.dart`; con mis cambios y sin los suyos
la salida fue **«No issues found!»** (medida dos veces durante la implementación). Anotado en
`deferred-items.md`; lo cierra 11-32 al pasar a GREEN. **No lo he tocado** (regla de alcance: solo
se auto-arregla lo que causa el propio cambio).

**El 466 de `app_cliente` NO es todo mío.** Medido aparte corriendo solo mis dos archivos:
**+31** (26 de `margen_reserva_test.dart` y 5 de `wizard_hoy_test.dart`). La baseline se sube a
**439** = 408 (la que dejó 11-30) + 31 **medidos**, no a 466. Los 27 restantes son de 11-32,
trabajando en el mismo árbol.

`audit:indexes` en verde: no se añadió ni se modificó ninguna consulta.

---

## Roturas deliberadas: 10, todas ROJAS

Ningún gate se da por bueno sin romper lo que dice proteger. Cada mutación se aplicó, se corrió la
suite y se revirtió acto seguido (script en el scratchpad; verde de partida: `+91` en
`test/reservas` + `test/a11y`).

**Sobre el cliente (7/7 rojas):**

| Se rompió | Resultado |
|---|---|
| Vuelve `firstDate = mañana` (hoy se esconde otra vez) | ROJA `+87 -4` |
| El desplegable deja de filtrar (ofrece la rejilla entera) | ROJA `+88 -3` |
| `crearReserva` deja de validar el margen | ROJA `+89 -2` |
| El margen pasa de 4 h a 3 h | ROJA `+68 -23` |
| El borde deja de ser inclusivo (`>` en vez de `>=`) | ROJA `+84 -7` |
| El botón ya no exige que la hora SIGA siendo válida | ROJA `+90 -1` |
| La rejilla filtra con 5 h mientras el validador usa 4 h | ROJA `+80 -11` ← *la contradicción picker↔validador* |

**Sobre las rules (3/3 rojas):**

| Se rompió | Resultado |
|---|---|
| Vuelve la regla vieja `fecha > request.time` (sin margen) | ROJA `fail 3` |
| El margen server-side pasa de 4 h a 5 h | ROJA `fail 2` |
| Se muta el **TEST**, no la regla: el caso de las 5 h manda 3 h | ROJA `fail 1` — **prueba que las rules se evalúan de verdad**, no que el test pase solo |

### Cazado: un caso que habría quedado verde por la razón equivocada

**Los cuatro archivos de reservas y el de a11y tenían tests dependientes del reloj de la máquina.**
`asignacion_mesa_test`, `errores_honestos_reserva_test` y `mis_reservas_render_test` usaban
`_slotDeHoy(23)` con `DateTime.now()`: con el margen de 4 h, esos casos **se habrían puesto rojos
a partir de las 19:01** y verdes el resto del día. `wizard_form_test` y `a11y_test` pulsan «19:00»
tras aceptar la fecha propuesta: con `firstDate` pasando a ser HOY, ese `19:00` **desaparece del
desplegable a partir de las 15:01**. Corrí la suite y pasó — porque eran las 14:5x. Un test que
pasa por la hora que es no prueba nada. Los cinco archivos usan ahora un instante **fijo**
(`_hoyALas(12)` / `_hoyALas(18)` / `relojProvider` inyectado), y son deterministas a cualquier hora
del día. Los tres casos de `wizard_form_test` que sí se rompieron de verdad con el cambio
(`firstDate` pasó a hoy) están arreglados, no silenciados.

---

## Desviaciones (no había PLAN.md; el brief era la especificación)

**1. [Regla 2 — Funcionalidad crítica ausente] `core/reloj.dart`.** El brief pedía instantes fijos
en los tests; con `DateTime.now()` incrustado en la pantalla y en el servicio eso no se puede
hacer, y además el picker y el validador leerían instantes **distintos**. `relojProvider` es la
pieza que hace posibles las dos cosas que se pidieron.

**2. [Regla 1 — Bug latente] `cancelarReserva` recibe el mismo reloj.** No estaba en el enunciado,
pero «de hoy» tiene que significar **lo mismo** en crear y en cancelar, o cancelar dejaría de
revertir exactamente la mesa que crear reservó. Es la simetría que fijó 11-29; sin el reloj
compartido se rompería en cuanto un test o un uso real cruzara la medianoche.

**3. [Regla 1 — Coherencia] La rejilla de horas se muda de la pantalla al dominio.** El mensaje de
rechazo tiene que nombrar el primer horario válido, y ese texto no puede salir de una lista
distinta de la que se pinta. `ReservaWizardScreen.horasSlot` queda como alias, así que el contrato
público que los tests existentes usaban no cambia.

**4. [Regla 2 — Estado sin explicar] Aviso cuando la hora elegida pierde el margen.** El
`_horaEsValida` apaga el botón «Confirmar reserva»; un botón apagado sin motivo es un callejón.
Se añade el texto que lo explica en el paso Confirmar y el hint del paso Hora. Probado con un
reloj que **avanza** dentro del test, que es el único camino real por el que esto ocurre (el
usuario deja la app abierta).

---

## Verificado vs. afirmado — leer antes de dar esto por cerrado

**Verificado por mí, ejecutando:**

- La regla en los cinco instantes de la tabla, con valores literales: 14:30 → 19:00; 14:00
  clavadas → 18:00 (borde inclusivo); 14:00:01 → 19:00; 17:00 → solo las 21:00; 17:01 → nada.
- Que el calendario abre en HOY a las 14:30 y en MAÑANA a las 17:01 (**en la UI**, no solo en la
  función).
- Que el desplegable y el validador coinciden hora por hora en la rejilla completa, para seis
  instantes.
- Que reservar para hoy **desde el wizard** escribe el doc con la fecha de hoy y deja la mesa
  `reservada` — la rama `esHoy`, ejercitada desde el producto por primera vez.
- Que una mesa `ocupada` se salta y gana la siguiente, con el margen activo.
- Que las rules deniegan a 3 h y a 1 minuto, permiten a 5 h, y que el borde ±30 s cae de cada lado.
- Que las rules se están **evaluando de verdad** (mutando el test, no la regla).
- Las 10 roturas deliberadas, todas rojas.
- Que el panel no se rompe (446 tests, 0 issues) y que `reservasHoy` lee la colección `reservas`,
  no el estado de la mesa.

**Afirmado, NO verificado — hace falta el proyecto real y una persona:**

- **Que esto funcione contra `p-gri-b5b40`.** Todo corre contra `fake_cloud_firestore` (sin motor
  de rules) y contra el emulador (sin índices compuestos). **No he desplegado nada**, como se me
  pidió. Reservar para hoy no añade ninguna consulta nueva, así que no debería hacer falta ningún
  índice — `audit:indexes` en verde lo respalda, pero eso es una auditoría estática.
- **El comportamiento del reloj real del servidor en el borde exacto.** Descrito arriba y acotado;
  no reproducido contra producción.
- **El efecto en el mapa de mesas del panel con datos reales.** Razonado leyendo
  `stats_provider.dart`; no lo he mirado en vivo.
- **Que los textos nuevos se lean bien.** Son tres: la nota «Puedes reservar para hoy con al menos
  4 horas de antelación», el rechazo «Necesitamos al menos 4 horas de antelación. El primer horario
  que puedes reservar ese día es las HH:00.» y el aviso «Ese horario ya no cumple las 4 horas de
  antelación…». Un test prueba que la cadena se renderiza, no que un comensal la entienda. El
  usuario no los ha revisado.
- **El desfase de reloj del dispositivo.** Si el móvil va atrasado varios minutos respecto del
  servidor, el cliente puede ofrecer un slot que las rules denieguen, y el mensaje que saldría
  hablaría de la cuenta y no del margen. Acotado y explicado; no mitigado (ver arriba por qué un
  colchón sería un número mágico).

## Known Stubs

Ninguno. No se dejó ningún valor vacío, texto de relleno ni componente sin cablear.

## Threat Flags

| Flag | Archivo | Descripción |
|------|---------|-------------|
| threat_flag: rules-tightening | `firestore.rules` | El `create` de `reservas` pasa de exigir «slot futuro» a exigir «slot a ≥ 4 h». Es un **estrechamiento**: no abre superficie, la cierra. Lo que sí conviene saber al desplegar es que **cualquier cliente antiguo que no conozca el margen empezará a recibir `permission-denied`** al reservar con menos de 4 h — hoy no existe ninguno (la app es el único escritor de `reservas` y va en el mismo repo), pero un APK viejo instalado en un móvil sí lo notaría. |

No se añadió ninguna consulta, ni endpoint, ni ruta de autenticación, ni campo nuevo al esquema.

## Self-Check: PASSED

Archivos creados: los 4 existen en disco. Commits `9e5e3e3`, `d223768`, `b8a4d6d`: los tres en el
árbol. `firestore.rules` en HEAD contiene `duration.value(4, 'h')`; `reserva_controller.dart` en
HEAD contiene `slotRespetaMargen` (3 apariciones).
