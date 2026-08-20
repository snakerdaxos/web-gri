import 'package:flutter/material.dart';

import '../../core/design_tokens.dart';
import '../../core/theme.dart';

/// Caja de error con reintento — el estado de fallo de una consulta.
///
/// POR QUÉ EXISTE (11-12). Estaba reimplementada como `_ErrorBox` privada en
/// TRES pantallas: `dashboard/dashboard_screen.dart:296-329`,
/// `mesas/mesas_screen.dart:112-145` y `cocina/cocina_screen.dart:319-350`.
/// Las tres pintaban el mismo mensaje gris a 16 y el mismo botón naranja
/// «Reintentar», así que cualquier cambio de ese estado exigía editar tres
/// archivos y era cuestión de tiempo que divergieran.
///
/// ⚠ NO eran idénticas, y por eso [padding] es un parámetro: las de dashboard
/// y mesas envolvían la caja en `Padding(EdgeInsets.symmetric(vertical: 32))`
/// y la de cocina NO. Unificarlas con el padding puesto habría añadido 64 px
/// de alto a la cola de cocina — un cambio visual. Cocina pasa
/// [EdgeInsets.zero], que es geométricamente lo mismo que no tener `Padding`.
///
/// El botón NO declara `style`: el naranja de marca lo pone
/// `griTheme.elevatedButtonTheme` (11-11). Ese era el cuarto, quinto y sexto
/// duplicado del estilo del botón primario.
class ErrorBox extends StatelessWidget {
  const ErrorBox({
    super.key,
    required this.message,
    required this.onRetry,
    this.padding = const EdgeInsets.symmetric(vertical: GriSpacing.xl),
  });

  /// El mensaje de error a mostrar.
  final String message;

  /// Qué hacer al pulsar «Reintentar».
  final VoidCallback onRetry;

  /// Relleno alrededor de la caja. Por defecto, los 32 px verticales que ya
  /// tenían dashboard y mesas; cocina pasa [EdgeInsets.zero].
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              message,
              // 16 regular: no hay slot de GriText con ese par y migrarlo a
              // `textTheme.bodyLarge` NO es pixel-neutral (medido en 11-19:
              // el slot trae su propio letterSpacing/height y el inline los
              // hereda del DefaultTextStyle ambiente). Se conserva literal.
              style: const TextStyle(
                color: GriColors.textoSecundarioAccesible,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: onRetry,
              child: const Text('Reintentar'),
            ),
          ],
        ),
      ),
    );
  }
}
