import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/design_tokens.dart';
import '../../core/theme.dart';

/// Shell de la app cliente — bottom nav de 4 tabs (mockup indexcliente.html).
///
/// Recibe el [StatefulNavigationShell] del `StatefulShellRoute.indexedStack`:
/// el body renderiza ese shell (un IndexedStack interno que preserva el
/// estado de cada branch) y el tap solo hace `goBranch` — NUNCA push, así
/// cada tab mantiene su scroll y datos al volver.
///
/// ── ZONA SEGURA (11-13) ───────────────────────────────────────────────────
/// El body va dentro de `SafeArea(bottom: false)`. Antes NO lo estaba, así que
/// el contenido arrancaba en y=0, POR DEBAJO de la barra de estado y del notch
/// — el bug que reportó el usuario ("no deja espacio en la parte superior,
/// se oculta el logo"). Solo 3 de las 9 pantallas traían `SafeArea` propio y
/// 6 tienen `AppBar` (que ya consume el inset), así que ponerlo aquí es lo
/// único que cubre las 3 que no se protegían solas.
///
/// El `bottom: false` es DELIBERADO: el `Scaffold` ya le pasa el inset
/// inferior a la [BottomNavigationBar]. Con `bottom: true` el body se
/// encogería otra vez esos píxeles y quedaría una banda muerta entre el
/// contenido y la barra. Hay un test que lo mide.
///
/// ── ANCHO ADAPTATIVO (11-13) ──────────────────────────────────────────────
/// Antes: `ConstrainedBox(maxWidth: 480)` fijo a cualquier ancho, que en un
/// navegador de escritorio dejaba una tira estrecha entre dos bandas. Ahora la
/// jaula es un TECHO que se adapta. Lo que NO se hace es borrar el
/// `ConstrainedBox`: estirar la app a 1600px empeoraría el desorden.
///
/// | viewport      | ancho del contenido            | ¿cambia respecto a antes? |
/// |---------------|--------------------------------|---------------------------|
/// | < 480         | todo el disponible             | no                        |
/// | 480 – 839     | [GriBreakpoints.contenidoMax]  | no                        |
/// | >= 840        | [GriBreakpoints.contenidoMaxAmplio] | SÍ (480 -> 720)      |
///
/// De 0 a 840px el comportamiento es IDÉNTICO al anterior — es la mitigación
/// de T-11-13-01 (deriva visual), y el test la afirma a 360, 600 y 839.
class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  static const _tabs = <(String, String)>[
    ('🏠', 'Inicio'),
    ('🔍', 'Restaurantes'),
    ('📅', 'Reservas'),
    ('👤', 'Perfil'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final maxW = constraints.maxWidth < GriBreakpoints.contenidoMax
                ? double.infinity
                : (constraints.maxWidth < GriBreakpoints.expanded
                    ? GriBreakpoints.contenidoMax
                    : GriBreakpoints.contenidoMaxAmplio);
            return Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: maxW),
                child: navigationShell,
              ),
            );
          },
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: navigationShell.currentIndex,
        onTap: (index) => navigationShell.goBranch(
          index,
          // false: volver al tab lo restaura donde estaba (no resetea la
          // ruta raíz del branch) — preservación de estado.
          initialLocation: index == navigationShell.currentIndex,
        ),
        selectedItemColor: GriColors.primary,
        unselectedItemColor: GriColors.gray,
        selectedFontSize: 12,
        unselectedFontSize: 12,
        items: [
          for (final (emoji, label) in _tabs)
            BottomNavigationBarItem(
              icon: Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(emoji, style: const TextStyle(fontSize: 20)),
              ),
              label: label,
            ),
        ],
      ),
    );
  }
}
