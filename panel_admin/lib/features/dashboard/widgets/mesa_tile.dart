import 'package:flutter/material.dart';

import '../../../core/theme.dart';
import '../../../models/mesa.dart';
import '../../../core/gri_icons.dart';

/// Tile individual del mapa de mesas (ADMN-02).
///
/// Replica `.table` del mockup: minHeight 130, borderRadius 15, bg/fg
/// color-coded por [EstadoMesa] (4 colores exactos vía [mesaTileBg]/[mesaTileFg]
/// de `theme.dart`), texto centrado con número grande + label de estado +
/// capacidad.
///
/// Tap del tile (08-03): abre el actions sheet de la mesa (transiciones
/// de estado + QR). null = no interactivo (mantiene el comportamiento
/// pre-08-03); el InkWell es aditivo — los tests de color no cambian.
class MesaTile extends StatelessWidget {
  const MesaTile({super.key, required this.mesa, this.onTap});

  final Mesa mesa;

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final bg = mesaTileBg(mesa.estado);
    final fg = mesaTileFg(mesa.estado);

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(15),
        // El control principal del mapa de mesas (lo que el staff toca todo
        // el día). Va DENTRO del InkWell y SIN `container: true`, así que se
        // funde en el nodo del propio InkWell — el que lleva la acción de tap.
        //
        // MEDIDO, para no afirmar de más: envolver el InkWell POR FUERA con
        // `Semantics(container: true, …)` da exactamente el mismo nodo único
        // (la acción de tap del InkWell se absorbe en el contenedor) y deja la
        // suite igual de verde. Lo que sí rompe —rotura F— es quedarse sin
        // etiqueta: entonces el nodo pulsable no tiene nombre y
        // `labeledTapTargetGuideline` se pone roja en `/` y en `/mesas`.
        //
        // `excludeSemantics` quita los tres textos del tile para que el
        // anuncio sea UNO y no la concatenación 'Mesa 4 / Ocupada / 4
        // personas'; la etiqueta de aquí dice lo mismo, ordenado.
        //
        // MEDIDO: esos tres textos ya eran invisibles para
        // `textContrastGuideline` antes de este cambio — la guía busca un
        // `Text` cuyo contenido sea EXACTAMENTE la etiqueta del nodo
        // (`accessibility.dart`: `find.text(data.label)`) y la etiqueta
        // fundida nunca coincidía con ninguno. El contraste de los 4 pares
        // de color del tile se afirma con la fórmula WCAG en
        // `test/a11y/a11y_test.dart`, que no depende de que el tile esté
        // montado.
        child: Semantics(
          button: onTap != null,
          label: 'Mesa ${mesa.numero}, ${_estadoLabel(mesa.estado)}, '
              '${mesa.capacidad} personas',
          excludeSemantics: true,
          child: Container(
        key: ValueKey('mesa-tile-${mesa.numero}'),
        constraints: const BoxConstraints(minHeight: 130),
        padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 12),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: Colors.transparent, width: 2),
        ),
        alignment: Alignment.center,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Mesa ${mesa.numero}',
              style: TextStyle(
                fontSize: 25,
                fontWeight: FontWeight.bold,
                color: fg,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _estadoLabel(mesa.estado),
              style: TextStyle(fontSize: 13, color: fg),
            ),
            const SizedBox(height: 5),
            // El '👥' iba DENTRO del texto; pasa a ser un Icon del mismo
            // tamaño (12) y del mismo color a la izquierda. `mainAxisSize.min`
            // + `Flexible` para que el Row no pueda desbordar el tile.
            Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  GriIcons.clientes,
                  size: 12,
                  color: fg.withValues(alpha: 0.8),
                ),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    '${mesa.capacidad} personas',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      color: fg.withValues(alpha: 0.8),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
          ),
        ),
      ),
    );
  }

  /// Capitaliza la primera letra del nombre del enum (disponible → Disponible).
  String _estadoLabel(EstadoMesa e) {
    final raw = e.name;
    return raw[0].toUpperCase() + raw.substring(1);
  }
}
