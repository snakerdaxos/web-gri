---
phase: 11-correcci-n-cr-tica-y-profesionalizaci-n-bootstrap-reglas-ndi
plan: 30
subsystem: app_cliente / menú
tags: [ui, carta, imagenes, app_cliente, responsive, a11y, datos-moviles]

# Dependency graph
requires:
  - phase: 10-02
    provides: "el campo `imagenUrl` del doc `productos/{id}` y `Producto.fromDoc` — el dato que llevaba desde entonces sin pintarse"
  - phase: 11-11
    provides: "GriSpacing / GriRadius / GriText — la carta no introduce ni un número nuevo"
  - phase: 11-13
    provides: "GriIcons.menu (el glifo del marcador) y el criterio de ancho adaptativo"
  - phase: 11-14
    provides: "el mínimo táctil de 48 dp y GriColors.textoSecundarioAccesible; las tres guías de a11y sobre el menú"
  - phase: 11-19
    provides: "el gate `sin_hex_crudos_test.dart` que prohíbe un color suelto"
provides:
  - "las fotos de los platos SE VEN en las dos pantallas de menú del cliente (antes: cero `Image` en las dos)"
  - "core/imagen_url.dart — saneado (solo http/s con host) y dimensionado por bucket de las URLs de foto"
  - "features/shared/foto_producto.dart — FotoProducto + PlaceholderPlato (fundido, caché, degradación)"
  - "features/shared/producto_card.dart — ProductoCard + ListaProductos (la carta y su rejilla)"
  - "menu_mesa_screen y restaurante_detalle_screen dejan de ser listas de ListTile"
  - "MEDIDO contra el CDN real: 88 KB por foto en móvil en vez de 176 KB (y de 2,0 MB sin `w`)"
affects: [panel_admin (deuda: no valida ni previsualiza la URL), scripts/seed_firebase.mjs (deuda: escribe imagenUrl null)]

# Tech tracking
tech-stack:
  added: []   # NINGUNA dependencia nueva — ver "Decisión: no se añade cached_network_image"
  patterns:
    - "El ancho de una imagen remota sale del LAYOUT, no de la URL que escribieron, y se redondea a un bucket: la URL es la clave del ImageCache y no puede bailar con cada píxel"
    - "A una URL ajena no se le AÑADEN parámetros (puede venir firmada); solo se reescribe el `w` que ella misma ya trae"
    - "Un recurso externo que falla se degrada al MISMO marcador que su ausencia: tres causas, un solo aspecto"
    - "Los objetivos táctiles nuevos se validan con meetsGuideline DENTRO del test del widget, no solo en la suite a11y"

key-files:
  created:
    - app_cliente/lib/core/imagen_url.dart
    - app_cliente/lib/features/shared/foto_producto.dart
    - app_cliente/lib/features/shared/producto_card.dart
    - app_cliente/test/core/imagen_url_test.dart
    - app_cliente/test/shared/foto_producto_test.dart
    - app_cliente/test/shared/producto_card_test.dart
    - app_cliente/test/pedidos/menu_carta_test.dart
  modified:
    - app_cliente/lib/features/pedidos/menu_mesa_screen.dart
    - app_cliente/lib/features/restaurantes/restaurante_detalle_screen.dart
    - app_cliente/test/pedidos/carrito_test.dart
    - app_cliente/test/a11y/a11y_test.dart
    - scripts/gates.mjs
    - .planning/phases/11-*/deferred-items.md

decisions:
  - "NO se añade `cached_network_image`: el ImageCache del framework ya cubre scroll y revisita dentro de la sesión, y esa dependencia arrastra flutter_cache_manager + sqflite + path_provider a un binario que hoy no los tiene"
  - "A la URL sin `w` no se le añade uno: puede venir firmada. El tamaño lo acota entonces `cacheWidth` (memoria), no la descarga"
  - "El dpr se topa en 2: en una FOTO el 3x no se distingue y triplica los datos del comensal"
  - "La tarjeta del menú de la mesa es pulsable (agrega el plato); la del detalle NO, porque allí no se pide nada"
  - "La rejilla cuenta columnas por ancho de lectura (~300 pt, máx 4) en vez de un breakpoint: /mesa y /restaurantes/:id viven FUERA del AppShell y no heredan su techo de 720 pt"

metrics:
  duration: "~2 h"
  completed: 2026-08-20
  commits: 11
  tests: "app_cliente 371 -> 408 (+37)"
---

# Phase 11 Plan 30: La carta del menú (fotos + rediseño) Summary

Las fotos que los 16 productos tenían guardadas desde la Fase 10 por fin se ven, pedidas al ancho que ocupan en pantalla (88 KB en vez de 176 KB por plato, medido contra el CDN real), y las dos pantallas de menú del cliente dejan de ser filas de `ListTile` para ser tarjetas con foto, descripción a dos líneas y precio grande en naranja de marca.

## Lo que reportó el usuario, y qué se hizo con cada cosa

| Lo que dijo | Qué pasaba de verdad | Qué se hizo |
|---|---|---|
| «el cliente en el menú no puede ver la imagen» | No había **ni un solo** `Image`/`NetworkImage` en `menu_mesa_screen.dart` ni en `restaurante_detalle_screen.dart`. El dato estaba, la UI no lo leía | `FotoProducto` en las dos, cableado desde `producto.imagenUrl` |
| «se ve como lista, no como carta» | `ListTile`: nombre, descripción a UNA línea y el precio de `trailing`, en el mismo tamaño que todo lo demás | `ProductoCard`: foto 16:9 arriba, nombre 16 bold, descripción a 2 líneas, precio 18 bold naranja, y el nombre de la categoría a 18 bold para que la sección mande |

## Lo que se construyó

**1. `core/imagen_url.dart` — la URL antes de que llegue a un `Image`.**
Tres funciones puras con 12 tests: `urlFotoSegura` (solo `http`/`https` con host; `''`, `'   '`, `javascript:`, `data:`, `file:`, `ftp:` y las cadenas sueltas son «no hay foto»), `anchoFotoSolicitado` (ancho del layout × dpr topado en 2, redondeado hacia arriba a bucket de 128 y acotado a 128–1024) y `urlFotoConAncho` (reescribe el `w` que la URL **ya trae**, escala el `h` en proporción si lo hay, y deja intacta la que no lo trae).

**2. `features/shared/foto_producto.dart` — `FotoProducto` + `PlaceholderPlato`.**
`Image.network` con `cacheWidth`, `gaplessPlayback`, `semanticLabel: 'Foto de {plato}'`, fundido de 300 ms sobre el marcador (`frameBuilder`) y `errorBuilder` al marcador. `PlaceholderPlato` es un `ExcludeSemantics` con el icono `GriIcons.menu` sobre `GriColors.primaryTint`, del **mismo alto exacto** que la foto.

**3. `features/shared/producto_card.dart` — `ProductoCard` + `ListaProductos`.**
La tarjeta y la rejilla, compartidas por las dos pantallas. Agotado: chip «Agotado», foto en escala de grises (`ColorFilter.matrix`, no un color nuevo), precio apagado, sin acción y sin pulsación.

## Verificado con salida real

**Gates (`npm run gates`, pasada final tras commitear):**

```
▶ app_cliente: flutter test … OK          408 (baseline 408)
▶ app_cliente: flutter analyze … OK       0 issues
▶ panel_admin: flutter test … OK          446 = baseline
▶ panel_admin: flutter analyze … OK       0 issues
▶ functions: npm test (unitarios) … OK    149 = baseline
▶ scripts: npm run test:rules … OK        285 = baseline
▶ scripts: npm run test:functions … OK    50 = baseline
▶ scripts: npm run audit:indexes … OK
▶ scripts: npm run audit:branding … OK
 9 gates · 9 OK · 0 fallo(s)
```

**Ahorro de datos, medido contra `images.unsplash.com` con `curl`** (no estimado):

| URL | Bytes |
|---|---|
| sin `w` (la original) | 2 037 979 |
| `w=1200` (lo que hay guardado en los productos) | 175 953 |
| `w=768` (lo que pide un móvil de 360 pt con esta carta) | 87 525 |
| `w=384` | 30 214 |

En un menú de 16 platos eso es ~1,4 MB en vez de ~2,8 MB. La misma pasada confirmó `Access-Control-Allow-Origin: *`, que es lo que hace falta para que las fotos se pinten también en Flutter Web (CanvasKit descarga los bytes, no usa `<img>`).

**Roturas deliberadas (14, todas en rojo como debían):**

| Qué rompí | Quién lo cazó |
|---|---|
| `dpr.clamp(1, 8)` (sin tope de densidad) | `imagen_url_test`: el dpr se topa en 2 |
| añadir `w` a ciegas a la URL que no lo trae | `imagen_url_test`: intacta / idempotencia / `w=auto` (3 casos) |
| `cacheWidth: 1200` fijo | `foto_producto_test`: pide el ancho del LAYOUT |
| quitar el `errorBuilder` | `foto_producto_test`: URL rota → excepción sin capturar |
| quitar el tope de 200 al alto de la foto | `producto_card_test`: ventanas anchas |
| precio con `GriText.cuerpoCompacto` | `producto_card_test`: PRECIO destacado |
| columnas fijas a 1 | `producto_card_test`: dos columnas en tablet |
| columnas fijas a 2 (breakpoint) | `producto_card_test`: ventana ANCHA (1400) |
| quitar el `Semantics` de la tarjeta pulsable | `producto_card_test`: `labeledTapTargetGuideline` |
| `url: null` en la tarjeta (desconectar el dato) | `menu_carta_test`: 3 casos de cableado |
| `Color(0xFF123456)` en `producto_card.dart` | `sin_hex_crudos_test`: lo señala con archivo y línea |
| baseline de `gates.mjs` a 409 | `npm run gates`: `REGRESIÓN: 408 tests < baseline 409`, 8 OK · 1 fallo |

**Cómo se comportan los dos casos feos** (probado, no razonado):

- **Plato sin foto** (`imagenUrl` nulo, `''`, en blanco, o un esquema que no es http): `PlaceholderPlato` con el icono del plato sobre el tinte de marca, **exactamente de la misma caja** que una foto (`expect(sinFoto, conFoto)` sobre `getSize`). La rejilla no cambia de ritmo.
- **URL rota o host caído**: el marcador, otra vez el mismo. Sin icono de imagen rota, sin `Icons.error`, y `tester.takeException()` es `null`. Esto **no es una simulación**: en `flutter test` el `HttpClient` del binding devuelve 400 a toda petición, así que ninguna de las URLs de la suite llega a cargar — cada test que pinta una foto está ejercitando el camino de fallo de verdad.

## Hallazgos

**1. El valor real del panel no es `null`, es `''`.**
`panel_admin/lib/features/menu/menu_provider.dart:169` escribe `'imagenUrl': imagenUrl ?? ''` al crear un producto. Un guard escrito como `imagenUrl != null` habría dado `Image.network('')` y una excepción en la primera tarjeta del primer producto creado desde el panel. `urlFotoSegura` lo trata como ausencia; hay un caso con ese literal exacto y el comentario que dice de dónde sale.

**2. Las dos pantallas de menú viven FUERA del `AppShell`.**
`app.dart` monta `/mesa` y `/restaurantes/:id` como rutas hermanas del `StatefulShellRoute`, así que **no** heredan el techo de 720 pt de 11-13: en un navegador maximizado reciben el ancho entero. La primera versión de la rejilla usaba un breakpoint (1 columna / 2 columnas) y en una ventana de 1400 daba dos tarjetas de 690 pt con una foto de 200 de alto — una tira aplastada. Se cambió a contar columnas por ancho de lectura (~300 pt, máximo 4), con un test a 1400 que exige que la tarjeta ni se estire ni se convierta en un sello.

**3. La carta cuesta scroll, y un test lo notó antes que nadie.**
`carrito_test` afirmaba `find.text('Bebidas')` sin desplazarse. Con tarjetas de ~280 px en vez de filas de ~60, la segunda categoría ya no cabe en un viewport de 600. El test ahora baja hasta ella (y lo dice en un comentario): sigue afirmando que las DOS categorías se pintan, pero paga el mismo scroll que el comensal. **Es el coste real del rediseño y conviene que el usuario lo juzgue**: con foto se ven ~2 platos por pantalla de móvil.

**4. `Image.network(..., cacheWidth: n)` no deja el `NetworkImage` desnudo.**
Lo envuelve en un `ResizeImage`, y `Image` no expone `cacheWidth` como getter. El primer test se escribió contra la API que yo creía y no compiló; los helpers desenvuelven las dos capas, que resultan ser justo las dos cosas que hay que comprobar por separado: **qué se le pide a la red** (`NetworkImage.url`) y **a cuánto se decodifica** (`ResizeImage.width`).

## Decisión: no se añade `cached_network_image`

Se evaluó porque el encargo pedía caché. Lo que aporta sobre lo que ya hay es **caché en disco entre arranques**; lo que cuesta es `flutter_cache_manager` → `sqflite` + `path_provider` + `uuid` + `rxdart` dentro del binario de producción, cuatro paquetes que hoy no están. El `ImageCache` del framework (1000 imágenes / 100 MB, clave = URL + `cacheWidth`) ya cubre el problema que se reportó —scroll arriba y abajo, salir del plato y volver, cambiar de categoría— y en Web la caché HTTP del navegador cubre además el rearranque. El bucket de 128 px existe precisamente para que esa clave no cambie con cada píxel del layout; hay un test que lo afirma (`dos anchos vecinos piden la MISMA URL`). Si algún día se quiere caché en disco, el único punto que habría que tocar es `FotoProducto._imagen`.

## Verificado vs. AFIRMADO

**Verificado** (salida real arriba): que la app pide la URL del plato con el `w` del layout y no la original; que el `w` más pequeño baja el peso a la mitad contra el CDN real; que sin foto, con URL basura y con host caído sale el marcador del mismo tamaño y sin excepción; que la tarjeta pulsable cumple `androidTapTargetGuideline` y `labeledTapTargetGuideline`; que el menú entero sigue cumpliendo las tres guías de a11y; que agregar al carrito y enviar el pedido siguen funcionando; que a 320, 700 y 1400 px no hay un solo desbordamiento; 9 gates verdes.

**AFIRMADO, no verificado:**

- **Que la carta se vea bien y dé hambre.** Ningún widget test mide eso. Se ha medido la geometría, los tamaños de letra y las URLs; el juicio es del usuario, que es quien detectó el problema. **Esto es lo que hay que mirar en la app real.**
- **Que las fotos se pinten.** En `flutter test` no hay red: ninguna imagen de esta suite se ha decodificado nunca. Lo que está probado es qué URL se pide. Que el píxel llegue depende del dispositivo y de Unsplash — el `curl` de arriba dice que el CDN responde 200 con CORS abierto, que es cuanto se puede saber sin ejecutar la app.
- **El fundido de 300 ms.** Está construido y el árbol lo contiene, pero como ninguna imagen carga en test, la animación no se ha llegado a ver ni una vez.
- **El comportamiento en Flutter Web.** `Access-Control-Allow-Origin: *` está verificado por HTTP; que CanvasKit lo pinte sin más se da por bueno. Si fallara, degrada al marcador (no rompe).
- **Que 2 platos por pantalla sea aceptable.** Es una consecuencia directa de poner fotos; si molesta, la palanca es `altoFotoMax` (hoy 200) o pasar la foto a un lado en vez de arriba.

## Alcance respetado

No se tocó nada de manejo de errores, ni `pedido_estado_screen`, ni nada bajo `features/reservas/` (otro ejecutor barría ese terreno en paralelo, y sus commits 11-29 están intercalados con estos). Ningún `git add -A`: los 11 commits llevan rutas explícitas, verificadas con `git diff --cached --name-only` antes de cada uno. Identidad visual intacta: cero colores nuevos (`sin_hex_crudos_test` lo comprueba y se rompió a propósito para confirmar que mira los archivos nuevos), y todos los tamaños salen de `GriText`/`GriSpacing`/`GriRadius`.

## Deuda anotada (en `deferred-items.md`)

Un producto creado desde el panel o desde el seed nace **sin** foto (`imagenUrl: null` en `seed_firebase.mjs:269`, `''` en el panel), y el formulario del panel no pide, ni valida, ni previsualiza la URL. Hoy eso se degrada al marcador y la carta no se rompe, pero la solución de fondo es portar `urlFotoSegura` al panel y enseñar una vista previa. Fuera del alcance de este trabajo.

## Self-Check: PASSED
