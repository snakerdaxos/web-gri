---
phase: 11-correcci-n-cr-tica-y-profesionalizaci-n-bootstrap-reglas-ndi
plan: 15
subsystem: verificacion
tags: [runbook, e2e, gates, bootstrap, qr, emuladores]
requires:
  - "11-07 bootstrapPlataforma + pantalla /bootstrap"
  - "11-08 crearUsuarioStaff + 11-24 cambiarEstadoStaff"
  - "11-05 alta de restaurante con slug canonico"
  - "11-03 query vs rules + audit_indexes"
  - "11-10 /equipo y la regla acotada de usuarios"
  - "11-17 ingreso con Google (checkpoint abierto)"
  - "11-22 politica de contrasenas"
  - "11-23 mensajes honestos del flujo de mesa"
provides:
  - "docs/SMOKE-E2E-v2.md — runbook E2E desde base VACIA, 15 pasos [A]..[O]"
  - "npm run gates — ejecutor unico de los 9 gates automatizados de la fase"
  - "scripts/verificar_email_emulador.mjs — hace ejecutable el paso [A]"
affects:
  - "11-16 (deploy de rules+indices) y 11-20 (deploy de functions + Google) parten de este runbook"
tech-stack:
  added: []
  patterns:
    - "Gate de baseline: un numero de tests que BAJA falla aunque el runner devuelva 0"
    - "Todo helper que hable con emuladores fija host y projectId en el codigo, no por parametro"
key-files:
  created:
    - scripts/gates.mjs
    - scripts/verificar_email_emulador.mjs
    - docs/SMOKE-E2E-v2.md
  modified:
    - scripts/package.json
    - docs/SMOKE-E2E.md
    - docs/FIREBASE_SETUP.md
decisions:
  - "Nueve gates, no ocho: los 149 unitarios de functions/ NO corrian dentro de scripts test:functions"
  - "El runbook usa functions/.env.demo-gri (versionado), no functions/.env — el valor real del secreto no se escribe en ningun sitio"
  - "El paso [A] crea la cuenta ANTES de abrir /bootstrap, porque una denegacion BORRA la cuenta"
metrics:
  duration: "~50 min"
  completed: "2026-08-20"
  tareas: 2
  roturas_deliberadas: 16
requirements: [E2E-01]
---

# Phase 11 Plan 15: Runbook E2E desde base vacía y gate único — Summary

Un solo comando (`npm run gates`) da el estado de los **9** gates automatizados de la fase y falla
cuando el número de tests baja aunque el runner devuelva 0; y `docs/SMOKE-E2E-v2.md` lleva de una base
de datos sin un solo documento hasta un comensal calificando su pedido, en 15 pasos con verificación
en los datos, diciendo abiertamente qué NO puede demostrar.

## Qué se construyó

### Tarea 1 — `scripts/gates.mjs` + `npm run gates` (commit `4286d3f`)

Ejecuta secuencialmente los gates, **continúa aunque uno falle** (panorama completo en una corrida) y
sale con 1 si alguno falla. Analizadores por tipo:

| Tipo | Cómo decide |
|---|---|
| `flutter test` | mayor `+N` de la salida; falla si `< baseline` **aunque el exit sea 0** |
| `flutter analyze` | exige literalmente `No issues found` |
| `node --test` | lee `pass N` / `fail N` (acepta reporter `spec` y `tap`); falla si `fail > 0` o `pass < baseline` |
| auditorías | código de salida |

`flutter` se resuelve recorriendo el `PATH` (en Windows `flutter.bat`, lanzado vía `cmd /c` — mismo
criterio que `run_emulators.mjs`, porque spawn de un `.bat` exige shell desde Node 18.20).

Baselines declarados en una constante con comentario: **345 / 423 / 149 / 221 / 50**. Bajarlos exige
editarlos ahí, en el mismo commit, para que quede el rastro de la decisión.

### Tarea 2 — `docs/SMOKE-E2E-v2.md` (commit `b68afff`)

677 líneas, 29 encabezados, 15 pasos etiquetados `[A]`…`[O]` (mismo formato que el runbook de la Fase
10 para que quien ya lo ejecutó reconozca la estructura). Cada paso: **qué se hace** (ruta o pantalla
exacta) · **qué debe pasar** · **cómo verificarlo en los datos** (documento y campo concretos) · **si
falla**. Los 11 pasos del alcance más contraseñas `[C]`, baja/readmisión `[E]` y Google `[I]`.

Los nombres de campo y de doc ID están **leídos del código**, no supuestos: `mesas/GRI-MESA-{rid}-{NNN}`,
`sesiones/{mesaId}.cuentaSolicitada`, `calificaciones/{pedidoId}` (el doc ID **es** el id del pedido, y
eso es lo que impide calificar dos veces), `reservas/{mesaId}{YYYYMMDD}_{HH}`, `pedidos/{id}.total`
entero en COP.

También: `docs/SMOKE-E2E.md` marcado como **SUPERADO** con enlace al v2 (se conserva como histórico) y
`docs/FIREBASE_SETUP.md` con una §0 nueva que hace de `/bootstrap` el camino de arranque y describe
`seed_firebase.mjs` como utilidad de datos de demostración.

## Verificación — resultados REALES

`cd scripts && npm run gates`, dos veces (tras la Tarea 1 y al cerrar el plan), **idéntico**:

```
 GATE                                   RES.   TESTS     DETALLE
 app_cliente: flutter test              OK     345       345 = baseline
 app_cliente: flutter analyze           OK     0 issues  0 issues
 panel_admin: flutter test              OK     423       423 = baseline
 panel_admin: flutter analyze           OK     0 issues  0 issues
 functions: npm test (unitarios)        OK     149       149 = baseline
 scripts: npm run test:rules            OK     221       221 = baseline
 scripts: npm run test:functions (e2e)  OK     50        50 = baseline
 scripts: npm run audit:indexes         OK     —         exit 0
 scripts: npm run audit:branding        OK     —         exit 0

 9 gates · 9 OK · 0 fallo(s) · 1.4 min       EXIT=0
```

Cero regresión: los cinco conteos igualan el baseline medido al cerrar 11-22.

`npm run verify:shell` **NO se ejecutó**: exige `flutter build web --release` previo en las dos apps y
no forma parte de la pasada rápida. Está declarado como tal en la cabecera de `gates.mjs` y en §7 del
runbook.

## La pregunta crítica: ¿falla `npm run gates` cuando falla cada sub-gate?

16 roturas deliberadas, todas aplicadas sobre código **ya commiteado** y revertidas. Cada gate se
rompió por sus **dos** vías posibles cuando las tiene: el runner en rojo, y —la que importa— el
conteo que **baja en silencio** con el runner en verde.

| # | Rotura | Resultado observado | Exit |
|---|---|---|---|
| A | test en rojo en `app_cliente` | `FALLO 345 · exit 1` | 1 |
| B | `password_policy_test.dart` retirado | `FALLO 288 · REGRESIÓN: 288 < 345` | 1 |
| C | test en rojo en `panel_admin` | `FALLO 423 · exit 1` | 1 |
| D | `a11y_test.dart` retirado | `FALLO 382 · REGRESIÓN: 382 < 423` | 1 |
| E | import sin usar en `app_cliente/lib` | `FALLO 1 issues — se exigen 0` | 1 |
| F | dos imports sin usar en `panel_admin/lib` | `FALLO 2 issues — se exigen 0` | 1 |
| G | test en rojo en `functions/test` | `FALLO 149 · 1 test(s) en rojo` | 1 |
| H | `baja-matrix.test.js` retirado | `FALLO 100 · REGRESIÓN: 100 < 149` | 1 |
| I | test en rojo en `scripts/test/rules` | `FALLO 221 · 1 test(s) en rojo` | 1 |
| J | `mesas.test.mjs` retirado | `FALLO 195 · REGRESIÓN: 195 < 221` | 1 |
| K | test en rojo en `scripts/test/functions` | `FALLO 50 · 1 test(s) en rojo` | 1 |
| L | `bootstrap.e2e.mjs` retirado | `FALLO 39 · REGRESIÓN: 39 < 50` | 1 |
| M | un `where('disponible')` borrado de `restaurantes_provider.dart` | `audit:indexes FALLO · exit 1` | 1 |
| N | `<title>A new Flutter project</title>` en `panel_admin/web/index.html` | `audit:branding FALLO · exit 1` | 1 |
| O | `PATH` sin `flutter` | `FALLO — flutter no está en el PATH` (los 2 gates), sin salto silencioso | 1 |
| P | rotura en el **primer** gate, corrida **completa** | `9 gates · 8 OK · 1 fallo(s)` | 1 |

**Las seis roturas B/D/H/J/L son la prueba de T-11-15-03:** en las cinco, el runner devolvió **0** y el
gate falló igualmente. Sin esa comparación con el baseline, borrar 57 tests del cliente pasaría verde.

**La rotura P es la que prueba el contrato del comando completo:** con el primer gate en rojo, los ocho
restantes **se ejecutaron igual** y el comando salió con 1.

## Desviaciones del plan

### 1. [Regla 2 — funcionalidad crítica ausente] Son NUEVE gates, no ocho

El plan afirma: *"`functions: node --test test/` corre dentro de `test:functions`; si se quiere por
separado, añadirlo como noveno gate."* **Es falso.** `scripts` → `test:functions` hace glob de
`scripts/test/functions/*.e2e.mjs` y `*.test.mjs`; en ese directorio solo hay `.e2e.mjs` (el segundo
glob casa con **cero** archivos). Los 149 unitarios viven en `functions/test/*.test.js` y los corre
`cd functions && npm test`, que ninguno de los ocho gates invocaba.

Sin el noveno gate, la red de seguridad de la fase habría dejado fuera la matriz de autorización pura
(11-08), la matriz de baja (11-24) y los vectores de contraseña del servidor (11-22). Añadido, con el
motivo escrito en el propio `gates.mjs`. Roturas G y H lo confirman.

### 2. [Regla 3 — desbloqueo] `scripts/verificar_email_emulador.mjs` (archivo no previsto)

Sin él **el paso [A] del runbook es inejecutable**, y con él se cae el plan entero: todo lo demás
cuelga de tener un `super_admin`.

Cadena verificada empíricamente hoy contra el emulador de Auth:
1. `bootstrapPlataforma` exige `email_verified === true` en el idToken (11-07).
2. La pantalla `/bootstrap` **no llama a `sendEmailVerification()`** — comprobado leyendo
   `bootstrap_controller.dart`: crea la cuenta y llama a la callable en el mismo submit.
3. El emulador de Auth **no envía correos**, y una cuenta recién creada por la vía del SDK cliente sale
   con `emailVerified: false` (medido: `signUp` → `accounts:lookup` → `false`).
4. Peor: si la callable deniega, `_revertir()` **borra la cuenta**. Después de un intento fallido no
   queda ni cuenta que verificar.

El script hace, contra el emulador y solo contra él, lo que en producción hace la persona al pulsar el
enlace del correo. Medido: tras `accounts:update` con `Bearer owner`, el siguiente idToken lleva
`email_verified: true`. Está fijado en código a `127.0.0.1:9099` y al proyecto `demo-gri` (no
parametrizable): **no puede tocar producción**. Verificado también su modo de fallo con el emulador
apagado (mensaje claro, exit 1).

Por eso el paso [A] del runbook crea la cuenta **antes** de abrir `/bootstrap`: así la pantalla recibe
`email-already-in-use`, inicia sesión con ella y la callable ve un token ya verificado.

### 3. [Corrección de la premisa del plan] El prerrequisito de `functions/.env` es erróneo para emuladores

El plan pedía que el paso 0 exigiera *"`functions/.env` con `BOOTSTRAP_EMAIL` ANTES de arrancar el
emulador de Functions"*. Contra emuladores eso **no hace falta**: todo va con `--project demo-gri` y
`functions/.env.demo-gri` ya está **versionado** con valores ficticios deterministas, que además son
los que `test:functions` inyecta. `functions/.env` (valores reales, gitignored) solo importa en el
despliegue del plan 11-20. El runbook explica los dos archivos en una tabla y **nunca escribe el valor
real del secreto** — verificado mecánicamente: 0 apariciones de los valores de `functions/.env` en los
cuatro archivos nuevos/modificados (comparación hecha sin imprimirlos).

### 4. `scripts/package.json` no estaba en `files_modified` para `gates`… sí lo estaba; sin desviación

Sin cambios respecto al plan.

## Hallazgos

### DUODÉCIMO gate defectuoso de la fase: el `<verify>` de la Tarea 2 no discrimina

No es insatisfacible (11-22) ni falso en las dos direcciones (11-12): simplemente **no tiene dientes**.
Sus cinco condiciones (≥12 encabezados · `GRI-MESA-` · `/bootstrap` · `BOOTSTRAP_EMAIL` · `google`) las
cumple **`docs/FIREBASE_SETUP.md`**, un archivo que existía ANTES de este plan y que no es un runbook.
Medido:

```
docs/SMOKE-E2E-v2.md   -> RUNBOOK_OK           (headings 29)
docs/FIREBASE_SETUP.md -> PASARIA (gate ciego) (headings 21, bootstrap 11, BOOTSTRAP_EMAIL 3)
docs/SMOKE-E2E.md      -> falla                (headings 6, bootstrap 0)
```

Se ejecutó tal cual (pasa, exit 0) y **además** una comprobación con dientes: los 15 pasos `[A]`…`[O]`
presentes como encabezado, los 9 patrones que definen el alcance del runbook (base VACÍA, la regexp del
QR, `/bootstrap`, `BOOTSTRAP_EMAIL`, `Agotado`, los remites a 11-16 y 11-20, anti-sobre-reserva) y ≥10
bloques "Cómo verificarlo en los datos". **SMOKE-E2E-v2.md: 0 fallos. FIREBASE_SETUP.md: 23 fallos.**
Eso sí distingue.

### `run_emulators.mjs` no sirve para una sesión interactiva

Envuelve `emulators:exec` (un solo disparo), no `emulators:start`. El plan ofrecía las dos vías como si
fueran intercambiables. El runbook usa `npx --prefix scripts firebase emulators:start` con `JAVA_HOME`
resuelto a mano (JBR de Android Studio, verificado presente en esta máquina) y deja el wrapper para
comandos puntuales, que es para lo que sirve.

## Qué queda como verificación SOLO humana

Este runbook **no se ha ejecutado**. Es un documento; ejecutarlo es el checkpoint. Lo automatizado es
la red de gates, no el flujo.

1. **Los 15 pasos [A]…[O] completos.** Ninguno es automatizable: son dos apps Flutter en Chrome
   conducidas a mano contra emuladores.
2. **[I] Ingreso con Google.** Imposible contra emuladores: el emulador de Auth no implementa el flujo
   real. Exige `p-gri-b5b40` y, en Android, la huella SHA-1 registrada (si no, `DEVELOPER_ERROR` 10).
   → checkpoint del plan **11-20**.
3. **§4.1 Índices compuestos.** El emulador de Firestore no los evalúa: pasar este runbook **no**
   demuestra que los índices estén bien. `audit:indexes` es mitigación **estática**.
   → checkpoint del plan **11-16**.
4. **Que la pantalla `/bootstrap` funcione de verdad contra el emulador.** Lo verificado aquí es que el
   token queda con `email_verified: true` y que la callable acepta ese token (11 casos e2e). El eslabón
   que **no** se ha ejercitado es la pantalla real.
5. **Que el runbook sea seguible por quien no participó.** Es su criterio de éxito y solo lo cierra una
   persona leyéndolo.

## Deudas arrastradas que el runbook declara (§5)

Ninguna se cierra en este plan; se hacen visibles para que quien ejecute no las confunda con fallos.

| Deuda | Estado |
|---|---|
| Ventana de ~1 h del idToken tras desactivar a alguien | Riesgo aceptado, **no medido** (11-24) |
| Blanco sobre `#FF4C05` a 3.34:1 en etiquetas de 14px | **Pendiente de decisión del usuario** (paleta bloqueada) |
| Paleta de mesas: 3 de 4 pares estado/etiqueta por debajo de AA | **Pendiente de decisión del usuario** (11-25) |
| Sin correo de invitación: quien da de alta teclea la contraseña del empleado | Aceptado en v1 |
| Reportes agregan en cliente: no escalan a años de datos | Aceptado en v1 |
| App Check diferido | Diferido |
| Pagos en línea | Diferidos desde la Fase 10 |
| Sin pantalla de error si `Firebase.initializeApp` falla | Deuda conocida (11-18) |

## Estado del proyecto real que el runbook recoge (§6)

Comprobado el 2026-08-20 **fuera de este ejecutor** (verificación del orquestador contra la consola);
aquí se registra, no se re-verifica:

- Los **diez índices están desplegados**, incluido `categorias(restauranteId, orden)`.
- Las **rules desplegadas son las de la Fase 10**: les faltan el match del centinela `plataforma`
  (11-07) y la lectura acotada de `usuarios` (11-10). **Sin la segunda, `/equipo` responde
  `permission-denied` en producción aunque el código sea correcto.**
- **No hay ninguna Cloud Function desplegada.** Blaze aprobado, no necesariamente activado.
- La base **no está vacía**: conserva el seed de demo de la Fase 10 y ya tiene un `super_admin`
  concedido a mano, así que **`/bootstrap` allí ya está cerrado** y el paso [A] no es reproducible
  contra el proyecto real. Está dicho explícitamente en el runbook.

## Notas para 11-16 y 11-20

- Partid de `docs/SMOKE-E2E-v2.md`; `docs/SMOKE-E2E.md` está marcado SUPERADO y no debe reactivarse.
- Los índices ya están; lo que 11-16 tiene que desplegar de verdad son las **rules** (el `plataforma` de
  11-07 y el `usuarios` de 11-10). Sin ellas `/equipo` sigue roto en producción.
- El `BOOTSTRAP_EMAIL` real es una cuenta de Google, que llega con `email_verified: true` de fábrica: en
  producción no hace falta el script del paso [A]. Si alguna vez se usara una cuenta de
  email/contraseña, hay que crearla y verificarla **antes** de abrir `/bootstrap` (§4.1 de
  `FIREBASE_SETUP.md`).
- Si añadís tests, `npm run gates` os obliga a subir el baseline en `scripts/gates.mjs`. Es intencional.

## Self-Check: PASSED

Archivos declarados, todos presentes en disco:

```
FOUND: scripts/gates.mjs
FOUND: scripts/verificar_email_emulador.mjs
FOUND: docs/SMOKE-E2E-v2.md
FOUND: docs/SMOKE-E2E.md
FOUND: docs/FIREBASE_SETUP.md
FOUND: scripts/package.json
```

Commits, verificados en `git log`:

```
FOUND: 4286d3f  feat(11-15): ejecutor unico de los gates de la fase (npm run gates)
FOUND: b68afff  docs(11-15): runbook SMOKE-E2E-v2 desde base VACIA (15 pasos A-O)
```
