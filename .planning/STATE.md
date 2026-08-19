---
gsd_state_version: 1.0
milestone: v1.0
milestone_name: milestone
status: verifying
last_updated: "2026-08-19T18:05:00.000Z"
progress:
  total_phases: 11
  completed_phases: 10
  total_plans: 52
  completed_plans: 39
  percent: 73
---

# STATE

## Project Reference

See: .planning/PROJECT.md

**Core value:** Un cliente puede sentarse en una mesa, escanear su QR, pedir del menu y recibir su comida en tiempo real sin intermediarios.
**Current focus:** Phase 11 — Correccion critica y profesionalizacion (plan 07/20 completado)

## Roadmap Evolution

- Phase 11 added (2026-08-19): Correccion critica y profesionalizacion. Auditoria del sistema encontro 3 bugs criticos independientes (sin ruta de bootstrap desde BD vacia; query de menu del cliente denegada por rules; indice compuesto de categorias faltante) + deuda de UI severa en ambas apps (sin responsive, sin toggles de password, branding Flutter por defecto). Alcance detallado en .planning/phases/11-*/SCOPE.md
- Phase 10 added (2026-08-16): Migracion Firebase Opcion B (decision usuario)
- Phase 10 executed+verified (2026-08-16): 7 planes, ambas apps 100% Firebase (app 91/91, panel 84/84), rules+seed+guia en raiz. Backend FastAPI ARCHIVADO como referencia (no borrado). Pagos en linea diferidos (solo solicitar cuenta).

## Progress

Phase 11: 7/20 planes [#######-------------] 35%

- [x] 11-01 Bootstrap del entorno de test Firebase (Java + .firebaserc + functions/ + arnes de rules + CLAUDE.md corregido) — 46e2422, 58063f0, af125a8
- [x] 11-02 Base vacia + cliente de Cloud Functions (buildFakeFirestoreVacio en ambas apps, firebaseFunctionsProvider us-central1 + emulador 5001, guia de arranque del dashboard) — 9b2b965, 65a5f5d, d347b71, a2333de, f6085af
- [x] 11-03 Correccion del menu: query vs rules + indice compuesto + audit estatico (P0 de la fase) — 23151d8, 5aa08d0, 7caeb71, 52d2db6, 74ceacb
- [x] 11-04 Suite completa de firestore.rules: 7 colecciones nuevas, 190 casos, 3 vectores de escalada verificados por rotura deliberada — 0d2cafc, a0828f0, 4825e26
- [x] 11-05 Alta de restaurante desde el producto: slug canonico + crearRestaurante + dialogo con vista previa + estado vacio guiado + confirmacion al desactivar — 5d02e98, c2e62d2, 66afa5b, 72b9234, f137263
- [x] 11-06 Ver/ocultar contrasena en los 5 campos + confirmar contrasena en el registro: PasswordField por app (48x48 verificado anulando los defaults del framework), 12 roturas deliberadas — 958d59f, 3723572, fd5a3e7, f3c2f99
- [x] 11-07 Bootstrap del primer super_admin: callable con guarda atomica ANTES de toda consulta + doble factor (email_verified + secreto en tiempo constante, sin cortocircuito, mensaje unico), centinela blindado en rules, pantalla /bootstrap exenta del guard e invalidacion de claims. 13 roturas deliberadas — 06ba232, 8dc3e35, 28c1714
- [ ] 11-08 .. 11-20

Status: Phases 1-10 ejecutadas. Phase 10 verificada PASSED (automatizable); pendiente sellado humano:

1. firebase login + deploy --only firestore:rules,firestore:indexes (SMOKE-E2E [N])
2. Auth email/password en Console + serviceAccountKey + seed real x2 ([O])
3. Smoke e2e flujo completo ([A]-[M] emuladores o [P] real)

## Test Baselines (final Firebase)

- app_cliente: 112 passed + analyze 0 (11-06: +16 de toggle de contrasena y confirmacion en el registro)
- panel_admin: 157 passed + analyze 0 (11-07: +18 — 5 sobre el GoRouter real y 13 de pantalla/controlador de /bootstrap)
- TOTAL apps: 269 (baseline previa 251, sin regresion)
- Cloud Functions e2e: 11 passed via `cd scripts && npm run test:functions` (11-07, emuladores auth+functions+firestore reales)
- firestore.rules: 208 passed via `cd scripts && npm run test:rules` (11-04: +190 — mesas 26, sesiones 29, pedidos 36, reservas 27, calificaciones 21, usuarios 22, restaurantes 29)
- indices/paridad: `cd scripts && npm run audit:indexes` — 21 queries clasificadas, 0 fallos, exit 0
- Cloud Functions: `bootstrapPlataforma` con 11 casos e2e contra emuladores reales (11-07); `crearUsuarioStaff` sigue sin tests (llega en 11-08)
- backend FastAPI: archivado (215 tests referencia MySQL, no se mantiene)

## Stack actual

- Firebase p-gri-b5b40: Auth + Firestore + Rules (claims {role,rid}) + Cloud Functions (Node 22, functions/)
- Alias `demo` -> `demo-gri` en .firebaserc: proyecto ficticio para emuladores y tests
- Apps: app_cliente (android+web), panel_admin (web) — onSnapshot realtime, runTransaction concurrencia
- scripts/seed_firebase.mjs idempotente; firestore.rules + indexes + firebase.json en raiz
- scripts/run_emulators.mjs resuelve Java solo (JAVA_HOME -> PATH -> JBR de Android Studio)
- panel_admin: cloud_functions 6.3.6 (pin exacto) — firebaseFunctionsProvider region us-central1; emulador de Functions en 127.0.0.1:5001 bajo --dart-define=USE_EMULATORS=true

## Decisions

- 11-01: el wrapper de emuladores ejecuta firebase-tools/lib/bin/firebase.js con process.execPath, no el shim .bin/firebase.cmd (spawn de .cmd exige shell:true desde Node 18.20/20.12 y corrompe argumentos con comillas)
- 11-01: todos los scripts de test pasan `--project demo-gri` explicito; el alias `default` queda PROHIBIDO en cualquier script de test
- 11-01: la config de las Cloud Functions en emulador vive versionada en functions/.env.demo-gri (el emulador la carga AL ARRANCAR; --set-env no le llega)
- 11-01: los 4 paquetes Firebase nuevos se fijan con version EXACTA (sin ^) por la mitigacion T-11-01-SC
- 11-01: Node 24 no acepta un directorio en `node --test`; los npm scripts usan el glob *.test.mjs y rutas relativas a la RAIZ del repo
- 11-02: buildFakeFirestoreVacio() es el punto de partida obligatorio de toda prueba de primer arranque (planes 05, 07, 10); buildFakeFirestoreConSeed() sigue intacto
- 11-02: la region de las callables se declara EXPLICITA en cliente y servidor (us-central1) con test de contrato que falla si se quita — un desajuste da 404 opaco que en Flutter Web parece error de CORS
- 11-02: la guia del dashboard reutiliza restaurantesListProvider (ya observado por el topbar del AppShell, app_shell.dart:324): cero consultas nuevas
- 11-02: en riverpod 3 el getter de AsyncValue es .value, NO .valueOrNull
- 11-03: si firestore.rules menciona resource.data.X, la query DEBE llevar where('X') — Firestore evalua las rules contra la CONSULTA, no contra los documentos devueltos
- 11-03: el orderBy('orden') de categorias del cliente se queda CLIENT-SIDE a proposito, para no introducir el indice categorias(restauranteId, activo, orden)
- 11-03: el emulador de Firestore NO valida indices compuestos; audit_indexes.mjs es mitigacion ESTATICA, no prueba. La verificacion real del indice es el checkpoint humano de 11-16
- 11-03: la exencion de la paridad rules-query debe DECLARARSE con // AUDIT-STAFF; una exencion silenciosa cuenta como fallo
- 11-03: todo archivo de test de rules DEBE llamar initEnv('<namespace>') — node --test paraleliza por archivo contra un emulador compartido y sin namespace propio los clearFirestore() se pisan
- 11-04: un gate de seguridad no esta verificado hasta que se ROMPE la regla que protege y la suite se pone en rojo por los casos correctos (6 roturas aplicadas y revertidas en el plan)
- 11-04: un caso limite debe aislarse con su propio fixture (mesa de capacidad 30 para el tope de 20 comensales); si otra condicion lo deniega antes, el test esta verde por la razon equivocada
- 11-04: se afirman tambien los bordes PERMITIDOS (50 items, 20 personas, 1 estrella) — un <= convertido en < no rompe ningun assertFails
- 11-04: fake_cloud_firestore NO tiene motor de rules; los 192 tests Flutter prueban FILTRADO, jamas AUTORIZACION. La unica prueba de autorizacion es npm run test:rules
- 11-04: la suite verde y el proyecto seguro son afirmaciones INDEPENDIENTES — hasta firebase deploy --only firestore:rules, p-gri-b5b40 puede correr una version mas laxa
- 11-04: HALLAZGO — el super_admin no puede cerrar sesiones, cancelar reservas ni cambiar estado de mesa (staffOf compara contra rid() y el super no tiene rid); en pedidos SI esta contemplado con isSuper(). Asimetria real, a decidir en 11-10/11-16
- 11-04: 11-07 debe mantener en verde el bloque default-deny de plataforma/bootstrap; 11-10 debe cambiar conscientemente el caso // AMPLIADO EN 11-10 de usuarios.test.mjs
- 11-05: el doc ID del restaurante es un slug [a-z0-9-] validado ANTES de escribir; de el derivan los doc ID de mesa (GRI-MESA-{rid}-{NNN}) y por tanto los QR impresos. slug_test.dart lleva una COPIA de la regexp del escaner (scan_screen.dart:41): cambiarla alla exige actualizarla aca a mano
- 11-05: el check de existencia va ANTES del .set() porque Firestore evalua un set sobre doc existente como UPDATE, y la regla del super solo permite 'activo' -> el usuario veria permission-denied en vez de 'identificador ya en uso'
- 11-05: toda pantalla de alta debe fijar el contexto de trabajo al cerrar (seleccionRestauranteProvider); _maybeInitDefaultRid solo corre una vez en initState y con la lista vacia no selecciona nada
- 11-05: con AutovalidateMode.onUserInteraction el validador de un campo que el usuario nunca toca NO se dispara — el aviso hay que forzarlo con InputDecoration.errorText
- 11-05: un test puede estar verde por construccion (el doble-guardado seguiria en 1 doc por el check de existencia); la asercion con dientes es que el boton se apaga

- 11-07: el ORDEN importa — la guarda atomica create() va ANTES de la consulta de comprobacion; con la query delante, la rama ALREADY_EXISTS queda inalcanzable y los tests pasarian identicos con la guarda borrada (verificado: create->set tumba 3 casos, incluida la sobrescritura del centinela ajeno)
- 11-07: la comprobacion secundaria de super_admin SOLO corre si el centinela se creo en esta invocacion; sin esa condicion el camino de reparacion encuentra al propio llamador y se auto-deniega (rompe la carrera y la segunda llamada)
- 11-07: el correo del fundador NO es un secreto (el registro email/password esta abierto) — por eso email_verified === true y BOOTSTRAP_SECRET en tiempo constante son obligatorios, con caso negativo propio cada uno
- 11-07: HALLAZGO — el `return null` incondicional de /bootstrap en app.dart es HOY REDUNDANTE con el conjunto rutasPublicas; quitarlo deja la suite del router en verde. Se conserva como defensa en profundidad pero queda AFIRMADO, no verificado
- 11-07: HALLAZGO — el sidebar del AppShell desborda 85px (app_shell.dart:171) a CUALQUIER ancho; primer test que renderiza el shell entero. Diferido al bloque 3 (deferred-items.md); bootstrap_router_test.dart filtra solo `A RenderFlex overflowed` y ese filtro debe retirarse al corregirlo
- 11-07: FirebaseFunctions no es instanciable en flutter test, asi que se anadio una segunda costura (bootstrapCallableProvider) — sin ella el invalidate de claims y la reversion de cuenta quedarian afirmados por grep en vez de verificados

## Performance Metrics

| Phase | Plan | Duracion | Tareas | Archivos |
| --- | --- | --- | --- | --- |
| 11 | 01 | ~25 min | 3 | 14 |
| 11 | 02 | ~30 min | 3 | 13 |
| 11 | 03 | ~13 min | 3 | 10 |
| 11 | 05 | ~15 min | 3 | 8 |
| 11 | 06 | ~40 min | 2 | 9 |
| 11 | 07 | ~65 min | 3 | 15 |

## Session

- Last session: 2026-08-19
- Stopped at: Completado 11-07-PLAN.md (bootstrap del primer super_admin: callable + rules + pantalla). Siguiente: 11-08-PLAN.md
- Resume file: .planning/phases/11-correcci-n-cr-tica-y-profesionalizaci-n-bootstrap-reglas-ndi/11-08-PLAN.md

## Blockers / Notas

- ENV-01, DOC-01 y TEST-02 (requisitos de la Fase 11 segun ROADMAP.md) NO existen en .planning/REQUIREMENTS.md, que solo contiene los requisitos v1: `requirements.mark-complete` los reporta como not_found (reconfirmado en 11-02).
- 11-03: FIX-01, FIX-02 y TEST-01 tampoco existen en .planning/REQUIREMENTS.md (mismo motivo que ENV-01/DOC-01/TEST-02): `requirements.mark-complete` no puede marcarlos.
- 11-06: UX-01 tampoco existe en .planning/REQUIREMENTS.md (mismo motivo). Queda registrado en el frontmatter del SUMMARY.
- 11-06: el `<verify>` de la Tarea 2 del plan (`grep -rc ... | grep -q '^0$'`) esta MAL ESCRITO — con `-r` sobre un directorio grep antepone el nombre de archivo y `^0$` nunca casa. Se ejecuto tal cual (exit=1) y ademas el equivalente semantico, que si pasa. Cualquier plan futuro que copie ese patron debe usar `grep -rn ... ; test $? -eq 1`.
- 11-06 AVISO PARA EL BLOQUE 3 (tokens/responsive): si se centraliza `inputDecorationTheme` con `suffixIconConstraints`, el area tactil de 48x48 del ojo depende de ello. El caso `PasswordField: los 48x48 los pone el widget...` existe en las DOS apps para detectar esa regresion.
- 11-06 PENDIENTE DE VERIFICACION HUMANA: la lectura del boton por TalkBack/VoiceOver y el aspecto real del ojo en las 4 pantallas no son observables en `flutter test`.
- PENDIENTE DE SELLADO HUMANO (11-15/11-16): el indice categorias(restauranteId, orden) queda DECLARADO en firestore.indexes.json pero NO verificado — el emulador no valida indices compuestos. Requiere `firebase deploy --only firestore:indexes` contra p-gri-b5b40 y abrir el menu del panel.
- Los handlers state.advance-plan / state.update-progress / state.record-metric / state.record-session siguen sin parsear este STATE.md (reconfirmado en 11-02); se actualiza a mano. `roadmap.update-plan-progress 11` si funciona.
- 11-02 (DIFERIDO, ver phases/11-*/deferred-items.md): StatCard del panel desborda 31px cuando el grid pasa a 4 columnas (viewport >=1100px). Preexistente; debe entrar en el bloque de responsive/tokens.
- Sigue pendiente el sellado humano de la Fase 10 (deploy real + smoke, docs/SMOKE-E2E.md).
- 11-05: BOOT-02 y UX-04 tampoco existen en .planning/REQUIREMENTS.md (mismo motivo que ENV-01/DOC-01/TEST-01/TEST-02): requirements.mark-complete no puede marcarlos.
- 11-05: la MITAD del bootstrap sigue abierta — un restaurante creado desde el panel aun no tiene staff propio hasta la callable de 11-07/11-08.
- 11-07: BOOT-01 tampoco existe en .planning/REQUIREMENTS.md (mismo motivo que el resto de IDs de la Fase 11): `requirements.mark-complete BOOT-01` devuelve not_found. Queda en el frontmatter del SUMMARY.
- 11-07 PENDIENTE DE SELLADO HUMANO: la funcion `bootstrapPlataforma` y el `match /plataforma` NO estan desplegados. Hasta `firebase deploy --only functions,firestore:rules --project p-gri-b5b40`, produccion sigue sin la callable y con el centinela sin regla explicita. Runbook en docs/FIREBASE_SETUP.md §4.1 (exige BOOTSTRAP_EMAIL y BOOTSTRAP_SECRET en functions/.env ANTES del deploy).
- 11-07 PARA 11-08: reutilizar `scripts/test/functions/_emu.mjs` tal cual. AVISO: su `limpiar()` borra TODOS los usuarios de Auth y las colecciones `usuarios` y `plataforma`; si 11-08 siembra otras, debe ampliar la lista. El glob de `test:functions` ya recoge *.e2e.mjs y *.test.mjs.
- 11-07: la resistencia real a un ataque de temporizacion NO esta medida (solo se verifica que timingSafeEqual esta y que una longitud distinta deniega sin lanzar). `maxInstances: 3` esta declarado pero el emulador no lo aplica. App Check sigue DIFERIDO.
