---
phase: 11
plan: 28
subsystem: firestore-queries
tags: [p0, firestore, rules, indices, query-vs-rules, audit, pedidos]
requires:
  - firestore.rules (sin cambios — la consulta se adapta a la regla)
  - inventario de queries del Dart de las dos apps
provides:
  - query de pedidos del cliente demostrable frente a las rules
  - índices compuestos de pedidos con el sentido correcto
  - audit estático que comprueba SENTIDO de índice, paridad por ramas y cobertura
  - scripts/probar_consultas_reales.mjs (verificación contra el proyecto real)
affects:
  - app_cliente (pantalla de seguimiento del pedido)
  - panel_admin (cola de cocina, reporte de ventas) — vía índices
  - despliegue: quedan 2 índices por desplegar
tech-stack:
  added: []
  patterns:
    - "inventario único de queries compartido por el audit estático y la prueba real"
    - "paridad rules↔query con ALTERNATIVAS (reglas en disyunción)"
key-files:
  created:
    - scripts/inventario_queries.mjs
    - scripts/probar_consultas_reales.mjs
    - app_cliente/test/pedidos/query_sesion_test.dart
  modified:
    - app_cliente/lib/features/pedidos/pedidos_provider.dart
    - firestore.indexes.json
    - scripts/audit_indexes.mjs
    - scripts/gates.mjs
    - scripts/package.json
    - scripts/test/rules/pedidos.test.mjs
    - scripts/test/rules/sesiones.test.mjs
    - scripts/test/rules/reservas.test.mjs
    - docs/SMOKE-E2E-v2.md
    - docs/ESTADO-DESPLIEGUE.md
decisions:
  - "El índice se adapta a la consulta, no al revés: cocina es una cola FIFO y el reporte no lleva orderBy. Se declaran los índices ASC en vez de retorcer las queries."
  - "No se poda ningún índice superado: borrarlo del JSON lo borra en producción al desplegar."
  - "No se tocó ninguna regla. La consulta del cliente se adaptó a la regla."
  - "La paridad del audit exige una rama que mire el documento (usuarioId | restauranteId) incluso para super_admin, que las rules eximirían: ninguna pantalla lista sin tenant."
metrics:
  duration: ~2 h
  completed: 2026-08-20
  gates: 9/9 OK
  tests: app_cliente 345→348 · panel_admin 445 (baseline corregido desde 423) · rules 260→282 · functions 149 + 50 e2e
---

# Fase 11 Plan 28: P0 de `pedidos` — query-vs-rules y sentido de los índices

Dos bugs distintos con un mismo síntoma: la pantalla de pedidos del cliente en blanco y
la cola de cocina en «error cargando pedidos». El del cliente era la consulta denegada
por no demostrar la regla; el de cocina, un índice compuesto declarado con el sentido
contrario. Se arreglan los dos, y el audit estático pasa a detectar las dos clases.

## Lo que se reprodujo, y cómo

**Bug 2 (cliente) — reproducido por mí contra el emulador con las rules reales**, antes
de tocar nada, con un barrido de las 22 consultas literales de las dos apps:

```
--- app_cliente ---
   DENEGADA pedidos_provider CLIENTE pedidos sesionId== orderBy(createdAt)
            → permission-denied  Property usuarioId is undefined on object. for 'list' @ L272
   OK       CANDIDATO FIX  pedidos sesionId== usuarioId== orderBy(createdAt)  (1 docs)
```

El mensaje del emulador nombra el campo exacto. Firestore evalúa las rules contra la
CONSULTA: la rama que ampara al cliente es `resource.data.usuarioId == request.auth.uid`
y una query que no restringe `usuarioId` no la puede demostrar, así que se deniega el
listener entero. La caché local pintaba el pedido recién escrito y el rechazo del
servidor la vaciaba: de ahí el «aparece y desaparece».

**Bug 1 (cocina y reportes) — NO reproducible en local; lo aportó el coordinador desde
el proyecto real** `p-gri-b5b40`, como super_admin (rol para el que las rules no
intervienen, porque `isSuper()` se demuestra sin mirar documentos):

| consulta | resultado real |
|---|---|
| `pedidos restauranteId== estado IN[…] orderBy(createdAt ASC)` | `FAILED_PRECONDITION` |
| la misma con `orderBy(createdAt DESC)` | OK |
| `pedidos restauranteId== estado=='servido' createdAt>=…` (sin orderBy) | `FAILED_PRECONDITION` |

Con el índice `pedidos(restauranteId, estado, createdAt DESCENDING)` **declarado y
construido**. En mi barrido contra el emulador esas mismas consultas salieron OK: el
emulador no evalúa índices compuestos, así que ninguna suite local podía verlo. Dos
hechos que quedan establecidos y documentados en el código:

1. Firestore **no** sirve un `orderBy` ASCENDENTE desde un índice compuesto declarado
   DESCENDENTE, aunque todos los campos que preceden sean de igualdad.
2. Un filtro de **rango sin `orderBy`** impone orden ASCENDENTE implícito sobre el campo
   del rango, y el índice tiene que declararlo ASCENDING.

## Auditoría completa: las 22 consultas de las dos apps contra su regla

Barrido ejecutado contra el emulador con las rules reales, un contexto por rol. Las
consultas están tal cual salen del Dart, sin simplificar.

| # | consulta (archivo Dart) | regla que aplica | veredicto |
|---|---|---|---|
| 1 | `pedidos sesionId== orderBy(createdAt)` — app_cliente/pedidos_provider | `usuarioId==uid` \| `staffOf` \| `isSuper` | **DENEGADA (BUG)** → arreglada |
| 2 | `sesiones usuarioId==` — app_cliente/sesion_provider | ídem | OK |
| 3 | `reservas usuarioId== orderBy(fecha desc)` — app_cliente/reservas_provider | ídem | OK |
| 4 | `mesas restauranteId== orderBy(numero)` — app_cliente/reserva_controller | `signedIn()` | OK |
| 5 | `restaurantes activo==` — app_cliente/restaurantes_provider | `true` | OK |
| 6 | `categorias restauranteId== activo==` — app_cliente/restaurantes_provider | `activo==true` | OK |
| 7 | `productos restauranteId== activo== disponible==` — app_cliente/restaurantes_provider | `activo && disponible` | OK |
| 8 | `pedidos restauranteId== estado IN[] orderBy(createdAt)` — panel/cocina | `staffOf(restauranteId)` | OK en rules · **FAILED_PRECONDITION en real (BUG)** |
| 9 | `sesiones restauranteId== cuentaSolicitada== estado==` — panel/cocina | `staffOf` | OK |
| 10 | `pedidos restauranteId==` — panel/clientes | `staffOf` | OK |
| 11 | `pedidos restauranteId== usuarioId==` — panel/clientes | `staffOf` | OK |
| 12 | `pedidos restauranteId== estado IN[]` — panel/stats | `staffOf` | OK |
| 13 | `pedidos restauranteId== estado== createdAt<> createdAt<>` — panel/reportes | `staffOf` | OK en rules · **FAILED_PRECONDITION en real (BUG)** |
| 14 | `reservas restauranteId== fecha<> fecha<>` — panel/stats | `staffOf` | OK |
| 15 | `reservas restauranteId== fecha<> fecha<>` — panel/reservas | `staffOf` | OK |
| 16 | `mesas restauranteId==` — panel/stats | `signedIn()` | OK |
| 17 | `mesas restauranteId== orderBy(numero)` — panel/mesas | `signedIn()` | OK |
| 18 | `usuarios restauranteId==` — panel/equipo | `admin del tenant` | OK |
| 19 | `categorias restauranteId== orderBy(orden)` — panel/menu | `menuStaffOf` | OK (exenta declarada) |
| 20 | `productos restauranteId==` — panel/menu | `menuStaffOf` | OK (exenta declarada) |
| 21 | `restaurantes activo==` — panel/dashboard | `true` | OK |
| 22 | `restaurantes` (sin filtro) — panel/configuracion | `true` | OK |

Fuera de `pedidos` no apareció ningún otro fallo de paridad ni de índice. Las tres
colecciones cuya regla mira el documento y que no estaban en la tabla del audit
(`pedidos`, `sesiones`, `reservas`) ya lo están.

## Qué se cambió

### 1. La consulta del cliente (`app_cliente/lib/features/pedidos/pedidos_provider.dart`)

Se añade `.where('usuarioId', isEqualTo: uid)`, con el uid tomado de **Auth** y no del
doc de sesión: la regla compara contra `request.auth.uid` y la query tiene que llevar
exactamente ese valor.

**No cambia lo que ve el dueño de la sesión** —las rules de `create` ya exigen que el
pedido lo emita el dueño, así que todo pedido de su sesión lleva su uid— y **arregla de
paso una incorrección**: `sesiones/{mesaId}` se REUTILIZA (`abrirSesion()` hace
`tx.set()` sobre el mismo doc id cuando la anterior está cerrada), así que `sesionId` es
compartido por todos los comensales que pasen por esa mesa. Sin el filtro, el segundo
comensal habría visto los pedidos del primero.

### 2. Los índices (`firestore.indexes.json`) — **2 nuevos, hay que desplegarlos**

```
pedidos(restauranteId ASC, estado ASC, createdAt ASCENDING)   ← cocina + reportes
pedidos(sesionId ASC, usuarioId ASC, createdAt ASCENDING)     ← cliente (query nueva)
```

Se declaran los índices que las consultas necesitan, en lugar de invertir las consultas
para aprovechar los que había: cocina es una **cola FIFO** (el pedido más antiguo primero
es la semántica correcta) y el reporte **no lleva `orderBy`** —su orden es implícito—, así
que «arreglarlo» desde el Dart habría sido escribir `descending: true` sin ninguna razón
de dominio, solo para encajar con un índice.

Los dos índices superados se dejan declarados a propósito, con el motivo escrito en el
propio JSON: **borrar una entrada lo borra en producción** en el siguiente despliegue, y
esa poda merece ser una decisión explícita. Quedan listados en el AUDIT 4/4 y en
`deferred-items.md`.

### 3. El audit estático (`scripts/audit_indexes.mjs` + `scripts/inventario_queries.mjs`)

Esta es la parte que impide la cuarta repetición. El parseo de las queries del Dart se
extrae a `inventario_queries.mjs` para que el audit y la herramienta nueva lean **el
mismo inventario**: una consulta nueva en el Dart aparece sola en las dos.

| # | comprobación | qué cambió |
|---|---|---|
| 1/4 | índices compuestos | ahora exige **sentido exacto**. Se retiran las dos concesiones que dejaron pasar el bug: aceptar un índice con todas las direcciones invertidas, y tratar un rango sin `orderBy` como «dirección indiferente». Distingue en el informe «falta el índice» de «está con el sentido equivocado» |
| 2/4 | paridad rules↔query | la tabla admite **alternativas** (`usuarioId` \| `restauranteId`), que es la forma real de las reglas en disyunción. Entran `pedidos`, `sesiones` y `reservas` |
| 3/4 | **cobertura (nueva)** | falla si una consulta apunta a una colección sin clasificar, **o** si `firestore.rules` gobierna una colección que las tablas no conocen. Es el cierre por los dos lados: los tres incidentes empezaron con una colección que nadie confrontó con su regla |
| 4/4 | índices sin uso (informativo) | lista los índices declarados que hoy no sirven a ninguna consulta. No falla |

### 4. `scripts/probar_consultas_reales.mjs` (nuevo) — la verificación contra el proyecto real

Firma un custom token con la cuenta de servicio para el uid y el rol que se le indiquen,
lo canjea por un idToken en Identity Toolkit y lanza las consultas del inventario por
REST contra el proyecto que se le diga, clasificando cada una en OK /
`PERMISSION_DENIED` / `FAILED_PRECONDITION` / SIN VALOR.

Es la única comprobación que distingue «falta un índice» de «las reglas deniegan».
uid, proyecto, rol y rid son parámetros; la cabecera insiste en correrlo **como cliente y
como super_admin**, porque con super la rama `isSuper()` se demuestra sola y todo pasa —
que es justo lo que hizo confuso este diagnóstico. La clave de servicio se pasa **por
ruta** y se le entrega a `firebase-admin`: el script no la lee ni la imprime, ni imprime
los tokens. Sale con 1 ante cualquier `FAILED_PRECONDITION` o estado inesperado; un
`PERMISSION_DENIED` se reporta pero lo juzga la persona, porque depende del rol.

**No entra en `npm run gates`**: toca la red y consume lecturas reales.

### 5. Tests

* **rules 260 → 282.** Bloques «QUERY vs RULES» en `pedidos` (+12), `sesiones` (+5) y
  `reservas` (+5), con las consultas **literales** de las apps. El primero de `pedidos`
  es la reproducción del P0: la query vieja debe quedar DENEGADA. Los tests anteriores
  solo hacían `getDoc`; la autorización de una QUERY es un problema distinto y nadie la
  ejercitaba — esa es la razón por la que el bug llegó a producción.
* **app_cliente 345 → 348.** `test/pedidos/query_sesion_test.dart` monta el provider de
  verdad contra `fake_cloud_firestore`. Los tests que había sobreescribían
  `pedidosSessionProvider` con un `Stream.value([...])`: probaban la pantalla dando la
  lista por buena.

### 6. Documentación

`SMOKE-E2E-v2.md` §4.1 reescrito (mitigación estática vs. verificación real, con las
órdenes exactas y el aviso de lecturas reales); §6 y `ESTADO-DESPLIEGUE.md` corregidos:
decían «los índices están TODOS desplegados», y lo estaban **en número y mal en sentido**.

## Verificación — rompiendo a propósito

Todo lo que sigue se ejecutó; no es una descripción de intención.

| Se rompió | Resultado esperado | Resultado real |
|---|---|---|
| Quitar `where('usuarioId')` del Dart | AUDIT 2/4 en rojo | `FALTA where('usuarioId') ó where('restauranteId')` · exit 1 |
| Dejar solo el índice `createdAt DESC` | AUDIT 1/4 en rojo en cocina **y** en reportes | `ÍNDICE CON EL SENTIDO EQUIVOCADO — la query exige (createdAt ASC); declarado: pedidos: restauranteId ASC, estado ASC, createdAt DESC` (×2) · exit 1 |
| Quitar `mesas` de la tabla de clasificación | AUDIT 3/4 en rojo por los dos lados | `consultada mesas SIN CLASIFICAR` + `en rules mesas SIN CLASIFICAR` · exit 1 |
| Quitar `where('usuarioId')` del Dart | el test de Flutter en rojo | `Expected: no matching candidates / Actual: Found 1 widget with text "Ajiaco del comensal anterior ×1"` |

El test de rules que reproduce el P0 usa `assertFails`, que **solo** acepta
`permission-denied` (no cualquier error), y el mensaje del emulador nombra el campo:
`Property usuarioId is undefined on object. for 'list'`. No está verde por la razón
equivocada.

`probar_consultas_reales.mjs` se validó contra el emulador (`--emulador localhost:8080`):
**las 22 consultas REST se aceptan**, es decir, la herramienta construye consultas bien
formadas. También se comprobó que un fallo de red se reporta como fila y hace salir con 1
en vez de tumbar la pasada.

## Estado real: verificado vs. no verificado

**Verificado por mí, ejecutando:**

- La query vieja del cliente queda denegada, y la nueva permitida, contra el emulador con
  las rules reales.
- El filtro `usuarioId` excluye de verdad los pedidos de otro comensal con el mismo
  `sesionId` (afirmación sobre datos, no sobre permisos).
- El audit detecta las tres clases de fallo (probado rompiendo cada una).
- Los 9 gates en verde, dos pasadas completas, la segunda sobre el árbol ya commiteado.
- Las 22 consultas del inventario son REST válido (aceptadas por el emulador).

**NO verificado — hace falta el proyecto real y el despliegue, que hace el usuario:**

- **Que los dos índices nuevos resuelvan el `FAILED_PRECONDITION`.** Está razonado desde
  la evidencia de campo del coordinador, pero nadie ha ejecutado esas consultas con los
  índices nuevos ya construidos. Es el paso obligatorio tras desplegar.
- **Que la pantalla del cliente y la cola de cocina carguen en producción.** El arreglo
  de rules no necesita despliegue (las rules no cambiaron); el de índices sí.
- La clasificación `PERMISSION_DENIED` / `FAILED_PRECONDITION` de la herramienta nueva:
  se probó el camino OK y el de error de red, no los dos de rechazo del backend. La
  lógica es una lectura directa de `error.status` de la respuesta REST.

## Pasos siguientes para el usuario (NO los hice: no despliego)

1. `firebase deploy --only firestore:indexes` — crea los 2 índices nuevos. **Tardan
   minutos en construirse**; hasta que no estén LISTOS seguirán dando
   `FAILED_PRECONDITION`.
2. Verificar con los dos roles:
   ```bash
   node scripts/probar_consultas_reales.mjs --proyecto p-gri-b5b40 \
     --clave <ruta-clave-adminsdk> --api-key <web-api-key> \
     --uid <uid-cliente-real> --rid demo --mesa GRI-MESA-demo-001
   node scripts/probar_consultas_reales.mjs --proyecto p-gri-b5b40 \
     --clave <ruta> --api-key <key> --uid <uid-super> --rol super_admin \
     --rid demo --mesa GRI-MESA-demo-001
   ```
   Se espera 0 `FAILED_PRECONDITION` en las dos pasadas.
3. Reproducir el flujo a mano: pedir desde la app y ver la cola de cocina.
4. Las **rules no cambiaron**, así que no hay que desplegarlas.

## Deviations from Plan

No había PLAN.md. Frente al diagnóstico parcial de partida:

**1. [Rule 1 — Bug] El bug de cocina no era el que se sospechaba.** El diagnóstico
parcial apuntaba al disyunto `resource == null` o a un desajuste de dirección de índice, y
pedía reproducirlo antes de arreglarlo. Lo reproduje: contra el emulador la consulta de
cocina **pasa** (el `resource == null` no interfiere en la demostrabilidad), y la evidencia
de campo del coordinador confirmó que era el sentido del índice. No se tocó el disyunto
`resource == null`, que sigue siendo necesario para el arreglo de 11-27.

**2. [Rule 2 — Funcionalidad crítica ausente] El audit no comprobaba el sentido del
índice.** Descubierto a partir de la evidencia de campo. Es la corrección de más valor del
plan: los tres fallos de índice tenían índice declarado.

**3. [Rule 2] Cobertura del audit (AUDIT 3/4).** Un audit que solo revisa las colecciones
que alguien se acordó de dar de alta reproduce el fallo que pretende evitar. Ahora falla
si una colección de las rules o de las queries no está clasificada.

**4. [Rule 1 — Bug] El baseline de `panel_admin` estaba desfasado.** `gates.mjs` decía 423
y la suite pasa 445 desde hace planes. El gate no habría detectado la pérdida de 22 tests.
Corregido al valor medido.

**5. [Rule 2] Robustez de la herramienta nueva.** Un fallo de red hacía caer el proceso
entero con una promesa rechazada; ahora se reporta como fila y sale con 1 (un exit 0 tras
un error de red haría creer que la comprobación se hizo).

**6. Petición añadida a mitad de trabajo:** `scripts/probar_consultas_reales.mjs`, con el
inventario compartido, uid/proyecto parametrizables y la clave por ruta. Entregada y
documentada en el runbook. **No la ejecuté contra producción**, como se pidió.

## Known Stubs

Ninguno.

## Threat Flags

Ninguna nueva. No se tocó `firestore.rules`; la consulta se adaptó a la regla. El cambio
del cliente **estrecha** lo que la app pide (de «todos los pedidos de la mesa» a «los
míos en esta mesa»), y el de los índices no tiene efecto sobre autorización.

## Self-Check: PASSED

- `scripts/inventario_queries.mjs` — FOUND
- `scripts/probar_consultas_reales.mjs` — FOUND
- `app_cliente/test/pedidos/query_sesion_test.dart` — FOUND
- commits `22075de`, `328bac1`, `9893966`, `1063ac7`, `5a74aa5` — FOUND
- 9/9 gates OK sobre el árbol commiteado
