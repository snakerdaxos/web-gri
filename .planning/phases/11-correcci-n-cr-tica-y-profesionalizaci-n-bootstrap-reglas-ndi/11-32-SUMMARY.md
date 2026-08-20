# Plan 11-32 — La cuenta de la mesa

**Estado:** completado. 9/9 gates verdes.
**Especificación:** `.planning/SPEC-CUENTA.md`
**Commits:** `82985ce` `2f0edfc` `737353d` `49b2c46` `3564b03` `a11de7f` `5bc851b`

---

## Qué se construyó

Hasta este plan **el producto no podía cobrar**. La única suma de las dos apps
era la del carrito, y ocurría *antes* de enviar el pedido. Después de eso el
comensal pedía la cuenta y no veía ningún importe; el mesero pulsaba «entregar
cuenta», la sesión se cerraba, la mesa se iba a limpieza — y el importe no
existía en ninguna pantalla. Para cobrar había que abrir Firestore y sumar los
pedidos a mano.

Ahora las dos partes ven **el mismo número**, calculado con la misma regla
(solo lo `servido`), y las dos ven además **qué se queda fuera**.

### Lado comensal — `app_cliente`

| Archivo | Qué hace |
|---|---|
| `lib/features/pedidos/cuenta.dart` (nuevo) | Lógica pura. Reparte los pedidos en cobrados / pendientes / rechazados / fuera-de-sesión. |
| `lib/features/pedidos/pedido_estado_screen.dart` | La barra inferior deja de ser solo un botón. |

### Lado mesero — `panel_admin`

| Archivo | Qué hace |
|---|---|
| `lib/features/cocina/cuenta_mesa.dart` (nuevo) | Espejo de la regla sobre `PedidoStaff`. |
| `lib/features/cocina/pedidos_staff_provider.dart` | `pedidosServidosMesaProvider(mesaId)`: la consulta de la cuenta. |
| `lib/features/cocina/cocina_screen.dart` | Cada fila del aviso lleva su importe; el snackbar lo repite. |

---

## Cómo la vista distingue lo cobrado de lo pendiente

Esta era la parte delicada del encargo, así que va detallada. La regla «solo se
cobra lo servido» tiene una consecuencia que la interfaz **tiene** que absorber:
el importe **sube solo** mientras la cocina trabaje. Si en pantalla hubiera un
único número, el comensal leería 50.000, llegaría su último plato, vería 75.000
y pensaría —con razón— que le están cobrando de más.

Se resolvió en **tres sitios a la vez**, no en uno:

**1. El total dice de qué está hecho.** `Total a pagar` = solo los servidos.
Aparece siempre que haya algo en la sesión: antes de pedir la cuenta, después
de pedirla, y tras el cierre (donde pasa a decir `Total pagado`). Saber cuánto
se debe no depende de haber pulsado un botón.

**2. Lo que falta se anuncia con su cifra, no se esconde.** Cuando hay pedidos
en curso aparece, pegado al total:

> *Aún en cocina: 2 pedidos por 38.000 $, se sumarán a tu cuenta cuando te los
> sirvan.*

Dice **cuántos**, **cuánto** y **cuándo entrará**. Con un solo pedido va en
singular. Sin pendientes el bloque no se pinta: no hay nada que aclarar.

**3. Cada tarjeta declara su situación.** Junto al importe de cada pedido:
`Se cobra` / `Aún no se cobra` / `No se cobra`. Sin esto, tres tarjetas con tres
importes y un total que no es su suma parecen un error de cálculo; con esto,
cada línea explica por qué entra o no entra.

Y si no han servido nada todavía, el cero se explica en vez de quedarse mudo:
*«Todavía no te han servido nada, por eso el total va en cero.»*

**Del lado del mesero** la distinción se hace en la misma fila donde decide:
el importe cobrable va grande a la derecha, y encima, en el color de aviso, va
la advertencia que necesita para decidir si cobra ya o espera:

> *1 pedido sin servir por 15.000 $: al cerrar la sesión no se cobra.*

Detalle deliberado: mientras la consulta carga, la fila muestra un guion, **no
un cero**. Un cero es una cifra y se leería como «esta mesa no debe nada».

---

## Reglas e índices: no hizo falta ninguno (verificado, no supuesto)

La spec anticipaba que quizá harían falta. **No hicieron falta**, y esto no es
una suposición: lo confirma `scripts/audit_indexes.mjs`, que parsea las queries
del Dart y las contrasta contra `firestore.rules` y `firestore.indexes.json`.

```
 panel_admin/lib/features/cocina/pedidos_staff_provider.dart:126
   pedidos restauranteId== estado== createdAt<>   OK (createdAt ASC)      [AUDIT 1/4 índices]
   pedidos restauranteId== estado== createdAt<>   OK (restauranteId)      [AUDIT 2/4 paridad rules]
```

- **Cliente:** cero consultas nuevas. La cuenta se calcula sobre el stream que
  ya existía. El `where('usuarioId')` de `pedidosSessionProvider` **sigue
  intacto** (el audit lo confirma en `pedidos_provider.dart:180`).
- **Mesero:** una consulta nueva con la forma
  `restauranteId== + estado== + createdAt>=`. El índice
  `pedidos(restauranteId, estado, createdAt ASC)` **ya estaba desplegado** — lo
  usa la cola de cocina — y sirve igual con un rango en el último campo. El
  `where('restauranteId')` es justamente lo que la rama staff de la regla
  (`staffOf(resource.data.restauranteId)`) necesita que la consulta demuestre.

`firestore.rules`, `firestore.indexes.json`, `app_cliente/lib/features/reservas/`
y `scripts/test/rules/` **no se tocaron** (propiedad del plan 11-31).

---

## Bugs encontrados y arreglados por el camino

### 1. `formatCOP` llevaba desde la fase 10 documentando mal el dinero

La cabecera de `core/format.dart` (en **las dos apps**) prometía `"$ 32.000"`.
Lo que el helper devuelve es `32.000` + **espacio duro U+00A0** + `$`. Dos cosas
mal: el orden del símbolo y el tipo de espacio.

**Por qué nadie lo vio en 30 planes:** los once tests de dinero del repo se
escriben `expect(find.text(formatCOP(50000)), ...)`. Comparan el helper consigo
mismo, así que **habrían pasado en verde con cualquier formato**, incluido uno
roto. El primer test que afirmó la *cadena literal* lo destapó en dos pasos:
primero el orden, después el NBSP (el diff decía `Expected: 50.000 $ / Actual:
50.000 $`, idénticos a la vista, distintos en el byte 7).

Se corrigió **la documentación, no el formato**: cambiar la salida movería todos
los precios de las dos apps y no era decisión de este plan. Los tests nuevos
usan un helper `cop('50.000')` que escribe el ` ` con el escape **visible**
en el código, para que nadie vuelva a pelearse con un espacio invisible.

### 2. Sesión reutilizada = cuenta de la visita anterior (Regla 1, dinero)

`sesiones/{mesaId}` tiene doc ID determinista y `abrirSesion()` hace `tx.set()`
sobre **el mismo documento** en cada visita. Los pedidos de la visita pasada
conservan `sesionId == mesaId` **y** `usuarioId == uid` — exactamente los dos
filtros de la consulta del cliente. Sin hacer nada, un comensal que vuelve a la
misma mesa se habría encontrado la cena de la semana pasada **sumada a su
cuenta**.

Arreglado en las dos apps acotando por el `inicioAt` de la sesión vigente. Del
lado del comensal se filtra client-side (no se tocó la consulta, que es la del
P0 de 11-28); del lado del mesero va **dentro** de la consulta, donde además
acota lo que se lee.

Un pedido con `createdAt == null` (serverTimestamp aún sin resolver) **siempre**
entra: excluirlo haría que el total bajara un instante justo después de pedir.

### 3. `docs/ICONOS-panel_admin.md` señalaba líneas que se habían movido

Insertar código en `cocina_screen.dart` desplazó tres entradas de la tabla
`archivo:línea` de iconos. Lo cazó el gate `sin_emojis_test`. Actualizadas.

---

## Verificación: qué está probado y qué no

### Verificado rompiendo a propósito

Cada garantía se saboteó y se comprobó que **algo se pone rojo**. Ninguna pasó
por silencio:

| Sabotaje | Tests en rojo |
|---|---|
| Cobrar todo lo no rechazado (quitar el filtro `servido`) | 8 |
| Quitar la ventana de sesión (`desde`) — cliente | 1 |
| Desconectar el total de la pantalla del cliente | 6 |
| Quitar el bloque de pendientes del cliente | 3 |
| Quitar la etiqueta por tarjeta | 2 |
| Quitar el filtro `sesionId` — panel | 1 |
| Quitar el guard `estado == servido` de `cuentaDeMesa` | 1 |
| Desconectar el importe de la fila del mesero | 2 |
| Quitar la ventana `createdAt >= inicioAt` — panel | 1 |
| Quitar el `where('restauranteId')` (tenant) — panel | 1 |

### Dos assertions que estaban verdes por el motivo equivocado

**(a) El guard `estado == servido` de `cuentaDeMesa` no lo cubría nadie.**
Es redundante en el camino feliz porque la consulta ya filtra por estado — y al
saboteárselo, **la suite entera siguió en verde**. Es defensa en profundidad
sobre dinero, así que se le escribió su propio caso: un pedido `en_preparacion`
colado en la lista de servidos no debe sumar.

**(b) `find.textContaining('15.000 $')` acertaba dos veces.** El importe del
pedido pendiente aparece también en su tarjeta de la cola de cocina, así que la
assertion habría pasado aunque el aviso no dijera nada. Se cambió por la frase
entera con la cifra dentro: `'1 pedido sin servir por 15.000 $'`.

**Sobre el `<verify>` de este plan:** el comando es `node scripts/gates.mjs` y
**se comprobó que puede fallar** — de hecho falló dos veces durante la ejecución
(el gate `sin_emojis` por las líneas del doc, y `flutter analyze` por
concatenaciones y un import sin uso), y hubo que arreglar el código para
ponerlo en verde. No es un comando decorativo.

### Gates — salida real

```
 GATE                                   RES.   TESTS     DETALLE
 app_cliente: flutter test              OK     466       466 = baseline
 app_cliente: flutter analyze           OK     0 issues  0 issues
 panel_admin: flutter test              OK     460       460 = baseline
 panel_admin: flutter analyze           OK     0 issues  0 issues
 functions: npm test (unitarios)        OK     149       149 = baseline
 scripts: npm run test:rules            OK     290       290 = baseline
 scripts: npm run test:functions (e2e)  OK     50        50 = baseline
 scripts: npm run audit:indexes         OK     —         exit 0
 scripts: npm run audit:branding        OK     —         exit 0

 9 gates · 9 OK · 0 fallo(s) · 2.3 min
```

**Baselines subidas por lo que este plan aporta, medido corriendo solo los
archivos nuevos** (no restando totales del árbol: 11-31 estaba añadiendo tests
en paralelo):

- `app_cliente` 439 → **466** (+27: 14 del cálculo, 13 de la pantalla)
- `panel_admin` 446 → **460** (+14: 1 ancla de formato, 6 cálculo, 3 consulta, 4 pantalla)

`rules` (290), `functions_unit` (149) y `functions_e2e` (50) sin cambios: este
plan no toca reglas ni funciones.

### NO verificado — decir la verdad

- **Nada de esto se ha probado contra Firestore real.** `fake_cloud_firestore`
  no evalúa security rules **ni valida índices compuestos**. Que la consulta
  del mesero funcione en la suite **no demuestra** que Firestore la acepte. Lo
  que sí hay es el audit estático (paridad rules↔query e índice con el sentido
  exacto), que es la evidencia más fuerte disponible sin red. La prueba real es
  `node scripts/probar_consultas_reales.mjs` contra `p-gri-b5b40` — **queda
  pendiente y es lo primero que hay que correr**; la consulta nueva ya está en
  el inventario, así que la recoge sola.
- **No se ha desplegado nada** (instrucción explícita).
- **No se ha visto en un dispositivo real.** Ninguna de las dos pantallas se ha
  mirado con ojos humanos: los tests afirman textos e importes, no que el
  bloque quepa, que no desborde en un móvil estrecho o que la jerarquía visual
  se lea bien. El resumen del comensal va en el `bottomNavigationBar` y crece
  hasta tres bloques; en un viewport corto eso es exactamente el tipo de cosa
  que revienta.
- **El importe es de solo lectura.** No hay cobro en línea (diferido desde la
  fase 10) ni registro de que se haya cobrado: `entregarCuenta` sigue cerrando
  la sesión sin guardar el importe en ninguna parte.

---

## Decisiones que conviene conocer

**La regla vive duplicada, a propósito.** `cuenta.dart` (cliente) y
`cuenta_mesa.dart` (panel) implementan lo mismo sobre modelos distintos, porque
las dos apps no comparten paquete (convención del repo desde la fase 10:
modelos y máquinas de estado ya están duplicados). Para que no deriven en
silencio, **las dos suites prueban el mismo vector**: 32.000 + 18.000 servidos,
25.000 en curso, 40.000 rechazado → total 50.000, pendiente 25.000. Si una copia
cambia la regla, su test cae.

**`entregarCuenta` no se tocó.** Sigue cerrando la sesión y mandando la mesa a
limpieza en una transacción. Tampoco se añadió diálogo de confirmación: el
importe se ve en la fila *antes* del toque, que es lo que pedía la spec, y
meter un paso extra habría cambiado un flujo que funciona.

**`pagado` no se cobra dos veces.** Es inalcanzable en v1 (ni la matriz del
panel ni las rules permiten llegar a ese estado), pero si algún día llega, cae
fuera del total en vez de sumarse. Tiene su caso de prueba.

---

## Cosas que este plan deja sobre la mesa

1. **Correr `probar_consultas_reales.mjs`** — lo único que distingue «falta el
   índice» de «las rules deniegan». Es la verificación que falta.
2. **Mirar las dos pantallas en un dispositivo.** Sobre todo el resumen del
   comensal en un móvil estrecho.
3. **El importe cobrado no se guarda.** Al entregar la cuenta se cierra la
   sesión y el número se pierde: no hay recibo ni queda rastro de cuánto se
   cobró. Los reportes siguen plegándose desde `pedidos`.
4. **Los once tests de dinero preexistentes siguen comparando `formatCOP`
   consigo mismo.** Se corrigió la documentación y los tests nuevos usan cadenas
   literales, pero los viejos no se reescribieron — quedan igual de ciegos al
   formato que antes.
