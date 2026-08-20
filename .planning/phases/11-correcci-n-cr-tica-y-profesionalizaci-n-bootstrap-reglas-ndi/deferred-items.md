# Hallazgos fuera de alcance (diferidos)

## 11-02 — StatCard desborda 31px a 4 columnas (panel_admin)

- **Encontrado durante:** 11-02 Tarea 3, al pumpear el dashboard con viewport de 1200px.
- **Qué pasa:** con `constraints.maxWidth >= 1100` el grid de stat cards pasa a 4 columnas
  (`dashboard_screen.dart:37-39`) y con `childAspectRatio: 2.6` cada card queda de ~104px de alto;
  el `Column` de `widgets/stat_card.dart:50` necesita ~91px de contenido sobre 59.8px disponibles
  → `RenderFlex overflowed by 31 pixels on the bottom`.
- **Por qué NO se arregla aquí:** `stat_card.dart` no está en los `files_modified` de 11-02 y el
  responsive/sistema de diseño es el bloque 3 de la fase. Tocarlo crearía conflicto de olas.
- **Dónde reaparecerá:** afecta a cualquier pantalla ancha real (el panel es web). Debe entrar en
  el plan de responsive/tokens del bloque 3.

## 11-07 — El sidebar del AppShell desborda 85px en el logo, a CUALQUIER ancho (panel_admin)

- **Encontrado durante:** 11-07 Tarea 3, al montar `GriApp` con sesión en `bootstrap_router_test.dart`
  (primer test del repo que renderiza `AppShell` completo; los tests del dashboard pumpean
  `DashboardScreen` suelta, así que este defecto nunca se había ejercitado).
- **Qué pasa:** el sidebar es un `Container(width: 220)` con `padding horizontal: 15` → 190px útiles.
  El `Row` del logo (`app_shell.dart:171`) mete un badge de 45px + 12px de hueco + un `Column` con
  los textos `GRI` y `Gestión de Restaurante`, que a 14px pide ~248px sin restricción de ancho:
  `A RenderFlex overflowed by 85 pixels on the right`. Un segundo `Row`
  (`app_shell.dart:264`, item del menú) desborda 33px por lo mismo.
- **No depende del viewport:** el ancho del sidebar es fijo, así que el desborde ocurre igual en
  800px que en 1920px. Es un defecto de layout real, visible en producción, no un artefacto de test.
- **Por qué NO se arregla aquí:** `app_shell.dart` no está en los `files_modified` de 11-07 y el
  responsive/sistema de diseño es el bloque 3 de la fase. Tocarlo cruzaría olas.
- **Mitigación temporal en el test:** `bootstrap_router_test.dart` filtra EXCLUSIVAMENTE las
  excepciones `A RenderFlex overflowed`, con el motivo documentado en el propio archivo. Cuando el
  bloque 3 corrija el sidebar, ese filtro debe RETIRARSE (y el test seguirá pasando).
- **Arreglo previsto:** envolver el `Column` de textos en `Expanded` (y el `Text(label)` del item
  del menú también), o dejar el sidebar en `collapsed` por debajo de un breakpoint.

## 11-18 — `orientation: portrait-primary` en el manifest del PANEL (panel_admin)

- **Encontrado durante:** 11-18 Tarea 2, al reescribir `panel_admin/web/manifest.json`.
- **Qué pasa:** el manifest hereda de `flutter create` la clave
  `"orientation": "portrait-primary"`. En la app cliente es correcto (es móvil), pero en el panel
  significa que una PWA instalada en tablet quedaría **bloqueada en vertical** — y el panel está
  diseñado a partir de 1100px de ancho (el grid de 4 columnas del dashboard, el sidebar de 220px).
- **Por qué NO se arregla aquí:** la tabla del bloque `<interfaces>` del plan 11-18 enumera
  exactamente qué claves se tocan (`name`, `short_name`, `description`, colores) y `orientation` no
  está. No es un valor de plantilla *de marca*, es una decisión de layout, y el responsive es el
  bloque 3 de la fase.
- **Arreglo previsto:** en el plan de responsive, poner `"orientation": "any"` (o retirar la clave)
  en `panel_admin/web/manifest.json` únicamente. `scripts/audit_branding.mjs` no comprueba esa clave,
  así que no hay que tocar el gate.

## 11-18 — `.dart_tool/flutter_build/` obsoleto rompe `flutter build web` en las DOS apps (entorno)

- **Encontrado durante:** 11-18 Tarea 2, primer `flutter build web --release` de la fase.
- **Qué pasa:** el `web_plugin_registrant.dart` cacheado en `.dart_tool/flutter_build/<hash>/`
  seguía importando `package:flutter_secure_storage_web`, dependencia que **ya no existe** (se fue
  con la migración a Firebase de la Fase 10). `flutter pub get` NO regenera ese archivo, así que
  ambas apps fallaban con `Couldn't resolve the package 'flutter_secure_storage_web'` aunque el
  `pubspec.yaml` esté perfecto.
- **Solución aplicada:** borrar `<app>/.dart_tool/flutter_build/` (directorio generado y
  gitignorado; NO se usó `git clean`). Tras eso las dos apps compilan.
- **Por qué queda anotado:** cualquiera que clone el repo con un `.dart_tool` heredado se va a topar
  con el mismo error y va a creer que el `pubspec.yaml` está mal. Debería mencionarse en el runbook
  de arranque del bloque 4.

## 11-21 — `MesaTile` se recorta 1.9px de alto por debajo de ~560px de ventana (panel)

- **Encontrado durante:** 11-21 Tarea 2, sondando el shell a 450/500/550/600px.
- **Medido:** a 550px de ventana (sidebar colapsado → 480 de contenido) el tile mide
  175×159.1 y su `Column` interior pide 121px en una caja de 119.1 → `A RenderFlex overflowed
  by 1.9 pixels on the bottom`, una vez por tile. A 600px ya no ocurre.
- **Por qué NO se arregla aquí:** el alto del tile sale de `childAspectRatio: 1.1`; bajarlo
  cambia el aspecto de la ficha de mesa a TODOS los anchos, y la decisión visual de la fase
  está bloqueada. Además el número es del entorno de test: con la fuente de test cada glifo
  ocupa 1 em, así que las tres líneas del tile piden 121px; con una fuente proporcional piden
  ~74 y sobra sitio. No hay evidencia de que se vea en producción.
- **Qué haría falta:** decidir con el usuario si a anchos < 600 el mapa de mesas debe bajar a
  1 columna (tiles más anchos y por tanto más altos) o si el tile debe tener una variante
  compacta. Es una decisión de diseño, no un arreglo.
- **Gate que lo cubriría:** el bucle de `test/shared/responsive_test.dart` está a 600px; bajarlo
  a 550 lo pone rojo el día que se decida.

## 11-26 — La cabecera de `docs/FIREBASE_SETUP.md` nombra fuentes de configuración que las apps no usan

- **Encontrado durante:** 11-26 Tarea 3, barriendo el documento.
- **Qué dice:** *«Fuentes de configuración: `documentos/google-services.json` (Android) y
  `documentos/firebase-config-web.js` (Web)»*.
- **Qué se midió:** las dos apps arrancan con `firebase_options.dart`
  (`app_cliente/lib/firebase_options.dart` y `panel_admin/lib/firebase_options.dart`, ambos
  existen). **No hay `google-services.json` en `app_cliente/android/app/`**, que es donde el
  plugin de Gradle lo buscaría. El que vive en `documentos/` es de otro registro
  (`package_name: gri.app`, no `com.gri.gri_cliente`) y sin ninguna entrada `oauth_client`
  — ya lo declaró `11-CONTEXT.md`.
- **Por qué NO se arregla aquí:** está fuera del alcance de este plan (que corrige los
  documentos que instruyen un **flujo imposible**, no todo el inventario de afirmaciones de
  `FIREBASE_SETUP.md`) y no lo causó ningún cambio de 11-26. Tocar la cabecera sin revisar el
  resto del documento dejaría la corrección a medias.
- **Por qué importa igualmente:** es la MISMA clase de defecto que originó la Fase 11 —
  documentación que describe una configuración que no es la real. Quien intente registrar la
  huella SHA-1 guiándose por esa línea buscará un archivo que no se usa.
- **Qué haría falta:** una pasada de revisión de `FIREBASE_SETUP.md` entera contra el árbol
  real, y decidir qué se hace con `documentos/google-services.json` (borrarlo o marcarlo como
  obsoleto). Media hora.

## 11-28 — Índices declarados que ya no sirven a ninguna consulta (Firestore)

- **Encontrado durante:** 11-28, al añadir el AUDIT 4/4 de `scripts/audit_indexes.mjs`.
- **Qué pasa:** seis índices compuestos declarados en `firestore.indexes.json` no los usa
  hoy ninguna consulta del código: `pedidos(restauranteId, estado, createdAt DESC)`,
  `pedidos(sesionId, createdAt ASC)`, `pedidos(usuarioId, createdAt DESC)`,
  `sesiones(usuarioId, estado)`, `sesiones(restauranteId, estado)` y
  `productos(restauranteId, categoriaId)`. Los dos primeros quedaron superados por los
  índices ASC que introdujo este plan; los otros cuatro venían de antes.
- **Por qué NO se podan aquí:** borrar una entrada de `firestore.indexes.json` **borra el
  índice en producción** en el siguiente `firebase deploy --only firestore:indexes`. Si
  alguna consulta manual, algún informe o algún trabajo futuro dependiera de ellos, el
  fallo aparecería lejos de este commit. La poda merece ser una decisión explícita, no un
  efecto colateral del arreglo de un P0.
- **Coste de no hacerlo:** almacenamiento y escrituras de índice, nada más. No hay riesgo
  de corrección.
- **Qué haría falta:** confirmar que nadie los usa fuera del repo y quitarlos en un commit
  propio. El AUDIT 4/4 los vuelve a listar en cada pasada de `npm run audit:indexes`.

## 11-28 — La pantalla de pedidos se queda en el spinner cuando no hay sesión (app_cliente)

- **Encontrado durante:** 11-28, escribiendo `app_cliente/test/pedidos/query_sesion_test.dart`
  (el tercer caso no podía usar `pumpAndSettle`: nunca converge).
- **Qué pasa:** `pedidosSessionProvider` devuelve un `Stream` VACÍO cuando no hay sesión
  (o no hay usuario), así que nunca emite y `pedidosAsync` se queda en `AsyncLoading` para
  siempre. `PedidoEstadoScreen` pinta su `CircularProgressIndicator` indefinidamente en
  lugar del vacío honesto «Aún no hay pedidos en esta sesión» / «Escanea el QR de la mesa».
- **Por qué NO se arregla aquí:** es comportamiento ANTERIOR a este plan —pasaba igual con
  `sesion == null`— y no lo causó el arreglo del P0. Cambiarlo es tocar el contrato del
  provider (emitir `[]` en vez de no emitir) y revisar quién más lo observa.
- **Por qué importa:** un spinner eterno es indistinguible de «está cargando» y de «se
  rompió». Es la misma clase de deshonestidad de UI que la Fase 11 viene corrigiendo.
- **Qué haría falta:** `yield <List<Pedido>>[]` en vez del stream vacío, y un caso en
  `query_sesion_test.dart` que exija el texto de estado vacío. Media hora.
