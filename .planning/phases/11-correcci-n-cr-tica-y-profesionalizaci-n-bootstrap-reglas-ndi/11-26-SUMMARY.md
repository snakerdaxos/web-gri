---
phase: 11-correcci-n-cr-tica-y-profesionalizaci-n-bootstrap-reglas-ndi
plan: 26
subsystem: ux + documentación (degradación honesta y cierre documental de la fase)
tags: [mensajes-honestos, degradacion, cloud-functions-sin-desplegar, blaze, documentacion, panel_admin, runbooks]

# Dependency graph
requires:
  - plan: 11-23
    provides: "el criterio de redacción de la fase — verdad + causa + siguiente paso — y el precedente de reescribir un caso preexistente que afirmaba el mensaje que se separa"
  - plan: 11-10
    provides: "features/equipo/ (pantalla, controlador, costuras inyectables) y mensajeAltaStaff()"
  - plan: 11-24
    provides: "la baja reversible, mensajeCambioEstadoStaff() y las filas de acción de /equipo"
  - plan: 11-25
    provides: "la suite de a11y del panel y el token textoSecundarioAccesible medido sobre los DOS fondos"
  - plan: 11-15
    provides: "docs/SMOKE-E2E-v2.md y el ejecutor único de gates (npm run gates)"
  - plan: 11-20
    provides: "scripts/gestion_staff.mjs y docs/GESTION-PERSONAL.md — el 'siguiente paso' que el mensaje nombra"
provides:
  - "panel_admin: mensajeGestionPersonalNoDisponible — constante ÚNICA que usan las dos traducciones de error, el aviso de la pantalla y el aviso del diálogo"
  - "panel_admin: _callableNoDesplegada() — separa el not-found de 'función sin desplegar' del not-found de DOMINIO"
  - "panel_admin/test/equipo/equipo_sin_functions_test.dart — 22 casos, incluida la regresión concreta"
  - "docs/ESTADO-DESPLIEGUE.md — inventario de qué está desplegado, qué no, por qué y cómo activarlo"
  - "docs/SMOKE-E2E-v2.md y docs/FIREBASE_SETUP.md corregidos: ningún documento instruye ya un flujo imposible"
  - "MEDICIÓN: 3 de los 4 comandos <verify> de este plan son defectuosos; uno no tiene dientes en absoluto"
  - "MEDICIÓN: en un modal, find.text() sin acotar es TAUTOLÓGICO — el árbol de debajo sigue ahí"
affects: []

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Un mensaje que el usuario puede ver ANTES y DESPUÉS de actuar vive en UNA constante; si se escribe dos veces, diverge"
    - "Cuando un código de error significa dos cosas, se separan por una señal OBSERVABLE (aquí: si el servidor mandó mensaje), no por adivinación"
    - "Un aviso dentro de un modal necesita su propia aserción ACOTADA: el árbol de la pantalla sigue debajo y contesta por él"
    - "«Visible» en un widget test es geometría (rect no vacío, dentro del viewport, en su sitio), no presencia en el árbol"
    - "Un documento que describe un flujo no desplegado se MARCA, no se borra: vuelve a ser válido el día del despliegue"

key-files:
  created:
    - panel_admin/test/equipo/equipo_sin_functions_test.dart
    - docs/ESTADO-DESPLIEGUE.md
  modified:
    - panel_admin/lib/features/equipo/equipo_controller.dart
    - panel_admin/lib/features/equipo/equipo_screen.dart
    - panel_admin/lib/features/equipo/staff_form_dialog.dart
    - panel_admin/test/equipo/equipo_baja_test.dart
    - panel_admin/test/equipo/equipo_provider_test.dart
    - docs/SMOKE-E2E-v2.md
    - docs/FIREBASE_SETUP.md
    - docs/ICONOS-panel_admin.md

key-decisions:
  - "El `not-found` se separa por el MENSAJE DEL SERVIDOR: las dos callables mandan siempre el suyo, así que un not-found sin mensaje es 'función no desplegada'. Se reconoce además el marcador crudo del transporte (NOT FOUND / 404), que el plan no pedía y sin el cual la regla volvería a soltar «El restaurante no existe»"
  - "El texto NO incluye la invocación literal del script: nombra `docs/GESTION-PERSONAL.md`, que tiene los cinco comandos. Un comando embebido en una cadena de UI se desincroniza del CLI y vuelve a mentir — que es el defecto que este plan cierra"
  - "El aviso se REPITE dentro del diálogo de alta (Regla 2): es modal y tapa la pantalla, así que sin eso el operador rellena cuatro campos y solo se entera al enviar"
  - "El texto del aviso usa `textoSecundarioAccesible`, no `advertencia`: el ámbar del patrón vigente da 3.5:1 sobre el fondo de página y este aviso es PERMANENTE. El icono sí conserva el ámbar"
  - "SMOKE-E2E-v2 NO se reescribe: es un runbook contra emuladores, donde las callables funcionan porque el emulador de Functions no necesita Blaze. Se marca qué NO se puede ejecutar contra el proyecto real"
  - "Las tres callables y sus ~200 pruebas se conservan íntegras y con su camino de activación escrito"

metrics:
  duration: "~35min"
  tasks: 3 (+1 adición por Regla 2)
  files: 10
  completed: 2026-08-20
---

# Phase 11 Plan 26: Degradación honesta de /equipo y cierre documental — Summary

`/equipo` deja de decir «El restaurante no existe» por una función que nunca se desplegó:
explica la situación real antes de pulsar y remite al script, y la documentación pasa a
describir el sistema que existe.

## Qué se construyó

**El bug concreto.** `equipo_controller.dart` traducía `not-found` como *«El restaurante no
existe.»* — heredado del caso en que el `rid` destino faltaba. Aplicado a `crearUsuarioStaff`,
que **no está desplegada** porque el usuario decidió no activar Blaze, ese texto es falso y
manda al operador a investigar el restaurante equivocado. Lo mismo en la baja, donde decía
*«Ese usuario ya no existe.»*.

Es el mismo defecto que el plan 11-23 cerró en el escaneo, donde un `permission-denied`
presentado como «revisa el código de la mesa» costó al usuario una sesión de depuración sobre
un QR que era correcto.

### El texto (constante `mensajeGestionPersonalNoDisponible`)

> «El alta y la baja de personal todavía no se hacen desde el panel: las funciones que las
> ejecutan no están desplegadas en este proyecto. Mientras tanto se hacen por script, desde el
> equipo del propietario — ver docs/GESTION-PERSONAL.md.»

Cumple el criterio de 11-23 y se verifica cada propiedad, no se afirma:

| Propiedad | Cómo se comprueba |
|---|---|
| **Verdad** | No dice «no existe», ni «no tienes permiso», ni «error», ni «falló» — casos 4 del grupo 2 |
| **Causa** | Contiene «desplegad…» |
| **Siguiente paso** | Contiene «script» y `GESTION-PERSONAL.md` |
| **No manda a un bucle** | No contiene «intenta de nuevo», «inténtalo», «vuelve a intentar» ni «reintenta» |

**Una sola constante para los tres sitios**: el aviso de la pantalla, el aviso del diálogo y el
mensaje del error. Escribirlo tres veces es garantizarse que un día digan cosas distintas.

### Cómo se separan los dos `not-found`

`_callableNoDesplegada(code, mensajeServidor)`:

- `unavailable` / `internal` → indisponibilidad.
- `not-found` **sin** mensaje del servidor → indisponibilidad. Las dos callables lanzan su
  `not-found` SIEMPRE con texto (`crear-usuario-staff.js:152`, `cambiar-estado-staff.js:118`),
  así que la ausencia de mensaje es la señal.
- `not-found` con el **marcador crudo del transporte** (`NOT FOUND`, `not_found`, `404`,
  normalizado) → indisponibilidad. **Esto el plan no lo pedía**; sin ello, si la plataforma
  rellenara `message` con el marcador en vez de dejarlo vacío, la regla volvería a soltar
  «El restaurante no existe» y el gate seguiría verde por el motivo equivocado.
- Cualquier otro `not-found` → traducción de dominio, INTACTA.

### Lo que NO cambió

`permission-denied`, `invalid-argument`, `already-exists`, `unauthenticated` y
`failed-precondition` conservan su traducción **exacta** en los dos mensajes, y hay un grupo de
casos que lo afirma literal. Son las que verá el operador el día del despliegue.

Los botones **siguen presentes y pulsables** —hay dos casos que lo afirman— para que ese día no
haya que tocar nada. El listado sigue mostrando nombre, correo, rol y estado: es una lectura de
Firestore, habilitada al desplegar las reglas el 2026-08-20.

## Tareas y commits

| # | Tarea | Commits |
|---|---|---|
| 1 | Degradación honesta de las acciones de /equipo | `b8eac8c` (RED), `68ac12e` (GREEN), `7ba13d4` (aviso por geometría) |
| — | [Regla 2] El diálogo de alta repite el aviso | `f887290`, `1920004` (verde cazado) |
| 2 | `docs/ESTADO-DESPLIEGUE.md` | `e5fdef0` |
| 3 | Corregir los runbooks | `1646cf5` |
| — | Deferred item registrado | `dd03ad1` |

## Gates ejecutados (salida REAL)

```
 GATE                                   RES.   TESTS     DETALLE
 app_cliente: flutter test              OK     345       345 = baseline
 app_cliente: flutter analyze           OK     0 issues  0 issues
 panel_admin: flutter test              OK     445       445 (baseline 423, +22)
 panel_admin: flutter analyze           OK     0 issues  0 issues
 functions: npm test (unitarios)        OK     149       149 = baseline
 scripts: npm run test:rules            FALLO  221       2 test(s) en rojo (ver abajo — NO es una regresión)
 scripts: npm run test:functions (e2e)  OK     50        50 = baseline
 scripts: npm run audit:indexes         OK     —         exit 0
 scripts: npm run audit:branding        OK     —         exit 0
```

**Base de tests panel_admin: 423 → 445 (+22).** Los 22 son
`equipo_sin_functions_test.dart` entero; ningún test preexistente se borró (tres se
reescribieron, ver Desviaciones).

### Los dos gates en rojo, medidos por separado

Ambos fallos son del **árbol compartido**, no del trabajo de este plan. El ejecutor de 11-20
corría en paralelo con sus emuladores levantados.

> **Pasada final, con 11-20 ya terminado y los puertos libres: 9 gates · 8 OK · 1 fallo.**
> El único rojo es `test:rules`, con **221 pasadas = baseline** y 2 rojos de un archivo ajeno
> sin commitear. Los conflictos de puerto de las dos pasadas anteriores desaparecieron.

**`test:functions` — era SOLO conflicto de puertos.** Ejecutado a solas con los puertos libres:

```
ℹ tests 50
ℹ pass 50
ℹ fail 0
+  Script exited successfully (code 0)
```

Antes de eso, el gate moría con `Error: Could not start Authentication Emulator, port taken`.
Comprobado con `netstat`: `127.0.0.1:8080` y `127.0.0.1:9099` LISTENING con PIDs ajenos.

**`test:rules` — 221 de 221 comprometidos en verde; los 2 rojos son de un archivo AJENO y SIN
COMMITEAR.** Ejecutado a solas:

```
ℹ tests 223
ℹ pass 221
ℹ fail 2

✖ failing tests:
test at scripts\test\rules\_diag_sesion.test.mjs:11:3
✖ sesiones/{mesaId} inexistente: el cliente lo lee?
test at scripts\test\rules\_diag_sesion.test.mjs:15:3
✖ reservas/{slot} inexistente: el cliente lo lee?
```

`scripts/test/rules/_diag_sesion.test.mjs` aparece como `??` en `git status`: **no existía al
empezar esta sesión** (el `git status` inicial no lo listaba) y apareció mientras 11-20
trabajaba. Es un archivo de diagnóstico suyo. **No se toca**: borrarlo o commitearlo sería
llevarse trabajo ajeno, que es exactamente el incidente que documentó 11-23. El baseline de la
suite de rules es 221 y el conteo de pasadas es 221: **no hay regresión**.

> ⚠️ **11-20 ya cerró (`dcb08ed`) y el archivo SIGUE sin commitear.** Ya no es «trabajo en
> vuelo»: es un residuo que deja la fase con un gate en rojo. **Hay que decidirlo antes de
> cerrar la fase**: arreglarlo y commitearlo, o borrarlo. Los dos casos afirman
> `assertSucceeds` sobre la lectura de un `sesiones/{id}` y un `reservas/{slot}` que **no
> existen**, y las rules responden `permission-denied` con `Null value error` al hacer `get`
> de un documento ausente — o sea, o la expectativa del diagnóstico está invertida, o hay algo
> real que mirar en `firestore.rules` L208 y L275. No es de este plan, pero no puede quedar
> como «ruido conocido».

### Gates de la Tarea 1 (los del `<verify>` del plan)

| Comando | Resultado |
|---|---|
| `flutter analyze` (panel_admin) | `No issues found!` |
| `flutter test test/equipo/` | `+83: All tests passed!` |
| `flutter test test/equipo/equipo_sin_functions_test.dart` | `+22: All tests passed!` |
| `flutter test` (panel_admin) | `+445: All tests passed!` |

## Roturas deliberadas: 14, y 1 VERDE cazada

Ningún gate se da por bueno sin romper lo que protege. Cada mutación se revirtió acto seguido.

| # | Mutación | Resultado |
|---|---|---|
| A | Quitar el guard de indisponibilidad del ALTA | 🔴 5 rojos |
| B | Quitar el guard de la BAJA | 🔴 5 rojos |
| C | Sacar `unavailable`/`internal` del grupo | 🔴 4 rojos |
| D | Quitar el reconocimiento del marcador de transporte | 🔴 1 rojo |
| E | Quitar el aviso permanente de la pantalla | 🔴 |
| F | El aviso de la pantalla dice OTRO texto (divergencia) | 🔴 |
| G | Deshabilitar el botón «Nuevo usuario» | 🔴 16 rojos |
| H | Deshabilitar la acción de la fila | 🔴 11 rojos |
| I | Romper el listado del equipo | 🔴 17 rojos |
| J | Envolver el aviso en `Offstage` | 🔴 |
| K | Aviso con `height: 0` | 🔴 |
| M | El diálogo pierde el aviso | 🔴 |
| N | El aviso del diálogo dice OTRO texto | 🟢 **VERDE** → cerrado → 🔴 |
| O | Deshabilitar el botón de envío del diálogo | 🔴 |

### VERDE — la aserción del aviso del diálogo era tautológica

La primera versión del caso afirmaba `expect(find.text(mensaje…), findsWidgets)` a secas.
**En un modal eso es tautológico**: el diálogo se monta ENCIMA de `EquipoScreen`, cuyo aviso
sigue en el árbol de widgets con el mismo texto. Verificado en vivo: **cambiando el texto del
diálogo a «No disponible por ahora.» la suite seguía verde**.

Cerrado acotando con `find.descendant(of: aviso, matching: find.text(...))`. Repetida la misma
mutación: roja. Commit `1920004`.

### Endurecimiento del aviso de la pantalla (antes de que hiciera falta)

`find.byKey` + `find.text` habrían pasado con el aviso dentro de un `Offstage` o con altura
cero — presente en el árbol, invisible para una persona, y por tanto sin cumplir su única
función. El caso afirma ahora la **geometría**: rect no vacío, dentro del viewport, y **entre**
el botón de alta y la tabla. Mutaciones J y K confirman que ahora sí pone rojo. Commit
`7ba13d4`.

## HALLAZGO: 3 de los 4 `<verify>` del plan son defectuosos, y uno no tiene dientes

Se probaron los cuatro en vivo antes de fiarse de ellos. Se ejecutaron todos igualmente y
todos salieron en verde; lo que sigue es qué NO cubren.

### Tarea 2, verify 1 — falso positivo demostrado

```
grep -q "25efd44a" … && grep -q "Blaze" … && grep -q "GESTION-PERSONAL" … && test $(wc -l < …) -ge 70
```

Probado con un archivo de **una línea con esas tres palabras seguida de 75 líneas en blanco**:
`ESTADO_OK`. El gate no comprueba ni una de las siete secciones que el plan exige. **Sustituido
por una comprobación real** de las 7 cabeceras — ejecutada, las 7 presentes.

### Tarea 2, verify 2 — tiene dientes para UNA forma, ciego para el resto

```
test $(grep -c "BOOTSTRAP_SECRET=" docs/ESTADO-DESPLIEGUE.md) -eq 0
```

| Prueba | Gate | Debería |
|---|---|---|
| `BOOTSTRAP_SECRET=valor` añadido | FALLA | FALLAR ✓ |
| `BOOTSTRAP_SECRET: valor` añadido | **PASA** | FALLAR ✗ punto ciego |

**Comprobación que sí cierra el hueco, ejecutada:** se leyó el valor real de `functions/.env`
(sin imprimirlo) y se buscó literalmente en el documento. `OK: el valor real del secreto NO
aparece en el doc`. Lo mismo con `BOOTSTRAP_EMAIL`: tampoco aparece.

### Tarea 3, verify 1 — sin dientes en su primera mitad

```
grep -qi "no est\|sin desplegar\|GESTION-PERSONAL" docs/SMOKE-E2E-v2.md && grep -q "ESTADO-DESPLIEGUE" docs/FIREBASE_SETUP.md
```

`"no est"` casa con cualquier «no está» del documento. **Medido: el `SMOKE-E2E-v2.md`
ORIGINAL, antes de tocar nada, ya tenía 5 coincidencias.** Esa mitad del gate estaba
condenada a pasar. La única condición con dientes era la segunda (`ESTADO-DESPLIEGUE` en
`FIREBASE_SETUP.md`), que sin este plan no existía.

**Sustituido por una comprobación real**, ejecutada: para cada uno de los pasos [A], [C], [D],
[E] se lee el bloque siguiente a su cabecera y se exige (a) un aviso de no-ejecutable y (b) una
remisión a `gestion_staff.mjs`; y se exige que **ninguno** de los pasos [B], [F]–[O] lo tenga,
para que un marcado a lo bruto tampoco pase.

```
[A] aviso_en_sitio=True  remite_al_script=True
[C] aviso_en_sitio=True  remite_al_script=True
[D] aviso_en_sitio=True  remite_al_script=True
[E] aviso_en_sitio=True  remite_al_script=True
TODOS_LOS_PASOS_MARCADOS
```

### Tarea 3, verify 2 — correcto, y además mordió

`test $(grep -c "checkpoint del plan 11-20" docs/SMOKE-E2E-v2.md) -eq 0` → `SIN_REFERENCIA_OBSOLETA`.
Mordió durante la ejecución: la nota histórica que se escribió en §4.2 contenía la frase
literal y hubo que reformularla. Es el primer `<verify>` de grep de la fase que sirve para
algo tal cual.

**Los `<verify>` de la Tarea 1 son correctos**: `flutter analyze` y `flutter test` sobre el
árbol real no tienen puntos ciegos de este tipo.

## Documentación: cuántos puntos se tocaron

### `docs/SMOKE-E2E-v2.md` — **13 puntos**, sin reescribirlo

1. **Cabecera nueva**: tabla emulador ↔ proyecto real, con los cuatro pasos no ejecutables y su
   equivalente por script.
2. §0.2, fila de `functions/.env` (decía «en el despliegue del plan 11-20»).
3-6. Nota en el sitio de **[A]**, **[C]**, **[D]** y **[E]**, para quien salte directo al paso.
7. **[I]**: el checkpoint es el de 11-17, no el de 11-20.
8. **§4.2**: título y explicación; se deja constancia de por qué cambió la referencia.
9. **§6, primer punto**: decía *«Las rules desplegadas son las de la Fase 10»* y que sin ellas
   `/equipo` respondía `permission-denied`. **Es falso desde el 2026-08-20**: están desplegadas
   (ruleset `25efd44a…`) y `/equipo` lista.
10. **§6, segundo punto**: decía *«Blaze está aprobado por el usuario pero puede no estar
    activado»*. Ahora dice que **no se va a activar** y que no es un despliegue pendiente.
11. **§6, cierre**: 11-16 ya está hecho; el despliegue de funciones no se hará.
12. **§8**: nota de que la checklist es la del recorrido contra emuladores.
13. **§8**, ítem [I]: checkpoint 11-17.

Lo que **NO** se hizo: recortar pasos. El runbook sigue siendo válido tal cual contra
emuladores, porque el emulador de Functions no necesita Blaze.

### `docs/FIREBASE_SETUP.md` — **4 puntos**

1. **§0** «¿Plataforma nueva?»: `/bootstrap` **existe pero no está desplegado**; la vía real hoy
   es `gestion_staff.mjs promover-super`. La descripción del flujo con funciones se conserva y
   se marca como válida contra emuladores.
2. **§4.1**: aviso de cabecera equivalente, sin borrar el procedimiento (que vuelve a aplicarse
   el día del despliegue).
3. **§5**: decía «los 9 índices compuestos»; **son 10** (contado en `firestore.indexes.json`).
   Y se añade que rules e índices ya están desplegados.
4. **§9 troubleshooting**: la fila de `/bootstrap → failed-precondition` se acota a emuladores.

### `docs/ESTADO-DESPLIEGUE.md` — nuevo, 177 líneas

Las siete secciones que el plan pedía. La única que se aparta del guion es la 5: ver la
desviación 4.

## Deviations from Plan

**1. [Regla 1 — realidad contradice el plan] Tres casos preexistentes afirmaban el
comportamiento que este plan separa**

- **Encontrado en:** Tarea 1, al correr la suite completa tras el GREEN.
- **Los casos:**
  - `equipo_baja_test.dart` — `expect(mensajeCambioEstadoStaff('not-found'), 'Ese usuario ya no
    existe.')`, llamado **sin mensaje del servidor**, que es justo el caso «función no
    desplegada». Reescrito para pasar el mensaje que la callable manda de verdad.
  - `equipo_baja_test.dart` y `equipo_provider_test.dart` — «un código desconocido cae al
    genérico», ejemplificado con **`internal`**, que este plan mueve al grupo de
    indisponibilidad. La INTENCIÓN del caso (código que nadie maneja → genérico, sin filtrar el
    texto crudo) se conserva íntegra usando `aborted`, que ninguna callable emite.
- **Decisión:** reescritos conscientemente, con comentario que explica qué cambió y dónde vive
  ahora el caso separado. No se relajó ninguna aserción: `equipo_sin_functions_test.dart` añade
  que `internal` **tampoco** filtra el texto crudo del servidor.
- **Commit:** `68ac12e`.

**2. [Regla 3 — bloqueante] `docs/ICONOS-panel_admin.md` apuntaba a una línea desplazada**

- **Encontrado en:** Tarea 1. `test/core/sin_emojis_test.dart` comprueba que los `archivo:línea`
  de esa tabla apuntan a donde dicen. Insertar el aviso movió `GriIcons.equipo` de la 138 a la
  185 y el gate se puso rojo.
- **Fix:** actualizada la referencia. **Commit:** `68ac12e`.

**3. [Regla 2] El diálogo de alta no repetía el aviso**

- **Encontrado en:** revisando qué ve realmente el operador en el flujo degradado.
- **Issue:** el plan pide el aviso «junto a las acciones de escritura» y se puso en la pantalla.
  Pero «Nuevo usuario» abre un **diálogo modal que la tapa**: quien lo abre rellena cuatro
  campos sin volver a ver el aviso y solo se entera al pulsar «Crear usuario» — que es el
  «error después de pulsar» que este plan vino a evitar.
- **Fix:** el aviso se repite dentro, con la MISMA constante y el mismo patrón visual. El botón
  de envío sigue habilitado.
- **Commit:** `f887290`.

**4. [Hallazgo — el plan afirma algo que no es del todo cierto] «los botones empiezan a
funcionar solos, sin tocar código»**

- **Qué dice el plan:** en la Tarea 2, §5, que al desplegar «los botones de `/equipo` empiezan a
  funcionar solos, sin tocar código».
- **Es cierto para `not-found`** y solo para él: una callable desplegada manda siempre su
  mensaje, así que la rama se apaga sola.
- **NO es cierto para `unavailable` e `internal`**, que el mismo plan manda meter en el grupo de
  indisponibilidad. Con las funciones desplegadas, esos dos códigos pasan a significar «la
  función existe y se cayó», y el mensaje —que afirma que no están desplegadas— sería falso.
- **Decisión:** se sigue el plan (se agrupan), porque hoy el mensaje es cierto y el genérico
  anterior mandaba a reintentar algo que no puede funcionar. Pero la imprecisión se registra en
  **dos sitios**: un aviso `⚠️ EL DÍA DEL DESPLIEGUE` en `_callableNoDesplegada()` y un punto
  explícito en `ESTADO-DESPLIEGUE.md` §5 («Una cosa SÍ hay que tocar, y son dos líneas»). No se
  reescribió la aserción para que encajara: se documentó la discrepancia.

**5. [Regla 2] Reconocimiento del marcador crudo del transporte**

- El plan manda distinguir «por el mensaje que acompaña al error del servidor cuando exista» y
  tratar el `not-found` **sin** mensaje como no desplegado. `FirebaseFunctionsException.message`
  es `required String` en el plugin: **no existe un mensaje nulo a nivel de tipos**. Si la
  plataforma lo rellenara con `NOT FOUND` en vez de dejarlo vacío, la regla literal del plan
  volvería a soltar «El restaurante no existe» y el gate seguiría verde.
- **Fix:** se normaliza el mensaje y se reconocen `notfound` y `404` como marcadores. Con caso
  dedicado y mutación D que lo confirma.

**6. [Regla 1 — dato falso en documentación] `FIREBASE_SETUP.md` decía 9 índices**

- Son **10**, contados en `firestore.indexes.json`. Corregido con la nota de qué decía antes.

**7. [Decisión de redacción, apartándose de la sugerencia del plan] El mensaje NO lleva el
comando literal**

- El plan sugiere el texto «…se hace por script desde el equipo del propietario:
  `npm run staff -- crear …`». Se decidió **no** embeber el comando y nombrar
  `docs/GESTION-PERSONAL.md`, que tiene los cinco comandos con sus banderas.
- **Motivo:** cuando se redactó el mensaje, 11-20 aún no había commiteado su script y el nombre
  del comando era una suposición. Escribir en una cadena de UI un comando que no se ha
  verificado es exactamente el defecto que este plan cierra. (11-20 aterrizó después y
  `npm run staff` **sí** existe; el mensaje sigue sin él a propósito: una cadena de UI se
  desincroniza de un CLI, un enlace a su manual no.)

## Threat model — estado de las cuatro mitigaciones

| ID | Estado |
|---|---|
| T-11-26-01 (mensaje engañoso al pulsar) | **Mitigado y verificado.** Traducción específica + aviso permanente en pantalla Y en el diálogo. El caso que afirma que el texto NO dice «El restaurante no existe» existe, y las mutaciones A y B lo ponen rojo |
| T-11-26-02 (documentación de un sistema inexistente) | **Mitigado.** `ESTADO-DESPLIEGUE.md` + 13 puntos en `SMOKE-E2E-v2.md` + 4 en `FIREBASE_SETUP.md`. Comprobado por script que los 4 pasos afectados —y solo esos 4— llevan su aviso |
| T-11-26-03 (`BOOTSTRAP_SECRET` en la documentación) | **Mitigado y verificado más allá del gate.** El gate del plan es ciego a la forma `BOOTSTRAP_SECRET: valor`; se comprobó además el valor REAL de `functions/.env` contra el documento — no aparece. El correo tampoco |
| T-11-26-04 (borrar el código no desplegado) | **Mitigado.** No se borró nada: `git show --name-only` de los 8 commits no lista ni un archivo de `functions/`. `ESTADO-DESPLIEGUE.md` §3 inventaría lo conservado con sus cifras |

## Verificado vs afirmado — leerlo antes de dar esto por cerrado

**Verificado por ejecución:**

- Que el `not-found` sin mensaje del servidor produce el texto de indisponibilidad y **no**
  «El restaurante no existe» / «Ese usuario ya no existe», tanto en el alta como en la baja.
- Que el mensaje que sale por el SnackBar al pulsar «Desactivar» lo produce el **controlador
  real**: se inyecta la CALLABLE, no la acción, así que la traducción que este plan arregla
  está en el camino ejercitado.
- Que los cuatro códigos que ya eran correctos devuelven **exactamente** la misma cadena de
  antes.
- Que el aviso está en pantalla, ocupa espacio, cabe en el viewport y está entre el botón de
  alta y la tabla.
- Que el listado sigue mostrando nombre, correo, rol y estado, y que los dos botones siguen
  habilitados.
- Que 445/445 de panel_admin, 345/345 de app_cliente, 149/149 de functions, 221/221 de rules y
  50/50 de e2e pasan.

**Afirmado, NO verificado (requiere una persona o un despliegue):**

- **Que el texto SE LEA bien y de verdad ayude.** Un widget test prueba que una cadena se
  renderiza; no prueba que el propietario, al verla, entienda que tiene que abrir una terminal.
  El texto está entero arriba para poder revisarlo de un vistazo.
- **Que un proyecto sin la función devuelva `not-found` con el mensaje vacío.** Aquí se
  **inyecta** la excepción. La única forma de observarlo es pulsar el botón contra
  `p-gri-b5b40`, que es justo lo que este plan hace innecesario. Por eso se añadió el
  reconocimiento del marcador crudo: cubre la variante plausible sin haberla podido medir.
- **Que `unavailable`/`internal` sean hoy siempre «no desplegada».** Es lo más probable con las
  funciones ausentes, pero un corte de red produciría el mismo código y el mismo mensaje. El
  mensaje sigue siendo accionable (el script funciona sin red hacia Functions), pero la causa
  que afirma sería inexacta en ese caso.
- **El recorrido del SMOKE-E2E-v2 corregido.** Se verificó que los avisos están donde deben y
  que ningún paso sano quedó marcado, pero **nadie ha recorrido el runbook** con esta versión.

## Known Stubs

Ninguno. No se dejó ningún valor vacío, texto de relleno ni componente sin cablear. Los
botones que no funcionan **no son un stub**: son código completo y probado esperando un
despliegue, con su indisponibilidad explicada en pantalla y su alternativa operativa.

## Threat Flags

Ninguno. Este plan no añade endpoints, ni rutas de autenticación, ni accesos a ficheros, ni
cambios de esquema. Toca dos traducciones de error, dos widgets de aviso y tres documentos.

## Notas para quien siga

- **El día que se despliegue:** `ESTADO-DESPLIEGUE.md` §5 tiene la lista, y el único cambio de
  código son dos líneas en `_callableNoDesplegada()` (sacar `unavailable` e `internal`).
- **`scripts/test/rules/_diag_sesion.test.mjs` sigue sin commitear** y pone 2 tests en rojo en
  la suite de rules. Es de 11-20 y estaba en vuelo; 11-26 no lo tocó. Si al cerrar la fase
  sigue ahí, hay que decidir: commitearlo arreglado o borrarlo.
- **Deuda registrada en `deferred-items.md`:** la cabecera de `FIREBASE_SETUP.md` nombra
  `documentos/google-services.json` como fuente de configuración de Android, y las apps usan
  `firebase_options.dart`. Misma clase de defecto que originó la fase, fuera del alcance de
  este plan.
- **AJENO, sigue sin commitear** (ya declarado por 11-13, 11-19, 11-14 y 11-23):
  `app_cliente/lib/features/restaurantes/restaurantes_provider.g.dart`,
  `android/app/src/main/AndroidManifest.xml` + `android/.../res/xml/`,
  `documentos/google-services.json`, `documentos/sdk.png` y `run_app.bat`. 11-26 no los estageó.
- **Ni un `git add .` en todo el plan.** Los 8 commits se hicieron con
  `git commit -- <rutas>` explícitas y `git diff --cached --name-only` antes de cada uno, que
  es la lección del incidente de 11-23. Verificado archivo a archivo: ninguno lleva nada de
  11-20.
- **Dos veces se perdió trabajo sin commitear** por hacer `git checkout -- <archivo>` para
  revertir una mutación cuando el archivo aún NO estaba commiteado. Se recuperó reescribiéndolo.
  La regla que faltaba: **commitear el GREEN antes de empezar a mutar**, para que el checkout
  restaure a lo correcto y no a lo anterior.

## Self-Check: PASSED

- **2 archivos creados + el SUMMARY**: los 3 existen en disco.
- **8 archivos modificados**: los 8 existen en disco.
- **8 commits**: los 8 están en `git log`.
- **Aislamiento del árbol compartido**: `git show --name-only` de los 8 commits →
  **0 archivos de `functions/` o `scripts/`** en ninguno. Nada de 11-20 se coló.
