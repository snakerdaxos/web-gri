import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme.dart';

/// Pantalla 404 propia del panel (11-09).
///
/// El panel es WEB: escribir una URL a mano es un gesto normal aquí, no un
/// caso raro. Hasta ahora eso daba la pantalla roja de error de Flutter.
///
/// ── SEGURIDAD (T-11-09-02) ────────────────────────────────────────────────
/// Se muestra ÚNICAMENTE [Uri.path]. Nunca `uri.toString()`, ni los query
/// params, ni el fragmento: en un panel de administración es justo donde
/// viajan ids de restaurante, tokens de invitación o filtros con datos de
/// clientes. Cubierto por `test/router_404_test.dart`.
///
/// ── SEGURIDAD (T-11-09-03) ────────────────────────────────────────────────
/// Esta pantalla NO es alcanzable sin sesión: el `redirect` del GoRouter se
/// evalúa antes que el `errorBuilder`, así que un anónimo que pruebe rutas al
/// azar acaba siempre en /login y no puede distinguir "no existe" de "existe
/// pero no es tuya". Ese es el caso negativo del test.
///
/// Gemela de `app_cliente/lib/features/shared/not_found_screen.dart`: mismo
/// contrato, tokens de cada app.
class NotFoundScreen extends StatelessWidget {
  const NotFoundScreen({super.key, required this.uri});

  /// URI solicitada. De aquí SOLO se pinta `.path`.
  final Uri uri;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: GriColors.background,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('\u{1F9ED}', style: TextStyle(fontSize: 40)),
              const SizedBox(height: 8),
              const Text('Página no encontrada'),
              const SizedBox(height: 4),
              const Text(
                'La dirección que abriste no existe en el panel.',
                textAlign: TextAlign.center,
                style: TextStyle(color: GriColors.gray),
              ),
              const SizedBox(height: 8),
              // Solo el path. Ver el bloque de seguridad de arriba.
              Text(
                uri.path,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: GriColors.gray,
                  fontSize: 12,
                  fontFamily: 'monospace',
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                // Aquí '/' SÍ existe (initialLocation del panel = dashboard).
                onPressed: () => context.go('/'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: GriColors.primary,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Volver al panel'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
