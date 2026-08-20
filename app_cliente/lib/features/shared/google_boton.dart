// features/shared/google_boton.dart — botón "Continuar con Google" (11-17).
//
// PROHIBIDO rediseñar las pantallas de auth: este botón se AÑADE debajo del
// bloque existente, con un separador. El layout, la paleta y la card no se
// tocan (decisión de identidad visual, LOCKED en 11-CONTEXT.md).
//
// NO se incrusta el logo oficial de Google: es un asset de marca de terceros
// con condiciones de uso propias y no se descarga nada al repo. Se usa un
// icono neutro de Material, como acordó el plan.
import 'package:flutter/material.dart';

import '../../core/design_tokens.dart';
import '../../core/theme.dart';

/// Separador "o" entre el formulario de email/contraseña y el botón de Google.
class SeparadorAuth extends StatelessWidget {
  const SeparadorAuth({super.key});

  @override
  Widget build(BuildContext context) {
    return const Row(
      children: [
        Expanded(child: Divider(color: GriColors.divisor)),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 12),
          child: Text('o', style: TextStyle(color: GriColors.textoSecundarioAccesible)),
        ),
        Expanded(child: Divider(color: GriColors.divisor)),
      ],
    );
  }
}

/// Botón de ingreso con Google: superficie blanca, borde gris y texto oscuro.
///
/// Mientras [cargando] es true el botón queda DESHABILITADO y muestra un
/// indicador: un doble toque no puede disparar dos ingresos.
class GoogleBoton extends StatelessWidget {
  const GoogleBoton({
    super.key,
    required this.onPressed,
    this.cargando = false,
    this.botonKey,
  });

  /// Acción de ingreso. Si es null el botón queda deshabilitado.
  final VoidCallback? onPressed;

  /// Operación en vuelo: deshabilita y muestra el indicador.
  final bool cargando;

  /// Key del botón en sí (para que `find.byKey` apunte al widget que se
  /// mide y se toca, no al envoltorio — mismo criterio que `fieldKey` de
  /// PasswordField en 11-06).
  final Key? botonKey;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      key: botonKey,
      onPressed: cargando ? null : onPressed,
      // 11-19: los literales de este estilo salen ya de los tokens. Los que
      // SIGUEN siendo números sueltos no están en ninguna escala y migrarlos
      // "al peldaño más cercano" cambiaría el aspecto, que está prohibido:
      //   · vertical: 12 y el horizontal: 12 del separador → la escala 4-pt
      //     salta de 8 a 16;
      //   · fontSize: 16 / w500 → no hay slot de GriText con ese peso;
      //   · icono de 22 y spinner de 20 → tamaños de componente, no espaciado.
      style: OutlinedButton.styleFrom(
        backgroundColor: Colors.white,
        foregroundColor: GriColors.text,
        disabledForegroundColor: GriColors.textoSecundarioAccesible,
        side: const BorderSide(color: GriColors.bordeBotonGoogle),
        // 48 de alto: el default de OutlinedButton es 40, así que este
        // mínimo lo pone el widget, no el framework. GriSpacing.xxl vale
        // exactamente 48 (mismo valor, no un redondeo).
        minimumSize: const Size.fromHeight(GriSpacing.xxl),
        padding:
            const EdgeInsets.symmetric(vertical: 12, horizontal: GriSpacing.md),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
      ),
      icon: cargando
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: GriColors.gray,
              ),
            )
          : const Icon(Icons.account_circle_outlined, size: 22),
      label: const Text('Continuar con Google'),
    );
  }
}
