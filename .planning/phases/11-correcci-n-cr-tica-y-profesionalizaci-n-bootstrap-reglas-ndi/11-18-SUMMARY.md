---
phase: 11-correcci-n-cr-tica-y-profesionalizaci-n-bootstrap-reglas-ndi
plan: 18
subsystem: branding / ui (identidad GRI en las dos apps)
tags: [branding, pwa, manifest, favicon, adaptive-icon, splash, android-12, flutter-launcher-icons, flutter-native-splash, sdf, cdp, chrome-headless, gate]

# Dependency graph
requires:
  - plan: 11-02
    provides: contexto de arranque de las dos apps (main() hace await bootstrap() antes de runApp)
  - plan: 11-03
    provides: scripts/audit_indexes.mjs — convención de gate estático en scripts/ (RAIZ desde import.meta.url, exit 1, cabecera "POR QUÉ EXISTE / LIMITACIÓN")
provides:
  - "app_cliente/tool/gen_branding.dart — generador determinista de los 13 assets de marca de LAS DOS apps, sin fuentes ni descargas"
  - "Identidad GRI en index.html y manifest.json de app_cliente y panel_admin (título, descripción, theme_color #FF4C05, background propio de cada app)"
  - "Shell de carga con marca en las dos apps, retirado con el evento flutter-first-frame del engine"
  - "scripts/audit_branding.mjs + npm run audit:branding — gate anti-regresión sobre los 4 archivos web"
  - "scripts/verify_loading_shell.mjs + npm run verify:shell — verificación REAL en Chrome headless por CDP de que el shell desaparece"
  - "Icono de launcher (adaptive) y splash (incl. Android 12+) de la app móvil"
  - "README.md reales en las dos apps (eran la plantilla de flutter create)"
affects: [11-13, 11-15, 11-16, 11-19, 11-20, 11-21]

# Tech tracking
tech-stack:
  added:
    - "image 4.9.1 (dev_dependency de app_cliente, pin exacto)"
    - "flutter_launcher_icons 0.14.4 (dev_dependency de app_cliente, pin exacto)"
    - "flutter_native_splash 2.4.8 (dev_dependency de app_cliente, pin exacto)"
  patterns:
    - "El logo ES CÓDIGO: se dibuja con SDF + antialias analítico, sin fuentes ni emoji, para que el PNG sea bit a bit idéntico en cualquier máquina y el script sea idempotente"
    - "Un gate de branding no basta con buscar cadenas: comprueba también que los iconos declarados existen, son PNG y MIDEN lo que el manifest promete"
    - "Cuando el gate del plan no puede detectar la amenaza que el propio plan declara, se añade el gate que sí puede (aquí: Chrome headless por CDP para T-11-18-02)"
    - "Un archivo AUSENTE es un FALLO del gate, nunca un 'nada que revisar'"

key-files:
  created:
    - app_cliente/tool/gen_branding.dart
    - app_cliente/assets/branding/icon_1024.png
    - app_cliente/assets/branding/icon_512.png
    - app_cliente/assets/branding/icon_foreground_1024.png
    - scripts/audit_branding.mjs
    - scripts/verify_loading_shell.mjs
    - app_cliente/android/app/src/main/res/mipmap-anydpi-v26/ic_launcher.xml
    - app_cliente/android/app/src/main/res/values/colors.xml
    - app_cliente/android/app/src/main/res/values-v31/styles.xml
    - app_cliente/android/app/src/main/res/values-night-v31/styles.xml
  modified:
    - app_cliente/web/index.html
    - app_cliente/web/manifest.json
    - panel_admin/web/index.html
    - panel_admin/web/manifest.json
    - app_cliente/web/favicon.png + web/icons/*.png
    - panel_admin/web/favicon.png + web/icons/*.png
    - app_cliente/pubspec.yaml
    - app_cliente/android/app/src/main/AndroidManifest.xml
    - app_cliente/android/app/src/main/res/mipmap-*/ic_launcher.png
    - app_cliente/android/app/src/main/res/drawable*/launch_background.xml
    - app_cliente/README.md
    - panel_admin/README.md
    - scripts/package.json

key-decisions:
  - "El glifo se dibuja con primitivas geométricas y NO con la fuente del emoji 🍽️ del mockup: el rasterizado de una fuente depende de versión, hinting y sistema, y el mismo comando daría PNG distintos en dos máquinas"
  - "`flutter build web --release` NO puede detectar un shell de carga atascado, que es exactamente la amenaza T-11-18-02 del plan. Se añade verify:shell (Chrome headless por CDP), verificado por rotura: con el evento mal escrito el shell sigue ahí a los 60s y el gate sale con 1"
  - "adaptive_icon_foreground_inset: 0 y glifo al 58%: con el 16% por defecto de flutter_launcher_icons la zona segura se aplicaba DOS veces y el glifo quedaba diminuto sobre el naranja"
  - "Se pinea image 4.9.1 y no la 4.9.2, publicada 14 horas antes de ejecutar el plan: una versión recién salida no ha tenido exposición (T-11-18-SC)"
  - "El azul #0175C2 y el lema de plantilla quedan en UN solo archivo del repo: scripts/audit_branding.mjs, que es el detector. Cualquier otra aparición es un fallo"

patterns-established:
  - "Verificación por rotura deliberada también en gates no-de-seguridad: 18 roturas en este plan (15 del audit de branding, 3 del gate del shell), todas revertidas"
  - "Los fondos de las dos apps DIFIEREN a propósito (#F7F7F7 cliente / #F5F6F8 panel) y el gate los afirma por separado: igualarlos sería un 'arreglo' equivocado"

requirements-completed: [UX-03]

# Metrics
duration: ~31min
completed: 2026-08-19
---

# Phase 11 Plan 18: Branding GRI en las dos apps Summary

**Las DOS apps dejan de servir la plantilla de `flutter create`: cero rastros de "A new Flutter project" y del azul de demo `#0175C2` en todo el repo, logo GRI generado por código (no hay un solo PNG aportado a mano), shell de carga que tapa la espera de Firebase — y dos gates automatizados, uno de ellos añadido porque el que pedía el plan no podía detectar la amenaza que el propio plan declaraba.**

## Performance

- **Duration:** ~31 min
- **Started:** 2026-08-19T17:46:26Z
- **Completed:** 2026-08-19T18:17:42Z
- **Tasks:** 3/3
- **Files created:** 10 · **modified:** ~45 (incluye 13 assets generados + 30 recursos Android)

## Accomplishments

- **El defecto era real y estaba en las DOS apps, no solo en el panel.** Verificado archivo por archivo antes de tocar nada: `app_cliente/web/index.html:21` y `manifest.json:8` decían literalmente `A new Flutter project.`, `index.html:32` tenía `<title>gri_cliente</title>`, y `manifest.json:7` usaba `#0175C2` — el azul de demo de Flutter, que ni siquiera es el color de marca. El panel, idéntico.
- **El logo es código, no un binario opaco.** No existe ningún archivo de logo en el repo (`documentos/` solo tiene mockups y capturas), así que `tool/gen_branding.dart` lo **dibuja**: cuadrado redondeado (radio 27% del lado, la proporción del mockup) en `#FF4C05` y un glifo blanco de plato con cubiertos hecho con campos de distancia con signo y antialias analítico. Sin fuentes, sin emoji, sin descargas. Un solo comando produce los 13 assets de las dos apps y el segundo pase escribe **0 archivos** (idempotente); el favicon del cliente y el del panel salen con el **mismo md5**.
- **El shell de carga tenía sentido y ahora está probado.** `main()` hace `await bootstrap()` (Firebase) **antes** de `runApp` en las dos apps — verificado en `main.dart` — así que la pestaña quedaba en blanco toda esa espera y se leía como "roto". Ahora hay un shell de marca que se retira con el evento `flutter-first-frame` del propio engine, medido en **837ms (cliente) y 904ms (panel)** en un Chrome de verdad.
- **Se añadió el gate que faltaba.** El plan mitiga T-11-18-02 ("shell que no se retira → app inutilizable") con `flutter build web --release`. Ese gate **no puede detectarlo**: se demostró rompiendo el enganche y comprobando que la app compila igual y el shell se queda para siempre. `npm run verify:shell` abre las dos apps en Chrome headless por CDP y falla de verdad (exit 1) en ese caso.
- **Cero rastros en TODO el repo, no solo en `web/`.** El grep del plan solo cubría `app_cliente/web` y `panel_admin/web`; ampliándolo aparecieron los dos `README.md` con la plantilla intacta. Se reescribieron. Hoy `A new Flutter project` y `#0175C2` solo existen dentro de `scripts/audit_branding.mjs`, que es el detector.
- **Sin regresiones.** app_cliente 112, panel_admin 157 (**269** en apps), rules 208, functions 11, `analyze` 0 issues en las dos, `audit:indexes` 0 fallos. Ninguna cuenta bajó.

## Task Commits

| # | Tarea | Commit |
|---|---|---|
| 1 | Generador determinista de los assets de marca (13 assets, 2 apps) | `69d1481` (feat) |
| 2 | Branding web de las dos apps + shell de carga + `audit:branding` + `verify:shell` | `fa4fe06` (feat) |
| 3 | Icono adaptive y splash (incl. Android 12+) de la app móvil | `12b97e5` (feat) |

> Entre el commit 1 y el 2 aparecieron en el historial dos commits de documentación ajenos a este plan (`e6c8624`, `c7bdd42`, planificación de 11-13/11-21). No tocan ningún archivo de este plan; se anotan para que la lectura del `git log` no confunda.

## Gates ejecutados (salida real)

| Gate | Comando | Resultado |
|---|---|---|
| Baseline previo cliente | `flutter analyze && flutter test` | `No issues found!` · `+112: All tests passed!` |
| Baseline previo panel | `flutter analyze && flutter test` | `No issues found!` · `+157: All tests passed!` |
| T1 assets | `dart run tool/gen_branding.dart && test -s …` | `BRANDING_OK: 13 assets (13 escritos, 0 sin cambios)` · `ASSETS_OK` |
| T1 idempotencia | segunda ejecución del generador | `BRANDING_OK: 13 assets (0 escritos, 13 sin cambios)` |
| T1 determinismo | `md5sum` favicon e Icon-512 de las dos apps | `3fe8bd8e…` y `766685df…` **idénticos** entre apps |
| T1 analyze | `cd app_cliente && flutter analyze` | `No issues found!` |
| T2 branding | `cd scripts && npm run audit:branding` | `AUDIT BRANDING OK · 2 apps · 4 archivos revisados · 0 rastros de plantilla` · exit 0 |
| T2 build panel | `flutter build web --release` | `✓ Built build\web` (tras desbloquear el caché obsoleto, ver desviación 2) |
| T2 build cliente | `flutter build web --release` | `✓ Built build\web` |
| T2 evento real | `grep -c flutter-first-frame build/web/main.dart.js` | `1` en las dos apps — el engine **sí** emite ese evento (no es un nombre inventado) |
| T2 shell | `cd scripts && npm run verify:shell` | `OK app_cliente · shell retirado en 837ms` · `OK panel_admin · 904ms` · exit 0 |
| T3 icono | `test $(stat -c%s …/mipmap-hdpi/ic_launcher.png) -gt 1000` | `ICONO_OK (3324 bytes, antes 544)` |
| T3 splash | `grep -c "You can insert your own image assets here" launch_background.xml` | `0` en `drawable/` y en `drawable-v21/` |
| T3 analyze+test | `cd app_cliente && flutter analyze && flutter test` | `No issues found!` · `+112: All tests passed!` |
| Verificación del plan | `grep -rn "A new Flutter project\|#0175C2" app_cliente/web panel_admin/web` | rc=1 (sin resultados) — `SIN_RASTROS_OK` |
| Ampliación | mismo grep, case-insensitive, sobre `app_cliente` y `panel_admin` enteros | rc=1 tras reescribir los dos README |
| Final cliente | `flutter analyze && flutter test` | `No issues found!` · `+112: All tests passed!` |
| Final panel | `flutter analyze && flutter test` | `No issues found!` · `+157: All tests passed!` |
| Rules | `cd scripts && npm run test:rules` | `pass 208 · fail 0` · `Script exited successfully (code 0)` |
| Functions | `cd scripts && npm run test:functions` | `tests 11 · pass 11 · fail 0` |
| Índices | `cd scripts && npm run audit:indexes` | `21 queries analizadas · 4 sujetas a paridad · 0 fallo(s)` |
| Shell tras rebuild final | `npm run verify:shell` | `OK` en las dos · exit 0 |

**Conteos: apps 269 (112 + 157, sin cambio), rules 208, functions 11. Ninguno bajó.**

## Verificación por ROTURA DELIBERADA (18 roturas, todas revertidas)

Un gate en verde no prueba nada hasta que se rompe lo que protege y se comprueba que **sale en rojo por el motivo correcto**. Las 15 primeras se aplicaron sobre copias de seguridad de `web/` y se revirtieron restaurando la copia; las 3 últimas sobre `build/web`.

### `npm run audit:branding` (15 roturas, exit 1 en las 15)

| # | Rotura | Hallazgo reportado |
|---|---|---|
| R1 | `theme_color` → `#0175C2` (cliente) | **2 fallos**: el escaneo literal del azul **y** la comprobación de `theme_color` |
| R2 | `A new Flutter project.` en el `index.html` del panel | `contiene el lema de plantilla` |
| R3 | `<title>gri_cliente</title>` | `<title> es el nombre del paquete Dart` |
| R4 | `name` → `gri_panel_admin` | `"name" es el nombre del paquete Dart` |
| R5 | quitar `<meta name="theme-color">` del cliente | `falta <meta name="theme-color">` |
| R6 | `background_color` del panel igualado al del cliente | `"background_color" es "#F7F7F7" y debe ser #F5F6F8` |
| R7 | borrar `web/icons/Icon-512.png` | `declarado en manifest.json pero NO existe en disco` |
| R8 | favicon del panel a 0 bytes | `existe pero está VACÍO (0 bytes)` |
| R9 | `Icon-192.png` deja de ser un PNG | `no es un PNG válido (cabecera IHDR ilegible)` |
| R10 | `Icon-192.png` con el contenido del de 512 | `mide 512x512 pero el manifest declara "192x192"` |
| R11 | **borrar `app_cliente/web/index.html`** | `no existe` — el gate **no** queda verde por ausencia de archivo |
| R12 | manifest con 3 iconos en vez de 4 | `declara 3 iconos y se esperan 4` |
| R13 | `description` recortada a `Panel` | `"description" ausente o demasiado corta para ser real` |
| R14 | `short_name` → `Mi App` | `"short_name" no menciona la marca GRI` |
| R15 | `apple-mobile-web-app-title` → `gri_panel_admin` | `apple-mobile-web-app-title es el nombre del paquete Dart` |

Tras revertir las 15: `AUDIT BRANDING OK`, exit 0, y `git status` de `web/` solo con los 4 archivos que el plan manda cambiar (los 10 PNG volvieron byte a byte a su estado commiteado).

### `npm run verify:shell` (3 roturas)

| # | Rotura | Resultado | Exit real |
|---|---|---|---|
| R16 | borrar entero el `<script>` de retirada del build del cliente | `FALLO app_cliente → el shell #gri-loading SIGUE en el DOM tras 60380ms`; el panel intacto sigue en OK | 1 |
| R17 | el listener del panel escucha `'jamas-ocurre'` en vez de `'flutter-first-frame'` | `FALLO panel_admin → … tras 60174ms`; el cliente intacto sigue en OK | 1 |
| R18 | falta `panel_admin/build/web/index.html` | `ERROR: falta panel_admin/build/web/index.html. Ejecuta antes: …` | 1 |

Los exit codes se comprobaron **de verdad** (`npm run verify:shell > /dev/null; echo $?`), no por el texto impreso: `1` en las tres roturas y `0` tras revertir. Ver la sección siguiente: en el primer intento el `$?` medido era el de un subshell y daba 0 con el gate en rojo.

## Caza de verdes (y rojos) por el motivo equivocado

**Encontrados tres. Se reportan sin maquillar.**

**1. El gate que el plan asigna a T-11-18-02 no puede detectar T-11-18-02.**
El `<threat_model>` dice que la mitigación de "shell de carga que no se retira" es `flutter build web --release` en las dos apps. Es falso, y se demostró: en R16 y R17 el `index.html` roto **compila perfectamente** (`✓ Built build\web`) y la app queda con un overlay `position: fixed; inset: 0; z-index: 2147483647` que ningún clic atraviesa. Un plan que se hubiera limitado a los gates listados habría entregado, sin enterarse, una app inutilizable. De ahí `verify_loading_shell.mjs`.

**2. Un ROJO por el motivo equivocado: el primer intento de verificación headless dio un falso negativo.**
Se empezó con `chrome --headless --virtual-time-budget=25000 --dump-dom`, que informó de que el shell **seguía presente** en el cliente. Antes de "arreglar" nada se instrumentó la página con sondas: no llegaba **ningún** evento (`flutter-first-frame`, `flutter-initialization-complete`), ni errores, ni rechazos — solo los temporizadores. El tiempo virtual corre mucho más rápido que la red real, así que el presupuesto se agotaba antes de que CanvasKit y el SDK JS de Firebase terminaran de descargarse: la app nunca llegaba a pintar. Con tiempo real y sondeo por CDP, el shell desaparece en <1s en las dos apps. **Si se hubiera aceptado el primer resultado, se habría "arreglado" un código que ya era correcto.**

**3. La aserción `<title> menciona GRI` NO es la que caza el título de plantilla.**
En R3 el título roto es `gri_cliente`, que en mayúsculas contiene `GRI`: esa comprobación pasa. Lo que lo caza es la lista de nombres de paquete Dart. La comprobación de marca sigue teniendo dientes por su cuenta (R14, `Mi App`), pero **queda dicho que no cubre el caso de plantilla**; las dos son necesarias.

**Cuarto candidato revisado y descartado:** que el favicon y los iconos "existan" pudiera pasar con un asset heredado de Flutter. R9 y R10 lo descartan: el gate lee la cabecera IHDR y compara las dimensiones contra lo que promete el `manifest.json`, así que un PNG cambiado o truncado cae.

**Quinto, sobre la medición:** el `EXIT=${PIPESTATUS[0]}` del primer barrido de R16–R18 medía el subshell `( cd scripts && … )` y devolvía `0` con el gate imprimiendo `FALLO`. Es el mismo tipo de error que 11-06 documentó con `grep -rc … | grep -q '^0$'`. Se repitió la medición sin tubería ni subshell y los códigos reales son los de la tabla.

## Deviations from Plan

**1. [Regla 2 — Funcionalidad crítica ausente] Se añade `scripts/verify_loading_shell.mjs` (+ `npm run verify:shell`), que el plan no pedía**

- **Found during:** Tarea 2.
- **Issue:** el plan declara T-11-18-02 (shell que no se retira → app inutilizable) y le asigna como mitigación `flutter build web --release`. Ese gate es ciego a esa amenaza (ver "caza de verdes", punto 1). Sin nada más, la retirada del shell quedaría **afirmada por lectura de código**, en un plan cuyo cambio más arriesgado es precisamente ese overlay a pantalla completa.
- **Fix:** script que sirve `build/web` de cada app, la abre en Chrome headless por CDP y sondea el DOM hasta que `#gri-loading` desaparece. Falla si falta el build o si no encuentra Chrome (no se auto-desactiva).
- **Verification:** roturas R16, R17 y R18, con exit code real 1 en las tres.
- **Committed in:** `fa4fe06`.

**2. [Regla 3 — Bloqueante] `.dart_tool/flutter_build/` obsoleto impedía `flutter build web` en las DOS apps**

- **Found during:** Tarea 2, primer `flutter build web --release` de la fase.
- **Issue:** el `web_plugin_registrant.dart` cacheado seguía importando `package:flutter_secure_storage_web`, dependencia retirada en la migración a Firebase de la Fase 10. `flutter pub get` **no** lo regenera. Nada que ver con este plan: los dos `pubspec.yaml` están correctos.
- **Fix:** borrar `<app>/.dart_tool/flutter_build/` (directorio generado, gitignorado — **no** se usó `git clean`). Tras eso las dos apps compilan.
- **Registrado en:** `deferred-items.md`, porque le va a pasar a cualquiera que arranque el bloque 4 con un `.dart_tool` heredado.

**3. [Regla 2] Los dos `README.md` seguían siendo la plantilla de `flutter create`**

- **Found during:** Tarea 2, al ampliar el grep del plan más allá de `web/`.
- **Issue:** el criterio de éxito es "cero rastros de `A new Flutter project`", y `app_cliente/README.md:3` y `panel_admin/README.md:3` lo tenían literalmente, junto con los títulos `# gri_cliente` y `# gri_panel_admin`.
- **Fix:** README reales (qué es cada app, cómo arrancarla, comandos, cómo se regenera la marca).
- **Committed in:** `fa4fe06`.

**4. [Regla 2] `android:label="gri_cliente"` — el último texto de plantilla visible en el móvil**

- **Found during:** Tarea 3.
- **Issue:** el icono pasa a ser GRI pero debajo, en el lanzador de Android y en el conmutador de apps, seguía leyéndose `gri_cliente`. `AndroidManifest.xml` no está en los `files_modified` del plan, pero el plan **sí** habla de ese archivo (para avisar del cambio ajeno sin commitear).
- **Fix:** `android:label="GRI"`. Se commiteó **solo esa línea**, ver desviación 5.
- **Committed in:** `12b97e5`.

**5. [Manejo del cambio ajeno, exigido por el plan] Qué se conservó de `AndroidManifest.xml` y `res/xml/`**

- El árbol de trabajo traía, **sin commitear**, `android:networkSecurityConfig="@xml/network_security_config"` en `AndroidManifest.xml` (más un BOM al inicio del archivo) y el directorio **sin seguimiento** `res/xml/network_security_config.xml`, que permite HTTP plano solo hacia `10.0.2.2`, `127.0.0.1` y `localhost` para los emuladores.
- **`flutter_launcher_icons` reescribe `AndroidManifest.xml`** (le quitó el BOM en las dos ejecuciones). Se hizo copia de seguridad antes de correr los generadores y se restauró byte a byte después; el `networkSecurityConfig` nunca se perdió. `flutter_native_splash` no tocó el archivo (md5 idéntico antes y después).
- Para commitear el `android:label` **sin arrastrar el cambio ajeno**: se llevó el archivo a la versión de HEAD, se aplicó solo el cambio de label, se hizo `git add`, y después se restauró en el árbol de trabajo la copia del usuario con ese mismo cambio de label aplicado. Resultado verificado: el commit contiene **una sola línea** (`android:label`), y `git diff` sigue mostrando exactamente el delta ajeno de antes (BOM + `networkSecurityConfig`). `res/xml/` **sigue sin seguimiento y sin tocar**, igual que `documentos/google-services.json`, `documentos/sdk.png` y `run_app.bat`.

**6. [Regla 1 — Corrección] La zona segura del adaptive icon se estaba aplicando dos veces**

- **Found during:** Tarea 3, tras la primera pasada de `flutter_launcher_icons`.
- **Issue:** el asset de primer plano ya venía con el glifo reducido (62% del lienzo) para caber en la zona segura, y `flutter_launcher_icons` le añade por defecto `android:inset="16%"` en `ic_launcher.xml`. Efecto compuesto: el glifo quedaba en ~42% del lienzo, diminuto dentro del naranja.
- **Fix:** `adaptive_icon_foreground_inset: 0` (clave soportada por 0.14.4, comprobado en el código del paquete) y el glifo ajustado de 0.62 a **0.58**, con el cálculo escrito en el propio generador: punto más alejado a 0.284 del lienzo ≈ 30.7dp sobre los 108dp del adaptive icon, dentro de los 33dp de radio seguro. Medido después sobre el PNG generado: caja del glifo de **0.449 del lienzo, centrada**.
- **Committed in:** `12b97e5`.

**7. [Endurecimiento de T-11-18-SC] Se pinea `image` 4.9.1, no la última**

- El plan manda verificar el publisher y pinear versión exacta. Publishers comprobados por la API de pub.dev: `image` → `loki3d.com`, `flutter_launcher_icons` → `fluttercommunity.dev`, `flutter_native_splash` → `jonhanson.net`.
- La última de `image` era la **4.9.2, publicada 14 horas antes** de ejecutar el plan. Se pinea la **4.9.1** (2026-05-30): una versión recién salida no ha tenido exposición y las tres son `dev_dependencies` (no entran en el binario de producción). El motivo queda escrito en el `pubspec.yaml`.

**8. [Fuera de alcance, registrado] `orientation: portrait-primary` en el manifest del panel**

- Heredado de `flutter create`. En el cliente es correcto; en el panel bloquearía una PWA instalada en vertical, y el panel está diseñado a partir de 1100px. No es un valor de marca y la tabla del plan no lo incluye. Registrado en `deferred-items.md` para el bloque de responsive.

---

**Total deviations:** 8 (2 ampliaciones por funcionalidad crítica ausente, 1 bloqueante de entorno, 1 corrección, 1 endurecimiento, 1 manejo de cambio ajeno, 1 diferido, 1 README). **Ninguna reduce alcance y ninguna aserción se relajó para poner algo en verde.**

## Mitigaciones del threat model

| Threat ID | Estado | Evidencia |
|---|---|---|
| T-11-18-SC (dependencias nuevas de pub.dev) | **Mitigado y verificado** | Publisher de las 3 consultado por API antes de instalar (`loki3d.com`, `fluttercommunity.dev`, `jonhanson.net`) y pin EXACTO en `pubspec.yaml`. `image` fijada a 4.9.1 y no a la 4.9.2 recién publicada. Las tres son `dev_dependencies` |
| T-11-18-02 (shell de carga que no se retira) | **Mitigado y verificado — con gate NUEVO** | El gate que pedía el plan (`flutter build web --release`) es **ciego** a esta amenaza: demostrado en R16/R17, donde el build es verde y el shell se queda. `npm run verify:shell` lo caza con exit 1. En verde: 837ms y 904ms |
| T-11-18-03 (fuga por el shell de carga) | **Aceptado, sin cambio** | El shell solo contiene el icono, el wordmark, un indicador y la palabra "Cargando". Ningún dato ni configuración; el `<script>` solo registra un listener |
| T-11-18-04 (regresión a los valores de plantilla) | **Mitigado y verificado** | `npm run audit:branding` sobre las dos apps, **15 roturas deliberadas** con exit 1 en las 15, incluidas las que borran o vacían archivos |

## Qué está VERIFICADO y qué solo está AFIRMADO

**VERIFICADO (ejecutado y medido, no leído):**
- Que un solo comando genera los 13 assets de las dos apps, que la segunda pasada escribe **0 archivos**, y que el favicon y los iconos del cliente y del panel salen con el **mismo md5** (misma función pura).
- Que no queda **ninguna** ocurrencia de `A new Flutter project` ni de `#0175C2` en `app_cliente` ni en `panel_admin` (grep case-insensitive, rc=1), ni en el resto del repo salvo dentro del propio detector.
- Que `audit:branding` sale con **1** ante 15 regresiones distintas y con **0** tras revertirlas.
- Que las dos apps compilan para web con el `index.html` editado.
- Que el engine de esta versión de Flutter **sí** emite `flutter-first-frame` (1 ocurrencia en `main.dart.js` de cada app): no es un nombre de evento inventado.
- Que el shell **desaparece** en un Chrome real en las dos apps, y que **no** desaparece si se rompe el enganche (exit 1 real).
- Que `mipmap-hdpi/ic_launcher.png` pasó de 544 a 3324 bytes y que `launch_background.xml` (normal y v21) ya no tiene el placeholder comentado.
- Que `android12splash.png` contiene el glifo centrado ocupando 0.449 del lienzo (medido pixel a pixel sobre el PNG, no a ojo).
- Que el commit del `android:label` contiene **una sola línea** y que el cambio ajeno sin commitear sigue exactamente igual.
- Que las suites no regresan: 112 + 157 + 208 + 11, `analyze` 0 issues.

**AFIRMADO, NO VERIFICADO — leer antes de confiar:**
- **Que el logo se VEA bien.** Se verifica que el PNG existe, que es un PNG válido, que mide lo que promete y que su geometría es la esperada. Que un humano lo lea como "plato con cubiertos" y lo considere digno de la marca **no es automatizable**: es sellado humano. El icono se inspeccionó visualmente durante la ejecución y se lee como un plato entre dos cubiertos, pero eso es un juicio, no un gate.
- **El icono y el splash en un Android real.** No se instaló la app en ningún dispositivo ni emulador Android; `flutter build apk` no se ejecutó (el plan no lo pide y la cadena Android no se ejercitó). Lo verificado son los **recursos generados**, no su render por el sistema.
- **La zona segura del adaptive icon** (30.7dp sobre 33dp) está **calculada**, no observada bajo la máscara real de un lanzador concreto. Los lanzadores aplican máscaras distintas (círculo, squircle, gota).
- **El splash de Android 12+.** `values-v31`/`values-night-v31` declaran `windowSplashScreenBackground`, `windowSplashScreenAnimatedIcon` e `IconBackgroundColor` correctamente, pero el splash de Android 12 lo dibuja el sistema y **no se ha visto arrancar**.
- **La legibilidad del favicon a 64px** y el aspecto de la pestaña real.
- **La instalación de la PWA.** El `manifest.json` es correcto por inspección y los cuatro iconos existen con sus dimensiones, pero **no se instaló** ninguna de las dos apps como PWA.
- **El comportamiento del shell con red lenta o caída.** Se midió con red normal (<1s). Si `Firebase.initializeApp` fallara, `runApp` no se ejecutaría, no habría primer frame y el shell **se quedaría** mostrando "Cargando" indefinidamente: es el comportamiento actual y **no hay pantalla de error**. Queda como deuda conocida.
- **El modo oscuro del splash.** `drawable-night-*` y `values-night-v31` se generaron con el mismo naranja; no se ha observado.

## Known Stubs

Ninguno. Los 13 assets están generados y referenciados; los cuatro nombres de `web/icons/` coinciden con los que ya declaraban los dos `manifest.json`, así que no se tocó ninguna ruta del PWA.

## Threat Flags

Ninguna superficie nueva fuera del `<threat_model>` del plan. `verify_loading_shell.mjs` es una herramienta **de desarrollo**: levanta un servidor estático y Chrome en `127.0.0.1`, no forma parte de ningún artefacto desplegado y no cruza ninguna frontera de confianza nueva.

## Issues Encountered

- **`flutter build web` roto en las dos apps por caché obsoleto** (desviación 2). Es el bloqueo que más tiempo consumió y no tiene nada que ver con el branding.
- **El primer método de verificación headless dio un falso negativo** (`--virtual-time-budget` + `--dump-dom`). Ver "caza de verdes", punto 2.
- **`flutter_launcher_icons` reescribe `AndroidManifest.xml`** aunque no cambie nada semántico (le quita el BOM). Con un cambio ajeno sin commitear en ese archivo, es una trampa: hay que hacer copia antes.
- **Python invocado desde Git Bash no entiende las rutas `/c/...`**: hay que pasarle `C:/...`. Un `cp` de restauración falló por eso y dejó momentáneamente el `AndroidManifest.xml` sin el cambio del usuario; se restauró desde la copia de seguridad y se verificó con `git diff`.
- `flutter_launcher_icons` imprime `⚠️Requirements failed for platform Web. Skipped`: es **lo deseado** — `web: generate: false`, los iconos de la PWA los produce `gen_branding.dart` con los nombres exactos que espera el manifest.

## Next Phase Readiness

**Para 11-13 / bloque de responsive y tokens:**
- `orientation: portrait-primary` del panel está en `deferred-items.md`.
- Los fondos `#F7F7F7` (cliente) y `#F5F6F8` (panel) están ahora afirmados **por app** en `audit_branding.mjs`. Si el sistema de tokens cambia `AppColors.background` de alguna app, hay que actualizar `backgroundEsperado` en ese script **en el mismo commit** o el gate se pone en rojo.

**Para 11-15 / 11-16 (runbook y smoke):**
- Añadir al runbook: si `flutter build web` falla con `Couldn't resolve the package 'flutter_secure_storage_web'`, borrar `<app>/.dart_tool/flutter_build/`.
- `npm run verify:shell` exige `flutter build web --release` previo en las dos apps.
- **Sellado humano pendiente:** ver el icono y el splash arrancando en un Android real, instalar las dos PWA y mirar la pestaña, el favicon y el instalador.

**Para cualquier plan que toque los assets:**
- No editar los PNG a mano. `cd app_cliente && dart run tool/gen_branding.dart` y, si cambia el icono base, volver a correr `dart run flutter_launcher_icons` y `dart run flutter_native_splash:create`.

## Self-Check: PASSED

Archivos declarados como creados — verificados en disco: `app_cliente/tool/gen_branding.dart`, `app_cliente/assets/branding/icon_1024.png`, `icon_512.png`, `icon_foreground_1024.png`, `scripts/audit_branding.mjs`, `scripts/verify_loading_shell.mjs`, `app_cliente/android/app/src/main/res/mipmap-anydpi-v26/ic_launcher.xml`, `values/colors.xml`, `values-v31/styles.xml`, `values-night-v31/styles.xml`.

Commits declarados — verificados en `git log`: `69d1481`, `fa4fe06`, `12b97e5`.

---
*Phase: 11-correcci-n-cr-tica-y-profesionalizaci-n-bootstrap-reglas-ndi*
*Completed: 2026-08-19*
