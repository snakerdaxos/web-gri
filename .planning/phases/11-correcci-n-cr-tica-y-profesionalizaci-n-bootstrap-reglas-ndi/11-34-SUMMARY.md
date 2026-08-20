---
phase: 11-correcci-n-cr-tica-y-profesionalizaci-n-bootstrap-reglas-ndi
plan: 34
subsystem: reservas + reglas + sesión
tags: [ventana-reserva, mapa-derivado, super-admin, firestore-rules, reabrir-cuenta, carrera, logout, reloj]

requires:
  - phase: 11-29
    provides: "el diagnóstico de los dos bugs de crearReserva y la DEUDA declarada: «el modelo correcto es que el mapa lea las reservas del día»"
  - phase: 11-31
    provides: "el margen mínimo de 4 h para reservar HOY — la premisa que convierte la escritura del estado de la mesa en un defecto, y la lección de los cinco archivos que dependían del reloj de la máquina"
  - phase: 11-32
    provides: "la cuenta de la mesa y `entregarCuenta`, sobre la que se monta el guard de la carrera"
  - phase: 11-33
    provides: "cuandoConFallo y el criterio de no pintar cifras ante un fallo, aplicados a los consumidores nuevos"
  - phase: 11-04
    provides: "la auditoría de reglas que ya marcó la asimetría del super_admin como «a decidir»"
provides:
  - "panel_admin/lib/features/dashboard/bloqueo_reserva.dart: la ventana [-30 min, +30 min] y el mapa derivado"
  - "panel_admin/lib/core/reloj.dart: el único punto por el que entra la hora a la aplicación"
  - "firestore.rules: opStaffOf(r) = isSuper() || staffOf(r) en los tres updates de sala"
  - "firestore.rules: la rama del comensal puede APAGAR cuentaSolicitada, con tres candados"
  - "panel_admin: reservasProximas (mañana → +7 días) y la pantalla partida hoy/próximas"
  - "panel_admin: CuentaReabiertaException — la carrera mesero/comensal cubierta dentro de la tx"
  - "panel_admin: el botón de cerrar sesión que el panel no tenía"
  - "MEDICIÓN: un Timer.periodic vivo en un test de widget enrojece 80 casos del panel"
  - "BUG ENCONTRADO Y ARREGLADO: logout() reventaba por disposición del notifier, en LAS DOS apps"
affects: [11-29, 11-31, 11-32]

tech-stack:
  added: ["fake_async (dev, panel_admin — declarada; llegaba transitivamente)"]
  patterns:
    - "Cuando un color depende de la HORA y no de un documento, hace falta un reloj en el árbol de providers: ningún onSnapshot avisa de que se hizo tarde"
    - "El defecto de un provider de reloj es el reloj QUIETO. El que late se instala solo en main.dart y se vigila con un gate estático — un Timer.periodic dentro de un test de widget es intermitencia gratis"
    - "Una comprobación anti-carrera solo es una barrera si lee DENTRO de la transacción; fuera es validar contra un modelo ya viejo"
    - "Invertir el veredicto de un test es legítimo cuando la premisa cambió, pero el caso debe DECIR qué afirmaba antes y por qué dejó de ser cierto"
    - "`ref.read(...notifier).metodo()` no crea listener: cualquier `ref.*` después de un await revienta. Se sostiene con ref.keepAlive()"

key-files:
  created:
    - panel_admin/lib/core/reloj.dart
    - panel_admin/lib/features/dashboard/bloqueo_reserva.dart
    - panel_admin/lib/features/dashboard/widgets/mapa_de_mesas.dart
    - panel_admin/test/dashboard/ventana_reserva_test.dart
    - panel_admin/test/dashboard/mapa_derivado_test.dart
    - panel_admin/test/core/reloj_test.dart
    - panel_admin/test/core/reloj_cableado_test.dart
    - panel_admin/test/shared/cerrar_sesion_test.dart
    - panel_admin/test_mutaciones_11_34.mjs
    - app_cliente/test/pedidos/reabrir_cuenta_test.dart
    - app_cliente/test/perfil/cerrar_sesion_test.dart
    - scripts/mutaciones_11_34.mjs
  modified:
    - firestore.rules
    - scripts/test/rules/sesiones.test.mjs
    - scripts/test/rules/mesas.test.mjs
    - scripts/test/rules/reservas.test.mjs
    - app_cliente/lib/features/pedidos/pedidos_provider.dart
    - app_cliente/lib/features/pedidos/pedido_estado_screen.dart
    - app_cliente/lib/features/reservas/reserva_controller.dart
    - app_cliente/lib/features/auth/auth_controller.dart
    - panel_admin/lib/features/cocina/pedidos_staff_provider.dart
    - panel_admin/lib/features/cocina/cocina_screen.dart
    - panel_admin/lib/features/auth/login_controller.dart
    - panel_admin/lib/features/shared/app_shell.dart
    - panel_admin/lib/features/dashboard/stats_provider.dart
    - panel_admin/lib/features/dashboard/dashboard_screen.dart
    - panel_admin/lib/features/dashboard/widgets/mesa_tile.dart
    - panel_admin/lib/features/mesas/mesas_screen.dart
    - panel_admin/lib/features/reservas/reservas_provider.dart
    - panel_admin/lib/features/reservas/reservas_screen.dart
    - panel_admin/lib/main.dart
    - panel_admin/lib/core/gri_icons.dart
    - scripts/gates.mjs
    - docs/ICONOS-panel_admin.md
    - "+ 6 archivos de test con veredictos INVERTIDOS a conciencia"

decisions:
  - "El mapa deriva el color de las reservas del día. La liberación automática pasa a ser implícita: no hay nada que escribir ni proceso que lo escriba (sin Blaze no hay Cloud Functions)"
  - "`crearReserva` deja de escribir `estado: 'reservada'` y deja de descartar candidatas ocupadas. Con el margen de 4 h de 11-31 las dos cosas eran defectos, no optimizaciones"
  - "La reserva NO se marca `no_show`: nadie la canceló, simplemente pasó su hora. Se deja `confirmada` (la especificación lo dejaba a decidir)"
  - "Liberar la mesa a mano = cancelar la reserva. `cancelarReservaNoShow` ya existía y ahora es LA palanca, porque una reserva cancelada deja de teñir en el acto"
  - "`opStaffOf` incluye al super_admin en las tres operaciones de sala. No abre nada: ya leía esos tres documentos. Revertir = sustituir `opStaffOf` por `staffOf` en tres sitios"
  - "Apagar `cuentaSolicitada` se permite con tres candados (sesión activa, estaba en true, el timestamp queda en null) y se dispara desde la transacción del pedido"
  - "El defecto del reloj es el QUIETO y el que late vive en main.dart, con un gate estático que lo vigila. Coste declarado: el latido no lo cubre ninguna prueba de widget"
  - "Ventana de «próximas»: 7 días. Es la pregunta que decide compras y turnos; «todas las futuras» exigiría paginación para un dato que casi nadie mira"

metrics:
  duration: "~5 h"
  tasks: 4
  files: 39
  completed: 2026-08-20
  gates: 9/9 OK
  tests: "app_cliente 489→500 (+11) · panel_admin 474→528 (+54) · rules 290→306 (+16) · functions 149 + 50"
  mutaciones: "17 (6 en rules, 5 en Dart a mano, 10 con arnés en el panel — 2 de control en verde)"
---

# Fase 11 Plan 34: la mesa se bloquea media hora antes y media hora después, y el super_admin por fin puede operar

Cinco decisiones que el usuario tomó probando el sistema en marcha. Cuatro eran
defectos que solo se ven operando de verdad; la quinta es un cambio de modelo
que estaba declarado como deuda desde 11-29 y que estos días se volvió
necesario.

---

## 1. La ventana de bloqueo: −30 min / +30 min

**Lo que había.** El mapa del panel pintaba el campo `estado` de la mesa, y ese
campo lo escribía `crearReserva`. De ahí salían tres comportamientos que el
operador no podía explicarse:

| Situación | Antes | Por qué estaba mal |
|---|---|---|
| Reserva creada hoy para hoy | la mesa se ponía `reservada` al crearla | con el margen de 4 h de 11-31, la bloqueaba **cuatro horas y media antes** |
| Reserva creada ayer para hoy | la mesa **no** se ponía `reservada` | el mesero perdía el aviso |
| El cliente no aparece | **nada** liberaba la mesa | inutilizable el resto del turno |

**Lo que hay.** La mesa está bloqueada por una reserva **solo** dentro de
`[reserva − 30 min, reserva + 30 min]`. El mapa deriva el color cruzando las
reservas del día con la hora, en `bloqueo_reserva.dart`.

Lo importante de esa decisión es que **simplifica**: la liberación automática
se vuelve implícita. Pasados los 30 minutos de cortesía la reserva deja de
teñir la mesa y no hay nada que escribir — que es exactamente lo que se
necesitaba, porque sin plan Blaze no hay Cloud Functions desplegadas y no
existe nadie que pudiera escribirlo.

Consecuencias que se siguieron y se hicieron:

- **`crearReserva` deja de escribir el estado de la mesa**, hoy o cualquier
  día. Y deja de **descartar candidatas** por estar ocupadas ahora: con el
  margen de 4 h, que la mesa esté ocupada a las 14:30 no dice nada de las
  19:00, y descartarla rechazaba reservas perfectamente válidas.
- **`cancelarReserva` deja de revertir**, por simetría. La mesa se libera
  igual, y mejor: sin una segunda escritura que pueda fallar por separado y
  sin el riesgo que 11-29 anotó (liberar una mesa reservada por *otra*
  reserva de esa misma tarde).
- **El contador «Mesas disponibles» deriva igual**, con la misma función que
  pinta el mapa, para que tablero y mapa no puedan contradecirse.
- **El tile dice por qué está amarillo** (`21:00 · 4 personas`). La queja
  literal del operador era que el color aparecía «a veces» y no se podía
  deducir de dónde venía.
- **Migración sin script**: una mesa que el código anterior dejó en
  `reservada` se pinta disponible en cuanto no hay reserva en ventana.
- **Liberar a mano** = cancelar la reserva (`cancelarReservaNoShow`, que ya
  existía). Una reserva cancelada no bloquea nunca.
- La reserva **no** se marca `no_show`: nadie la canceló, simplemente pasó su
  hora. La especificación lo dejaba a decidir.

### El reloj, y lo que costó

Si el color depende de la hora, la pantalla se queda obsoleta **sin que cambie
ningún documento**: pasan los 30 minutos y ningún `onSnapshot` va a emitir
nada, porque en Firestore no se ha movido nada. Hizo falta un reloj en el árbol
de providers (`core/reloj.dart`, tic de 30 s).

**MEDIDO:** con el reloj latiendo por defecto, la primera pasada completa de la
suite del panel dio **80 casos rojos** con `A Timer is still pending even after
the widget tree was disposed`. Los tests que montan la app entera usan
`UncontrolledProviderScope` con `addTearDown(container.dispose)`, y el harness
comprueba `!timersPending` **antes** de ejecutar los tearDown.

Decisión: **el defecto es el reloj QUIETO** (una emisión, sin temporizador) y
el que late se instala solo en `main.dart`. Un test no tiene por qué saber que
el reloj existe. **Coste declarado sin adornos:** el latido no lo cubre ninguna
prueba de widget. Se cubre por dos vías: `reloj_test.dart` (fakeAsync: emite,
sigue emitiendo, la limpieza apaga el temporizador, con canario) y
`reloj_cableado_test.dart`, un gate estático que afirma que `main.dart` instala
el que late — sin él, borrar ese override dejaría el mapa sin refrescarse en
producción y **ninguna prueba lo notaría**.

---

## 2. El `super_admin` no podía operar

Reproducido por el usuario: pulsar «entregar cuenta» daba `permission-denied`.
`staffOf(r)` exige `r == rid()` y un rol de la lista, y el super_admin no
cumple ninguna de las dos (no tiene `rid`). Podía **leer** sesiones, mesas y
reservas desde el día uno, pero no cerrar sesiones, ni mover mesas, ni cancelar
reservas. `pedidos` ya lo contemplaba con `isSuper()`; el resto no. La
auditoría de 11-04 lo había marcado como asimetría a decidir.

**Arreglo:** `opStaffOf(r) = isSuper() || staffOf(r)`, aplicado a los **tres**
updates de sala. No concede ni un campo nuevo: `soloEstado`, `transMesa` y el
estado destino se evalúan igual para él. Revertir es sustituir `opStaffOf` por
`staffOf` en tres sitios.

Tres tests de rules **invirtieron su veredicto** a conciencia (decían «el
super_admin no opera»). Se añadieron además casos en rojo que fijan que las
restricciones de forma **sí** se le aplican: no re-abre sesiones cerradas, no
salta `transMesa`, no cuela `capacidad` junto al estado.

---

## 3. El panel no veía las reservas futuras

`reservasHoy` acotaba a `fecha >= inicioHoy && fecha < inicioMañana`. Y hasta
11-31 el cliente solo podía reservar de mañana en adelante. Combinando las dos
cosas: **ninguna reserva había sido nunca visible para el restaurante hasta el
día en que ocurría.** Sin eso no se pueden planificar compras ni turnos.

**Arreglo:** `reservasProximas` (de mañana a +7 días) y la pantalla partida en
dos pestañas, como pidió el usuario, porque el uso es distinto: en «Hoy» se
opera, en «Próximos 7 días» se planifica.

- Las **cuentas van en la etiqueta** de la pestaña: separar no puede
  significar esconder. Ante un fallo **no se pinta un 0** — «Próximas (0)» se
  lee como «no hay nada la semana que viene», y eso es justo lo que no sabemos
  (criterio de 11-33 aplicado a un contador, no a dinero).
- «Próximas» **agrupa por día** y **no ofrece acciones de sala**: marcar
  ocupada una mesa por una reserva de pasado mañana la bloquearía hoy, que es
  el bug que este mismo plan quita.
- **Ningún índice nuevo.** `reservas(restauranteId ASC, fecha ASC)` existe
  desde 10-01 y sirve igual a una ventana más ancha. `audit:indexes`: 24
  consultas analizadas, 0 fallos.

---

## 4. Reabrir la cuenta

Reproducido por el usuario: pidió la cuenta, después pidió un café. El café se
aceptó y pasó a preparación, pero no entraba en el total (solo se cobra lo
`servido`), el botón de pedir la cuenta no volvía y el mesero tenía en su lista
un importe viejo. La mesa se quedaba **sin salida**.

Decisión del usuario: se **reabre** la cuenta. Tres piezas:

1. **Las rules lo permiten** (antes lo denegaban: exigían
   `cuentaSolicitada == true`). La ampliación está acotada por tres candados,
   cada uno con su caso en rojo: sesión **activa**, la bandera estaba en
   **true**, y `cuentaPedidaAt` queda en **null** (no se puede apagar la
   bandera conservando el sello de tiempo viejo). De paso se **endureció** un
   caso que antes estaba permitido: encender la bandera sobre una sesión ya
   cerrada.
2. **`crearPedido` la apaga dentro de la misma transacción** que crea el
   pedido: si el pedido falla, la solicitud de cuenta sigue en pie. Solo se
   toca si estaba encendida — un `false` incondicional sería, además de una
   escritura de más, **denegado**.
3. **La pantalla del comensal**: `_cuentaYaPedida` era un latch de una sola
   dirección que habría **tapado el arreglo entero**. Ahora se apaga con la
   transición `true → false` del doc de sesión.

**El aviso al mesero se resuelve solo**: `avisoCuenta` filtra
`cuentaSolicitada == true`, así que la fila con el importe viejo desaparece de
su lista sin que nadie haga nada.

### La carrera

El mesero pulsa «entregar cuenta» en el mismo instante en que el comensal manda
otro pedido. Antes daba igual: `entregarCuenta` miraba solo `estado ==
'activa'` y cerraba la sesión, dejando el pedido nuevo dentro de una sesión
cerrada — sin cobrar y **sin poder cobrarse nunca**, porque `cerrada` es
terminal en las rules.

Ahora la función comprueba, **sobre el snapshot leído dentro de la
transacción**, que la bandera sigue puesta; si no, lanza
`CuentaReabiertaException` y no escribe nada. Que la lectura sea *dentro* de la
tx es lo que la hace una barrera: Firestore aborta si el documento cambió entre
el `get` y el commit. Comprobarlo fuera sería exactamente la carrera que 11-29
dejó anotada para el guard de transición de mesa.

Tipo propio y no `StateError` porque dicen cosas contrarias: en uno la sesión
ya no existe; en el otro sigue viva, con un plato más.

---

## 5. Cerrar sesión en el panel — y un bug que salió al tirar del hilo

`logout()` existía desde 10-05 y **ningún widget lo llamaba**: una vez dentro
del panel no se podía salir salvo borrando los datos del navegador. En el
equipo compartido de un restaurante eso deja la sesión del administrador
abierta para quien se siente después.

Se añadió al topbar, junto a la identidad del usuario: tooltip,
`semanticLabel`, 48 dp escritos (no heredados de un default) y confirmación
antes de salir.

**Y al llamarlo por primera vez, saltó.** `ref.read(...notifier).logout()` no
crea listener, así que el notifier autoDispose se disponía mientras el `await
signOut()` estaba en vuelo y el `ref.invalidate(claimsProvider)` de después
lanzaba *«Cannot use "ref" after the provider was disposed»*. Además del error
visible, el efecto silencioso es peor: **los claims del usuario que acaba de
salir se quedaban cacheados**. Y en el panel pasaba siempre, no de vez en
cuando: la redirección a `/login` desmonta el shell mientras el `signOut` está
en vuelo. Se sostiene con `ref.keepAlive()` mientras dura la operación.

### La app cliente: comprobado, y también estaba rota

El botón **sí existía** (`perfil_screen.dart`), así que el problema principal
no lo tenía. Pero su `LogoutController.logout()` es **código idéntico** y se
invoca igual: el mismo defecto. El test de unidad que había no podía verlo —
llama al notifier desde un `ProviderContainer` que el propio test retiene.
Arreglado igual y cubierto desde la **pantalla**, que es donde el provider
queda sin listener.

**Lo que NO se cambió y se reporta:** el botón del cliente **no pide
confirmación**. En un móvil personal el riesgo es menor que en un equipo
compartido y el usuario no lo pidió; queda anotado.

---

## Verificación

### Gates (salida real)

```
 GATE                                   RES.   TESTS     DETALLE
 app_cliente: flutter test              OK     500       500 = baseline
 app_cliente: flutter analyze           OK     0 issues  0 issues
 panel_admin: flutter test              OK     528       528 = baseline
 panel_admin: flutter analyze           OK     0 issues  0 issues
 functions: npm test (unitarios)        OK     149       149 = baseline
 scripts: npm run test:rules            OK     306       306 = baseline
 scripts: npm run test:functions (e2e)  OK     50        50 = baseline
 scripts: npm run audit:indexes         OK     —         exit 0
 scripts: npm run audit:branding        OK     —         exit 0

 9 gates · 9 OK · 0 fallo(s) · 2.5 min
```

Ningún número bajó: 489→500, 474→528, 290→306, 149 y 50 estables.

### Mutaciones — 17, ninguna sobrevivió

**Reglas** (`node scripts/mutaciones_11_34.mjs`, arnés reutilizable):

| Mutación | Rojo esperado | Resultado |
|---|---|---|
| M1 `opStaffOf` vuelve a `staffOf` | los 3 casos de super operando | 4 rojos: mesas ×2, reservas, sesiones |
| M2 **control**: `opStaffOf` redundante | ninguno | **verde** |
| M3 sin el candado del timestamp | CANDADO 1 | 1 rojo, el suyo |
| M4 sin «solo se apaga lo encendido» | bandera ya en false | 1 rojo, el suyo |
| M5 sin el candado «sesión activa» | CANDADO 3 + el endurecido | 3 rojos |
| M6 `hasOnly` → `hasAny` | caballo de Troya | 2 rojos |

**Panel** (`node panel_admin/test_mutaciones_11_34.mjs`, 10 mutaciones): borde
inferior de la ventana, cortesía a 0, `cancelada` vuelve a bloquear, `ocupada`
deja de ganar, el mapa vuelve a pintar `estado`, el aviso de reservas
ilegibles se calla, los contadores vuelven al campo `estado`, la ventana de
próximas a 60 días, las acciones de sala en «Próximas», y **una de control**
(cambiar un comentario) que queda verde. Las nueve destructivas enrojecieron
el caso previsto.

**A mano:** quitar la limpieza de la bandera en `crearPedido` (2 rojos),
neutralizar el reset del espejo local (1), quitar el guard de la carrera (3),
quitar el `keepAlive` del panel (1) y del cliente (1), vaciar el `onPressed`
del logout (1), y **reinstalar la escritura del estado de la mesa** en
`crearReserva` (4 rojos, exactamente los cuatro casos invertidos).

### Disciplina del tiempo

Ninguna expectativa se calcula con la misma expresión que el código. La suite
de la ventana usa instantes literales (20:29, 20:30, 21:30, 21:31) y los cuatro
bordes tienen su caso: un `>=` escrito como `>` no lo detecta ninguna prueba «a
media ventana».

**Se encontró y se corrigió un test que ya dependía del reloj de la máquina**:
`stats_render_test.dart` se puso rojo con `mesasDisponibles: Expected 3, Actual
2` porque sus reservas son de las 12:00 y las 14:00 y la suite corrió dentro de
la ventana. Ahora fija `fabricaDeRelojProvider`, que es el único punto por el
que entra la hora, así que mapa y contadores no pueden afirmar sobre horas
distintas.

**Y se retiró una aserción propia por flaky**: `reloj_test.dart` afirmaba que
las horas avanzaban entre tics. `fakeAsync` adelanta los *temporizadores*, no
`DateTime.now()`, así que las horas salían del reloj real: rojo una vez, verde
al repetir sin tocar nada. Queda documentado en el propio archivo. Lo que ese
archivo puede afirmar sin mentir es la **cadencia** y la **limpieza**.

### Veredictos invertidos (9 casos, todos marcados)

Tres en rules (super_admin) y seis en Dart (`crearReserva` marcaba la mesa,
saltaba mesas ocupadas y `cancelarReserva` revertía). **Ninguno se borró**:
cada uno dice qué afirmaba antes y por qué la premisa cambió. La invertida más
significativa es la de 11-31, que escribió «la primera vez que la rama `esHoy`
se ejecuta desde el producto»: se ejecutó, se vio lo que hacía, y este plan la
quitó.

---

## Lo que está verificado y lo que no

**Verificado (ejecutado, con salida):**

- Los 9 gates en verde, con los tres baselines subidos en el mismo commit.
- Las 306 pruebas de rules contra el **emulador**, incluidos los 8 casos nuevos
  de reapertura y los del super_admin.
- 17 mutaciones, cada una enrojeciendo el caso previsto; 2 de control en verde.
- `audit:indexes`: 24 consultas, 0 fallos → **no hace falta ningún índice
  nuevo** para `reservasProximas`.
- El recorrido completo del logout del panel (pulsar → confirmar → `signOut` →
  el router redirige a `/login`) y el del cliente desde la pantalla.
- El recorrido completo de la reapertura sobre base fake real: pulsar «pedir la
  cuenta» → pedir un café → el botón vuelve → volver a pedirla.

**Afirmado, no verificado:**

- **Nada de esto se ha probado contra producción.** Las rules están escritas y
  probadas contra el emulador; **falta desplegarlas** (lo hace el usuario). Sin
  ese despliegue, el super_admin sigue recibiendo `permission-denied` y la
  reapertura de la cuenta sigue denegada en el proyecto real.
- El emulador **no valida índices compuestos**. La conclusión de que
  `reservasProximas` no necesita índice es de análisis estático más la forma
  del índice existente. Tras desplegar conviene `node
  scripts/probar_consultas_reales.mjs`.
- El **latido** del reloj está probado con `fakeAsync`, no en una pantalla
  montada. Que el mapa se repinte solo a los 30 minutos reales no se ha
  observado; lo que se ha observado es que el mapa se colorea correctamente
  para cualquier instante que se le dé, y que `main.dart` instala el reloj que
  late.
- El comportamiento con **dos reservas solapadas en la misma mesa** está
  cubierto por un test (gana la más temprana), pero el doc ID
  `{mesa}_{fecha}_{hora}` hace que sea una situación que no debería ocurrir.

## Deuda que este plan deja

- El botón de cerrar sesión de la **app cliente no pide confirmación**.
- El contador `mesasReservadas` de `DashboardStats` ya deriva, pero **ninguna
  tarjeta del dashboard lo muestra**: sigue siendo un campo del modelo sin
  consumidor visible.
- `_sinCandidata` conserva el parámetro `mesasOcupadas`, hoy siempre 0. Se
  mantiene porque su texto está probado y la rama volvería a valer si
  reaparece un motivo de descarte «de ahora mismo».

## Self-Check: PASSED

Archivos creados verificados en disco (12/12) y commits verificados en
`git log` (4/4): `51806c3`, `3222a8c`, `02a4d0b`, `b055fe4`.
