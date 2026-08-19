import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../models/mesa.dart';
import 'print_service.dart';
import '../../core/gri_icons.dart';

/// Muestra el código QR imprimible de una mesa (MESA-03, 08-03).
///
/// * [QrImageView] con fondo blanco explícito (contraste para el escáner
///   del cliente y para impresión — el fondo del dialog no alcanza).
/// * El código como [SelectableText]: fallback textual — el staff puede
///   tipearlo/copearlo si el QR impreso se daña.
/// * Botón Imprimir vía `window.print()` (export condicional
///   `print_service.dart` — package:web rompería la VM de tests; en tests
///   NO se tapea ese botón).
Future<void> showQrDialog(BuildContext context, Mesa mesa) {
  return showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text('Mesa ${mesa.numero} — Código QR'),
      content: SizedBox(
        width: 340,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            QrImageView(
              data: mesa.codigoQr,
              version: QrVersions.auto,
              size: 280,
              gapless: false,
              backgroundColor: Colors.white,
            ),
            const SizedBox(height: 12),
            SelectableText(
              mesa.codigoQr,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 15),
            ),
          ],
        ),
      ),
      actions: [
        TextButton.icon(
          // web-only: imprime la vista actual del browser (el dialog queda
          // como contenido principal). No existe en la VM — jamás tapear
          // este botón en widget tests.
          onPressed: printCurrentView,
          // size 14 = el labelLarge que el emoji heredaba dentro del boton.
          icon: const Icon(GriIcons.imprimir, size: 14),
          label: const Text('Imprimir'),
        ),
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: const Text('Cerrar'),
        ),
      ],
    ),
  );
}
