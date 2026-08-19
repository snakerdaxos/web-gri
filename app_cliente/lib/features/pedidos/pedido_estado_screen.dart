import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/firebase_providers.dart';
import '../../core/format.dart';
import '../../core/gri_icons.dart';
import '../../core/theme.dart';
import '../../models/pedido.dart';
import '../../models/sesion_mesa.dart';
import '../pagos/calificacion_sheet.dart';
import '../sesion_qr/sesion_provider.dart';
import '../../core/design_tokens.dart';
import 'pedidos_provider.dart';

/// Estado de los pedidos de la sesión (PEDI-04 UI) — cards con chips de
/// estado coloreados que se actualizan SOLOS (stream snapshots, MIGRA-05)
/// + botón "Pedir la cuenta" (PAGO-01; el checkout en línea quedó
/// DIFERIDO en Phase 10) + calificación de pedidos servidos tras el
/// cierre de la sesión.
class PedidoEstadoScreen extends ConsumerStatefulWidget {
  const PedidoEstadoScreen({super.key});

  @override
  ConsumerState<PedidoEstadoScreen> createState() =>
      _PedidoEstadoScreenState();
}

class _PedidoEstadoScreenState extends ConsumerState<PedidoEstadoScreen> {
  bool _pidiendoCuenta = false;

  /// Mirror local tras pedir la cuenta exitosamente — la visibilidad no
  /// depende solo del stream (robusto en cualquier flujo).
  bool _cuentaYaPedida = false;

  Future<void> _pedirCuenta() async {
    if (_pidiendoCuenta) return;
    final sesion = ref.read(sesionActualProvider).value;
    final uid = ref.read(firebaseAuthProvider).currentUser?.uid;
    if (sesion == null || uid == null) return;
    setState(() => _pidiendoCuenta = true);
    try {
      await solicitarCuenta(
        ref.read(firestoreProvider),
        uid: uid,
        mesaId: sesion.mesaId,
      );
      if (!mounted) return;
      setState(() => _cuentaYaPedida = true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cuenta solicitada — el mesero viene en camino'),
          backgroundColor: GriColors.green,
        ),
      );
    } on PedidoException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.message),
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

  void _abrirCalificacion(String pedidoId) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => CalificacionSheet(pedidoId: pedidoId),
    );
  }

  @override
  Widget build(BuildContext context) {
    final sesion = ref.watch(sesionActualProvider).value;
    final pedidosAsync = ref.watch(pedidosSessionProvider);

    final sesionCerrada = sesion != null && sesion.estado != 'activa';

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
              const Icon(GriIcons.enVivo, size: 40, color: GriColors.gray),
              const SizedBox(height: GriSpacing.sm),
              const Text('Error al cargar tus pedidos'),
              const SizedBox(height: GriSpacing.md),
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
                  const Icon(GriIcons.cocinando,
                      size: 40, color: GriColors.gray),
                  const SizedBox(height: GriSpacing.sm),
                  const Text('Aún no hay pedidos en esta sesión'),
                  const SizedBox(height: GriSpacing.md),
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
            padding: const EdgeInsets.all(GriSpacing.md),
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Center(
                  child: Text(
                    'Se actualiza automáticamente',
                    style: GriText.auxiliar.copyWith(color: GriColors.gray),
                  ),
                ),
              ),
              for (final pedido in pedidos)
                _PedidoCard(
                  pedido: pedido,
                  // Calificación: pedido servido + sesión cerrada (locked).
                  onCalificar: sesionCerrada && pedido.estado == 'servido'
                      ? () => _abrirCalificacion(pedido.id)
                      : null,
                ),
            ],
          );
        },
      ),
      bottomNavigationBar:
          sesion == null ? null : _cuentaSection(sesion, sesionCerrada),
    );
  }

  Widget _cuentaSection(SesionMesa sesion, bool sesionCerrada) {
    if (sesionCerrada) {
      // Tras el cierre: el staff ya llevó la cuenta — solo queda calificar
      // (los CTAs viven en los cards de pedidos servidos).
      return const SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(GriSpacing.md, GriSpacing.sm, GriSpacing.md, 12),
          child: Center(
            child: Text(
              // ignore: lines_longer_than_80_chars
              'Sesión cerrada — ¡gracias por tu visita! 🙌', // EMOJI-OK: despedida
              style: TextStyle(color: GriColors.gray),
            ),
          ),
        ),
      );
    }

    final yaPedida = sesion.cuentaSolicitada || _cuentaYaPedida;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(GriSpacing.md, GriSpacing.sm, GriSpacing.md, 12),
        child: yaPedida
            ? Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: GriColors.chipConfirmadaBg,
                  borderRadius: BorderRadius.circular(12),
                ),
                // El ✓ era un glifo dentro del texto: pasa a Icon en un Row
                // con el MISMO tamano (15 = el fontSize del Text) y el mismo
                // color. La cadena queda sin el glifo para que el lector de
                // pantalla no lea "marca de verificacion" detras de la frase.
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Cuenta solicitada',
                      style: GriText.boton.copyWith(color: GriColors.chipConfirmadaFg),
                    ),
                    const SizedBox(width: GriSpacing.xs),
                    const Icon(GriIcons.confirmado,
                        size: 15, color: GriColors.chipConfirmadaFg),
                  ],
                ),
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
                    style: GriText.botonGrande,
                  ),
                ),
              ),
      ),
    );
  }
}

/// Card de un pedido: chip de estado coloreado + items + total (+ CTA
/// calificar cuando la sesión cerró y el pedido está servido).
class _PedidoCard extends StatelessWidget {
  const _PedidoCard({required this.pedido, this.onCalificar});

  final Pedido pedido;
  final VoidCallback? onCalificar;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(GriSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Pedido #${pedido.codigoCorto}',
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
            const SizedBox(height: 10),
            Row(
              children: [
                const Spacer(),
                Text(
                  formatCOP(pedido.total),
                  style: GriText.botonGrande.copyWith(color: GriColors.primary),
                ),
              ],
            ),
            if (onCalificar != null) ...[
              const SizedBox(height: GriSpacing.sm),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: onCalificar,
                  icon: const Icon(Icons.star_border, color: GriColors.calificacionEstrella),
                  label: const Text(
                    'Calificar',
                    style: TextStyle(
                        color: GriColors.calificacionEstrella,
                        fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
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
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: GriSpacing.xs),
      decoration: BoxDecoration(
        color: pedido.estadoBg(context),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        pedido.estadoLabel,
        style: GriText.chip.copyWith(color: pedido.estadoColor(context)),
      ),
    );
  }
}
