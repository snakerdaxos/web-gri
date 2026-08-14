import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_client.dart';
import '../../core/theme.dart';
import '../../core/token_provider.dart';
import '../../models/restaurante.dart';
import '../dashboard/restaurante_provider.dart';
import '../menu/menu_screen.dart';
import 'restaurantes_admin_provider.dart';

/// Pantalla /configuracion — hub de administración (decisión discreta 08:
/// el sidebar de 7 ítems no tiene entrada Menú; Configuración queda
/// reservada para administración).
///
/// Tabs:
///  * 'Menú' → [MenuScreen] embebido (CRUD categorías/productos, 08-04).
///  * 'Restaurante' → info read-only del restauranteProvider (la edición
///    del perfil queda fuera de v1).
///  * 'Restaurantes' → SOLO super_admin (PLAT-05, 08-05): lista COMPLETA
///    (incluye inactivos) con switch desactivar/reactivar.
///
/// El [DefaultTabController] length se computa ANTES del build (2 staff /
/// 3 super_admin) — el tab extra no existe para staff ni en el TabBar.
class ConfiguracionScreen extends ConsumerWidget {
  const ConfiguracionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isSuperAdmin =
        ref.watch(authStateProvider).value?.isSuperAdmin ?? false;

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
          Expanded(
            child: TabBarView(
              children: [
                const MenuScreen(),
                const _RestauranteTab(),
                if (isSuperAdmin) const _RestaurantesTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Tab Restaurante — ficha read-only del restaurante activo.
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
          padding: const EdgeInsets.all(24),
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
/// restaurantes (incluye inactivos, `?incluir_inactivos=true`) con switch
/// desactivar/reactivar.
///
/// Alcance v1 del backend (08-02): desactivar oculta el restaurante de
/// /public (desaparece de la app de clientes) pero el staff con token
/// vigente SIGUE operando — por eso desactivar el restaurante ACTUALMENTE
/// seleccionado en el dropdown del topbar NO lo desmonta.
class _RestaurantesTab extends ConsumerWidget {
  const _RestaurantesTab();

  Future<void> _toggle(BuildContext context, WidgetRef ref, Restaurante r,
      bool valor) async {
    try {
      await ref
          .read(apiClientProvider)
          .patchRestauranteActivo(r.id, valor);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            valor
                ? 'Restaurante reactivado'
                : 'Restaurante desactivado — desaparece de la app de clientes',
          ),
        ),
      );
      ref.invalidate(restaurantesAdminProvider);
    } on DioException catch (e) {
      if (!context.mounted) return;
      final detail =
          e.response?.data is Map ? e.response?.data['detail'] : null;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            detail is String ? detail : 'Error actualizando el restaurante',
          ),
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
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
              child: Text(
                '${restaurantes.length} restaurantes en la plataforma',
                style: const TextStyle(
                  fontSize: 13,
                  color: GriColors.gray,
                ),
              ),
            ),
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
