import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/firebase_providers.dart';
import '../../core/state_machines.dart';
import '../../core/theme.dart';
import '../../models/reserva.dart';
import 'reservas_provider.dart';

/// Pantalla /reservas (RESV-05 UI, 10-06): reservas de HOY del tenant EN
/// VIVO (`reservasHoyProvider` — misma query del dashboard, onSnapshot).
///
/// * 'Marcar ocupada' (confirmadas): transición de la MESA
///   `reservada → ocupada` vía [marcarMesaOcupada] — la transición se
///   valida ANTES del write ([cambiarEstadoMesa] 10-05; las rules
///   re-fuerzan `transMesa`). Un [TransicionInvalidaException] (otro staff
///   movió la mesa primero) se traduce a SnackBar — el stream ya muestra
///   la verdad.
/// * 'No-show' (pendientes/confirmadas): [cancelarReservaNoShow] — la
///   reserva pasa a `cancelada` (staff lo permite rules).
class ReservasScreen extends ConsumerWidget {
  const ReservasScreen({super.key});

  Future<void> _marcarOcupada(BuildContext context, WidgetRef ref,
      Reserva reserva) async {
    final messenger = ScaffoldMessenger.maybeOf(context);
    final db = ref.read(firestoreProvider);

    try {
      await marcarMesaOcupada(db, reserva: reserva);
      messenger?.showSnackBar(
        SnackBar(
          content: Text('Mesa ${reserva.mesaNumero} marcada ocupada'),
          duration: const Duration(seconds: 3),
        ),
      );
    } on TransicionInvalidaException {
      messenger?.showSnackBar(
        const SnackBar(
          content: Text('La mesa ya cambió de estado'),
          duration: Duration(seconds: 3),
        ),
      );
    } catch (_) {
      messenger?.showSnackBar(
        const SnackBar(
          content: Text('Error al marcar la mesa'),
          duration: Duration(seconds: 3),
        ),
      );
    }
    // Sin invalidate local: el onSnapshot mantiene TODO vivo (la reserva
    // no cambia — lo que se movió fue la mesa).
  }

  Future<void> _cancelarNoShow(
      BuildContext context, WidgetRef ref, Reserva reserva) async {
    final messenger = ScaffoldMessenger.maybeOf(context);
    final db = ref.read(firestoreProvider);

    try {
      await cancelarReservaNoShow(db, reserva: reserva);
      messenger?.showSnackBar(
        const SnackBar(
          content: Text('Reserva cancelada'),
          duration: Duration(seconds: 3),
        ),
      );
    } catch (_) {
      messenger?.showSnackBar(
        const SnackBar(
          content: Text('No se pudo cancelar la reserva'),
          duration: Duration(seconds: 3),
        ),
      );
    }
    // El stream re-emite con la reserva cancelada (chip tachado) solo.
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reservasAsync = ref.watch(reservasHoyProvider);

    return Material(
      // Material ancestor: en producción lo provee el Scaffold del AppShell;
      // standalone (tests) sin esto Flutter inyecta estilos fallback.
      color: GriColors.background,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Text('📅', style: TextStyle(fontSize: 18)),
                const SizedBox(width: 8),
                Text(
                  'Reservas de hoy (${DateFormat('dd/MM/yyyy').format(DateTime.now())})',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: GriColors.text,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            const Text(
              'En vivo — al llegar el cliente marca la mesa ocupada',
              style: TextStyle(color: GriColors.gray, fontSize: 13),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: reservasAsync.when(
                loading: () =>
                    const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'Error cargando reservas',
                        style: TextStyle(color: GriColors.gray),
                      ),
                      TextButton(
                        onPressed: () => ref.invalidate(reservasHoyProvider),
                        child: const Text('Reintentar'),
                      ),
                    ],
                  ),
                ),
                data: (reservas) => reservas.isEmpty
                    ? const Center(
                        child: Text(
                          'Sin reservas para hoy',
                          style: TextStyle(color: GriColors.gray),
                        ),
                      )
                    : ListView.builder(
                        itemCount: reservas.length,
                        itemBuilder: (context, i) => _ReservaCard(
                          reserva: reservas[i],
                          onMarcarOcupada: (r) => _marcarOcupada(context, ref, r),
                          onNoShow: (r) => _cancelarNoShow(context, ref, r),
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Card de una reserva: hora (HH:mm del Timestamp), mesa, personas, chip
/// de estado y — SOLO en vivas (pendiente/confirmada) — las acciones
/// 'Marcar ocupada' y 'No-show' (las canceladas ya no actúan sobre la
/// mesa).
class _ReservaCard extends StatelessWidget {
  const _ReservaCard({
    required this.reserva,
    required this.onMarcarOcupada,
    required this.onNoShow,
  });

  final Reserva reserva;
  final void Function(Reserva) onMarcarOcupada;
  final void Function(Reserva) onNoShow;

  static final DateFormat _hora = DateFormat('HH:mm');

  @override
  Widget build(BuildContext context) {
    final viva = reserva.estado == 'confirmada' || reserva.estado == 'pendiente';
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            // Hora del slot (Timestamp → HH:mm local).
            Text(
              _hora.format(reserva.fecha),
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: GriColors.text,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Mesa ${reserva.mesaNumero}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: GriColors.text,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${reserva.numPersonas} personas',
                    style: const TextStyle(color: GriColors.gray, fontSize: 13),
                  ),
                ],
              ),
            ),
            _EstadoChip(estado: reserva.estado),
            if (viva) ...[
              const SizedBox(width: 12),
              OutlinedButton(
                onPressed: () => onNoShow(reserva),
                child: const Text('No-show'),
              ),
              const SizedBox(width: 8),
              if (reserva.estado == 'confirmada')
                ElevatedButton(
                  onPressed: () => onMarcarOcupada(reserva),
                  child: const Text('Marcar ocupada'),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Chip de estado: confirmada verde / cancelada rojo TACHADA / pendiente
/// ámbar (paleta de mesas del theme — fuente única de verdad visual).
class _EstadoChip extends StatelessWidget {
  const _EstadoChip({required this.estado});

  final String estado;

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = switch (estado) {
      'confirmada' => (
          GriColors.mesaDisponibleBg,
          GriColors.mesaDisponibleFg,
        ),
      'cancelada' => (GriColors.mesaOcupadaBg, GriColors.mesaOcupadaFg),
      _ => (GriColors.mesaReservadaBg, GriColors.mesaReservadaFg),
    };
    final tachado = estado == 'cancelada';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        estado,
        style: TextStyle(
          color: fg,
          fontSize: 12,
          fontWeight: FontWeight.bold,
          decoration: tachado ? TextDecoration.lineThrough : null,
        ),
      ),
    );
  }
}
