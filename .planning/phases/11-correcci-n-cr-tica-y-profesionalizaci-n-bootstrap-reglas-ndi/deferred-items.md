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
