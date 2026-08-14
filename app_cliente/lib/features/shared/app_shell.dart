import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme.dart';

/// Shell de la app cliente — bottom nav de 4 tabs (mockup indexcliente.html).
///
/// Recibe el [StatefulNavigationShell] del `StatefulShellRoute.indexedStack`:
/// el body renderiza ese shell (un IndexedStack interno que preserva el
/// estado de cada branch) y el tap solo hace `goBranch` — NUNCA push, así
/// cada tab mantiene su scroll y datos al volver.
///
/// El body se envuelve en `Center + ConstrainedBox(maxWidth: 480)` para que
/// en web (dev en Chrome) la app se vea como móvil y no estirada (la regla
/// `.app { max-width: 480px }` del mockup).
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
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: navigationShell,
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
