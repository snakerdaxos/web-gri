import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/async_fallo.dart';
import '../../core/firebase_error_mapper.dart';
import '../../core/firebase_providers.dart';
import '../../core/theme.dart';
import '../dashboard/restaurante_provider.dart';
import '../dashboard/restaurantes_list_provider.dart';
import '../equipo/equipo_provider.dart' show rolesQueGestionanEquipo;
import '../auth/login_controller.dart';
import '../../core/design_tokens.dart';
import '../../core/gri_icons.dart';

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
        final collapsed = constraints.maxWidth < GriBreakpoints.compact;
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
                    const Divider(height: 1, color: GriColors.divider),
                    // ⚠️ Este `Semantics` NO es decorativo: es lo que hace que
                    // el sidebar y el topbar EXISTAN para un lector de
                    // pantalla.
                    //
                    // MEDIDO (11-25): sin él, el árbol de semántica del panel
                    // montado con el router real contiene ÚNICAMENTE el
                    // contenido de la ruta. Los 8 ítems de navegación, el
                    // logo, el título y el nombre del restaurante no aparecen
                    // por ninguna parte — no es que estén sin etiqueta: no
                    // están.
                    //
                    // Causa: el `ShellRoute` monta `widget.child` sobre un
                    // Navigator PROPIO, y toda ruta modal de un Navigator
                    // emite un `ModalBarrier`, que envuelve su contenido en
                    // `BlockSemantics`. Ese widget descarta la semántica de
                    // todo lo pintado ANTES que él, y el sidebar y el topbar
                    // se pintan antes (son los hermanos previos de este Row /
                    // Column). El descarte sube por el árbol hasta el primer
                    // límite de semántica (`isSemanticBoundary`) —
                    // `rendering/object.dart`, `isBlockingPreviousSibling` —,
                    // y sin este `Semantics(container: true)` no había
                    // ninguno entre la barrera y la raíz.
                    //
                    // NO lleva `explicitChildNodes`: se probó y es un NO-OP
                    // aquí (rotura B — quitarlo deja los 14 casos de
                    // `test/a11y/` en verde). El contenido de la ruta ya forma
                    // sus propios nodos, así que no hay nada que este
                    // contenedor pudiera absorber; añadirlo sería una línea
                    // que no puede fallar.
                    //
                    // No cambia ni un píxel: `Semantics` no pinta ni ocupa
                    // espacio.
                    Expanded(
                      child: Semantics(
                        container: true,
                        child: widget.child,
                      ),
                    ),
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

  static const _items = <(IconData, String)>[
    (GriIcons.dashboard, 'Dashboard'),
    (GriIcons.mesas, 'Mesas'),
    (GriIcons.pedidos, 'Pedidos'),
    (GriIcons.reservas, 'Reservas'),
    (GriIcons.clientes, 'Clientes'),
    (GriIcons.reportes, 'Reportes'),
    (GriIcons.equipo, 'Equipo'),
    (GriIcons.configuracion, 'Configuración'),
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
                // size 24 = el fontSize exacto del emoji que sustituye.
                child: const Icon(
                  GriIcons.marca,
                  size: 24,
                  color: Colors.white,
                  semanticLabel: 'GRI',
                ),
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
                          color: GriColors.sidebarSubtitulo,
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
                  icono: item.$1,
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
    required this.icono,
    required this.label,
    required this.active,
    required this.collapsed,
    required this.onTap,
  });

  final IconData icono;
  final String label;
  final bool active;
  final bool collapsed;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final bg = active ? GriColors.primary : Colors.transparent;
    final fg = active ? Colors.white : GriColors.sidebarItemInactivo;
    final item = Padding(
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
                  // size 18 = el fontSize del Text que sustituye; el color es
                  // el MISMO que el de la etiqueta (antes lo ponía la fuente
                  // de emoji del sistema, que es justo lo que se quería dejar
                  // de depender). Colapsado el icono queda solo, así que
                  // lleva su etiqueta semántica.
                  child: Icon(
                    icono,
                    size: 18,
                    color: fg,
                    semanticLabel: collapsed ? label : null,
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

    // Colapsado el ítem es SOLO un icono de 18px: ni un usuario de ratón ni
    // uno de teclado tienen forma de saber qué es. El `Tooltip` lo resuelve
    // para los dos — al pasar el ratón se ve el nombre, y en el árbol de
    // semántica llega por el campo `tooltip`, que es un nombre accesible
    // válido (`labeledTapTargetGuideline` acepta `label` O `tooltip`).
    //
    // Expandido NO se pone: el nombre ya está escrito al lado, y un tooltip
    // encima solo duplicaría el anuncio. Hay un test que lo afirma.
    return collapsed ? Tooltip(message: label, child: item) : item;
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
                  style: const TextStyle(color: GriColors.textoSecundarioAccesible),
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
                    // 11-33: la rama de error era `SizedBox.shrink()`. El
                    // selector desaparecía sin decir nada, que es peor que un
                    // mensaje malo: no hay qué leer ni qué hacer, y el
                    // super-admin no puede deducir si es que no hay
                    // restaurantes o que no se pudieron cargar.
                    child: restaurantesListAsync?.cuandoConFallo(
                          cargando: () => const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                          fallo: (e) => _AvisoTopbar(
                            mensaje: mensajeDeFallo(e,
                                contexto: Contexto.restaurantes),
                          ),
                          datos: (list) =>
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
                        restauranteAsync.cuandoConFallo(
                          cargando: () => const Text(
                            'Cargando…',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: GriColors.textoSecundarioAccesible,
                              fontSize: 13,
                            ),
                          ),
                          // Ídem: callar aquí deja el topbar sin nombre y sin
                          // explicación (11-33).
                          fallo: (e) => _AvisoTopbar(
                            mensaje: mensajeDeFallo(e,
                                contexto: Contexto.restaurantes),
                          ),
                          datos: (r) => Text(
                            r?.nombre ?? 'Sin restaurante',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: GriColors.textoSecundarioAccesible,
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
                const SizedBox(width: GriSpacing.sm),
                // AQUÍ y no en el sidebar (11-34): el topbar es donde ya se
                // muestra QUIÉN eres —el nombre y las iniciales, justo a la
                // izquierda—, así que es donde se busca el «dejar de ser esta
                // persona». Va DESPUÉS del avatar, en el extremo, que es la
                // convención de todo panel de gestión.
                const _BotonCerrarSesion(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Botón de CERRAR SESIÓN del topbar (11-34).
///
/// ── POR QUÉ NO EXISTÍA ────────────────────────────────────────────────────
/// `LoginController.logout()` está escrito desde 10-05 y es correcto: hace
/// `signOut()` e invalida `claimsProvider`, y el `refreshListenable` del
/// router redirige a `/login` solo. Pero NINGÚN widget lo llamaba — un grep de
/// `logout` en todo `panel_admin/lib` no devolvía una sola llamada fuera del
/// propio controlador. Consecuencia real: una vez dentro del panel no se podía
/// salir salvo borrando los datos del navegador, y el caso de uso de un panel
/// de gestión es precisamente el equipo COMPARTIDO del restaurante.
///
/// ── LAS TRES COSAS QUE NO SON OPCIONALES ─────────────────────────────────
///  1. CONFIRMACIÓN. Cerrar sesión por un clic accidental tira el trabajo a
///     medias de cualquier formulario abierto. No hay «deshacer» posible.
///  2. ÁREA TÁCTIL DE 48dp. El icono es de 20 y el `IconButton` por defecto
///     de Material da 48; se fija con `constraints` explícitas para que no
///     dependa de un default que puede cambiar. Lo vigila
///     `test/a11y/a11y_test.dart` (tapTargetGuideline).
///  3. ETIQUETA. Un `IconButton` sin etiqueta es un nodo pulsable anónimo para
///     un lector de pantalla y pone roja `labeledTapTargetGuideline`. El
///     `tooltip` de Material ya alimenta la semántica; se pone además
///     `semanticLabel` en el icono para que la etiqueta no dependa de que el
///     tooltip siga ahí.
class _BotonCerrarSesion extends ConsumerWidget {
  const _BotonCerrarSesion();

  Future<void> _confirmarYSalir(BuildContext context, WidgetRef ref) async {
    final salir = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('¿Cerrar sesión?'),
        content: const Text(
          'Se cerrará tu sesión en este equipo. Si tienes un formulario a '
          'medias, perderás lo que no hayas guardado.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: griBotonPrimario,
            child: const Text('Cerrar sesión'),
          ),
        ],
      ),
    );
    if (salir != true) return;

    // Sin `context` a través del gap async: la redirección a /login no la
    // hace esta pantalla, la hace el `refreshListenable` del router al ver
    // `authStateChanges` emitir null.
    await ref.read(loginControllerProvider.notifier).logout();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return IconButton(
      onPressed: () => _confirmarYSalir(context, ref),
      tooltip: 'Cerrar sesión',
      // 48dp EXACTOS de área táctil, escritos y no heredados.
      constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
      icon: const Icon(
        GriIcons.cerrarSesion,
        size: 20,
        color: GriColors.textoSecundarioAccesible,
        semanticLabel: 'Cerrar sesión',
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

/// Aviso compacto para el topbar (11-33).
///
/// Las dos ramas de error del topbar eran `SizedBox.shrink()`: el selector de
/// restaurante y el nombre del restaurante activo desaparecían en silencio.
/// El sitio es estrecho, así que el texto se acota a una línea y el mensaje
/// completo queda en el tooltip — pero algo se ve SIEMPRE, que es el punto.
class _AvisoTopbar extends StatelessWidget {
  const _AvisoTopbar({required this.mensaje});

  final String mensaje;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: mensaje,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(GriIcons.aviso, size: 16, color: GriColors.mesaReservadaFg),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              mensaje,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: GriColors.mesaReservadaFg,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
