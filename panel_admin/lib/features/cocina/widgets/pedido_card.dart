import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/format.dart';
import '../../../core/theme.dart';
import '../../../models/pedido_staff.dart';

/// Card de un pedido de la cola de cocina (ADMN-05).
///
/// * Borde lateral + chip del color del estado (enviado azul, aceptado
///   naranja, en_preparación morado, servido verde — [EstadoPedidoUI]).
/// * Header: "Mesa N" grande + chip estado + hora HH:mm.
/// * Badge destacado "🍽️ pidió la cuenta" (PAGO-01) si [PedidoStaff.solicitaCuenta].
/// * Items "nombre ×cantidad" con subtotal; total COP destacado; notas en
///   itálica; usuario sutil.
/// * Botones según `nextActions(rol)` — [rol] llega por parámetro para
///   testeabilidad (la pantalla lo saca del authStateProvider). El server
///   es la autoridad: 409/403 se manejan upstream.
class PedidoCard extends StatelessWidget {
  const PedidoCard({
    super.key,
    required this.pedido,
    required this.rol,
    this.onAvanzar,
  });

  final PedidoStaff pedido;

  /// Rol del usuario autenticado ('cocina' | 'mesero' | 'admin_restaurante'
  /// | 'super_admin') — decide qué botones se muestran.
  final String rol;

  /// Callback de avance: recibe el pedido + el estado DESTINO. La pantalla
  /// decide cómo llamar a la API y cómo refrescar la cola.
  final void Function(PedidoStaff pedido, EstadoPedido destino)? onAvanzar;

  @override
  Widget build(BuildContext context) {
    final estado = pedido.estado;
    final acciones = pedido.nextActions(rol);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0D000000),
            blurRadius: 12,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(15),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Borde lateral del color del estado.
              SizedBox(width: 6, child: ColoredBox(color: estado.color)),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── Header: Mesa N + chip estado + hora ─────────────
                      Row(
                        children: [
                          Text(
                            'Mesa ${pedido.mesaNumero}',
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: GriColors.text,
                            ),
                          ),
                          const SizedBox(width: 10),
                          _EstadoChip(estado: estado),
                          const Spacer(),
                          Text(
                            DateFormat('HH:mm').format(pedido.createdAt),
                            style: const TextStyle(color: GriColors.gray),
                          ),
                        ],
                      ),

                      // ── Badge cuenta (PAGO-01) ──────────────────────────
                      if (pedido.solicitaCuenta) ...[
                        const SizedBox(height: 12),
                        const _CuentaBadge(),
                      ],
                      const SizedBox(height: 14),

                      // ── Items ───────────────────────────────────────────
                      for (final item in pedido.items)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  '${item.nombre} ×${item.cantidad}',
                                  style: const TextStyle(
                                    color: GriColors.text,
                                    fontSize: 15,
                                  ),
                                ),
                              ),
                              Text(
                                formatCOP(item.subtotal),
                                style: const TextStyle(color: GriColors.gray),
                              ),
                            ],
                          ),
                        ),
                      const Divider(height: 18),

                      // ── Total ───────────────────────────────────────────
                      Row(
                        children: [
                          const Text(
                            'Total',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: GriColors.text,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            formatCOP(pedido.total),
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                              color: GriColors.text,
                            ),
                          ),
                        ],
                      ),

                      // ── Notas ────────────────────────────────────────────
                      if (pedido.notas != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          '📝 “${pedido.notas}”',
                          style: const TextStyle(
                            fontStyle: FontStyle.italic,
                            color: GriColors.gray,
                          ),
                        ),
                      ],
                      const SizedBox(height: 6),
                      Text(
                        'Pedido por ${pedido.usuarioNombre}',
                        style: const TextStyle(
                          color: GriColors.gray,
                          fontSize: 12,
                        ),
                      ),

                      // ── Acciones según matriz rol×estado ────────────────
                      if (acciones.isNotEmpty) ...[
                        const SizedBox(height: 14),
                        Wrap(
                          spacing: 10,
                          runSpacing: 8,
                          children: [
                            for (final a in acciones)
                              a.destino == EstadoPedido.rechazado
                                  ? OutlinedButton(
                                      onPressed: onAvanzar == null
                                          ? null
                                          : () => onAvanzar!(pedido, a.destino),
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor:
                                            GriColors.mesaOcupadaFg,
                                        side: const BorderSide(
                                          color: GriColors.mesaOcupadaDot,
                                        ),
                                      ),
                                      child: Text(a.label),
                                    )
                                  : ElevatedButton(
                                      onPressed: onAvanzar == null
                                          ? null
                                          : () => onAvanzar!(pedido, a.destino),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: GriColors.primary,
                                        foregroundColor: Colors.white,
                                      ),
                                      child: Text(a.label),
                                    ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Chip compacto del estado (tint del color del estado).
class _EstadoChip extends StatelessWidget {
  const _EstadoChip({required this.estado});

  final EstadoPedido estado;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: estado.color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        estado.label,
        style: TextStyle(
          color: estado.color,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

/// Badge "pidió la cuenta" — amarillo del mockup, visible a distancia.
class _CuentaBadge extends StatelessWidget {
  const _CuentaBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: GriColors.mesaReservadaBg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('🍽️', style: TextStyle(fontSize: 14)),
          SizedBox(width: 6),
          Text(
            'pidió la cuenta',
            style: TextStyle(
              color: GriColors.mesaReservadaFg,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
