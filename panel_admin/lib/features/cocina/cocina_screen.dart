import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_client.dart';
import '../../core/theme.dart';
import '../../core/token_provider.dart';
import '../../models/pedido_staff.dart';
import '../dashboard/restaurante_provider.dart';
import 'pedidos_staff_provider.dart';
import 'widgets/pedido_card.dart';

/// Vista cocina (ADMN-05) — cola de pedidos activos con polling 10s.
///
/// Vive DENTRO del ShellRoute del panel (sin Scaffold propio de AppShell):
/// el body es un header + [ListView] de [PedidoCard]. `onAvanzar` llama a
/// `POST /staff/pedidos/{id}/estado` y refresca SIEMPRE (éxito → nuevo
/// estado; 409/403 → re-sincroniza con la autoridad del server).
class CocinaScreen extends ConsumerWidget {
  const CocinaScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pedidosAsync = ref.watch(pedidosStaffProvider);
    final rol = ref.watch(authStateProvider).value?.role ?? '';

    // Material ancestor: en producción lo provee el Scaffold del AppShell,
    // pero la pantalla debe ser fiel también standalone (tests/usuarios que
    // la bombean directa) — sin esto Flutter inyecta el fallback style
    // (48px) a los Text sin fontSize explícito.
    return Material(
      color: GriColors.background,
      child: Padding(
        padding: const EdgeInsets.all(30),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Pedidos · Cocina',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: GriColors.text,
              ),
            ),
            const SizedBox(height: 5),
            const Text(
              'Cola de pedidos activos (se actualiza cada 10s)',
              style: TextStyle(color: GriColors.gray),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: pedidosAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => _ErrorBox(
                  message: 'Error cargando pedidos',
                  onRetry: () => ref.invalidate(pedidosStaffProvider),
                ),
                data: (pedidos) {
                  if (pedidos.isEmpty) {
                    return const Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'No hay pedidos activos 🎉',
                            style: TextStyle(
                              fontSize: 18,
                              color: GriColors.gray,
                            ),
                          ),
                          SizedBox(height: 6),
                          Text(
                            'Los pedidos enviados desde la app aparecerán aquí',
                            style: TextStyle(
                              color: GriColors.gray,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    );
                  }
                  return ListView.separated(
                    itemCount: pedidos.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 16),
                    itemBuilder: (_, i) => PedidoCard(
                      pedido: pedidos[i],
                      rol: rol,
                      onAvanzar: (pedido, destino) =>
                          _avanzar(context, ref, pedido, destino),
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

  /// POST del avance + feedback accionable. El [ScaffoldMessenger] se
  /// captura ANTES del await (sin context a través del gap async).
  Future<void> _avanzar(
    BuildContext context,
    WidgetRef ref,
    PedidoStaff pedido,
    EstadoPedido destino,
  ) async {
    final messenger = ScaffoldMessenger.maybeOf(context);
    final user = ref.read(authStateProvider).value;
    final rid = ref.read(currentRestauranteIdProvider) ?? user?.restaurantId;
    final queryRid = user?.isSuperAdmin == true ? rid : null;

    try {
      await ref
          .read(apiClientProvider)
          .avanzarPedido(
            pedido.id,
            estadoPedidoToJson(destino),
            restauranteId: queryRid,
          );
    } on DioException catch (e) {
      final code = e.response?.statusCode;
      final msg = code == 409
          ? 'Alguien ya movió este pedido — refrescando'
          : code == 403
          ? 'Tu rol no puede hacer esta acción'
          : 'No se pudo actualizar el pedido';
      messenger?.showSnackBar(
        SnackBar(content: Text(msg), duration: const Duration(seconds: 3)),
      );
    } catch (_) {
      messenger?.showSnackBar(
        const SnackBar(
          content: Text('No se pudo actualizar el pedido'),
          duration: Duration(seconds: 3),
        ),
      );
    }
    // Refresca SIEMPRE: el server es la autoridad del estado real.
    ref.invalidate(pedidosStaffProvider);
  }
}

class _ErrorBox extends StatelessWidget {
  const _ErrorBox({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            message,
            style: const TextStyle(color: GriColors.gray, fontSize: 16),
          ),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: onRetry,
            style: ElevatedButton.styleFrom(
              backgroundColor: GriColors.primary,
              foregroundColor: Colors.white,
            ),
            child: const Text('Reintentar'),
          ),
        ],
      ),
    );
  }
}
