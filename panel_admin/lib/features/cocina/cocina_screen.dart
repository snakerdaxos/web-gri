import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/firebase_providers.dart';
import '../../core/state_machines.dart';
import '../../core/theme.dart';
import '../../models/pedido_staff.dart';
import 'pedidos_staff_provider.dart';
import 'widgets/pedido_card.dart';

/// Vista cocina (ADMN-05) — cola de pedidos activos EN VIVO (Phase 10:
/// onSnapshot nativo — WS y polling retirados de esta vista, MIGRA-05).
///
/// Vive DENTRO del ShellRoute del panel (sin Scaffold propio de AppShell):
/// el body es un header + [ListView] de [PedidoCard]. `onAvanzar` escribe
/// el nuevo estado a Firestore vía [avanzarPedidoStaff] (transición +
/// matriz rol validadas ANTES del update; las rules re-fuerzan) y la cola
/// se refresca sola por el snapshot — sin invalidate manual.
class CocinaScreen extends ConsumerWidget {
  const CocinaScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pedidosAsync = ref.watch(pedidosStaffProvider);
    // Rol de claims (gating de UI; la matriz la re-valida avanzarPedidoStaff
    // y las rules son la autoridad final).
    final rol = ref.watch(claimsProvider).value?.role ?? '';
    final avisos = ref.watch(avisoCuentaProvider).value ?? const [];

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
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Pedidos · Cocina',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: GriColors.text,
                      ),
                    ),
                    SizedBox(height: 5),
                    Text(
                      'Cola de pedidos activos (en vivo)',
                      style: TextStyle(color: GriColors.gray),
                    ),
                  ],
                ),
                // Aviso de cuenta EN VIVO (PAGO-01): sesiones activas con
                // cuentaSolicitada — sustituye el badge del WS. Flexible:
                // en pantallas angostas el badge se acota y su texto
                // ellipsiza (sin RenderFlex overflow). Tap → sheet de
                // entrega (cierra sesión + mesa a limpieza, PAGO-04).
                if (avisos.isNotEmpty)
                  Flexible(
                    child: _CuentaAvisosBadge(
                      cantidad: avisos.length,
                      onTap: () => _abrirAvisosCuenta(context, ref, avisos),
                    ),
                  ),
              ],
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

  /// Sheet de avisos de cuenta: una fila por mesa que pidió la cuenta con
  /// la acción "Entregar cuenta" ([entregarCuenta] — cierra la sesión y
  /// pasa la mesa a limpieza). El badge del header desaparece SOLO al
  /// commitear la tx (el stream `avisoCuenta` re-emite — sin invalidate).
  Future<void> _abrirAvisosCuenta(
    BuildContext context,
    WidgetRef ref,
    List<AvisoCuenta> avisos,
  ) {
    return showModalBottomSheet<void>(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 18, 20, 6),
              child: Row(
                children: [
                  Text(
                    'Mesas que pidieron la cuenta',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            for (final a in avisos)
              ListTile(
                leading: const Text('🍽️', style: TextStyle(fontSize: 20)),
                title: Text('Mesa ${a.mesaNumero}'),
                subtitle: const Text(
                  'Entregar cuenta cierra la sesión y pasa la mesa a limpieza',
                ),
                onTap: () => _entregar(context, ref, a),
              ),
          ],
        ),
      ),
    );
  }

  /// Entrega + feedback. Capturas síncronas ANTES del await (patrón
  /// _avanzar). El sheet se cierra primero; el aviso desaparece del header
  /// por el onSnapshot (JAMÁS se muta estado local).
  Future<void> _entregar(
    BuildContext context,
    WidgetRef ref,
    AvisoCuenta aviso,
  ) async {
    final messenger = ScaffoldMessenger.maybeOf(context);
    final db = ref.read(firestoreProvider);

    Navigator.of(context).pop();

    try {
      await entregarCuenta(db, mesaId: aviso.mesaId);
      messenger?.showSnackBar(
        SnackBar(
          content:
              Text('Mesa ${aviso.mesaNumero} — cuenta entregada (sesión cerrada)'),
          duration: const Duration(seconds: 3),
        ),
      );
    } on StateError catch (e) {
      messenger?.showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    } catch (_) {
      messenger?.showSnackBar(
        const SnackBar(
          content: Text('No se pudo entregar la cuenta'),
          duration: Duration(seconds: 3),
        ),
      );
    }
  }

  /// Avance + feedback accionable. El [ScaffoldMessenger] se captura ANTES
  /// del await (sin context a través del gap async).
  ///
  /// SIN invalidate post-escritura: el onSnapshot de la cola emite el doc
  /// actualizado por sí solo (server es la fuente de verdad).
  Future<void> _avanzar(
    BuildContext context,
    WidgetRef ref,
    PedidoStaff pedido,
    EstadoPedido destino,
  ) async {
    final messenger = ScaffoldMessenger.maybeOf(context);
    final db = ref.read(firestoreProvider);
    final rol = ref.read(claimsProvider).value?.role ?? '';

    try {
      await avanzarPedidoStaff(db, rol: rol, pedido: pedido, destino: destino);
    } on TransicionInvalidaException {
      // La carrera la ganó otro staff: la cola ya se refrescó sola.
      messenger?.showSnackBar(
        const SnackBar(
          content: Text('Alguien ya movió este pedido — refrescando'),
          duration: Duration(seconds: 3),
        ),
      );
    } on StateError catch (e) {
      messenger?.showSnackBar(
        SnackBar(
          content: Text(e.message),
          duration: const Duration(seconds: 3),
        ),
      );
    } catch (_) {
      messenger?.showSnackBar(
        const SnackBar(
          content: Text('No se pudo actualizar el pedido'),
          duration: Duration(seconds: 3),
        ),
      );
    }
  }
}

/// Badge "pidieron la cuenta" para el header de cocina (amarillo del
/// mockup, visible a distancia). Tap → sheet de entrega de cuentas.
class _CuentaAvisosBadge extends StatelessWidget {
  const _CuentaAvisosBadge({required this.cantidad, this.onTap});

  final int cantidad;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: GriColors.mesaReservadaBg,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('🍽️', style: TextStyle(fontSize: 14)),
            const SizedBox(width: 6),
            // Flexible: el texto se acota al ancho que el header le deje
            // (pantallas angostas) en vez de desbordar el Row del badge.
            Flexible(
              child: Text(
                cantidad == 1
                    ? '1 mesa pidió la cuenta'
                    : '$cantidad mesas pidieron la cuenta',
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: GriColors.mesaReservadaFg,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
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
