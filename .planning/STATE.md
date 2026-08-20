---
gsd_state_version: 1.0
milestone: v1.0
milestone_name: milestone
status: verifying
last_updated: "2026-08-19T23:03:50.895Z"
progress:
  total_phases: 11
  completed_phases: 10
  total_plans: 53
  completed_plans: 47
  percent: 89
---

# STATE

## Project Reference

See: .planning/PROJECT.md

**Core value:** Un cliente puede sentarse en una mesa, escanear su QR, pedir del menu y recibir su comida en tiempo real sin intermediarios.
**Current focus:** Phase 11 — Correccion critica y profesionalizacion (planes 01-07 + 18 completados)

## Roadmap Evolution

- Phase 11 added (2026-08-19): Correccion critica y profesionalizacion. Auditoria del sistema encontro 3 bugs criticos independientes (sin ruta de bootstrap desde BD vacia; query de menu del cliente denegada por rules; indice compuesto de categorias faltante) + deuda de UI severa en ambas apps (sin responsive, sin toggles de password, branding Flutter por defecto). Alcance detallado en .planning/phases/11-*/SCOPE.md
- Phase 10 added (2026-08-16): Migracion Firebase Opcion B (decision usuario)
- Phase 10 executed+verified (2026-08-16): 7 planes, ambas apps 100% Firebase (app 91/91, panel 84/84), rules+seed+guia en raiz. Backend FastAPI ARCHIVADO como referencia (no borrado). Pagos en linea diferidos (solo solicitar cuenta).

## Progress

Phase 11: 15/21 planes [###############------] 71%

- [x] 11-01 Bootstrap del entorno de test Firebase (Java + .firebaserc + functions/ + arnes de rules + CLAUDE.md corregido) — 46e2422, 58063f0, af125a8
- [x] 11-02 Base vacia + cliente de Cloud Functions (buildFakeFirestoreVacio en ambas apps, firebaseFunctionsProvider us-central1 + emulador 5001, guia de arranque del dashboard) — 9b2b965, 65a5f5d, d347b71, a2333de, f6085af
- [x] 11-03 Correccion del menu: query vs rules + indice compuesto + audit estatico (P0 de la fase) — 23151d8, 5aa08d0, 7caeb71, 52d2db6, 74ceacb
- [x] 11-04 Suite completa de firestore.rules: 7 colecciones nuevas, 190 casos, 3 vectores de escalada verificados por rotura deliberada — 0d2cafc, a0828f0, 4825e26
- [x] 11-05 Alta de restaurante desde el producto: slug canonico + crearRestaurante + dialogo con vista previa + estado vacio guiado + confirmacion al desactivar — 5d02e98, c2e62d2, 66afa5b, 72b9234, f137263
- [x] 11-06 Ver/ocultar contrasena en los 5 campos + confirmar contrasena en el registro: PasswordField por app (48x48 verificado anulando los defaults del framework), 12 roturas deliberadas — 958d59f, 3723572, fd5a3e7, f3c2f99
- [x] 11-07 Bootstrap del primer super_admin: callable con guarda atomica ANTES de toda consulta + doble factor (email_verified + secreto en tiempo constante, sin cortocircuito, mensaje unico), centinela blindado en rules, pantalla /bootstrap exenta del guard e invalidacion de claims. 13 roturas deliberadas — 06ba232, 8dc3e35, 28c1714
- [x] 11-18 Branding GRI en las DOS apps: generador determinista de 13 assets (SDF, sin fuentes ni descargas), identidad web en los 4 archivos, shell de carga verificado en Chrome real, icono adaptive + splash Android 12, audit:branding y verify:shell. 18 roturas deliberadas — 69d1481, fa4fe06, 12b97e5
- [x] 11-08 Alta de staff con custom claims: matriz de autorizacion PURA (sin imports de firebase, 27 casos en 61ms) + callable crearUsuarioStaff idempotente con anti-secuestro de 3 ramas (la tercera consulta el doc espejo, porque un cliente auto-registrado no lleva claim role) + 14 e2e con tokens reales. 18 roturas deliberadas — 94f35f1, 5761769, b7b59a8
- [x] 11-09 Estados vacios guiados + 404 propio en las dos apps: EmptyState (resistente al desbordamiento) cierra la pantalla EN BLANCO del menu post-escaneo del QR; errorBuilder cableado en los dos GoRouter mostrando SOLO uri.path y por detras del guard de sesion. 11 roturas deliberadas — b1719ca, e5c921b, 2840752
- [x] 11-10 Gestion de equipo del panel: la regla de usuarios se abre por PRIMERA VEZ a docs ajenos, acotada a role()=='admin_restaurante' && resource.data.restauranteId==rid() (clientes fuera por construccion, restauranteId null); pantalla /equipo unica adaptativa + formulario que NO manda restauranteId siendo admin (la callable lo deriva del claim) + gating en sidebar y router. 2 verdes por el motivo equivocado cazados (uno HEREDADO de 11-04) y 1 gate del plan inejecutable. 21 roturas deliberadas — 7f3f9a2, 5ef72b6, 69799e8
- [x] 11-11 Base del sistema de diseno: GriSpacing/GriRadius/GriBreakpoints/GriText en las DOS apps, griTextTheme con los 15 slots DECLARADOS (valores de M3 medidos con sonda: la escala de GRI NO cabe ahi porque esos slots los consume el chrome), GriSemanticColors registrada, models/pedido.dart pierde su segunda paleta, panel con elevatedButtonTheme + griCardDecoration + 4 estilos con nombre. 17 roturas deliberadas; 1 test propio RETIRADO por estar verde por construccion — 3e5f931, 6ad9a63, 808487b, 7d0528a
- [x] 11-13 TODO lo visible de la app cliente: SafeArea(bottom:false) cierra el bug del espacio superior reportado por el usuario; el ConstrainedBox fijo de 480 pasa a techo adaptativo (0-840 IDENTICO, >=840 pasa a 720); overflow del wizard cerrado + 2 mas del mismo tipo hallados en el barrido; 37 emojis -> Icon de Material con GriIcons; primera red de seguridad del AppShell (17 casos de geometria real). 21 roturas deliberadas, 2 VERDES cazadas (SafeArea(bottom:true) es un no-op medido; el textAlign no lo veia getRect). Suite ENTERA verde a 320px con canario — 85f0f45, 81323f5, 6207ded, f5b6049, a0a83d9, da167b8, 65c1c17
- [x] 11-21 TODO lo visible del panel admin: 7 desbordes de RenderFlex cerrados (4 del plan + 3 que no estaban: sidebar COLAPSADO 5px+13px x8 por geometria pura, topbar 77px, cabecera del mapa 148px, cabecera de cocina 150px a 450) y los TRES filtros de overflow del repo retirados (el plan solo conocia 1); ResponsivePage con techo de 1200 en las 12 pantallas contadas del arbol; 33 emojis -> Icon de Material con GriIcons, incluido uno camuflado como una secuencia de escape que ningun grep de glifos veia. 29 roturas deliberadas, 3 VERDES cazadas (el gate del plan no distingue filtro de detector; find.byIcon es tautologico respecto a QUE icono se eligio). HALLAZGO: los 85px del sidebar son de la fuente de TEST, no hay evidencia de que se vieran en produccion. panel_admin 226 -> 280 -- 4872666, 7e0d330, 67859cc, dea78d7, 9c67d7e, 5e55e8b
- [x] 11-19 Tokens en la app cliente: los 20 hex crudos de 6 pantallas a GriColors (el ambar estaba 9 veces, el degradado copiado en 4) + 34 TextStyle a GriText + 103 espaciados a GriSpacing; resuelto el TODO(11-19) de 11-17. MEDIDO con sonda que el criterio del plan para migrar a textTheme NO es pixel-neutral (bodySmall trae letterSpacing 0.4/height 1.33 frente al 0.25/1.43 heredado: 12px pasaria de 257.3x17 a 260.4x16); solo bodyMedium lo es, y por ser el DefaultTextStyle. Migracion 1:1 DEMOSTRADA: reversion byte a byte del espaciado en 32 archivos + auditoria del multiconjunto de numeros/hex/pesos en los 16 archivos de pantalla con 0 diferencias. Gate sin_hex_crudos_test con exencion TOKEN-IGNORE. 20 roturas/inyecciones, 2 VERDES cazadas (romper un estilo de la escala no lo notaba ninguna pantalla). app_cliente 206 -> 214 -- fa85e34, ac2328b, b72f221
- [~] 11-17 Login con Google en la app cliente: 3 de 4 tareas cerradas (adaptador con rama Web funcional, boton en login y registro, appId de Android corregido al registro real). PARADO en su checkpoint humano: falta registrar la huella SHA-1 en la app com.gri.gri_cliente y verificar el ingreso en Android
- [ ] 11-12, 11-14, 11-15, 11-16, 11-20, 11-22 .. 11-25

Status: Phases 1-10 ejecutadas. Phase 10 verificada PASSED (automatizable); pendiente sellado humano:

1. firebase login + deploy --only firestore:rules,firestore:indexes (SMOKE-E2E [N])
2. Auth email/password en Console + serviceAccountKey + seed real x2 ([O])
3. Smoke e2e flujo completo ([A]-[M] emuladores o [P] real)

## Test Baselines (final Firebase)

- 11-21: panel_admin 226 -> 280 (+54); analyze 0. Desglose: +9 app_shell_layout_test (nuevo), +34 responsive_test (nuevo), +1 sin_filtros_overflow_test (nuevo), +4 sin_emojis_test (nuevo), +4 stats_render_test, +3 reservas_screen_test. Los 3 filtros de FlutterError.onError que tapaban desbordes (bootstrap_router 11-07, router_404 11-09, equipo_gating 11-10) estan RETIRADOS

- 11-19: app_cliente 206 -> 214 (+8); analyze 0. Desglose: +5 en theme_tokens_test (los 5 tokens nuevos valen su hex, gradienteInicio != primary, el gradiente conserva extremos, la home lo PINTA, el bloque de Google conserva sus dos grises), +1 mas de render tipografico (24/bold y 16/bold medidos en la home) y +2 de sin_hex_crudos_test (nuevo). RE-MEDIDO tras el corte de sesion con 11-21 ya integrado: identico
- 11-13: app_cliente 178 -> 206 (+28); analyze 0. Desglose: +17 app_shell_responsive_test (nuevo), +4 wizard_form_test, +2 sin_emojis_test (nuevo), +4 iconos_test (nuevo), +1 theme_tokens_test. MEDIDO tambien con la suite ENTERA forzada a 320px (flutter_test_config.dart temporal): 206 verdes y CERO `RenderFlex overflowed`
- 11-11: app_cliente 158 -> 178 (+20) y panel_admin 163 -> 189 (+26); analyze 0 en las dos. OJO: `flutter test` en panel_admin da 226 porque 11-10 aporta +37 en test/equipo (medido aparte con `flutter test test/equipo`)

- app_cliente: 122 passed + analyze 0 (11-09: +10 — 4 de menu_vacio, 1 en base_vacia, 5 de router_404). MEDIDO EN DOS MITADES: 11-17 tenia test/auth y lib/features/auth abiertos en vuelo, asi que `flutter test` a secas salia rojo por archivos ajenos; test/auth por separado +50 y todo lo demas +99
- panel_admin: 200 passed atribuibles hasta 11-10 + analyze 0 (11-09: +6 de router_404; 11-10: +37 — 15 de provider/controlador, 13 de pantalla/formulario, 9 de gating sobre el GoRouter REAL). Medido con el ejecutor de 11-11 en el mismo arbol: su +26 no se cuenta aqui
- TOTAL apps: 285 atribuible a 11-09 (269 + 16), sin regresion. El total real sera mayor cuando 11-17 cierre sus tests de Google Sign-In
- Cloud Functions e2e: 25 passed via `cd scripts && npm run test:functions` (11-07 bootstrap 11 + 11-08 crearUsuarioStaff 14, emuladores auth+functions+firestore reales)
- Cloud Functions unitarios: 34 passed via `cd functions && npm test` (11-08; matriz pura 27 + contratos de fuente 7). OJO: `node --test test/` NO funciona en Node 24, el script usa el glob test/*.test.js
- firestore.rules: 221 passed via `cd scripts && npm run test:rules` (11-04: +190; 11-10: +13 en usuarios, 22 -> 35 — la lectura del equipo acotada al rid, con la query sin filtro y el cruce de tenant en los dos sentidos)
- indices/paridad: `cd scripts && npm run audit:indexes` — 22 queries clasificadas, 5 sujetas a paridad, 0 fallos, exit 0 (11-10 anade la query de `usuarios`, que la tabla PARIDAD_RULES_QUERY ya exigia)
- branding: `cd scripts && npm run audit:branding` — 2 apps, 4 archivos, 0 rastros de plantilla, exit 0 (11-18; 15 roturas deliberadas)
- shell de carga: `cd scripts && npm run verify:shell` — 2 apps en Chrome headless por CDP, shell retirado en <1s (11-18; 3 roturas deliberadas). EXIGE `flutter build web --release` previo en las dos apps
- Cloud Functions: `bootstrapPlataforma` (11-07, 11 casos e2e) y `crearUsuarioStaff` (11-08, 14 casos e2e + 34 unitarios). NINGUNA de las dos esta DESPLEGADA en p-gri-b5b40
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

- 11-18: el logo de GRI es CODIGO (app_cliente/tool/gen_branding.dart): se dibuja con campos de distancia con signo y antialias analitico, NO con la fuente del emoji del mockup — el rasterizado de una fuente depende de version/hinting/sistema y el mismo comando daria PNG distintos en dos maquinas. Prohibido editar los PNG a mano: `cd app_cliente && dart run tool/gen_branding.dart` los regenera los 13 (las DOS apps) y es idempotente
- 11-18: HALLAZGO — el gate que el plan asignaba a T-11-18-02 (`flutter build web --release`) es CIEGO a la amenaza: un shell de carga que no se retira compila perfectamente y deja un overlay a pantalla completa que ningun clic atraviesa. Demostrado con 2 roturas. Por eso existe `npm run verify:shell` (Chrome headless por CDP), que si sale con 1
- 11-18: la verificacion headless con `--virtual-time-budget` + `--dump-dom` da FALSOS NEGATIVOS: el tiempo virtual corre mas rapido que la red real y la app nunca llega a pintar. Cualquier comprobacion de una app Flutter Web en navegador debe usar tiempo REAL y sondeo por CDP
- 11-18: `flutter_launcher_icons` REESCRIBE AndroidManifest.xml aunque no cambie nada semantico (le quita el BOM). Con cambios sin commitear en ese archivo hay que hacer copia antes de correr el generador
- 11-18: `adaptive_icon_foreground_inset: 0` es obligatorio porque el asset de primer plano YA trae su zona segura (glifo al 58% del lienzo); con el 16% por defecto se aplica dos veces y el glifo queda diminuto
- 11-18: los fondos `#F7F7F7` (cliente) y `#F5F6F8` (panel) DIFIEREN a proposito y `audit_branding.mjs` los afirma POR APP. Si el bloque de tokens cambia `AppColors.background` de una app, hay que actualizar `backgroundEsperado` en ese script EN EL MISMO COMMIT
- 11-18: la asercion `<title> menciona GRI` NO es la que caza el titulo de plantilla (`gri_cliente` contiene "GRI" en mayusculas); lo caza la lista de nombres de paquete Dart. Las dos comprobaciones son necesarias

- 11-08: la decision de autorizacion se aisla como modulo PURO sin imports de Firebase (functions/src/auth-matrix.js); es lo que permite probar la combinatoria COMPLETA de escaladas en 61ms sin emulador, que es donde vive de verdad la seguridad de la matriz
- 11-08: el rid efectivo se DERIVA del claim del llamador, JAMAS del payload. Un admin_restaurante no puede elegir restaurante aunque mienta en el body
- 11-08: la prohibicion de asignar super_admin es ABSOLUTA, no relativa al llamador — ni el propio super_admin puede crear otro por esta via (caso e2e dedicado). El unico super nace de bootstrapPlataforma
- 11-08: el anti-secuestro por correo tiene TRES ramas y la tercera consulta el DOC ESPEJO, no los claims: un cliente auto-registrado no lleva claim role (11-04), asi que mirar claims no ve nada y cualquiera que conozca el correo de un cliente lo convertiria en su mesero
- 11-08: riesgo residual ACEPTADO — una cuenta en Auth sin claims Y sin doc espejo se deja pasar porque es indistinguible de un alta de staff incompleta; cerrarlo romperia la reparacion idempotente, unica mitigacion de la no-atomicidad Auth/Firestore
- 11-08: HALLAZGO — un caso de denegacion que solo asserta el CODIGO puede estar verde por otro control que comparte codigo. ESCALADA HORIZONTAL seguia verde con los claims sin llegar al token; ahora asserta la identidad del MENSAJE y la rotura del arnes pasa de tumbar 10 casos a 11
- 11-08: HALLAZGO — el gate `grep -c "e.message"` es CIEGO a `err.message` y `err?.message` (el punto es comodin en grep y exige la letra e delante). Demostrado en vivo: con la fuga puesta, el gate PASA. Todo gate de grep debe probarse contra la forma REAL de la fuga
- 11-08: al reves que 11-07, aqui cada denegacion tiene mensaje PROPIO: alli el llamador podia ser anonimo y el texto unico evitaba un oraculo; aqui ya es staff autenticado (T-11-08-06 acepta la enumeracion) y el mensaje distinto es lo que da dientes a los tests

- 11-09: `context.go('/')` NO sirve en app_cliente — esa app no tiene ruta raiz (su initialLocation es '/inicio'). El plan lo indicaba para las DOS apps; en el cliente el boton de salida del 404 habria caido en OTRO 404. Verificado por rotura deliberada
- 11-09: un estado vacio con icono + titular + guia + boton es MUCHO mas alto que el `Text` gris al que sustituye y desborda donde el otro no. `EmptyState` elige con un LayoutBuilder: scrollable con altura ACOTADA (Scaffold body, SliverFillRemaining), rigido con altura LIBRE — un SingleChildScrollView dentro de un ListView lanza por viewport sin acotar
- 11-09: en `flutter test` la fuente por defecto pinta cada caracter como un cuadro del tamano de la fuente, asi que un titular de 31 caracteres ocupa 144px de ALTO. Cualquier medida de layout tomada en widget test es del orden de magnitud equivocado respecto al render real: sirve para detectar desbordes, no para validar espaciado
- 11-09: el CTA de un estado vacio NUNCA debe llamarse igual que el de la rama de error ('Reintentar'). Ademas de mentir sobre lo que paso, rompe la asercion `find.text('Reintentar') findsNothing` que 11-02 dejo para distinguir 'no hay datos' de 'no pude leerlos'
- 11-09: el 404 muestra SOLO `uri.path`. `uri.toString()` filtraria el query string, que es justo donde viajan tokens e ids; el test junta el `data` de TODOS los Text del arbol para afirmarlo, no solo el del widget que yo mire
- 11-09: el `redirect` de GoRouter se evalua ANTES que el `errorBuilder`, asi que el 404 no sirve para sondear rutas internas. El caso con dientes no es 'sin sesion va a login' sino que una ruta que EXISTE y una que NO dan la MISMA respuesta

- 11-11: la escala tipografica de GRI NO cabe en ThemeData.textTheme. MEDIDO con sonda: titleLarge es el titulo de los 8 AppBar del cliente, headlineSmall el de los 8 AlertDialog del panel, labelLarge la etiqueta de TODOS los botones, bodyLarge el titulo de los ListTile. Meter ahi los 24-bold/18-bold cambiaria ese chrome. griTextTheme declara los 15 slots con los valores de M3 (deja de ser un default implicito) y la escala propia vive en GriText, con valores IDENTICOS al TextStyle inline que sustituye
- 11-11: el panel conserva 750/1100 como breakpoints; app_cliente, que no tenia ninguno, adopta los 600/840 de M3. Un gate de paridad con dart:io afirma que el token y el literal de la pantalla dicen lo mismo (verificado por rotura: cambiar cualquiera de los dos pone rojo)
- 11-11: se registra elevatedButtonTheme (10 de 12 sitios ya lo declaraban: es convencion) pero NO textButtonTheme (0 de 26), outlinedButtonTheme (1 de 4, y es la variante destructiva) ni inputDecorationTheme (12 de 16 campos no declaran border y hoy pintan el subrayado de M3; registrarlo les cambia la GEOMETRIA). Hay un test que AFIRMA esa ausencia con el motivo escrito
- 11-11: HALLAZGO — el aviso de 11-06 sobre el area tactil es correcto en el riesgo pero su test NO lo cubriria: ningun test de 48x48 monta griTheme. Demostrado en vivo (inputDecorationTheme hostil metido en griTheme -> suite de login entera en verde). Y resulta que el tema real NO PUEDE encogerla: el constraints 48x48 explicito del IconButton es un minimo de ConstrainedBox, inmune a suffixIconConstraints, iconButtonTheme y visualDensity (3 roturas verdes). Por eso el test que escribi para cerrar el hueco se BORRO: no podia fallar nunca
- 11-11: HALLAZGO — el panel y la app cliente pintan el MISMO estado de pedido con colores DISTINTOS (enviado #2563EB vs #3478F6, aceptado #D97706 vs #FF4C05, en_preparacion #7C3AED vs #8E44AD). Unificarlo cambia pixeles en una de las dos apps: queda declarado y con test a cada lado, no corregido
- 11-11: un MaterialColor (Colors.red) dentro de un ThemeExtension rompe el contrato de lerp — Color.lerp devuelve siempre un Color plano y Color.== compara el runtimeType, asi que lerp(otro, 0) dejaba de ser igual a this. Los tokens de color se declaran como Color plano
- 11-11: textoSecundarioAccesible (#6E6E6E) se DECLARA pero NO se aplica en ningun sitio; aplicarlo es de 11-14. GriColors.gray sigue siendo #777777 y hay dos tests por app que lo impiden cambiar

- 11-13: HALLAZGO — `SafeArea(bottom: true)` en el AppShell es un NO-OP, no un bug. El Scaffold ya pone padding.bottom a 0 en el MediaQuery del body cuando declara bottomNavigationBar (MEDIDO con sonda). La premisa "no negociable" del plan (que duplicarlo anadiria un hueco) es FALSA: la rotura deliberada dejo la suite entera en verde. `bottom: false` se conserva como documentacion de intencion y la asercion se reescribio por tres que si tienen dientes
- 11-13: el ConstrainedBox del shell NO se borra, se convierte en techo adaptativo. De 0 a 840px el ancho es IDENTICO al anterior (afirmado a 360/600/839, el borde exacto); solo por encima de 840 pasa de 480 a GriBreakpoints.contenidoMaxAmplio (720), unico valor NUEVO de design_tokens.dart
- 11-13: HALLAZGO — la fuente por defecto de `flutter test` pinta cada glifo como un cuadrado de fontSize, asi que el texto mide ~2x lo que mide en Roboto real ('Elige una hora'@16 -> 224px vs ~105px). Un barrido de overflow a 320px produce FALSOS POSITIVOS: hay que medir con TextPainter antes de declarar un bug. El desborde de _ResumenRow es real con cualquier fuente (840 vs ~170px de hueco); los otros dos solo aparecen con el texto ampliado por accesibilidad
- 11-13: HALLAZGO — una asercion que mide la CAJA del parrafo no ve el textAlign. Con Expanded, la caja ocupa todo el hueco se alinee como se alinee; quitar textAlign.end dejo la suite entera en verde. Se lee la posicion de los GLIFOS con RenderParagraph.getBoxesForSelection
- 11-13: HALLAZGO — el grep de inventario del plan (rangos 1F300-1FAFF y 2600-27BF) NO cubre U+2B50, asi que se dejaba fuera las 4 apariciones de la estrella, que estan en su propia tabla de equivalencias. Total real 54, no ~46. Cuarto gate de grep defectuoso de la fase (11-06, 11-08 x2, 11-13)
- 11-13: HALLAZGO — el gate `<verification>` del plan (`grep -rn "RenderFlex overflowed" app_cliente/test`) da FALSO POSITIVO: casa con un comentario explicativo dentro de un `reason:`. Confunde "hay un filtro" con "alguien menciona la frase"
- 11-13: la regla que separa "icono" de "texto expresivo" es la PERSISTENCIA del elemento: chip/tab/tarjeta/estado vacio/metadatos de fila -> icono (se sustituye); SnackBar o frase conversacional -> texto (se conserva con // EMOJI-OK: motivo)
- 11-13: un emoji DENTRO de una frase se traduce con WidgetSpan (iconoInline), no con Row — el Row cambia el salto de linea del parrafo y con dos iconos en la misma frase exigiria anidar
- 11-19: los TextStyle inline NO migran a ThemeData.textTheme. MEDIDO con sonda bajo griTheme y 8 cadenas de la misma longitud: coincidir en tamano Y peso (el criterio de corte del plan) NO basta, porque el slot trae su propio letterSpacing/height y el inline los HEREDA del DefaultTextStyle. 12/w400: 257.3x17 inline vs 260.4x16 con bodySmall; 16/w400: 341.3x23 vs 346.5x24; 16/w500: 341.3x23 vs 339.1x24 con titleMedium. El UNICO slot pixel-neutral es bodyMedium, y solo porque ES el estilo ambiente. Destino correcto: GriText, que es literalmente el mismo TextStyle. AVISO PARA 11-12: no migres los fontSize del panel a textTheme
- 11-19: GriText.tituloCard ("titulo de tarjeta, 12 usos") y GriText.boton ("etiqueta de boton, 3 usos") NO describen esta app. Los 9 usos de 16 bold de app_cliente son TODOS etiquetas de CTA y no hay ni un titulo de tarjeta a 16 bold; de los 3 de 15 bold solo uno es un boton (los otros son el contador del carrito y el banner "Cuenta solicitada"). Consecuencia de que 11-11 derivara la escala CONTANDO estilos repetidos. Se anade GriText.botonGrande con el MISMO valor y el significado correcto, con test que afirma la igualdad para que divergir sea consciente
- 11-19: el espaciado se migra a nivel de VALOR, no de expresion: en EdgeInsets.fromLTRB(16, 8, 16, 12) los tres primeros pasan a token y el 12 se queda como numero suelto. El numero desnudo entre tokens senala la deuda; convertirlo al peldano mas cercano seria un cambio visual
- 11-19: una asercion de render debe comparar contra el HEX/NUMERO literal, JAMAS contra el token. Comparando contra el token, cambiar el token deja el caso verde y no prueba nada. Es lo que hace que la rotura del ambar tumbe el caso PREEXISTENTE de iconos_test.dart (11-13) sin haber editado su valor esperado
- 11-19: HALLAZGO - romper un estilo de GriText no lo notaba NINGUNA pantalla (roturas G y H tumbaban solo la asercion literal del propio token). La tipografia estaba afirmada solo contra si misma. Se anadio un caso que renderiza la home y mide 24/bold y 16/bold con los numeros escritos a mano
- 11-19: HALLAZGO - el <verify> de la Tarea 2 del plan (`grep -rn "textTheme" lib | wc -l > 0`) esta VERDE POR CONSTRUCCION desde 11-11: devuelve 3 coincidencias antes de tocar nada y DOS SON COMENTARIOS. Pasa igual si la tarea no se hace. Septimo gate defectuoso de la fase (11-06, 11-08 x2, 11-13 x2, 11-19)
- 11-19: HALLAZGO - subprocess(shell=True) en Windows lanza cmd.exe, donde `^` es el caracter de escape: `git show fa85e34^:archivo` se convierte en `fa85e34:archivo` y la comparacion se hace contra el commit EQUIVOCADO en silencio. Cualquier script de auditoria que use un ref con `^` o `~` desde Python en Windows debe resolver el SHA antes (git rev-parse)

- 11-13: el gate de paridad token<->codigo de 11-11 se REESCRIBIO, tal y como su propio comentario pedia ("hay que reescribirlo, no borrarlo"): ya no hay literal que comparar, asi que afirma que NO vuelve ninguno y que los tres tokens se usan. El gate fuerte es el nuevo, que renderiza y mide

## Performance Metrics

| Phase | Plan | Duracion | Tareas | Archivos |
| --- | --- | --- | --- | --- |
| 11 | 01 | ~25 min | 3 | 14 |
| 11 | 08 | ~2h 14min | 3 | 8 |
| 11 | 02 | ~30 min | 3 | 13 |
| 11 | 03 | ~13 min | 3 | 10 |
| 11 | 05 | ~15 min | 3 | 8 |
| 11 | 06 | ~40 min | 2 | 9 |
| 11 | 07 | ~65 min | 3 | 15 |
| 11 | 18 | ~31 min | 3 | 55 |
| 11 | 09 | ~50 min | 2 | 12 |
| 11 | 11 | ~95 min | 2 | 8 |
| 11 | 13 | ~110 min | 3 | 23 |
| 11 | 19 | ~80 min | 3 | 20 |

## Session

- Last session: 2026-08-19
- Stopped at: Completado 11-19-PLAN.md (tokens de la app cliente: 20 hex + 34 TextStyle + 103 espaciados; migracion 1:1 demostrada mecanicamente, 0 diferencias de valor). Ejecutado en paralelo con 11-21.
- Stopped at (anterior): Completado 11-13-PLAN.md (todo lo visible de la app cliente: zona segura, responsive, overflow e iconos; 21 roturas deliberadas, 2 verdes cazadas). Ejecutado en paralelo con 11-21.
- Resume file: .planning/phases/11-correcci-n-cr-tica-y-profesionalizaci-n-bootstrap-reglas-ndi/11-12-PLAN.md

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
- 11-08 (cumplido el aviso de 11-07): `scripts/test/functions/_emu.mjs` reutilizado y AMPLIADO — `limpiar()` borra ahora tambien `restaurantes`, y expone `llamarCrearStaff()`, `crearUsuarioConClaims()` (claims ANTES del login: el idToken se acuña en el signIn) y `crearRestaurante()`. Quien siembre otras colecciones debe ampliar la lista.
- 11-07: la resistencia real a un ataque de temporizacion NO esta medida (solo se verifica que timingSafeEqual esta y que una longitud distinta deniega sin lanzar). `maxInstances: 3` esta declarado pero el emulador no lo aplica. App Check sigue DIFERIDO.
- 11-18: UX-03 tampoco existe en .planning/REQUIREMENTS.md (mismo motivo que el resto de IDs de la Fase 11): `requirements.mark-complete UX-03` devuelve not_found. Queda en el frontmatter del SUMMARY.
- 11-18 (DIFERIDO, ver deferred-items.md): `orientation: portrait-primary` en panel_admin/web/manifest.json — bloquearia una PWA instalada del panel en vertical, y el panel se disena a partir de 1100px. Va al bloque de responsive.
- 11-18 (ENTORNO, ver deferred-items.md): `.dart_tool/flutter_build/` obsoleto rompe `flutter build web` en las DOS apps con `Couldn't resolve the package 'flutter_secure_storage_web'` (dependencia retirada en la Fase 10). `flutter pub get` NO lo arregla: hay que borrar `<app>/.dart_tool/flutter_build/`. Debe entrar en el runbook del bloque 4.
- 11-18 PENDIENTE DE VERIFICACION HUMANA: que el logo se VEA bien no es automatizable. Tampoco se ha visto el icono ni el splash arrancando en un Android real (no se ejecuto `flutter build apk`), ni se ha instalado ninguna de las dos PWA. Lo verificado son los recursos generados y sus dimensiones, no su render por el sistema.
- 11-18: si `Firebase.initializeApp` fallara, no habria primer frame y el shell de carga se quedaria en "Cargando" indefinidamente — NO hay pantalla de error. Deuda conocida.
- 11-18: `npm run verify:shell` exige `flutter build web --release` previo en las dos apps y Chrome instalado; falla ruidosamente si falta cualquiera de los dos (no se auto-desactiva).
- 11-09: UX-02 y UX-04 tampoco existen en .planning/REQUIREMENTS.md (mismo motivo que el resto de IDs de la Fase 11): `requirements.mark-complete` los devuelve como not_found. Quedan en el frontmatter del SUMMARY.
- 11-09: `panel_admin/test/router_404_test.dart` lleva el MISMO filtro de `A RenderFlex overflowed` que `bootstrap_router_test.dart` (desborde de 85px del sidebar del AppShell, deuda preexistente de 11-07). Al corregir el sidebar hay que retirar el filtro en LOS DOS archivos.
- 11-09: `test:rules` y `test:functions` NO se ejecutaron en este plan — dependen de los emuladores y 11-08 los estaba usando en paralelo (colision de puertos). El plan no toca rules, indexes ni functions. Si se ejecutaron `audit:indexes` y `audit:branding`, ambos exit 0.
- 11-09 PENDIENTE DE VERIFICACION HUMANA: que los copies nuevos SE LEAN bien y que las pantallas se VEAN bien en un dispositivo real. Un widget test prueba que una cadena se renderiza, no que este bien escrita. Tampoco se ha comprobado que el emoji del 404 se renderice en Android/Chrome reales (en flutter test se pinta como un cuadro y el test pasaria igual si faltara el glifo), ni que el 404 se alcance escribiendo la URL en la barra del navegador del panel (los tests navegan con router.go()).
- 11-11: DS-01 tampoco existe en .planning/REQUIREMENTS.md (mismo motivo que el resto de IDs de la Fase 11): `requirements.mark-complete DS-01` devuelve not_found. Queda en el frontmatter del SUMMARY.
- 11-11 CAMBIO VISUAL DELIBERADO Y ACOTADO (unico del plan): registrar elevatedButtonTheme alinea los 2 ElevatedButton del panel que NO declaraban estilo (reportes_screen.dart:140 "Consultar" y reservas_screen.dart:221 "Marcar ocupada"), que renderizaban #FFF1ED sobre #8F4C37 — el derivado de ColorScheme.fromSeed, que NO es la marca — con el naranja #FF4C05 de los otros 10 CTA. PENDIENTE DE VERIFICACION HUMANA: no se ha visto renderizado. Revertirlo es borrar elevatedButtonTheme de griTheme (la rotura M confirma que el test lo detecta).
- 11-11: `test:rules` y `test:functions` NO se ejecutaron — dependen de los emuladores y 11-10 estaba en vuelo tocando firestore.rules. El plan no toca rules, indices ni functions. Si se ejecutaron `audit:indexes` (22 queries, 0 fallos, exit 0) y `audit:branding` (exit 0).
- 11-11 PENDIENTE DE VERIFICACION HUMANA: que la escala GriText sea la correcta para el mockup. Se derivo CONTANDO los TextStyle inline mas repetidos, no de un diseno.
- 11-13: DS-02 y DS-03 tampoco existen en .planning/REQUIREMENTS.md (mismo motivo que el resto de IDs de la Fase 11): `requirements.mark-complete` los devuelve como not_found. Quedan en el frontmatter del SUMMARY.
- 11-13 PENDIENTE DE VERIFICACION HUMANA: (1) el espacio superior en un movil REAL con notch — es literalmente lo que reporto el usuario y flutter test no puede cerrarlo del todo; (2) el aspecto a >=840px en un navegador (columna de 720); (3) los 37 iconos, en especial soup_kitchen_outlined ("cocinando") y sensors ("en vivo"), y el gris de los estados vacios, que es el UNICO color nuevo del plan; (4) que el Wrap de los controles del Stepper se vea igual que el Row cuando los dos botones caben.
- 11-13 AVISO PARA 11-14: el boton QR de la home sigue midiendo 45x45 (< 48 de Material) y hay un test que lo CONGELA en 45 — al subirlo hay que actualizar test/restaurantes/iconos_test.dart. Los iconos sin texto al lado ya llevan semanticLabel.
- 11-13 AVISO PARA 11-19: todo Icon sale de GriIcons y su `size` esta atado al fontSize del Text que sustituyo; si mueves codigo, actualiza los archivo:linea de docs/ICONOS-app_cliente.md.
- 11-13 (AJENO, sin commitear): `app_cliente/lib/features/restaurantes/restaurantes_provider.g.dart` aparecio REGENERADO por build_runner durante la ejecucion sin que este plan lo ejecutara. Queda en el arbol de trabajo sin estagear y sin explicacion. Tambien quedan sin estagear los 13 archivos de panel_admin (11-21, en vuelo) y .planning/config.json (parallelization 1 -> 3, del orquestador).
- 11-19: DS-01 tampoco existe en .planning/REQUIREMENTS.md (mismo motivo que el resto de IDs de la Fase 11); ya lo reporto 11-11. Queda en el frontmatter del SUMMARY.
- 11-19 AVISO PARA 11-12: (1) NO migres los fontSize inline del panel a textTheme.* — no es pixel-neutral (medicion en 11-19-SUMMARY.md); usa GriText. (2) `panel_admin/test/core/sin_hex_crudos_test.dart` NO existia al escribir el del cliente (11-12 no habia corrido): el gate de app_cliente es el ORIGINAL y hay que PORTARLO, no escribir otro.
- 11-19 AVISO PARA 11-14: el rol de texto secundario del cliente vive ahora en `GriText.auxiliar.copyWith(color: GriColors.gray)` en 7 sitios — un unico patron buscable, no 7 literales. GriColors.gray sigue siendo #777777 con dos tests que lo impiden cambiar.
- 11-19 (DEUDA): `docs/ICONOS-app_cliente.md` lleva `archivo:linea` que este plan ha desplazado en 13 pantallas (lo aviso el propio 11-13). No se actualizo: fuera de alcance.
- 11-19 PENDIENTE DE VERIFICACION HUMANA: que la app se vea EXACTAMENTE igual que antes. Lo demostrado es que ningun valor numerico ni de color cambio (auditoria mecanica, 0 diferencias en 16 archivos); que el render sea identico se sigue por construccion pero NO se ha fotografiado — este repo no tiene golden tests.
- 11-19: `test:rules` y `test:functions` NO se ejecutaron (el plan no toca rules, indices ni functions). Si se ejecutaron `audit:branding` y `audit:indexes`, ambos exit 0.
- 11-19 (AJENO, sigue sin commitear): `app_cliente/lib/features/restaurantes/restaurantes_provider.g.dart` sigue regenerado por build_runner sin que ningun plan lo reclame (ya declarado por 11-13). 11-19 NO lo estageo: no ejecuto build_runner ni toco ningun @riverpod.
- 11-19 (DISCREPANCIA DE CONTABILIDAD, preexistente): en disco hay 16 *-SUMMARY.md de la Fase 11 y `roadmap.update-plan-progress 11` cuenta 16, pero la lista de arriba solo marca 15 — **11-17 tiene SUMMARY pero nunca se anadio a este checklist**. No lo corrige 11-19 porque no es su trabajo; queda senalado para quien cierre la fase.
