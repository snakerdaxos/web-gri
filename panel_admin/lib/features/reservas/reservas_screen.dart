import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/api_client.dart';
import '../../core/theme.dart';
import '../../core/token_provider.dart';
import '../../models/reserva.dart';
import '../dashboard/restaurante_provider.dart';
import 'reservas_provider.dart';

/// Pantalla /reservas (RESV-05 UI): reservas del día del tenant con
/// selector de fecha y botón 'Marcar ocupada' en las confirmadas.
///
/// Consume el endpoint F5 EXISTENTE (`GET /staff/reservas?fecha=`) vía
/// [reservasDelDiaProvider] (family por fecha). Al llegar el cliente, el
/// staff marca la mesa ocupada con `setMesaEstado` (08-03) — el server es
/// la autoridad: un 409 (la mesa ya cambió de estado por otra vía) se
/// traduce a SnackBar + refresh del listado (threat model 08-05).
class ReservasScreen extends ConsumerStatefulWidget {
  const ReservasScreen({super.key});

  @override
  ConsumerState<ReservasScreen> createState() => _ReservasScreenState();
}

class _ReservasScreenState extends ConsumerState<ReservasScreen> {
  /// Fecha consultada (estado local — el family del provider hace el resto).
  DateTime _fecha = DateTime.now();

  static final DateFormat _fmt = DateFormat('dd/MM/yyyy');

  /// Key del family: YYYY-MM-DD (substring del ISO8601).
  String get _fechaKey => _fecha.toIso8601String().substring(0, 10);

  Future<void> _pickFecha() async {
    final elegida = await showDatePicker(
      context: context,
      initialDate: _fecha,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (elegida == null) return;
    setState(() => _fecha = elegida);
    // Nueva key → nueva instancia del family (fetch fresco). El invalidate
    // es defensivo por si esa fecha ya se consultó antes en la sesión.
    ref.invalidate(reservasDelDiaProvider(_fechaKey));
  }

  Future<void> _marcarOcupada(Reserva reserva) async {
    // queryRid como en cocina: super_admin manda el tenant del dropdown;
    // staff viaja sin param (el tenant sale del token).
    final user = ref.read(authStateProvider).value;
    final selectedRid = ref.read(currentRestauranteIdProvider);
    final rid = selectedRid ?? user?.restaurantId;
    final queryRid = user?.isSuperAdmin == true ? rid : null;

    try {
      await ref.read(apiClientProvider).setMesaEstado(
            // mesaId String (doc ID = código QR, Phase 10-05) — el wire
            // REST legacy recibía el int como path param.
            reserva.mesaId.toString(),
            'ocupada',
            restauranteId: queryRid,
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Mesa ${reserva.mesaNumero} marcada ocupada')),
      );
      ref.invalidate(reservasDelDiaProvider(_fechaKey));
    } on DioException catch (e) {
      if (!mounted) return;
      // 409: la mesa ya cambió de estado por otra vía (carrera) — el
      // listado se refresca para mostrar la verdad del server.
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e.response?.statusCode == 409
                ? 'La mesa ya cambió de estado'
                : 'Error al marcar la mesa',
          ),
        ),
      );
      ref.invalidate(reservasDelDiaProvider(_fechaKey));
    }
  }

  @override
  Widget build(BuildContext context) {
    final reservasAsync = ref.watch(reservasDelDiaProvider(_fechaKey));

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
                OutlinedButton.icon(
                  onPressed: _pickFecha,
                  icon: const Text('📅'),
                  label: Text(_fmt.format(_fecha)),
                ),
                const SizedBox(width: 12),
                TextButton(
                  onPressed: () {
                    setState(() => _fecha = DateTime.now());
                    ref.invalidate(reservasDelDiaProvider(_fechaKey));
                  },
                  child: const Text('Hoy'),
                ),
              ],
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
                        onPressed: () =>
                            ref.invalidate(reservasDelDiaProvider(_fechaKey)),
                        child: const Text('Reintentar'),
                      ),
                    ],
                  ),
                ),
                data: (reservas) => reservas.isEmpty
                    ? const Center(
                        child: Text(
                          'Sin reservas para este día',
                          style: TextStyle(color: GriColors.gray),
                        ),
                      )
                    : ListView.builder(
                        itemCount: reservas.length,
                        itemBuilder: (context, i) =>
                            _ReservaCard(
                              reserva: reservas[i],
                              onMarcarOcupada: _marcarOcupada,
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

/// Card de una reserva: hora, mesa, personas, chip de estado y — SOLO en
/// confirmadas — el botón 'Marcar ocupada' (el resto de estados no tiene
/// acción sobre la mesa).
class _ReservaCard extends StatelessWidget {
  const _ReservaCard({required this.reserva, required this.onMarcarOcupada});

  final Reserva reserva;
  final void Function(Reserva) onMarcarOcupada;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            // Hora (HH:MM del HH:MM:SS del wire).
            Text(
              reserva.horaInicio.substring(0, 5),
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
            if (reserva.estado == 'confirmada') ...[
              const SizedBox(width: 12),
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
