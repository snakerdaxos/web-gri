import 'package:flutter/material.dart';

import '../../core/design_tokens.dart';

/// Envoltorio de página del panel: pone un TECHO al ancho del contenido y lo
/// centra cuando sobra espacio (11-21).
///
/// ── EL PROBLEMA QUE RESUELVE ──────────────────────────────────────────────
/// El panel es una app WEB y se mira en monitores de 1920. Con el sidebar de
/// 250px quedaban ~1670px de contenido y las tarjetas, tablas y formularios se
/// estiraban de borde a borde. Eso es exactamente lo que el usuario describió
/// como «se ve todo muy desordenado»: una línea de texto de 1600px no se lee,
/// y una tarjeta de 1600px no se mira.
///
/// ── POR QUÉ `LayoutBuilder` Y NO `MediaQuery` ─────────────────────────────
/// `MediaQuery.sizeOf(context).width` da el ancho de la VENTANA. Dentro del
/// `AppShell` del panel hay un sidebar de 250px (o 70 colapsado) a la
/// izquierda, así que el ancho de la ventana es SIEMPRE el número equivocado
/// para decidir el layout del contenido: a 1280px de ventana el contenido mide
/// 1030, no 1280. `LayoutBuilder` da el ancho REAL de la caja en la que se va
/// a pintar, que es el único que sirve para elegir columnas o breakpoints.
/// (Y `MediaQuery` no aparecía ni una vez en `lib/` antes de este plan.)
///
/// ── CONTRATO ──────────────────────────────────────────────────────────────
/// * El hijo nunca mide más de [maxWidth]; por debajo de ese ancho ocupa TODO
///   lo disponible, sin recortes ni márgenes sorpresa.
/// * [padding] va DENTRO del techo, no fuera: así el área útil es idéntica en
///   todas las pantallas y el padding que cada una ya tenía se conserva tal
///   cual (30, 24 o `fromLTRB(24,16,24,4)` — homogeneizarlos sería un cambio
///   visual y está fuera de alcance).
/// * El `builder` recibe el ancho DISPONIBLE (el de la caja, antes del techo),
///   que es el que hay que mirar para decidir número de columnas: eso lo
///   mantiene compatible con los breakpoints 750/1100 ya vigentes.
class ResponsivePage extends StatelessWidget {
  const ResponsivePage({
    super.key,
    required this.builder,
    this.maxWidth = anchoMaxContenido,
    this.padding,
    this.alineacion = Alignment.topCenter,
  });

  /// Techo de ancho del contenido de una pantalla de trabajo.
  ///
  /// NO es un breakpoint: [GriBreakpoints] decide CUÁNTAS columnas caben, esto
  /// decide HASTA DÓNDE crece el contenido. Se elige 1200 porque es el ancho
  /// al que el panel ya está diseñado (a 1450px de ventana el contenido mide
  /// 1200) y porque por encima del tramo expandido (1100) no aparecen columnas
  /// nuevas: estirar más solo engorda las tarjetas.
  static const double anchoMaxContenido = 1200;

  /// Techo de las pantallas de tarjeta única centrada (login, bootstrap, 404).
  /// Es el `maxWidth: 400` que esas pantallas ya declaraban a mano desde la
  /// fase 8; aquí solo deja de estar copiado en tres sitios.
  static const double anchoMaxFormulario = 400;

  /// [anchoMaxFormulario] más el padding de 24 de cada lado. Es el techo que
  /// hay que darle a la CAJA para que la TARJETA siga midiendo exactamente
  /// 400: en login, bootstrap y 404 el padding vivía por fuera del
  /// `ConstrainedBox(400)`, así que meterlo dentro sin compensar encogería la
  /// tarjeta 48px. Medido en `responsive_test.dart`.
  static const double anchoMaxFormularioConPadding =
      anchoMaxFormulario + 2 * GriSpacing.lg;

  /// Contenido de la página. Recibe el ancho DISPONIBLE de la caja (sin techo
  /// ni padding aplicados) para decidir columnas con [GriBreakpoints].
  final Widget Function(BuildContext context, double ancho) builder;

  /// Ancho máximo del contenido. Por defecto [anchoMaxContenido].
  final double maxWidth;

  /// Padding interior, DENTRO del techo. `null` = ninguno (las pantallas que
  /// ya lo ponen en sus propios hijos, como el menú, no lo necesitan aquí).
  final EdgeInsetsGeometry? padding;

  /// Dónde se ancla el contenido cuando sobra sitio. `topCenter` (por defecto)
  /// para las pantallas de trabajo, que empiezan arriba; `center` para las de
  /// tarjeta única (login, bootstrap, 404), que hoy usan `Center`.
  final AlignmentGeometry alineacion;

  /// `true` por debajo de [GriBreakpoints.compact] (750): el tramo en el que
  /// el sidebar se colapsa y los grids bajan de columnas.
  static bool esCompacto(double ancho) => ancho < GriBreakpoints.compact;

  /// `true` a partir de [GriBreakpoints.expanded] (1100): el tramo de 4
  /// columnas.
  static bool esExpandido(double ancho) => ancho >= GriBreakpoints.expanded;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final ancho = constraints.maxWidth;
        Widget contenido = builder(context, ancho);
        if (padding != null) {
          contenido = Padding(padding: padding!, child: contenido);
        }
        // Align en vez de Center: `topCenter` evita que una pantalla de
        // contenido corto quede flotando en mitad del alto disponible, que es
        // lo que hace `Center` y NO es lo que hacen hoy estas pantallas. Las
        // tres que sí lo hacen pasan `alineacion: Alignment.center`.
        return Align(
          alignment: alineacion,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth),
            child: contenido,
          ),
        );
      },
    );
  }
}
