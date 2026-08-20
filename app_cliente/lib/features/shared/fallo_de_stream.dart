import 'package:flutter/material.dart';

import '../../core/design_tokens.dart';
import '../../core/theme.dart';

/// Estado de FALLO de un `AsyncValue`, con su mensaje y su salida (11-33).
///
/// Antes cada pantalla llevaba su propia `Column` copiada con un `Text`
/// distinto, y ninguno de esos textos decía QUÉ había pasado: «Error al
/// cargar el menú», «Error al cargar tus reservas», «Error al cargar
/// restaurantes». Servían igual para un permiso denegado que para una caída
/// de red, que son dos problemas con dos soluciones distintas.
///
/// Este widget no elige el texto: lo recibe ya clasificado por
/// `core/firebase_error_mapper.dart` (11-23). Lo que impone es la ESTRUCTURA:
///
/// * [mensaje] es obligatorio y viene del clasificador;
/// * [onReintentar] es obligatorio — un error sin nada que hacer deja al
///   usuario en un callejón sin salida, que es la mitad del defecto que este
///   plan repara.
class FalloDeStream extends StatelessWidget {
  const FalloDeStream({
    super.key,
    required this.icono,
    required this.mensaje,
    required this.onReintentar,
    this.etiquetaAccion = 'Reintentar',
  });

  final IconData icono;

  /// Texto honesto de `mensajeDeFallo(error, contexto: …)`.
  final String mensaje;

  final VoidCallback onReintentar;

  /// «Reintentar» por defecto. Se cambia cuando la salida NO es reintentar
  /// (p. ej. «Escanear el QR» cuando no hay ninguna mesa abierta): decir
  /// «Reintentar» ahí prometería que algo se está reintentando.
  final String etiquetaAccion;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(GriSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icono, size: 40, color: GriColors.gray),
            const SizedBox(height: GriSpacing.sm),
            Text(
              mensaje,
              textAlign: TextAlign.center,
              style: GriText.cuerpo
                  .copyWith(color: GriColors.textoSecundarioAccesible),
            ),
            const SizedBox(height: GriSpacing.md),
            ElevatedButton.icon(
              onPressed: onReintentar,
              icon: const Icon(Icons.refresh),
              label: Text(etiquetaAccion),
            ),
          ],
        ),
      ),
    );
  }
}
