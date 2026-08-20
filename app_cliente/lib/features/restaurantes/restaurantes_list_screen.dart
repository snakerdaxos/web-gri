import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/gri_icons.dart';
import '../../core/theme.dart';
import '../../models/restaurante.dart';
import '../shared/empty_state.dart';
import '../../core/design_tokens.dart';
import 'restaurantes_provider.dart';

/// Tab Restaurantes (REST-01) — lista de restaurantes activos con
/// calificación "—" (null hasta Phase 9). Tap → detalle con menú.
class RestaurantesListScreen extends ConsumerWidget {
  const RestaurantesListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(restaurantesListProvider);

    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => _ErrorView(
        message: 'Error al cargar restaurantes',
        onRetry: () => ref.invalidate(restaurantesListProvider),
      ),
      data: (restaurantes) => CustomScrollView(
        slivers: [
          const SliverAppBar(
            title: Text('Restaurantes'),
            backgroundColor: Colors.white,
            foregroundColor: GriColors.text,
            floating: true,
          ),
          if (restaurantes.isEmpty)
            // 11-09: era un `Text` gris suelto que constataba el vacío sin
            // explicarlo. La etiqueta del botón es 'Actualizar' y NO
            // 'Reintentar' a propósito: 'Reintentar' pertenece a la rama de
            // ERROR (_ErrorView) y confundir las dos le diría al usuario que
            // algo falló cuando lo único que pasa es que aún no hay datos.
            SliverFillRemaining(
              child: EmptyState(
                icono: GriIcons.menu,
                titulo: 'No hay restaurantes disponibles',
                guia: 'Aún no hay restaurantes publicados en GRI. '
                    'Vuelve a intentarlo en un momento.',
                accion: ElevatedButton.icon(
                  onPressed: () => ref.invalidate(restaurantesListProvider),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: GriColors.primary,
                    foregroundColor: Colors.white,
                  ),
                  icon: const Icon(Icons.refresh),
                  label: const Text('Actualizar'),
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(GriSpacing.md, GriSpacing.sm, GriSpacing.md, GriSpacing.lg),
              sliver: SliverList.builder(
                itemCount: restaurantes.length,
                itemBuilder: (_, i) =>
                    _RestauranteCard(restaurante: restaurantes[i]),
              ),
            ),
        ],
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(GriIcons.menu, size: 40, color: GriColors.gray),
          const SizedBox(height: GriSpacing.sm),
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: GriSpacing.md),
          ElevatedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: const Text('Reintentar'),
          ),
        ],
      ),
    );
  }
}

/// Card de restaurante estilo mockup: imagen placeholder (gradiente naranja
/// con icono), nombre, tipo de cocina + dirección, calificación.
class _RestauranteCard extends StatelessWidget {
  const _RestauranteCard({required this.restaurante});

  final Restaurante restaurante;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: GriSpacing.md),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push('/restaurantes/${restaurante.id}'),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Imagen placeholder — gradiente del mockup (.restaurant-image).
            Container(
              height: 110,
              decoration: const BoxDecoration(
                gradient: griGradienteRestaurante,
              ),
              child: const Center(
                child: Icon(GriIcons.menu, size: 44, color: Colors.white),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(GriSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    restaurante.nombre,
                    style: GriText.tituloSeccion.copyWith(color: GriColors.text),
                  ),
                  if (restaurante.tipoCocina != null ||
                      restaurante.direccion != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      [
                        restaurante.tipoCocina,
                        restaurante.direccion,
                      ].whereType<String>().join(' · '),
                      style: const TextStyle(color: GriColors.textoSecundarioAccesible),
                    ),
                  ],
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      const Icon(GriIcons.calificacion,
                          color: GriColors.calificacionEstrella, size: 14),
                      const SizedBox(width: GriSpacing.xs),
                      Text(
                        restaurante.ratingLabel,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: GriColors.calificacionEstrella,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
