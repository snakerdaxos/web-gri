import 'package:flutter/material.dart';

import '../../../core/theme.dart';

/// Tarjeta blanca de estadística del dashboard (ADMN-01).
///
/// Replica pixel-for-pixel la `.stat-card` del mockup: card blanca radius 15,
/// padding 22, sombra sutil. Layout en Row(spaceBetween): label+valor a la
/// izquierda, círculo coloreado 55x55 con emoji a la derecha.
///
/// El color del icono lo decide el caller ([iconBg] + [iconFg]) según el tipo
/// de stat: disponible=verde, ocupada=naranja, reservas=amarillo, pedidos=azul
/// (mockup `.orange/.green/.yellow/.blue`).
class StatCard extends StatelessWidget {
  const StatCard({
    super.key,
    required this.label,
    required this.value,
    required this.iconBg,
    required this.iconFg,
    required this.emoji,
  });

  final String label;
  final int value;
  final Color iconBg;
  final Color iconFg;
  final String emoji;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: ValueKey('stat-card-$label'),
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0D000000), // rgba(0,0,0,0.05)
            blurRadius: 12,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: GriColors.gray,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '$value',
                  style: const TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.bold,
                    color: GriColors.text,
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: 55,
            height: 55,
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(14),
            ),
            alignment: Alignment.center,
            child: Text(
              emoji,
              style: TextStyle(fontSize: 25, color: iconFg),
            ),
          ),
        ],
      ),
    );
  }
}
