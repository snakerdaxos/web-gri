import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme.dart';
import '../../core/token_provider.dart';
import '../../models/restaurante.dart';
import '../dashboard/restaurante_provider.dart';
import '../dashboard/restaurantes_list_provider.dart';

/// AppShell completo (Task 3) — sidebar 250px + topbar con nombre restaurante.
///
/// Reemplaza al placeholder del Task 2. Contrato idéntico: recibe el `child`
/// del ShellRoute. Layout:
///  * Sidebar 250px fijo (responsive: <750px colapsa a 70px con solo iconos).
///    Logo GRI + 7 ítems del mockup. Solo Dashboard navega; los otros 6
///    muestran SnackBar "Próximamente" (Phase 8).
///  * TopBar: título "Dashboard" + subtítulo. A la derecha: si super_admin,
///    DropdownButton de restaurantes (cambia currentRestauranteIdProvider);
///    si staff, texto nombre+rol. Avatar con iniciales.
///  * Body: child (la ruta activa).
class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  @override
  void initState() {
    super.initState();
    // Para super_admin: setear default del restaurante al primer activo si
    // currentRestauranteIdProvider aún no fue seteado.
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeInitDefaultRid());
  }

  void _maybeInitDefaultRid() {
    final user = ref.read(authStateProvider).value;
    if (user == null || !user.isSuperAdmin) return;
    if (ref.read(currentRestauranteIdProvider) != null) return;

    final list = ref.read(restaurantesListProvider).value;
    if (list == null || list.isEmpty) return;
    final firstActive = list.firstWhere(
      (r) => r.activo,
      orElse: () => list.first,
    );
    ref.read(currentRestauranteIdProvider.notifier).set(firstActive.id);
  }

  void _showProximamente() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Próximamente'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authStateProvider).value;
    final isSuperAdmin = user?.isSuperAdmin ?? false;

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
                onProximamente: _showProximamente,
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _TopBar(
                      collapsed: collapsed,
                      isSuperAdmin: isSuperAdmin,
                      userName: user?.nombre ?? 'Usuario',
                      userRole: _roleLabel(user?.role),
                      onProximamente: _showProximamente,
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
    required this.onProximamente,
  });

  final double width;
  final bool collapsed;
  final VoidCallback onProximamente;

  static const _items = <(String, String)>[
    ('🏠', 'Dashboard'),
    ('🪑', 'Mesas'),
    ('📋', 'Pedidos'),
    ('📅', 'Reservas'),
    ('👥', 'Clientes'),
    ('📊', 'Reportes'),
    ('⚙️', 'Configuración'),
  ];

  @override
  Widget build(BuildContext context) {
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
              itemBuilder: (_, i) {
                final item = _items[i];
                final isActive = i == 0; // Dashboard (única ruta activa)
                return _MenuItem(
                  emoji: item.$1,
                  label: item.$2,
                  active: isActive,
                  collapsed: collapsed,
                  onTap: isActive ? null : onProximamente,
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
    required this.collapsed,
    required this.isSuperAdmin,
    required this.userName,
    required this.userRole,
    required this.onProximamente,
  });

  final bool collapsed;
  final bool isSuperAdmin;
  final String userName;
  final String userRole;
  final VoidCallback onProximamente;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final restauranteAsync = ref.watch(restauranteProvider);
    final restaurantesListAsync =
        isSuperAdmin ? ref.watch(restaurantesListProvider) : null;

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
              children: const [
                Text(
                  'Dashboard',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: GriColors.text,
                  ),
                ),
                SizedBox(height: 5),
                Text(
                  'Resumen de tu restaurante',
                  style: TextStyle(color: GriColors.gray),
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
                          r.nombre,
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

/// Dropdown de restaurantes para el topbar del super_admin.
class _RestauranteDropdown extends ConsumerWidget {
  const _RestauranteDropdown({required this.restaurantes});

  final List<Restaurante> restaurantes;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(currentRestauranteIdProvider);
    final active = restaurantes.where((r) => r.activo).toList();
    final items = active.isEmpty ? restaurantes : active;

    return DropdownButton<int>(
      value: items.any((r) => r.id == selected)
          ? selected
          : (items.isNotEmpty ? items.first.id : null),
      items: [
        for (final r in items)
          DropdownMenuItem(value: r.id, child: Text(r.nombre)),
      ],
      underline: const SizedBox.shrink(),
      style: const TextStyle(
        color: GriColors.text,
        fontWeight: FontWeight.bold,
      ),
      onChanged: (newId) {
        if (newId != null) {
          ref.read(currentRestauranteIdProvider.notifier).set(newId);
        }
      },
    );
  }
}
