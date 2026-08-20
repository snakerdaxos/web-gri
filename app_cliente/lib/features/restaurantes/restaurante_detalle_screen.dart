import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/async_fallo.dart';
import '../../core/firebase_error_mapper.dart';
import '../../core/gri_icons.dart';
import '../shared/fallo_de_stream.dart';
import '../../core/theme.dart';
import '../shared/empty_state.dart';
import '../shared/producto_card.dart';
import '../../core/design_tokens.dart';
import 'restaurantes_provider.dart';

/// Detalle del restaurante (REST-02) — datos + menú por categorías
/// (ExpansionTile) con precio COP formateado (`formatCOP`), y botón
/// "Reservar una mesa" que abre el wizard.
class RestauranteDetalleScreen extends ConsumerWidget {
  const RestauranteDetalleScreen({super.key, required this.restauranteId});

  /// Slug del doc `restaurantes/{slug}` — String end-to-end (Phase 10).
  final String restauranteId;

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
      body: async.cuandoConFallo(
        cargando: () => const Center(child: CircularProgressIndicator()),
        fallo: (e) => FalloDeStream(
          icono: GriIcons.menu,
          mensaje: mensajeDeFallo(e, contexto: Contexto.verMenu),
          onReintentar: () =>
              ref.invalidate(restauranteDetalleProvider(restauranteId)),
        ),
        datos: (detalle) => ListView(
          padding: const EdgeInsets.all(GriSpacing.md),
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
                      gradient: griGradienteRestaurante,
                    ),
                    child: const Center(
                      child: Icon(GriIcons.menu, size: 52, color: Colors.white),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(GriSpacing.md),
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
                            style: const TextStyle(color: GriColors.textoSecundarioAccesible),
                          ),
                        ],
                        if (detalle.descripcion != null) ...[
                          const SizedBox(height: GriSpacing.sm),
                          Text(detalle.descripcion!),
                        ],
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            const Icon(GriIcons.calificacion,
                                color: GriColors.calificacionEstrella, size: 14),
                            const SizedBox(width: GriSpacing.xs),
                            Text(
                              detalle.ratingLabel,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: GriColors.calificacionEstrella,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: GriSpacing.md),
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
            const SizedBox(height: GriSpacing.sm),

            // ── Menú por categorías ────────────────────────────────────────
            if (detalle.categorias.isEmpty)
              // 11-09: mismo caso que el guard de `menu_mesa_screen`, aquí ya
              // contemplado desde antes. Se homogeneiza al widget compartido
              // CONSERVANDO el copy del titular (no es un cambio de mensaje,
              // es dejar de resolverlo de dos maneras distintas). Sin acción:
              // esta pantalla ya ofrece 'Reservar una mesa' más arriba.
              const Padding(
                padding: EdgeInsets.symmetric(vertical: GriSpacing.lg),
                child: EmptyState(
                  icono: GriIcons.resumenPedido,
                  titulo: 'Este restaurante aún no tiene menú',
                  guia: 'Cuando publique sus platos los verás aquí.',
                ),
              )
            else
              for (final categoria in detalle.categorias)
                ExpansionTile(
                  initiallyExpanded: detalle.categorias.first == categoria,
                  title: Text(
                    categoria.nombre,
                    // 11-30: era el peso por defecto del `ListTile` (16). El
                    // nombre de la sección de una carta —"Entradas", "Platos
                    // fuertes"— manda sobre los platos que la siguen; con el
                    // mismo tamaño que el nombre de un plato, no mandaba.
                    style: GriText.tituloSeccion.copyWith(
                      color: GriColors.text,
                    ),
                  ),
                  subtitle: Text(
                    '${categoria.productos.length} ítems',
                    style: GriText.auxiliar.copyWith(color: GriColors.textoSecundarioAccesible),
                  ),
                  childrenPadding:
                      const EdgeInsets.only(bottom: GriSpacing.md),
                  children: [
                    // La MISMA tarjeta que la carta de la mesa (11-30), pero
                    // sin acción ni pulsación: esto es el escaparate del
                    // restaurante, aquí todavía no se pide nada y un botón
                    // que no hace nada es peor que ninguno. El precio lo
                    // formatea la tarjeta con `formatCOP` (Pitfall 3).
                    ListaProductos(
                      productos: categoria.productos,
                      tarjeta: (producto) => ProductoCard(producto: producto),
                    ),
                  ],
                ),
          ],
        ),
      ),
    );
  }
}
