import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/format.dart';
import '../../core/theme.dart';
import 'restaurantes_provider.dart';

/// Detalle del restaurante (REST-02) — datos + menú por categorías
/// (ExpansionTile) con precio COP formateado (`formatCOP`), y botón
/// "Reservar una mesa" que abre el wizard.
class RestauranteDetalleScreen extends ConsumerWidget {
  const RestauranteDetalleScreen({super.key, required this.restauranteId});

  final int restauranteId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(restauranteDetalleProvider(restauranteId));

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: GriColors.text,
        elevation: 0,
        title: async.maybeWhen(
          data: (d) => Text(d.nombre),
          orElse: () => const Text('Restaurante'),
        ),
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('🍽️', style: TextStyle(fontSize: 40)),
              const SizedBox(height: 8),
              const Text('Error al cargar el restaurante'),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () =>
                    ref.invalidate(restauranteDetalleProvider(restauranteId)),
                icon: const Icon(Icons.refresh),
                label: const Text('Reintentar'),
              ),
            ],
          ),
        ),
        data: (detalle) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // ── Info del restaurante ────────────────────────────────────────
            Card(
              clipBehavior: Clip.antiAlias,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    height: 130,
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xFFFF6B35), Color(0xFFFF9B5A)],
                      ),
                    ),
                    child: const Center(
                      child: Text('🍽️', style: TextStyle(fontSize: 52)),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          detalle.nombre,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: GriColors.text,
                          ),
                        ),
                        if (detalle.tipoCocina != null) ...[
                          const SizedBox(height: 6),
                          Text(
                            detalle.tipoCocina!,
                            style: const TextStyle(color: GriColors.gray),
                          ),
                        ],
                        if (detalle.descripcion != null) ...[
                          const SizedBox(height: 8),
                          Text(detalle.descripcion!),
                        ],
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            const Text('⭐ ',
                                style: TextStyle(
                                    color: Color(0xFFF5A623), fontSize: 14)),
                            Text(
                              detalle.calificacionLabel,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Color(0xFFF5A623),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: () => context.push(
                              '/reservas/wizard'
                              '?restauranteId=$restauranteId'
                              '&restauranteNombre=${Uri.encodeComponent(detalle.nombre)}',
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: GriColors.primary,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                            icon: const Icon(Icons.calendar_month),
                            label: const Text(
                              'Reservar una mesa',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),

            // ── Menú por categorías ────────────────────────────────────────
            if (detalle.categorias.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(
                  child: Text(
                    'Este restaurante aún no tiene menú',
                    style: TextStyle(color: GriColors.gray),
                  ),
                ),
              )
            else
              for (final categoria in detalle.categorias)
                ExpansionTile(
                  initiallyExpanded: detalle.categorias.first == categoria,
                  title: Text(
                    categoria.nombre,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: GriColors.text,
                    ),
                  ),
                  subtitle: Text(
                    '${categoria.productos.length} ítems',
                    style: const TextStyle(
                        color: GriColors.gray, fontSize: 12),
                  ),
                  children: [
                    for (final producto in categoria.productos)
                      ListTile(
                        enabled: producto.disponible,
                        title: Text(producto.nombre),
                        subtitle: producto.descripcion != null
                            ? Text(
                                producto.descripcion!,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              )
                            : null,
                        trailing: Text(
                          // ⚠️ SIEMPRE formatCOP — el precio llega como
                          // double del backend (Pitfall 3).
                          formatCOP(producto.precio),
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: GriColors.primary,
                          ),
                        ),
                      ),
                  ],
                ),
          ],
        ),
      ),
    );
  }
}
