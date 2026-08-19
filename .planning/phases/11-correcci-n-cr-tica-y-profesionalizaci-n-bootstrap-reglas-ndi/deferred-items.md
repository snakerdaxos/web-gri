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
