import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/firebase_providers.dart';
import '../../core/theme.dart';
import '../../models/restaurante.dart';
import '../dashboard/restaurante_provider.dart';
import '../menu/menu_screen.dart';
import 'restaurante_form_dialog.dart';
import 'restaurantes_admin_provider.dart';
import '../shared/responsive_page.dart';

import '../../core/design_tokens.dart';
/// Pantalla /configuracion — hub de administración (decisión discreta 08:
/// el sidebar de 7 ítems no tiene entrada Menú; Configuración queda
/// reservada para administración).
///
/// Tabs:
///  * 'Menú' → [MenuScreen] embebido (CRUD categorías/productos en vivo).
///  * 'Restaurante' → info read-only del [restauranteProvider] (stream
///    Firestore del doc del tenant — la edición del perfil queda fuera
///    de v1).
///  * 'Restaurantes' → SOLO super_admin (PLAT-05): lista COMPLETA
///    (incluye inactivos) con switch desactivar/reactivar
///    ([toggleRestauranteActivo] — update de SOLO `activo` por rules).
///
/// El gating vive en claims (`role == 'super_admin'`); los tabs se
/// construyen cuando los claims resuelven (brief spinner al abrir).
class ConfiguracionScreen extends ConsumerWidget {
  const ConfiguracionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final claimsAsync = ref.watch(claimsProvider);

    return claimsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => const Center(
        child: Text('Error cargando la sesión', style: TextStyle(color: GriColors.gray)),
      ),
      data: (claims) {
        final isSuperAdmin = claims.role == 'super_admin';
        return DefaultTabController(
          length: isSuperAdmin ? 3 : 2,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Material(
                color: Colors.white,
                child: TabBar(
                  isScrollable: true,
                  tabAlignment: TabAlignment.start,
                  tabs: [
                    const Tab(text: 'Menú'),
                    const Tab(text: 'Restaurante'),
                    if (isSuperAdmin) const Tab(text: 'Restaurantes'),
                  ],
                ),
              ),
              // El techo se aplica al CONTENIDO de los tabs, no a la barra:
              // el TabBar es una franja blanca de ancho completo (chrome del
              // shell) y recortarla a 1200 sí sería un cambio de aspecto.
              Expanded(
                child: ResponsivePage(
                  builder: (context, ancho) => TabBarView(
                    children: [
                      const MenuScreen(),
                      const _RestauranteTab(),
                      if (isSuperAdmin) const _RestaurantesTab(),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Tab Restaurante — ficha read-only del restaurante activo (stream del
/// doc `restaurantes/{rid}`).
class _RestauranteTab extends ConsumerWidget {
  const _RestauranteTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rAsync = ref.watch(restauranteProvider);

    return Material(
      color: GriColors.background,
      child: rAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'No hay restaurante seleccionado',
                style: TextStyle(color: GriColors.gray),
              ),
              TextButton(
                onPressed: () => ref.invalidate(restauranteProvider),
                child: const Text('Reintentar'),
              ),
            ],
          ),
        ),
        data: (r) => ListView(
          padding: const EdgeInsets.all(GriSpacing.lg),
          children: [
            _InfoCard(
              titulo: 'Nombre',
              valor: r.nombre,
              trailing: _EstadoBadge(activo: r.activo),
            ),
            _InfoCard(titulo: 'Tipo de cocina', valor: r.tipoCocina),
            _InfoCard(titulo: 'Dirección', valor: r.direccion),
            _InfoCard(titulo: 'Descripción', valor: r.descripcion),
            const SizedBox(height: 8),
            const Text(
              'La edición del perfil del restaurante estará disponible en una '
              'próxima versión.',
              style: TextStyle(color: GriColors.gray, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.titulo, required this.valor, this.trailing});

  final String titulo;
  final String? valor;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final v = (valor ?? '').trim().isEmpty ? '—' : valor!.trim();
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    titulo.toUpperCase(),
                    style: const TextStyle(
                      color: GriColors.gray,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(v, style: const TextStyle(fontSize: 15)),
                ],
              ),
            ),
            ?trailing,
          ],
        ),
      ),
    );
  }
}

class _EstadoBadge extends StatelessWidget {
  const _EstadoBadge({required this.activo});

  final bool activo;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: activo ? GriColors.mesaDisponibleBg : GriColors.mesaOcupadaBg,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        activo ? 'Activo' : 'Inactivo',
        style: TextStyle(
          color: activo ? GriColors.mesaDisponibleFg : GriColors.mesaOcupadaFg,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

/// Tab Restaurantes (PLAT-05) — SOLO super_admin: lista COMPLETA de
/// restaurantes (get() de TODOS — incluye inactivos para poder
/// re-activarlos) con switch desactivar/reactivar.
///
/// El update toca SOLO la key `activo` (rules: `diff hasOnly(['activo'])`
/// — ni nombre ni calificaciones tocables desde el panel). Desactivar
/// oculta el restaurante del discover de clientes en vivo, y por eso pide
/// confirmación explícita (11-05); reactivar no.
///
/// Desde 11-05 este tab también DA DE ALTA restaurantes
/// ([RestauranteFormDialog]) y, con la plataforma vacía, muestra un estado
/// vacío guiado en vez de una lista en blanco: es la pantalla en la que
/// aterriza un super_admin recién llegado.
class _RestaurantesTab extends ConsumerWidget {
  const _RestaurantesTab();

  /// Abre el alta (11-05). El propio diálogo ya fija la selección del
  /// restaurante nuevo e invalida la lista; se invalida también aquí porque
  /// esta pantalla es la dueña de la lista y no debe depender de que el
  /// diálogo lo haga por ella.
  Future<void> _abrirAlta(BuildContext context, WidgetRef ref) async {
    final creado = await showDialog<bool>(
      context: context,
      builder: (_) => const RestauranteFormDialog(),
    );
    if (creado == true) ref.invalidate(restaurantesAdminProvider);
  }

  Future<void> _toggle(BuildContext context, WidgetRef ref, Restaurante r,
      bool valor) async {
    final messenger = ScaffoldMessenger.maybeOf(context);
    final db = ref.read(firestoreProvider);

    // Confirmación SOLO en el sentido destructivo (11-05): desactivar saca el
    // restaurante de la app de clientes en vivo. Reactivar no necesita
    // confirmación — es reversible y no rompe nada. Mismo patrón que el
    // borrado de mesa (mesa_form_dialog.dart:155-171).
    if (!valor) {
      final confirmo = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text('¿Desactivar ${r.nombre}?'),
          content: const Text(
            'El restaurante desaparece de la app de clientes: dejará de '
            'aparecer en el listado y nadie podrá abrir sesión en sus mesas. '
            'Puedes reactivarlo cuando quieras.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancelar'),
            ),
            TextButton(
              style: griBotonPeligroTexto,
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Desactivar'),
            ),
          ],
        ),
      );
      if (confirmo != true) return;
    }

    try {
      await toggleRestauranteActivo(db, slug: r.id, valor: valor);
      messenger?.showSnackBar(
        SnackBar(
          content: Text(
            valor
                ? 'Restaurante reactivado'
                : 'Restaurante desactivado — desaparece de la app de clientes',
          ),
        ),
      );
      ref.invalidate(restaurantesAdminProvider);
    } catch (_) {
      messenger?.showSnackBar(
        const SnackBar(
          content: Text('Error actualizando el restaurante'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final restaurantesAsync = ref.watch(restaurantesAdminProvider);

    return Material(
      color: GriColors.background,
      child: restaurantesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Error cargando restaurantes',
                style: TextStyle(color: GriColors.gray),
              ),
              TextButton(
                onPressed: () => ref.invalidate(restaurantesAdminProvider),
                child: const Text('Reintentar'),
              ),
            ],
          ),
        ),
        data: (restaurantes) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  GriSpacing.lg, GriSpacing.lg, GriSpacing.lg, GriSpacing.sm),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '${restaurantes.length} restaurantes en la plataforma',
                      style: const TextStyle(
                        fontSize: 13,
                        color: GriColors.gray,
                      ),
                    ),
                  ),
                  ElevatedButton(
                    onPressed: () => _abrirAlta(context, ref),
                    child: const Text('+ Nuevo restaurante'),
                  ),
                ],
              ),
            ),
            // Plataforma vacía: es la pantalla en la que aterriza un
            // super_admin recién llegado. Antes mostraba una lista en blanco
            // bajo un contador en cero — el callejón sin salida que reportó el
            // usuario. Mismo patrón de estado vacío que mesas/menú/clientes,
            // pero con CTA porque aquí SÍ hay algo que hacer.
            if (restaurantes.isEmpty)
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.storefront_outlined,
                        size: 44,
                        color: GriColors.gray,
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Aún no hay restaurantes en la plataforma',
                        style: TextStyle(fontSize: 18, color: GriColors.gray),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Crea el primero para empezar a operar',
                        style: TextStyle(fontSize: 13, color: GriColors.gray),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () => _abrirAlta(context, ref),
                        child: const Text('Crear el primer restaurante'),
                      ),
                    ],
                  ),
                ),
              )
            else
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  itemCount: restaurantes.length,
                  itemBuilder: (context, i) {
                    final r = restaurantes[i];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    r.nombre,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15,
                                      color: GriColors.text,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    r.activo ? 'Activo' : 'Inactivo',
                                    style: TextStyle(
                                      color: r.activo
                                          ? GriColors.mesaDisponibleFg
                                          : GriColors.mesaOcupadaFg,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Switch(
                              value: r.activo,
                              onChanged: (v) => _toggle(context, ref, r, v),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}
