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
