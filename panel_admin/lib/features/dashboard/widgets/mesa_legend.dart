import 'package:flutter/material.dart';

import '../../../core/theme.dart';
import '../../../models/mesa.dart';

/// Leyenda de los 4 estados de mesa (ADMN-02).
///
/// Fila envuelta (Wrap) con 4 [_LegendItem]: dot coloreado + label. Espejo de
/// `.legend` del mockup.
class MesaLegend extends StatelessWidget {
  const MesaLegend({super.key});

  static const _items = <(EstadoMesa, String)>[
    (EstadoMesa.disponible, 'Disponible'),
    (EstadoMesa.ocupada, 'Ocupada'),
    (EstadoMesa.reservada, 'Reservada'),
    (EstadoMesa.limpieza, 'Limpieza'),
  ];

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 20,
      runSpacing: 8,
      children: [
        for (final item in _items)
          _LegendItem(dot: mesaDot(item.$1), label: item.$2),
      ],
    );
  }
}

class _LegendItem extends StatelessWidget {
  const _LegendItem({required this.dot, required this.label});

  final Color dot;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(color: dot, shape: BoxShape.circle),
        ),
        const SizedBox(width: 7),
        Text(label, style: const TextStyle(fontSize: 13, color: GriColors.textoSecundarioAccesible)),
      ],
    );
  }
}
