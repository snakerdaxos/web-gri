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
///
/// 11-21: [icono] era un `String emoji` pintado como `Text(fontSize: 25)`. El
/// `Icon` lo sustituye con `size: 25` — el mismo número — y con el `iconFg`
/// que el caller ya pasaba, que antes solo teñía a los emojis monocromos.
class StatCard extends StatelessWidget {
  const StatCard({
    super.key,
    required this.label,
    required this.value,
    required this.iconBg,
    required this.iconFg,
    required this.icono,
  });

  final String label;
  final int value;
  final Color iconBg;
  final Color iconFg;
  final IconData icono;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: ValueKey('stat-card-$label'),
      padding: const EdgeInsets.all(22),
      decoration: griCardDecoration,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Una línea SIEMPRE. Sin esto la etiqueta se parte en 2 o 3
                // líneas cuando la card se estrecha (grid a 4 columnas), y el
                // alto que pide la card deja de ser predecible: de 115px a
                // 155px según el ancho. Ese era el otro lado del desborde de
                // 31px que 11-02 dejó anotado.
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: GriColors.textoSecundarioAccesible,
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
            child: Icon(icono, size: 25, color: iconFg),
          ),
        ],
      ),
    );
  }
}
