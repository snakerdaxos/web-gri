import 'package:flutter/material.dart';

import '../../core/gri_icons.dart';
import '../../core/theme.dart';

/// Estado vacío guiado, compartido por las listas de la app cliente (11-09).
///
/// ── QUÉ ES Y QUÉ NO ES ────────────────────────────────────────────────────
/// Esto es una EXTRACCIÓN, no un rediseño. La estructura, los tamaños, los
/// colores y el espaciado salen tal cual del patrón que ya era bueno en esta
/// app (`mis_reservas_screen.dart` y `pedido_estado_screen.dart`): icono a 40,
/// 8px, titular con el estilo por defecto, 4px, guía en [GriColors.gray] y —si
/// hay acción— 16px y el botón. La identidad visual está BLOQUEADA por decisión
/// del usuario (11-CONTEXT §"Alcance visual"): aquí no se introduce ni un color
/// ni una tipografía nueva.
///
/// ── POR QUÉ EXISTE ────────────────────────────────────────────────────────
/// Las mismas pantallas resolvían este caso de tres maneras distintas: unas con
/// icono + titular + guía + botón, otras con un `Text` gris suelto, y
/// `menu_mesa_screen` con NADA (cuerpo en blanco). Un widget único hace que el
/// caso "no hay datos" sea imposible de olvidar y que se vea igual en todas.
///
/// [guia] es obligatoria a propósito: un estado vacío que solo constata el
/// vacío ("No hay X") deja al usuario sin saber si la app falló o si de verdad
/// no hay nada. La guía dice cuál de las dos cosas es y qué puede hacer.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icono,
    required this.titulo,
    required this.guia,
    this.accion,
  });

  /// Icono del estado, SIEMPRE de [GriIcons].
  ///
  /// 11-13: era un `String` con un emoji. El tamaño (40) y la posición no
  /// cambian — lo que cambia es que el glifo deja de depender de la fuente
  /// del sistema.
  final IconData icono;

  /// Titular corto: QUÉ pasa.
  final String titulo;

  /// Texto de ayuda: POR QUÉ pasa y QUÉ hacer.
  final String guia;

  /// Botón opcional. Su etiqueta debe ser DISTINTA del [titulo] y de la [guia]:
  /// si coincide, cualquier `find.text` del test casa dos veces y la aserción
  /// deja de distinguir el mensaje del botón.
  final Widget? accion;

  @override
  Widget build(BuildContext context) {
    // Único añadido sobre el patrón original: margen. Los textos guía son más
    // largos que los titulares sueltos que había y sin él tocan el borde al
    // hacer wrap. No altera el espaciado ENTRE elementos.
    const margen = EdgeInsets.symmetric(horizontal: 24, vertical: 24);

    final columna = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // size 40 = el fontSize que tenía el Text del emoji.
        Icon(icono, size: 40, color: GriColors.gray),
        const SizedBox(height: 8),
        Text(titulo, textAlign: TextAlign.center),
        const SizedBox(height: 4),
        Text(
          guia,
          textAlign: TextAlign.center,
          style: const TextStyle(color: GriColors.gray),
        ),
        if (accion != null) ...[
          const SizedBox(height: 16),
          accion!,
        ],
      ],
    );

    // ── POR QUÉ ESTE LayoutBuilder ─────────────────────────────────────────
    // Este widget tiene MÁS alto que el `Text` gris suelto al que sustituye
    // (icono + titular + guía de varias líneas + botón). En un viewport corto
    // —teléfono pequeño, landscape, o texto ampliado por accesibilidad— una
    // Column rígida desborda y pinta la banda amarilla y negra. Cambiar una
    // pantalla en blanco por un error de layout no es arreglar nada.
    //
    // Con la altura ACOTADA (body de un Scaffold, SliverFillRemaining) se hace
    // scrollable; con la altura LIBRE (hijo de un ListView, como en
    // `restaurante_detalle_screen`) NO puede haber SingleChildScrollView: un
    // viewport vertical con altura no acotada lanza. De ahí las dos ramas.
    return LayoutBuilder(
      builder: (context, constraints) {
        if (!constraints.hasBoundedHeight) {
          return Center(child: Padding(padding: margen, child: columna));
        }
        return Center(
          child: SingleChildScrollView(padding: margen, child: columna),
        );
      },
    );
  }
}
