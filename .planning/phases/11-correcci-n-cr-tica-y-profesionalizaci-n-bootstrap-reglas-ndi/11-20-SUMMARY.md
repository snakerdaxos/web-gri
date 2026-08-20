---
phase: 11-correcci-n-cr-tica-y-profesionalizaci-n-bootstrap-reglas-ndi
plan: 20
subsystem: tooling / gestión de personal
tags: [cli, admin-sdk, autorización, firebase, staff, recuperación]
requires:
  - functions/src/auth-matrix.js (11-08)
  - functions/src/baja-matrix.js (11-24)
  - functions/src/password-policy.js (11-22)
  - scripts/run_emulators.mjs (11-01)
provides:
  - scripts/gestion_staff.mjs (CLI de personal sobre el Admin SDK)
  - scripts/test/staff-cli/ (gate de contrato + 27 e2e)
  - docs/GESTION-PERSONAL.md (manual del propietario)
  - npm script scripts/test:staff (décimo gate candidato; lo recoge 11-26)
affects:
  - docs/SMOKE-E2E-v2.md (la vía de alta de staff deja de ser la callable)
  - panel_admin /equipo (11-26 explica que los botones remiten a este script)
tech-stack:
  added: []
  patterns:
    - "delegación total de la autorización en módulos puros importados de otro paquete"
    - "// ROL-LITERAL-OK como marcador de exención declarada (tras // AUDIT-STAFF, // TOKEN-IGNORE, // POLICY-LOGIN-OK)"
    - "clave de servicio referenciada por RUTA vía applicationDefault(), nunca leída"
key-files:
  created:
    - scripts/gestion_staff.mjs
    - scripts/test/staff-cli/contrato-matrices.test.mjs
    - scripts/test/staff-cli/gestion-staff.e2e.mjs
    - docs/GESTION-PERSONAL.md
  modified:
    - scripts/package.json
decisions:
  - "El alcance de `listar` se le PREGUNTA a autorizarAlta con un rol de sonda tomado de ROLES_ASIGNABLES, en vez de escribir una regla de rol propia. Consecuencia aceptada: la plataforma debe pasar --rid y no hay listado global"
  - "El script NUNCA abre la clave de servicio: existsSync + GOOGLE_APPLICATION_CREDENTIALS + applicationDefault(). Divergencia deliberada de seed_firebase.mjs (readFileSync + cert)"
  - "La contraseña temporal se genera por BUCLE DE RECHAZO contra validarPassword, no construyéndola por categorías"
  - "promover-super vive en el MISMO archivo y salta la matriz a propósito; doble confirmación (bandera + reescribir el correo), --si NO la salta"
metrics:
  duration: 32 min
  completed: 2026-08-20
  tasks: 3
  commits: 4
  tests_added: 40
---

# Phase 11 Plan 20: Gestión de personal por script local — Summary

CLI `scripts/gestion_staff.mjs` que ejecuta lo que hacían `crearUsuarioStaff` y
`cambiarEstadoStaff` **importando** sus tres matrices puras en vez de reimplementarlas, con un gate
de contrato que se pone rojo si alguien vuelve a decidir la autorización dentro del script.

## Qué se construyó

| Comando | Qué hace por debajo |
|---|---|
| `listar` | query `usuarios` acotada al rid que devuelve la matriz + cruce con Auth para marcar desincronizaciones |
| `crear` | réplica paso a paso de `crear-usuario-staff.js`: forma del payload → política → matriz → restaurante existe → alta idempotente + anti-secuestro de 3 ramas → claims → espejo |
| `baja` | réplica de `cambiar-estado-staff.js`: `disabled` + claims a `null` + `revokeRefreshTokens` + espejo `activo:false` CONSERVANDO `role`/`restauranteId`. Confirmación interactiva; `--si` la salta |
| `reactivar` | restaura `disabled:false` y los claims LEÍDOS del espejo. Sin confirmación (no es destructivo) |
| `promover-super` | **salta la matriz a propósito**: bandera + reescribir el correo por stdin. Registra `promovidoPor` |

## La restricción dura, demostrada

`gestion_staff.mjs` importa `autorizarAlta`, `autorizarCambioEstado` y `validarPassword`, y **no
tiene ni una comparación de rol ni una regex de contraseña propias**. No es una afirmación: es lo que
mide `contrato-matrices.test.mjs` (13 casos, 82 ms, sin emulador), que además comprueba que los tres
módulos siguen siendo PUROS —la premisa de la que depende todo el plan— y lleva un caso de control
de su propio detector de comentarios.

Los dos únicos literales de rol del archivo (`super_admin`, `cliente`) son los que **la matriz no
puede razonar**, porque `ROLES_ASIGNABLES` y `ROLES_GESTIONABLES` los excluyen a propósito. Van
declarados con `// ROL-LITERAL-OK`; quitar el marcador pone el gate rojo (MEDIDO).

Prueba por rotura de que la delegación es real, no decorativa (roturas aplicadas sobre código ya
commiteado y revertidas):

| Rotura | Resultado |
|---|---|
| quitar el import de `auth-matrix` / `baja-matrix` / `password-policy` | 1 caso rojo cada una |
| quitar la denegación de `autorizarAlta` en `crear` | 2 e2e rojos (rid ajeno, rol `super_admin`) |
| quitar la denegación de `autorizarCambioEstado` | 3 e2e rojos (plataforma, uno mismo, otro rid) |
| quitar `validarPassword` de `crear` | 1 e2e rojo (`12345678` acabaría en Auth) |
| meter `if (rol === 'mesero')` | contrato rojo |
| meter `/[A-Z]/`, `\p{Lu}`, `.length < 8` o `MIN_PASSWORD` | contrato rojo (uno cada una) |
| ensuciar cualquiera de los tres módulos con un import de firebase | contrato rojo |

## Verificación (salida real)

```
cd scripts && npm run test:staff      → ℹ tests 40  ℹ pass 40  ℹ fail 0   (13 contrato + 27 e2e)
cd scripts && node --test test/staff-cli/contrato-matrices.test.mjs
                                      → ℹ pass 13  ℹ fail 0   (81.6 ms, sin emulador)
cd functions && npm test              → ℹ tests 149  ℹ pass 149  ℹ fail 0
git check-ignore -v p-gri-b5b40-firebase-adminsdk.json
                                      → .gitignore:36:*firebase-adminsdk*.json  (sigue ignorada)
grep -n adminsdk scripts/gestion_staff.mjs
                                      → 4 apariciones: 3 comentarios + 1 constante de RUTA. Ninguna lectura.
grep -n "readFile|JSON.parse|cert(" scripts/gestion_staff.mjs
                                      → 0 en código (solo existsSync). El proceso NUNCA abre la clave.
```

`cd scripts && npm run gates` (pasada completa, 1.6 min):

```
 app_cliente: flutter test              OK     345       345 = baseline
 app_cliente: flutter analyze           OK     0 issues
 panel_admin: flutter test              OK     445       445 (baseline 423, +22)   ← +22 es de 11-26, en vuelo
 panel_admin: flutter analyze           OK     0 issues
 functions: npm test (unitarios)        OK     149       149 = baseline
 scripts: npm run test:rules            FALLO  221       2 test(s) en rojo         ← ver más abajo
 scripts: npm run test:functions (e2e)  OK     50        50 = baseline
 scripts: npm run audit:indexes         OK     —         exit 0
 scripts: npm run audit:branding        OK     —         exit 0
```

**El fallo de `test:rules` NO es de este plan y no es una regresión.** El contador de aprobados es
**221, exactamente el baseline**: los 2 rojos son los 2 únicos casos de
`scripts/test/rules/_diag_sesion.test.mjs`, un archivo **sin versionar** (`??` en `git status`,
creado a las 05:25 por el ejecutor de 11-26 mientras diagnosticaba) que el glob del npm script
recoge. 221 + 2 = 223 corridos; los 221 versionados están verdes. No se ha tocado ese archivo: es
territorio ajeno y está en vuelo.

`npm run gates` **todavía no corre `test:staff`**: engancharlo es responsabilidad de 11-26, tal como
declara este plan.

## Verdes cazadas (5)

1. **`revokeRefreshTokens` se puede borrar y NO tumba nada.** Misma verde que 11-24 encontró en la
   callable, aquí confirmada de nuevo. Y aquí es **estructural**: el CLI nunca sostiene un refresh
   token que revocar, así que ningún test suyo puede notar su ausencia. **AFIRMADO, no verificado.**
2. **La delegación de `listar` en la matriz estaba verde por construcción.** Sustituir
   `ridEfectivo()` por «el rid del actor y, si no, el de `--rid`» no tumbaba NADA, porque el único
   caso usaba un admin cuyo rid coincidía. Cerrado con 2 casos: un `--rid` ajeno se rechaza con el
   mensaje de la matriz, y la plataforma sin `--rid` también.
3. **Solo estaba probada la rama (c) del anti-secuestro.** Retirar la (a) —cuenta de plataforma— o
   la (b) —otro tenant— no tumbaba nada. +2 casos que además afirman que los claims de la víctima
   quedan intactos.
4. **La comprobación de «el restaurante existe» no la notaba nadie.** Sin ella, un dedazo en el slug
   crea staff HUÉRFANO con claims válidos para un rid inexistente. +1 caso.
5. **Un test propio era una TAUTOLOGÍA y se reescribió.** «El rid se deriva del claim, no del
   payload» no podía fallar: MEDIDO, cambiar `decision.rid` por `texto(flags.rid) ?? decision.rid`
   no tumba ni un caso — cuando el alta llega ahí la matriz ya corrió y su prohibición 2 garantiza
   que ambos valores son el MISMO. Renombrado a lo que sí guarda.

Además, la primera versión del caso «reactivar con una ficha sin rol» estaba **verde por el motivo
equivocado**: escrito con el `admin_restaurante` como actor, moría en el alcance de tenant
(«No puedes cambiar el estado de personal de otro restaurante») y nunca llegaba a la rama que decía
probar. Con la ficha sin `restauranteId` y sin claims, esa rama **es inalcanzable para un
`admin_restaurante`**: solo la alcanza la plataforma. Reescrito con `--como` de plataforma.

## Gates defectuosos del plan (DECIMOTERCERO de la fase)

**El `<verify>` de la Tarea 2 no tiene DIENTES.** `grep -q "baja-matrix" gestion_staff.mjs` **pasa
sobre un archivo sin una sola línea de `baja`**: lo satisface la línea 23 de la cabecera, que
menciona el módulo en un comentario. MEDIDO en vivo: el commit de la Tarea 1 (8fcdfbe) no importa
`baja-matrix` y el gate de la Tarea 2 lo aprueba igual. Lo mismo vale para los greps de
`auth-matrix` y `password-policy` de la Tarea 1: con el import sustituido por un stub local, siguen
pasando.

Quien tiene dientes es `contrato-matrices.test.mjs`, que **elimina los comentarios antes de buscar**
y lleva su propio caso de control (romper el separador de comentarios pone 8 casos en rojo; hacerlo
inoperante —que no quite nada— pone 3).

El `<verify>` de la Tarea 1 (`grep -qi "como\|uso"`) es débil por otro motivo: «como» aparece en casi
cualquier texto en español, así que aprueba cualquier salida en castellano. No es falso en las dos
direcciones, pero no distingue una ayuda útil de un párrafo cualquiera.

## Desviaciones del plan

**1. [Regla 3] El `test:staff` que propone el plan NO es ejecutable.** El plan pide
`node --test test/staff-cli/`. Node 24 **no acepta un directorio** en `--test` (decisión 11-01) y
`run_emulators.mjs` fija el cwd en la RAÍZ del repo, así que las rutas relativas a `scripts/` no
resuelven. Sustituido por el patrón ya establecido en el repo:
`node --test --test-concurrency=1 scripts/test/staff-cli/*.test.mjs scripts/test/staff-cli/*.e2e.mjs`.

**2. [decisión] La plataforma DEBE pasar `--rid` también en `listar`.** El plan lo marca opcional.
Preguntarle el alcance a `autorizarAlta` —en vez de escribir aquí «si es X usa su rid»— hereda su
exigencia de restaurante explícito para quien no tiene uno propio. Más estricto que el plan; la
alternativa era escribir una regla de rol dentro del script, que es justo lo prohibido. Documentado
en el manual y con un caso e2e que lo fija.

**3. [Regla 2] La clave de servicio NO se lee.** El plan dice «inicializar el Admin SDK como hace
`seed_firebase.mjs`», que hace `readFileSync` + `cert()`. Aquí se usa `existsSync` +
`GOOGLE_APPLICATION_CREDENTIALS` + `applicationDefault()`: el contenido no entra nunca en el
proceso, así que no puede acabar en un log ni en el volcado de una excepción (T-11-20-03). Además
el modo EMULADORES tiene precedencia sobre la clave: apuntando a emuladores no se mira siquiera.

**4. [fidelidad] `crear` NO escribe `activo: true`, igual que la callable.** Consecuencia real: usar
`crear` para readmitir a alguien reescribe claims y ficha pero **no** rehabilita la cuenta ni borra
`activo:false`, así que esa persona seguiría sin poder entrar. Se replica tal cual y se **documenta
en el manual** («para readmitir usa `reactivar`, no `crear`»), en vez de arreglarlo aquí y divergir
del comportamiento que volverá cuando se despliegue Blaze.

**5. [proceso] Tareas 1 y 2 modifican el MISMO archivo.** Para que los commits sigan siendo atómicos
por tarea, el script se escribió entero, se recortaron las secciones de la Tarea 2 para el commit de
la Tarea 1 y se restauraron para el de la Tarea 2. Ambos commits pasan `node --check` y sus
`<verify>`.

**6. [proceso] Las Tareas 1 y 2 vienen marcadas `tdd="true"` pero el plan asigna TODOS los archivos
de test a la Tarea 3**, así que un RED previo era imposible sin cruzar la frontera de tareas. Se
implementó primero y se probó después, compensándolo con **33 roturas deliberadas** (16 sobre el
gate de contrato, 17 sobre el e2e) que es un estándar más fuerte que el orden RED/GREEN.

**7. [Regla 2] +6 casos e2e sobre los que pide el plan**, todos hallados rompiendo el propio gate:
ramas (a) y (b) del anti-secuestro, restaurante inexistente, `listar` con rid ajeno, `listar` de
plataforma sin rid, e **inicio de sesión REAL** contra el emulador para probar que la contraseña
generada sirve, que la baja EXPULSA y que la readmisión devuelve el acceso.

## Qué está verificado y qué NO

**VERIFICADO** (emuladores auth+firestore reales, el CLI como proceso hijo de verdad):
los 27 casos e2e — alta, idempotencia, las tres ramas del anti-secuestro, política de contraseñas,
las tres denegaciones de la baja, reactivación desde el espejo, confirmación interactiva en sus dos
respuestas, y las dos confirmaciones de `promover-super`.

**NO VERIFICADO — pendiente humano:** el script **nunca se ha ejecutado contra el proyecto real
`p-gri-b5b40`**. De la rama de proyecto real solo está probado el camino de error (clave ausente).
Que el Admin SDK autentique con la clave, que las escrituras lleguen a la Firestore real y que los
claims se propaguen a las apps son cosas que **solo se pueden comprobar ejecutándolo**. Un script
probado contra emuladores no es prueba de que se comporte igual contra el proyecto real.

**AFIRMADO, no verificado:** el efecto de `revokeRefreshTokens` (ver Verde cazada 1).

**Recordatorio de alcance que el manual dice en claro:** con las callables desplegadas la matriz era
una frontera de seguridad real, evaluada en el servidor contra un llamador que no controlaba nada.
En un script local, **quien tiene la clave de servicio puede hacer cualquier cosa sin pasar por
aquí**: la matriz es una barrera contra ERRORES, no contra un atacante. La seguridad del sistema pasa
a depender de dónde esté guardada esa clave.

## Baselines de test

- **NUEVO gate `scripts: npm run test:staff` → 40** (13 contrato + 27 e2e). Todavía **fuera** de
  `npm run gates`: engancharlo es de 11-26.
- Sin cambios en el resto: app_cliente 345, functions unitarios 149, functions e2e 50, rules 221
  (versionados), analyze 0 en las dos apps, `audit:indexes` y `audit:branding` exit 0.
- panel_admin 423 → 445 durante la corrida, pero ese +22 es del ejecutor de 11-26 trabajando en
  paralelo, no de este plan.

## Commits

| Hash | Qué |
|---|---|
| `8fcdfbe` | Tarea 1 — CLI de alta y listado delegando en las matrices puras |
| `f1aed92` | Tarea 2 — baja, reactivación, `promover-super` y `docs/GESTION-PERSONAL.md` |
| `c014c54` | Tarea 3 — gate de contrato (13) + e2e (21) |
| `066c2d5` | Tarea 3 — cerrar 4 huecos hallados rompiendo el propio gate (21 → 27) |

## Threat Flags

Ninguna superficie nueva fuera del `<threat_model>` del plan. `T-11-20-02` (`promover-super` salta la
matriz) se mantiene **aceptada** y ahora está acotada por dos confirmaciones y un rastro en el
espejo, y con tres casos e2e que fijan que ninguna de las dos se puede omitir.

## Self-Check: PASSED

Los 5 archivos declarados existen en disco y los 4 commits existen en el historial
(`8fcdfbe`, `f1aed92`, `c014c54`, `066c2d5`). Verificado mecánicamente, no de memoria.
