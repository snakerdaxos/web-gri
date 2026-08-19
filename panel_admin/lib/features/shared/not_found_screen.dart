import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme.dart';
import 'responsive_page.dart';
import '../../core/gri_icons.dart';

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
      // La única de las tres pantallas de tarjeta que NO tenía techo: su
      // texto se estiraba hasta los 1670px del contenido del panel. Con el
      // techo de formulario el path largo de una URL desconocida se parte en
      // varias líneas en vez de tirar del layout.
      body: ResponsivePage(
        maxWidth: ResponsivePage.anchoMaxFormularioConPadding,
        alineacion: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        builder: (context, ancho) => SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Era un emoji escrito como secuencia de escape, invisible a
              // cualquier grep de glifos. size 40 = su fontSize.
              const Icon(
                GriIcons.rutaDesconocida,
                size: 40,
                color: GriColors.gray,
              ),
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
