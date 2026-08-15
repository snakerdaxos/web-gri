import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api_client.dart';
import '../../core/format.dart';
import '../../core/theme.dart';
import '../../models/pedido.dart';
import '../../models/sesion_mesa.dart';
import '../sesion_qr/sesion_provider.dart';
import 'pedidos_provider.dart';

/// Estado de los pedidos de la sesión (PEDI-04 UI) — cards con chips de
/// estado coloreados que se actualizan solas (polling 10s del provider) +
/// botón "Pedir la cuenta" (PAGO-01 UI, idempotente server-side).
class PedidoEstadoScreen extends ConsumerStatefulWidget {
  const PedidoEstadoScreen({super.key});

  @override
  ConsumerState<PedidoEstadoScreen> createState() =>
      _PedidoEstadoScreenState();
}

class _PedidoEstadoScreenState extends ConsumerState<PedidoEstadoScreen> {
  bool _pidiendoCuenta = false;

  /// Mirror local tras pedir la cuenta exitosamente — la visibilidad no
  /// depende solo del invalidate del provider (robusto en cualquier flujo).
  bool _cuentaYaPedida = false;

  Future<void> _pedirCuenta() async {
    if (_pidiendoCuenta) return;
    setState(() => _pidiendoCuenta = true);
    try {
      await ref.read(apiClientProvider).pedirCuenta();
      ref.invalidate(sesionProvider); // el banner del home se entera
      if (!mounted) return;
      setState(() => _cuentaYaPedida = true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cuenta solicitada — el mesero viene en camino'),
          backgroundColor: GriColors.green,
        ),
      );
    } on DioException catch (e) {
      if (!mounted) return;
      final data = e.response?.data;
      final detail = data is Map<String, dynamic> ? data['detail'] : null;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            detail is String && detail.isNotEmpty
                ? detail
                : 'No pudimos solicitar la cuenta. Intenta de nuevo.',
          ),
          backgroundColor: GriColors.chipCanceladaFg,
        ),
      );
    } catch (e) {
      debugPrint('pedir cuenta falló: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Error de conexión. Intenta de nuevo.'),
          backgroundColor: GriColors.chipCanceladaFg,
        ),
      );
    } finally {
      if (mounted) setState(() => _pidiendoCuenta = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final sesion = ref.watch(sesionProvider).value;
    final pedidosAsync = ref.watch(pedidosSessionProvider);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: GriColors.text,
        elevation: 0,
        title: Text(
          sesion == null
              ? 'Mis pedidos'
              : 'Mis pedidos · Mesa ${sesion.mesaNumero}',
        ),
      ),
      body: pedidosAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('📡', style: TextStyle(fontSize: 40)),
              const SizedBox(height: 8),
              const Text('Error al cargar tus pedidos'),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () => ref.invalidate(pedidosSessionProvider),
                icon: const Icon(Icons.refresh),
                label: const Text('Reintentar'),
              ),
            ],
          ),
        ),
        data: (pedidos) {
          if (pedidos.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('🧑‍🍳', style: TextStyle(fontSize: 40)),
                  const SizedBox(height: 8),
                  const Text('Aún no hay pedidos en esta sesión'),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => context.push('/mesa'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: GriColors.primary,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Ver el menú'),
                  ),
                ],
              ),
            );
          }
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const Padding(
                padding: EdgeInsets.only(bottom: 12),
                child: Center(
                  child: Text(
                    'Se actualiza automáticamente',
                    style: TextStyle(color: GriColors.gray, fontSize: 12),
                  ),
                ),
              ),
              for (final pedido in pedidos) _PedidoCard(pedido: pedido),
            ],
          );
        },
      ),
      bottomNavigationBar:
          sesion == null ? null : _cuentaSection(sesion),
    );
  }

  Widget _cuentaSection(SesionMesa sesion) {
    final yaPedida = sesion.solicitaCuenta || _cuentaYaPedida;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: yaPedida
            ? Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      color: GriColors.chipConfirmadaBg,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Center(
                      child: Text(
                        'Cuenta solicitada ✓',
                        style: TextStyle(
                          color: GriColors.chipConfirmadaFg,
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  // PAGO-02 UI: pagar la cuenta en línea desde acá.
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => context.push('/mesa/pago'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: GriColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      icon: const Icon(Icons.credit_card),
                      label: const Text(
                        'Pagar en línea 💳',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              )
            : SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _pidiendoCuenta ? null : _pedirCuenta,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: GriColors.primary,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: GriColors.primaryTint,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  icon: _pidiendoCuenta
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.receipt_long),
                  label: const Text(
                    'Pedir la cuenta',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
      ),
    );
  }
}

/// Card de un pedido: chip de estado coloreado + items + notas + total.
class _PedidoCard extends StatelessWidget {
  const _PedidoCard({required this.pedido});

  final Pedido pedido;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Pedido #${pedido.id}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: GriColors.text,
                    ),
                  ),
                ),
                _EstadoChip(pedido: pedido),
              ],
            ),
            const SizedBox(height: 10),
            for (final item in pedido.items)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Text('${item.nombre} ×${item.cantidad}'),
              ),
            if (pedido.notas != null && pedido.notas!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                '📝 ${pedido.notas}',
                style: const TextStyle(
                  color: GriColors.gray,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
            const SizedBox(height: 10),
            Row(
              children: [
                const Spacer(),
                Text(
                  formatCOP(pedido.total),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: GriColors.primary,
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

/// Chip coloreado según el estado (5 estados, paleta PedidoEstadoX).
class _EstadoChip extends StatelessWidget {
  const _EstadoChip({required this.pedido});

  final Pedido pedido;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: pedido.estadoBg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        pedido.estadoLabel,
        style: TextStyle(
          color: pedido.estadoColor,
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
      ),
    );
  }
}
