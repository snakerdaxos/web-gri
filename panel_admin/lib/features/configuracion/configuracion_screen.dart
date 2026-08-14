import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme.dart';
import '../dashboard/restaurante_provider.dart';
import '../menu/menu_screen.dart';

/// Pantalla /configuracion — hub de administración (decisión discreta 08:
/// el sidebar de 7 ítems no tiene entrada Menú; Configuración queda
/// reservada para administración).
///
/// Tabs v1:
///  * 'Menú' → [MenuScreen] embebido (CRUD categorías/productos, 08-04).
///  * 'Restaurante' → info read-only del restauranteProvider (la edición
///    del perfil queda fuera de v1).
///
/// El tercer tab 'Restaurantes' (super_admin, PLAT-05) se agrega en 08-05
/// — reservado en el DefaultTabController (length 2 hoy).
class ConfiguracionScreen extends StatelessWidget {
  const ConfiguracionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      // 08-05: +1 tab 'Restaurantes' (super_admin — PLAT-05).
      length: 2,
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Material(
            color: Colors.white,
            child: TabBar(
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              tabs: [
                Tab(text: 'Menú'),
                Tab(text: 'Restaurante'),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              children: [
                MenuScreen(),
                _RestauranteTab(),
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
