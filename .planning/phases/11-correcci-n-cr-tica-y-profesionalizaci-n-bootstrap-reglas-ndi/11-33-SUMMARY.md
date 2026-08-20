---
phase: 11-correcci-n-cr-tica-y-profesionalizaci-n-bootstrap-reglas-ndi
plan: 33
subsystem: ux
tags: [errores, streams, riverpod, asyncvalue, spinner-eterno, dinero, app_cliente, panel_admin]

requires:
  - phase: 11-23
    provides: "el clasificador único de fallos (CausaFallo/Contexto/mensajeDe) y el criterio de mensaje honesto que este plan extiende y replica"
  - phase: 11-28
    provides: "scripts/probar_consultas_reales.mjs — la única comprobación que separa «falta índice» de «regla deniega»"
  - phase: 11-32
    provides: "la cuenta de la mesa (cliente y mesero) y el aviso, escrito en su SUMMARY, de que el resumen del bottomNavigationBar no se había mirado a 320 px"
provides:
  - "app_cliente/lib/core/async_fallo.dart y panel_admin/lib/core/async_fallo.dart: reintentoGri + AsyncFalloX.cuandoConFallo"
  - "panel_admin/lib/core/firebase_error_mapper.dart: el clasificador de 11-23 replicado con vocabulario de staff"
  - "app_cliente: 4 contextos de LECTURA en el clasificador (verPedidos, verMenu, verReservas, verRestaurantes)"
  - "features/shared/fallo_de_stream.dart: el estado de fallo unificado del cliente"
  - "MEDICIÓN: Riverpod 3 reintenta 10 veces y mantiene AsyncLoading — ~38 s de spinner por cada fallo"
  - "MEDICIÓN: el resumen de la cuenta desbordaba 101 px a 320 px"
  - "VERDAD DE CAMPO: 23/23 consultas OK como super_admin y 7/7 del cliente OK contra p-gri-b5b40"
affects: [11-28, 11-32]

tech-stack:
  added: []
  patterns:
    - "La rama `error:` de un AsyncValue es tan mentirosa como un `catch`: un Stream que falla no pasa por ningún catch, así que un barrido de `catch` no puede verla"
    - "`AsyncValue.when` despacha por isLoading ANTES que por el error; con el reintento automático de Riverpod 3 eso convierte cualquier fallo en un spinner. Se usa `cuandoConFallo`"
    - "La política de reintento se decide sobre la CausaFallo del clasificador, no sobre el código crudo: mismo vocabulario que los mensajes, así no pueden divergir"
    - "Ante un fallo NO se pinta una cifra. Un cero es un dato y se lee como tal; el guion no"
    - "Un test de desborde lleva CANARIO: un ancho absurdo donde tiene que detectar algo"

key-files:
  created:
    - app_cliente/lib/core/async_fallo.dart
    - app_cliente/lib/features/shared/fallo_de_stream.dart
    - app_cliente/test/pedidos/errores_de_stream_test.dart
    - app_cliente/test/pedidos/cuenta_320_test.dart
    - app_cliente/test/shared/errores_de_stream_pantallas_test.dart
    - panel_admin/lib/core/async_fallo.dart
    - panel_admin/lib/core/firebase_error_mapper.dart
    - panel_admin/test/cocina/errores_de_stream_test.dart
    - panel_admin/test/cocina/recibo_cobro_test.dart
    - panel_admin/test/shared/errores_que_mienten_test.dart
  modified:
    - app_cliente/lib/core/firebase_error_mapper.dart
    - app_cliente/lib/main.dart
    - app_cliente/lib/features/pedidos/pedidos_provider.dart
    - app_cliente/lib/features/pedidos/pedido_estado_screen.dart
    - app_cliente/lib/features/pedidos/menu_mesa_screen.dart
    - app_cliente/lib/features/restaurantes/restaurante_detalle_screen.dart
    - app_cliente/lib/features/restaurantes/restaurantes_list_screen.dart
    - app_cliente/lib/features/reservas/mis_reservas_screen.dart
    - app_cliente/lib/features/reservas/reserva_wizard_screen.dart
    - panel_admin/lib/main.dart
    - panel_admin/lib/features/cocina/cocina_screen.dart
    - panel_admin/lib/features/clientes/historial_dialog.dart
    - panel_admin/lib/features/configuracion/configuracion_screen.dart
    - panel_admin/lib/features/shared/app_shell.dart
    - "+ 6 pantallas más del panel (clientes, equipo, menú, mesas, reportes, reservas, dashboard, staff_form_dialog)"
    - scripts/gates.mjs
    - docs/ICONOS-panel_admin.md

decisions:
  - "Solo CausaFallo.sinConexion se reintenta. Lo determinista —permiso denegado, not-found, failed-precondition— pasa a error inmediato: reintentarlo son 38 segundos de humo"
  - "El panel NO copia los textos del cliente, solo las causas y los criterios: quien lee es staff, y «entra con una cuenta de cliente» no le dice nada"
  - "Los textos del panel salen de una plantilla (causa + sustantivo del contexto) y no de 72 cadenas a mano: el criterio se comprueba una vez por causa en vez de doce"
  - "El criterio de 08-01 («404 y vacío indistinguibles») se CONSERVA para noEncontrado en el historial, que es donde era correcto; el resto de causas se dicen"
  - "`failed-precondition` sigue cayendo en `desconocido` (decisión de 11-23), no se reclasifica"

metrics:
  duration: "~4 h"
  tasks: 8
  files: 33
  completed: 2026-08-20
  gates: 9/9 OK
  tests: "app_cliente 466→489 (+23) · panel_admin 460→474 (+14) · rules 290 · functions 149 + 50"
---

# Fase 11 Plan 33: un stream que falla no es un stream que carga

El usuario dijo «el cliente en ver pedido se queda cargando». La rama `error:` de esa
pantalla existía desde 11-09 y el clasificador honesto desde 11-23. Aun así no se veía
ninguna de las dos cosas — y no se veían en **ninguna** pantalla de **ninguna** de las dos
apps.

---

## La causa raíz no estaba en nuestro código

```
ProviderContainer.defaultRetry(retryCount, error)   riverpod 3.4.2
  provider_container.dart:982
    if (retryCount >= 10) return null;
    if (error is ProviderException || error is Error) return null;
    delay = 200ms * 2^retryCount, tope 6400ms
```

Cuando un provider falla con algo que **no es un `Error` de Dart** —y una
`FirebaseException` es una `Exception`— Riverpod 3 lo **reintenta diez veces**. Y mientras
reintenta el estado no es `AsyncError`:

```
element.dart:790
  return AsyncLoading<ValueT>._(…, error: (err: error, stack: …, retrying: true));
```

`AsyncValue.when` despacha por `isLoading` **antes** que por el error, así que pinta la rama
`loading:`. Sumando la escalera `200+400+800+1600+3200+6400×5` son **≈38 segundos de
spinner mudo** antes del primer mensaje. Para un `permission-denied` esos 38 segundos son
puro humo: la regla deniega las diez veces y cada reintento vuelve a suscribir el listener.

**Medido, no deducido.** El hecho está fijado por un test que no prueba código nuestro sino
el comportamiento de la librería del que depende todo el arreglo:

```
un provider que falla queda en AsyncLoading CON error, no en AsyncError
  v.isLoading  → true
  v.hasError   → true
  v.when(…)    → 'CARGA'      ← el bug
  v.cuandoConFallo(…) → 'ERROR'
```

Si una versión futura de Riverpod deja de reintentar, o deja de representarlo así, ese caso
lo dirá en vez de que nos enteremos por otro incidente.

### Y encima, un segundo bug propio en la pantalla del incidente

```dart
final sesion = ref.watch(sesionActualProvider).value;   // descarta el AsyncError
if (sesion == null || uid == null) {
  yield* const Stream<List<Pedido>>.empty();            // cierra sin emitir
  return;
}
```

`.value` sobre un `AsyncError` da `null`, así que un listener denegado de `sesiones` era
indistinguible de «este usuario no tiene mesa abierta». Y un `async*` que hace `yield*` de un
stream vacío y retorna **cierra sin emitir nunca**: ahí el spinner ya no dura 38 segundos,
dura para siempre. La ruta `/mesa/pedidos` **no tiene guard de sesión** (`app.dart`), así que
entrar sin mesa abierta producía lo mismo.

---

## Auditoría completa: los 24 consumidores de `AsyncValue` de las dos apps

Se revisaron **todos**, incluidos los que se juzgan sanos.

### app_cliente — 8 consumidores

| # | Sitio | Cómo pintaba el error | Veredicto |
|---|---|---|---|
| 1 | `pedidos_provider.dart:166` (`pedidosSession`) | `.value` + `Stream.empty()` → **AsyncLoading eterno** | **BUG — el del incidente** |
| 2 | `pedido_estado_screen.dart:117` | «Error al cargar tus pedidos» + spinner durante 38 s | **BUG** |
| 3 | `pedido_estado_screen.dart:92` (`sesion`) | `.value` → el fallo se disfraza de «sin mesa»; la barra de la cuenta desaparece | **BUG** |
| 4 | `menu_mesa_screen.dart:102` | «Error al cargar el menú» + spinner | **BUG** |
| 5 | `restaurante_detalle_screen.dart:35` | «Error al cargar el restaurante» + spinner | **BUG** |
| 6 | `restaurantes_list_screen.dart:21` | «Error al cargar restaurantes» + spinner | **BUG** |
| 7 | `mis_reservas_screen.dart:48` | «Error al cargar tus reservas» + spinner | **BUG** |
| 8 | `reserva_wizard_screen.dart:492` | «No se pudieron cargar los restaurantes» + spinner | **BUG (menor)** — el texto no mentía, pero no decía la causa ni ofrecía nada |
| — | `restaurante_detalle_screen.dart:30` (`maybeWhen` del título) | `orElse` → el AppBar queda con el título genérico | **SANO, no se toca.** Es un título; el cuerpo de la pantalla ya explica el fallo con su mensaje y su botón. Duplicar el error en la barra no añade nada |

### panel_admin — 16 consumidores

| # | Sitio | Cómo pintaba el error | Veredicto |
|---|---|---|---|
| 9 | `cocina_screen.dart:307,310` (`_FilaAvisoCuenta`) | `.value ?? const []` → **importe 0** | **BUG DE DINERO** |
| 10 | `cocina_screen.dart:308` (`_importeMesa`, en el cobro) | `.value ?? const []` → **recibo «entregada por 0 $»** | **BUG DE DINERO** |
| 11 | `cocina_screen.dart:33` (`avisoCuenta`) | `.value ?? const []` → «ninguna mesa pidió la cuenta» | **BUG** |
| 12 | `cocina_screen.dart:93` (cola) | «Error cargando pedidos» + spinner | **BUG** |
| 13 | `historial_dialog.dart:47` | `error: (e,_) => _SinPedidos()` → **«este cliente no tiene pedidos»** | **MENTIRA** |
| 14 | `configuracion_screen.dart:95` | **«No hay restaurante seleccionado»** | **MENTIRA** (familia 11-24) |
| 15 | `app_shell.dart:507` | `SizedBox.shrink()` → el selector desaparece | **SILENCIO** |
| 16 | `app_shell.dart:537` | `SizedBox.shrink()` → el nombre desaparece | **SILENCIO** |
| 17 | `configuracion_screen.dart:36` | «Error cargando la sesión» | genérico |
| 18 | `configuracion_screen.dart:290` | «Error cargando restaurantes» | genérico |
| 19 | `clientes_screen.dart:54` | «Error cargando clientes» | genérico |
| 20 | `equipo_screen.dart:87` | «No se pudo cargar el equipo» | genérico |
| 21 | `menu_screen.dart:65` | «Error cargando el menú» | genérico |
| 22 | `mesas_screen.dart:60` | «Error cargando mesas» | genérico |
| 23 | `reportes_screen.dart:196` | «Error al consultar los reportes» | genérico |
| 24 | `reservas_screen.dart:131` | «Error cargando reservas» | genérico |
| — | `dashboard_screen.dart:110,219` | «Error cargando estadísticas/mesas» | genérico |
| — | `staff_form_dialog.dart:314` | «No se pudo cargar la lista de restaurantes» | genérico |
| — | `dashboard_screen.dart:85` (`ridAsync.hasValue`) | comprueba `hasValue` explícitamente | **SANO.** Ya distingue los tres estados a mano |

**Los 24 están arreglados**, salvo el `maybeWhen` del título y el `hasValue` del dashboard,
que se examinaron y se juzgan correctos por las razones de arriba.

---

## Los dos bugs de dinero, que son los peores

11-32 tuvo el cuidado de que la fila del mesero mostrara un **guion** mientras carga, con
esta razón escrita al lado: *«un cero es una cifra y se leería como esta mesa no debe
nada»*. La rama de **error** se saltaba ese cuidado y caía en `.value ?? const []`.

**(a) La fila.** Con el listener denegado, `cuentaDeMesa` suma 0 y el mesero lee `0 $`.
Reproducido:

```
Expected: not contains '0 $'
Actual:   'Pedidos · Cocina | … | Mesas que pidieron la cuenta | … | 0 $'
```

**(b) El recibo.** Éste apareció en la auditoría **final**, cuando el plan ya parecía
terminado: `_importeMesa` llega por un camino **distinto** (`read`, no `watch`), así que
arreglar la fila no lo arreglaba. Es el instante exacto del cobro — se lee el importe, se
cierra la sesión, y el snackbar hace de recibo:

```
Actual: 'Mesa 3 — cuenta entregada por 0 $ (sesión cerrada)'
```

Una cifra inventada, escrita cuando la sesión ya está cerrada y el aviso —con su fila y su
importe— ha desaparecido. Ahora `_importeMesa` devuelve `int?` y el recibo dice *«sesión
cerrada, pero NO pudimos calcular el importe. Consúltalo antes de cobrar.»*

---

## El desborde que 11-32 anunció y nadie había medido

> *«El resumen del comensal va en el `bottomNavigationBar` y crece hasta tres bloques; en un
> viewport corto eso es exactamente el tipo de cosa que revienta.»* — SUMMARY de 11-32

Tenía razón. A 320 px (iPhone SE 1.ª gen, Galaxy Fold cerrado): **`A RenderFlex overflowed
by 101 pixels on the right`**. Tres `Row` con el patrón «etiqueta + `Spacer` + importe», que
no cede espacio a nadie. En los tres cede ahora la **etiqueta** (`Expanded` + elipsis) y el
importe conserva su tamaño: la cifra es dinero y no puede recortarse.

El test lleva **canario**: a 60 px tiene que detectar desborde. Sin él, los tres casos
podrían estar en verde porque el detector no mira, no porque quepa.

---

## Verificación contra el proyecto real — salida REAL

`node scripts/probar_consultas_reales.mjs --proyecto p-gri-b5b40`, las dos identidades.
Reglas e índices desplegados y verificados hoy por el usuario.

### Como cliente (`d7c4xzmrbYcgiaGW0mCnqrdMril2`, `--rol cliente`)

```
 23 consultas · 12 OK · 0 sin índice usable · 11 denegadas · 0 sin valor
```

**Las 7 consultas de `app_cliente`, todas OK.** Incluida la del incidente:

```
 app_cliente/…/pedidos_provider.dart:208  pedidos sesionId== usuarioId== orderBy(createdAt)  OK  1 doc(s)
 app_cliente/…/reserva_controller.dart:204 mesas restauranteId== orderBy(numero)             OK  1 doc(s)
 app_cliente/…/reservas_provider.dart:19   reservas usuarioId== orderBy(fecha desc)          OK  1 doc(s)
 app_cliente/…/restaurantes_provider.dart:21 restaurantes activo==                           OK  1 doc(s)
 app_cliente/…/restaurantes_provider.dart:72 categorias restauranteId== activo==             OK  1 doc(s)
 app_cliente/…/restaurantes_provider.dart:77 productos restauranteId== activo== disponible== OK  1 doc(s)
 app_cliente/…/sesion_provider.dart:188    sesiones usuarioId==                              OK  1 doc(s)
```

Las 11 `PERMISSION_DENIED` son **todas** consultas de `panel_admin` ejecutadas con un uid de
cliente. Es lo correcto por diseño: un comensal no es staff. Ninguna pantalla que use ese rol
hace ninguna de ellas.

Detalle que conviene conocer: `panel_admin/…/clientes_provider.dart:101`
(`pedidos restauranteId== usuarioId==`) sale **OK** con el uid de cliente, porque la rama
`usuarioId == uid` de la regla la ampara. No es un fallo — es la disyunción funcionando.

### Como super_admin (`np9HetsgY6UcVCdC1sGhsUloI6D3`, `--rol super_admin`)

```
 23 consultas · 23 OK · 0 sin índice usable · 0 denegadas · 0 sin valor
```

**Cero `FAILED_PRECONDITION` en las dos pasadas.** Los índices que 11-28 dejó pendientes de
desplegar están construidos y sirven a sus consultas, incluidas las dos que en su día daban
`FAILED_PRECONDITION`:

```
 panel_admin/…/pedidos_staff_provider.dart:36   pedidos restauranteId== estado== orderBy(createdAt)  OK
 panel_admin/…/reportes_provider.dart:35        pedidos restauranteId== estado== createdAt<> …       OK
```

**No hay ningún defecto vivo de consultas ni de índices.** El «se queda cargando» del usuario
era su build antiguo (anterior al `usuarioId` de 11-28) sumado al defecto de renderizado que
este plan repara. La clave de servicio se pasó por ruta; ni su contenido ni ningún token
aparecen en esta salida.

---

## Roturas deliberadas: 7, las 7 en rojo

Ninguna garantía se da por buena sin romperla.

| # | Se rompió | Resultado |
|---|---|---|
| A | `cuandoConFallo` vuelve a mirar `isLoading` primero (= `when`) | **10 casos rojos** |
| B | El provider vuelve a tragarse el error de la sesión | **2 rojos** |
| C | `reintentoGri` reintenta todo (default de Riverpod) | **2 rojos** |
| D | El importe de la fila vuelve a `isLoading` a secas | **1 rojo**, con `'0 $'` en pantalla |
| E | `_importeMesa` vuelve a devolver 0 | **1 rojo**: `'Mesa 3 — cuenta entregada por 0 $ (sesión cerrada)'` |
| F | El historial vuelve a `_SinPedidos()` para todo | **1 rojo**: `'Sin pedidos en este restaurante'` |
| G | El total vuelve a `Text + Spacer` | **3 rojos** (los tres anchos de 320 px) |

### Sobre el `<verify>` de este plan

El comando es `node scripts/gates.mjs`. **Se comprobó que puede fallar**, de dos maneras:

1. Saboteando la baseline a 9999 → `2 gates · 1 OK · 1 fallo(s)`.
2. Falló **de verdad tres veces** durante el trabajo y hubo que arreglar código: dos por
   `sin_emojis_test` (las líneas del doc de iconos se desplazaron al insertar código) y una
   por `stats_render_test` (el mensaje nuevo).

Las baselines se subieron (466→489, 460→474): sin subirlas, borrar los 35 tests de este plan
pasaría en verde, que es el fallo que 11-28 ya tuvo que corregir una vez.

---

## Dos tests preexistentes actualizados, y por qué no es aflojar

Los dos afirmaban `find.textContaining('Error')`, que pasa con **cualquier** cadena que
lleve esa palabra — incluido el «Error al cargar X» que este plan elimina. Se cambian por el
mensaje **literal** más la comprobación de que no culpa ni a la red ni a la cuenta. Son
aserciones más fuertes, no más débiles:

- `app_cliente/test/restaurantes/list_test.dart`
- `panel_admin/test/dashboard/stats_render_test.dart`

Y el canario del gate de a11y bajó de 12 a 7 apariciones de `GriColors.gray` porque se
unificaron **cinco** copias del bloque de error en una. Umbral 10 → 6, con el motivo escrito
al lado; el gate sigue leyendo los mismos archivos y clasificando las mismas apariciones.

---

## Gates — salida real

```
 GATE                                   RES.   TESTS     DETALLE
 app_cliente: flutter test              OK     489       489 = baseline
 app_cliente: flutter analyze           OK     0 issues  0 issues
 panel_admin: flutter test              OK     474       474 = baseline
 panel_admin: flutter analyze           OK     0 issues  0 issues
 functions: npm test (unitarios)        OK     149       149 = baseline
 scripts: npm run test:rules            OK     290       290 = baseline
 scripts: npm run test:functions (e2e)  OK     50        50 = baseline
 scripts: npm run audit:indexes         OK     —         exit 0
 scripts: npm run audit:branding        OK     —         exit 0

 9 gates · 9 OK · 0 fallo(s) · 2.7 min
```

**+37 tests** (`app_cliente` +23, `panel_admin` +14), medidos corriendo solo los archivos
nuevos.

---

## Verificado vs. afirmado — leerlo antes de dar esto por cerrado

**Verificado ejecutando:**

- Que un listener denegado ya no produce spinner en ninguna de las 22 ramas arregladas, y
  que el texto que sale nombra la causa correcta. Probado con la pareja
  permiso-denegado / sin-red en cada pantalla, afirmando además que los dos textos **diferen**.
- Que Riverpod 3 mantiene `AsyncLoading` con el error dentro mientras reintenta (test propio
  contra la librería).
- Que el importe no se renderiza como cero ni en la fila ni en el recibo, con las dos
  roturas que lo demuestran.
- Que a 320 px no desborda, con canario que prueba que el detector mira.
- Las 23 consultas contra el proyecto real, con las dos identidades. Salida completa arriba.
- Los 9 gates, dos pasadas, la segunda sobre el árbol ya commiteado.

**Afirmado, NO verificado (requiere una persona o el proyecto real):**

- **Que los textos nuevos SE LEAN bien.** Un widget test prueba que una cadena se renderiza;
  no prueba que un comensal con el móvil en la mano —o un mesero con la comanda— entienda qué
  hacer. Los del panel salen de una **plantilla**, así que conviene leerlos: la lista de
  sustantivos está en el `enum Contexto` de
  `panel_admin/lib/core/firebase_error_mapper.dart`, revisable de un vistazo.
- **Nada de esto se ha visto en un dispositivo.** El desborde de 320 px se midió con el motor
  de layout de Flutter, que es la misma medida que hace el dispositivo, pero la jerarquía
  visual del resultado (etiqueta con elipsis junto a la cifra) no la ha mirado nadie.
- **El comportamiento de reintento en la app real.** `reintentoGri` está probado como función
  y a través de un `ProviderContainer`, pero nadie ha visto la app perder la red y
  recuperarse sola.
- **No se ha desplegado nada** (instrucción explícita).

---

## Deviations from Plan

No había PLAN.md; el encargo era la especificación.

**1. [Regla 1 — Bug] El encargo apuntaba a la rama `error:` de las pantallas; la causa
estaba una capa más abajo.** El encargo describía como defecto «un `when` que mapea `error` a
un spinner». Ninguna pantalla hacía eso: todas tenían su rama `error:` escrita. El defecto era
que esa rama **nunca se alcanzaba**, por el reintento automático de Riverpod 3. Arreglar solo
los textos habría dejado el spinner de 38 segundos intacto en las dos apps.

**2. [Regla 2 — Funcionalidad crítica ausente] Dos bugs de DINERO no anticipados.** El
importe de la fila y el del recibo se renderizaban como `0` ante un fallo de lectura. El
segundo llega por un camino distinto (`read` en vez de `watch`) y se encontró en la auditoría
final, ya con el plan aparentemente terminado.

**3. [Regla 2] El desborde de 320 px era real.** El encargo lo pedía como comprobación
(«check it at 320px»); resultó ser un bug de 101 px que hubo que arreglar, no solo verificar.

**4. [Regla 2] El panel no tenía clasificador.** Había que replicarlo para poder cumplir el
encargo de «reutilizar el vocabulario en vez de inventar otro». Se replican las causas y los
criterios, no los textos.

**5. Alcance ampliado sobre lo pedido:** el encargo hablaba de `StreamProvider`/`.snapshots()`.
El mismo defecto afecta idénticamente a los `FutureProvider` (`restaurantesList`,
`restauranteDetalle`, `clienteHistorial`, `clientes`, `reportes`), porque la causa es del
motor de reintento y no del tipo de provider. Se arreglaron también.

---

## Known Stubs

Ninguno.

## Threat Flags

Ninguna nueva. No se tocó `firestore.rules`, `firestore.indexes.json`, `functions/` ni
ninguna consulta. Los mensajes nuevos describen la CONDICIÓN de la cuenta y **no** nombran la
regla, el rol exigido ni la estructura de datos — hay un caso que lo comprueba sobre los 13
contextos del panel (mitigación T-11-23-01 heredada).

Detalle de ese caso que merece quedar escrito: la lista de tokens prohibidos se escribió
primero con `'cocina'` dentro y se puso **roja**, no por una fuga sino porque «cocina» es
también el sustantivo legítimo de `Contexto.pedidosCocina` («los pedidos de la cocina»). Está
documentado en el propio test para que nadie lo vuelva a añadir.

---

## Notas para quien siga

- **`app_cliente/test/pedidos/errores_de_stream_test.dart` contiene un test que prueba
  RIVERPOD, no nuestro código.** Es deliberado: todo el arreglo depende de que
  `AsyncLoading` lleve el error dentro mientras se reintenta. Si una actualización cambia
  eso, ese caso avisa.
- **Las dos copias de `async_fallo.dart` son idénticas salvo la cabecera**, y las dos suites
  prueban el mismo vector de `reintentoGri`. Igual que `cuenta.dart` / `cuenta_mesa.dart` de
  11-32.
- **`docs/ICONOS-panel_admin.md` se recalculó tres veces** durante este plan; hay un script
  reutilizable en el histórico de la sesión que reasigna las líneas **leyendo el código** en
  vez de a ojo. Insertar código en `cocina_screen.dart` o `dashboard_screen.dart` volverá a
  romper ese gate.
- **AJENO, no commiteado:** apareció un `ESTRUCTURA PARA EL DOCUMENTO.pdf` sin seguir en la
  raíz a mitad del trabajo. **No se estageó.** Todos los commits de este plan usan
  `git commit -- <rutas>` y se comprobó `git diff --cached --name-only` antes de cada uno.
- **MEDICIÓN de herramienta, por si le pasa a otro:** actualizar
  `PENDIENTE-POST-FASE-11.md` con un script duplicó el archivo entero. La causa es que en
  `String.prototype.replace`, dentro de la CADENA de reemplazo, `$` seguido de acento grave
  significa «todo lo anterior al match». El texto insertado contenía un importe en pesos
  escrito con acentos graves, y eso bastó. Se arregla usando una **función** de reemplazo o
  cortando por índice con `slice`. Mismo tipo de trampa que el espacio duro de `formatCOP`:
  invisible en el diff hasta que se miran los bytes.
- **Los once tests de dinero preexistentes siguen comparando `formatCOP` consigo mismo**
  (deuda anotada por 11-32). Los tres casos de dinero que añade este plan usan cadenas
  literales con el escape ` ` visible; no se añadió ningún duodécimo test tautológico.

## Self-Check: PASSED

- `app_cliente/lib/core/async_fallo.dart` — FOUND
- `app_cliente/lib/features/shared/fallo_de_stream.dart` — FOUND
- `panel_admin/lib/core/async_fallo.dart` — FOUND
- `panel_admin/lib/core/firebase_error_mapper.dart` — FOUND
- Los 5 archivos de test nuevos — FOUND
- Commits `3a7e783` `2612df9` `618162d` `8704fe3` `8398cb8` `65eff89` `fc2bf65` `0b4deed`
  `31f577a` `6f44c92` — FOUND
- 9/9 gates OK sobre el árbol commiteado
