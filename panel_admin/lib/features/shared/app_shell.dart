import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/firebase_providers.dart';
import '../../core/theme.dart';
import '../dashboard/restaurante_provider.dart';
import '../dashboard/restaurantes_list_provider.dart';

/// AppShell completo (Task 3) — sidebar 250px + topbar con nombre restaurante.
///
/// Reemplaza al placeholder del Task 2. Contrato idéntico: recibe el `child`
/// del ShellRoute + [location] (path actual, para derivar el ítem activo).
/// Layout:
///  * Sidebar 250px fijo (responsive: <750px colapsa a 70px con solo iconos).
///    Logo GRI + 7 ítems, TODOS navegables (7/7 activos desde 08-05:
///    Dashboard, Mesas, Pedidos→/cocina, Reservas, Clientes, Reportes,
///    Configuración — el flujo placeholder fue eliminado).
///  * TopBar: título dinámico + subtítulo. A la derecha: si super_admin,
///    DropdownButton de restaurantes (cambia seleccionRestauranteProvider);
///    si staff, texto nombre+rol. Avatar con iniciales.
///  * Body: child (la ruta activa).
class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key, required this.child, this.location = '/'});

  final Widget child;

  /// Path actual de la ruta dentro del ShellRoute (derivado del GoRouter
  /// state) — decide qué ítem del sidebar queda activo.
  final String location;

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  @override
  void initState() {
    super.initState();
    // Para super_admin: setear default del restaurante al primero activo
    // si aún no hay selección (claims → lista → selección).
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeInitDefaultRid());
  }

  /// Default del super: primer restaurante activo de la lista (Firestore).
  /// El try/catch cubre claims/list caídos y el unmount a mitad del await
  /// — el super siempre puede elegir a mano en el dropdown.
  Future<void> _maybeInitDefaultRid() async {
    try {
      final claims = await ref.read(claimsProvider.future);
      if (claims.role != 'super_admin') return;
      if (ref.read(seleccionRestauranteProvider) != null) return;

      final list = await ref.read(restaurantesListProvider.future);
      if (list.isEmpty) return;
      ref.read(seleccionRestauranteProvider.notifier).set(list.first.id);
    } catch (_) {
      // Sin default — el selector queda disponible en el topbar.
    }
  }

  @override
  Widget build(BuildContext context) {
    // Phase 10: identidad de FirebaseAuth + claims (era REST retirada del
    // shell). claimsAsync carga → vista staff por defecto.
    final claimsAsync = ref.watch(claimsProvider);
    final user = ref.watch(firebaseAuthProvider).currentUser;
    final isSuperAdmin = claimsAsync.value?.role == 'super_admin';

    return LayoutBuilder(
      builder: (context, constraints) {
        final collapsed = constraints.maxWidth < 750;
        final sidebarWidth = collapsed ? 70.0 : 250.0;

        return Scaffold(
          body: Row(
            children: [
              _Sidebar(
                width: sidebarWidth,
                collapsed: collapsed,
                location: widget.location,
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _TopBar(
                      location: widget.location,
                      collapsed: collapsed,
                      isSuperAdmin: isSuperAdmin,
                      userName: user?.displayName ?? user?.email ?? 'Usuario',
                      userRole: _roleLabel(claimsAsync.value?.role),
                    ),
                    const Divider(height: 1, color: Color(0xFFEEEEEE)),
                    Expanded(child: widget.child),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  String _roleLabel(String? role) => switch (role) {
        'super_admin' => 'Super Admin',
        'admin_restaurante' => 'Administrador',
        'mesero' => 'Mesero',
        'cocina' => 'Cocina',
        _ => role ?? '',
      };
}

/// Iniciales del nombre para el avatar (ej: "Admin Demo" → "AD").
String _iniciales(String nombre) {
  final parts = nombre.trim().split(RegExp(r'\s+')).take(2).toList();
  if (parts.isEmpty) return '?';
  return parts.map((p) => p.isEmpty ? '' : p[0].toUpperCase()).join();
}

class _Sidebar extends StatelessWidget {
  const _Sidebar({
    required this.width,
    required this.collapsed,
    required this.location,
  });

  final double width;
  final bool collapsed;

  /// Path de la ruta activa ('/' | '/cocina' | …) — deriva el índice activo.
  final String location;

  static const _items = <(String, String)>[
    ('🏠', 'Dashboard'),
    ('🪑', 'Mesas'),
    ('📋', 'Pedidos'),
    ('📅', 'Reservas'),
    ('👥', 'Clientes'),
    ('📊', 'Reportes'),
    ('⚙️', 'Configuración'),
  ];

  /// Ruta navegable por índice — 7/7 activos (08-05): '📋 Pedidos' abre la
  /// vista cocina (ADMN-05); '🪑 Mesas' la gestión de mesas + QR (08-03);
  /// '📅 Reservas' las del día con marcar-ocupada (08-05); '👥 Clientes' la
  /// tabla + historial (08-04, ADMN-03); '📊 Reportes' ventas y top platos
  /// (08-05, REPO-01/02); '⚙️ Configuración' el hub Menú/Restaurante/
  /// Restaurantes (08-04/08-05).
  static const _routes = <String>[
    '/',
    '/mesas',
    '/cocina',
    '/reservas',
    '/clientes',
    '/reportes',
    '/configuracion',
  ];

  @override
  Widget build(BuildContext context) {
    final activeIndex = _routes.indexOf(location);
    return Container(
      width: width,
      color: GriColors.sidebar,
      padding: const EdgeInsets.symmetric(vertical: 25, horizontal: 15),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Logo ─────────────────────────────────────────────────────────
          Row(
            mainAxisAlignment:
                collapsed ? MainAxisAlignment.center : MainAxisAlignment.start,
            children: [
              Container(
                width: 45,
                height: 45,
                decoration: BoxDecoration(
                  color: GriColors.primary,
                  borderRadius: BorderRadius.circular(12),
                ),
                alignment: Alignment.center,
                child: const Text('🍽️', style: TextStyle(fontSize: 24)),
              ),
              if (!collapsed) ...[
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text(
                      'GRI',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'Gestión de Restaurante',
                      style: TextStyle(color: Color(0xFFAAAAAA), fontSize: 11),
                    ),
                  ],
                ),
              ],
            ],
          ),
          const SizedBox(height: 35),
          // ── Menu ─────────────────────────────────────────────────────────
          Expanded(
            child: ListView.builder(
              itemCount: _items.length,
              itemBuilder: (context, i) {
                final item = _items[i];
                final isActive = i == activeIndex;
                final route = _routes[i];
                return _MenuItem(
                  emoji: item.$1,
                  label: item.$2,
                  active: isActive,
                  collapsed: collapsed,
                  // Todos los ítems navegan (7/7); el activo queda
                  // deshabilitado (no tiene sentido re-navegar).
                  onTap: isActive ? null : () => context.go(route),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _MenuItem extends StatelessWidget {
  const _MenuItem({
    required this.emoji,
    required this.label,
    required this.active,
    required this.collapsed,
    required this.onTap,
  });

  final String emoji;
  final String label;
  final bool active;
  final bool collapsed;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final bg = active ? GriColors.primary : Colors.transparent;
    final fg = active ? Colors.white : const Color(0xFFCCCCCC);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: bg,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              mainAxisAlignment: collapsed
                  ? MainAxisAlignment.center
                  : MainAxisAlignment.start,
              children: [
                SizedBox(
                  width: 25,
                  child: Text(
                    emoji,
                    style: const TextStyle(fontSize: 18),
                    textAlign: TextAlign.center,
                  ),
                ),
                if (!collapsed) ...[
                  const SizedBox(width: 15),
                  Text(label, style: TextStyle(color: fg, fontSize: 14)),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TopBar extends ConsumerWidget {
  const _TopBar({
    required this.location,
    required this.collapsed,
    required this.isSuperAdmin,
    required this.userName,
    required this.userRole,
  });

  /// Path activo ('/' | '/mesas' | '/cocina' | …) — decide título/subtítulo.
  final String location;

  final bool collapsed;
  final bool isSuperAdmin;
  final String userName;
  final String userRole;

  /// Título + subtítulo por path (los 7 del sidebar). Default: Dashboard.
  static const _titles = <String, (String, String)>{
    '/': ('Dashboard', 'Resumen de tu restaurante'),
    '/mesas': ('Mesas', 'Gestión de mesas y códigos QR'),
    '/cocina': ('Pedidos', 'Cola de pedidos en vivo'),
    '/reservas': ('Reservas', 'Reservas del día'),
    '/clientes': ('Clientes', 'Clientes del restaurante'),
    '/reportes': ('Reportes', 'Ventas y platos más vendidos'),
    '/configuracion': ('Configuración', 'Menú y administración'),
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Phase 10: restaurante activo EN VIVO del doc restaurantes/{rid}
    // (staff → claims; super → selección).
    final restauranteAsync = ref.watch(restauranteActivoProvider);
    final restaurantesListAsync =
        isSuperAdmin ? ref.watch(restaurantesListProvider) : null;
    final (title, subtitle) = _titles[location] ?? _titles['/']!;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 22),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // ── Title + subtitle ─────────────────────────────────────────────
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: GriColors.text,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  subtitle,
                  style: const TextStyle(color: GriColors.gray),
                ),
              ],
            ),
          ),
          // ── User chip + restaurante ──────────────────────────────────────
          Flexible(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (isSuperAdmin) ...[
                  restaurantesListAsync?.when(
                        loading: () => const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                        error: (_, _) => const SizedBox.shrink(),
                        data: (list) => _RestauranteDropdown(restaurantes: list),
                      ) ??
                      const SizedBox.shrink(),
                ] else
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        userName,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: GriColors.text,
                        ),
                      ),
                      restauranteAsync.when(
                        loading: () => const Text(
                          'Cargando…',
                          style: TextStyle(
                            color: GriColors.gray,
                            fontSize: 13,
                          ),
                        ),
                        error: (_, _) => const SizedBox.shrink(),
                        data: (r) => Text(
                          r?.nombre ?? 'Sin restaurante',
                          style: const TextStyle(
                            color: GriColors.gray,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                const SizedBox(width: 12),
                Container(
                  width: 45,
                  height: 45,
                  decoration: BoxDecoration(
                    color: GriColors.primary,
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    _iniciales(userName),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Dropdown de restaurantes para el topbar del super_admin (Phase 10:
/// ids String de Firestore + selección persistida en
/// [seleccionRestauranteProvider]).
class _RestauranteDropdown extends ConsumerWidget {
  const _RestauranteDropdown({required this.restaurantes});

  final List<RestauranteResumen> restaurantes;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(seleccionRestauranteProvider);

    return DropdownButton<String>(
      value: restaurantes.any((r) => r.id == selected)
          ? selected
          : (restaurantes.isNotEmpty ? restaurantes.first.id : null),
      items: [
        for (final r in restaurantes)
          DropdownMenuItem(value: r.id, child: Text(r.nombre)),
      ],
      underline: const SizedBox.shrink(),
      style: const TextStyle(
        color: GriColors.text,
        fontWeight: FontWeight.bold,
      ),
      onChanged: (newId) {
        if (newId != null) {
          ref.read(seleccionRestauranteProvider.notifier).set(newId);
        }
      },
    );
  }
}
