import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/firebase_providers.dart';
import '../../core/theme.dart';
import '../dashboard/restaurante_provider.dart';
import '../dashboard/restaurantes_list_provider.dart';
import '../equipo/equipo_provider.dart' show rolesQueGestionanEquipo;

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
                // Gating del ítem 'Equipo'. Es CORTESÍA, no seguridad: evita
                // que un mesero se tropiece con una pantalla que no le sirve.
                // Quien decide de verdad son las rules y la callable. Mientras
                // los claims cargan `value` es null y `contains(null)` es
                // false, así que el ítem NO aparece: mejor que parpadee a que
                // se le enseñe un instante a quien no debe verlo.
                puedeGestionarEquipo:
                    rolesQueGestionanEquipo.contains(claimsAsync.value?.role),
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
    required this.puedeGestionarEquipo,
  });

  final double width;
  final bool collapsed;

  /// El rol del que ha iniciado sesión gestiona personal (`super_admin` o
  /// `admin_restaurante`) → se pinta el ítem 'Equipo'.
  final bool puedeGestionarEquipo;

  /// Path de la ruta activa ('/' | '/cocina' | …) — deriva el índice activo.
  final String location;

  static const _items = <(String, String)>[
    ('🏠', 'Dashboard'),
    ('🪑', 'Mesas'),
    ('📋', 'Pedidos'),
    ('📅', 'Reservas'),
    ('👥', 'Clientes'),
    ('📊', 'Reportes'),
    ('🪪', 'Equipo'),
    ('⚙️', 'Configuración'),
  ];

  /// Índice de 'Equipo' en [_items]/[_routes] — el único ítem con visibilidad
  /// condicionada por rol (11-10). Se filtra al construir la lista, así que
  /// `_items` y `_routes` siguen siendo paralelos y el índice activo se sigue
  /// derivando del path, no de la posición visible.
  static const _iEquipo = 6;

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
    '/equipo',
    '/configuracion',
  ];

  @override
  Widget build(BuildContext context) {
    final activeIndex = _routes.indexOf(location);
    // Índices VISIBLES para este rol, en orden. Filtrar aquí (y no dentro del
    // itemBuilder) mantiene el ListView sin huecos.
    final visibles = <int>[
      for (var i = 0; i < _items.length; i++)
        if (i != _iEquipo || puedeGestionarEquipo) i,
    ];
    return Container(
      width: width,
      color: GriColors.sidebar,
      // El padding horizontal se estrecha al colapsar. NO es cosmética: con
      // los 15 de siempre, el sidebar colapsado (70px) dejaba 40px útiles y
      // el badge del logo mide 45 → desbordaba 5px, y cada ítem del menú
      // otros 13. Medido en 11-21; era un defecto de GEOMETRÍA PURA (no
      // depende de la fuente ni del texto), presente a cualquier ancho
      // < 750px. Expandido no cambia nada: sigue siendo 15.
      padding: EdgeInsets.symmetric(
        vertical: 25,
        horizontal: collapsed ? 10 : 15,
      ),
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
                // Expanded + ellipsis: el Column de textos pedía su ancho
                // intrínseco dentro de un Row acotado a 220px útiles. Con la
                // métrica de fuente del entorno de test eso son ~300px →
                // desbordaba 85px. Acotarlo aquí hace que el sidebar sea
                // correcto por CONSTRUCCIÓN, sea cual sea la fuente, el
                // idioma o la escala de texto del sistema.
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text(
                        'GRI',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Gestión de Restaurante',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Color(0xFFAAAAAA),
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 35),
          // ── Menu ─────────────────────────────────────────────────────────
          Expanded(
            child: ListView.builder(
              itemCount: visibles.length,
              itemBuilder: (context, pos) {
                final i = visibles[pos];
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
            // Horizontal 10 al colapsar: con 14 el ítem dejaba 12px útiles
            // para un icono de 25 → 13px de desborde por ítem, ocho veces.
            // Expandido sigue siendo 14 en los cuatro lados.
            padding: EdgeInsets.symmetric(
              vertical: 14,
              horizontal: collapsed ? 10 : 14,
            ),
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
                  // Expanded + ellipsis: 'Configuración' pedía más de los
                  // 152px que quedaban → 33px de desborde.
                  Expanded(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: fg, fontSize: 14),
                    ),
                  ),
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
    '/equipo': ('Equipo', 'Personal con acceso al panel'),
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
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: GriColors.text,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
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
                // Flexible en las DOS ramas: ni el nombre del usuario ni el
                // del restaurante tienen tope de longitud (los escribe el
                // operador), así que sin acotar aquí un nombre largo empuja
                // el avatar fuera del topbar. Medido a 800px de ventana con
                // el seed: 77px de desborde.
                if (isSuperAdmin) ...[
                  Flexible(
                    child: restaurantesListAsync?.when(
                          loading: () => const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                          error: (_, _) => const SizedBox.shrink(),
                          data: (list) =>
                              _RestauranteDropdown(restaurantes: list),
                        ) ??
                        const SizedBox.shrink(),
                  ),
                ] else
                  Flexible(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          userName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: GriColors.text,
                          ),
                        ),
                        restauranteAsync.when(
                          loading: () => const Text(
                            'Cargando…',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: GriColors.gray,
                              fontSize: 13,
                            ),
                          ),
                          error: (_, _) => const SizedBox.shrink(),
                          data: (r) => Text(
                            r?.nombre ?? 'Sin restaurante',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: GriColors.gray,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
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

    // ConstrainedBox + isExpanded: un `DropdownButton` se dimensiona por el
    // item MÁS ANCHO y no encoge. El nombre del restaurante lo escribe el
    // operador y no tiene tope de longitud, así que sin acotarlo aquí el
    // selector empuja el avatar fuera del topbar (medido: la fila interna del
    // dropdown desbordaba su celda de 288px con el seed de tres restaurantes).
    // 260 es el ancho máximo; con nombres cortos el texto simplemente no lo
    // llena.
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 260),
      child: DropdownButton<String>(
      isExpanded: true,
      value: restaurantes.any((r) => r.id == selected)
          ? selected
          : (restaurantes.isNotEmpty ? restaurantes.first.id : null),
      items: [
        for (final r in restaurantes)
          DropdownMenuItem(
            value: r.id,
            child: Text(r.nombre, maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
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
      ),
    );
  }
}
