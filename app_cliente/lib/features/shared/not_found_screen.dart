import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme.dart';
import '../../core/design_tokens.dart';

/// Pantalla 404 propia de la app cliente (11-09).
///
/// Sustituye a la pantalla roja de error por defecto de Flutter, que es una
/// pantalla de DESARROLLO: le enseña un volcado al usuario final y no le da
/// ninguna salida.
///
/// ── SEGURIDAD (T-11-09-02) ────────────────────────────────────────────────
/// Se muestra ÚNICAMENTE [Uri.path]. Nunca `uri.toString()`, ni los query
/// params, ni el fragmento: un enlace mal formado puede llevar un token, un
/// código de invitación o un id de sesión ahí, y pintarlo en pantalla lo
/// expone a quien mire el teléfono y a cualquier captura de pantalla.
/// Cubierto por `test/router_404_test.dart`.
///
/// ── POR QUÉ NO REUTILIZA `EmptyState` ─────────────────────────────────────
/// [EmptyState] es el widget de "esta lista no tiene datos" y expone tres
/// ranuras (icono/titular/guía). El 404 necesita una CUARTA: la ruta pedida,
/// con estilo propio y aislable por los tests. Además el panel no tiene ese
/// widget compartido y las dos pantallas 404 deben ser simétricas. Lo que sí
/// se conserva es el lenguaje visual (emoji a 40, gris de apoyo, botón
/// primario) — no hay ni un color nuevo.
class NotFoundScreen extends StatelessWidget {
  const NotFoundScreen({super.key, required this.uri});

  /// URI solicitada. De aquí SOLO se pinta `.path`.
  final Uri uri;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: GriColors.background,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: GriSpacing.lg, vertical: GriSpacing.lg),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('\u{1F9ED}', style: TextStyle(fontSize: 40)),
                const SizedBox(height: GriSpacing.sm),
                const Text('Página no encontrada'),
                const SizedBox(height: GriSpacing.xs),
                const Text(
                  'El enlace que abriste no existe o ya no está disponible.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: GriColors.gray),
                ),
                const SizedBox(height: GriSpacing.sm),
                // Solo el path. Ver el bloque de seguridad de arriba.
                Text(
                  uri.path,
                  textAlign: TextAlign.center,
                  style: GriText.auxiliar.copyWith(color: GriColors.gray, fontFamily: 'monospace'),
                ),
                const SizedBox(height: GriSpacing.md),
                ElevatedButton(
                  // '/inicio', NO '/'. Esta app no tiene ruta raíz (su
                  // initialLocation es '/inicio'): con `context.go('/')` el
                  // botón de salida del 404 caería en OTRO 404.
                  onPressed: () => context.go('/inicio'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: GriColors.primary,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Volver al inicio'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
