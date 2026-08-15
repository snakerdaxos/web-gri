import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme.dart';
import '../../models/restaurante.dart';
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
            const SliverFillRemaining(
              child: Center(
                child: Text(
                  'No hay restaurantes disponibles',
                  style: TextStyle(color: GriColors.gray),
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
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
          const Text('🍽️', style: TextStyle(fontSize: 40)),
          const SizedBox(height: 8),
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 16),
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
/// con emoji), nombre, tipo de cocina + dirección, calificación "⭐ —".
class _RestauranteCard extends StatelessWidget {
  const _RestauranteCard({required this.restaurante});

  final Restaurante restaurante;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
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
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFFFF6B35), Color(0xFFFF9B5A)],
                ),
              ),
              child: const Center(
                child: Text('🍽️', style: TextStyle(fontSize: 44)),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    restaurante.nombre,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: GriColors.text,
                    ),
                  ),
                  if (restaurante.tipoCocina != null ||
                      restaurante.direccion != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      [
                        restaurante.tipoCocina,
                        restaurante.direccion,
                      ].whereType<String>().join(' · '),
                      style: const TextStyle(color: GriColors.gray),
                    ),
                  ],
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      const Text('⭐ ',
                          style: TextStyle(
                              color: Color(0xFFF5A623), fontSize: 14)),
                      Text(
                        restaurante.ratingLabel,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Color(0xFFF5A623),
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
