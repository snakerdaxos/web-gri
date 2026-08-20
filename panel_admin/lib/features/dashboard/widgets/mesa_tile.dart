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
  const MesaTile({
    super.key,
    required this.mesa,
    this.onTap,
    this.estadoVisual,
    this.detalleReserva,
  });

  final Mesa mesa;

  final VoidCallback? onTap;

  /// El estado que se PINTA cuando no es el que el documento guarda (11-34).
  ///
  /// Desde 11-34 el amarillo de «reservada» no sale del campo `estado` sino
  /// de cruzar las reservas del día con la hora (`bloqueo_reserva.dart`). El
  /// parámetro es opcional y cae a `mesa.estado`: los tiles que aún no pasan
  /// por el mapa derivado se pintan exactamente como siempre.
  final EstadoMesa? estadoVisual;

  /// Por qué está amarilla, en una línea («21:00 · 4 personas»).
  ///
  /// NO es adorno. La queja literal del operador sobre el mapa anterior era
  /// que el amarillo aparecía «a veces» y no se podía deducir de dónde venía.
  /// Un color sin causa visible es una pregunta, no una información.
  final String? detalleReserva;

  @override
  Widget build(BuildContext context) {
    final estado = estadoVisual ?? mesa.estado;
    final bg = mesaTileBg(estado);
    final fg = mesaTileFg(estado);

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
          label: 'Mesa ${mesa.numero}, ${_estadoLabel(estado)}, '
              '${mesa.capacidad} personas'
              '${detalleReserva == null ? '' : ', reserva $detalleReserva'}',
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
              _estadoLabel(estado),
              style: TextStyle(fontSize: 13, color: fg),
            ),
            if (detalleReserva != null) ...[
              const SizedBox(height: 2),
              Text(
                detalleReserva!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: fg,
                ),
              ),
            ],
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
