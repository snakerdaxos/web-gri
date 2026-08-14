import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme.dart';
import '../../models/reserva.dart';
import 'reserva_controller.dart';
import 'reservas_provider.dart';

/// Tab Reservas (RESV-03/04) — las reservas del cliente divididas en
/// Próximas (fecha >= hoy) y Pasadas (fecha < hoy), split client-side
/// (comparación lexicográfica de fechas ISO — `Reserva.esProxima`).
/// Las próximas confirmadas se pueden cancelar (con dialog de confirmación).
class MisReservasScreen extends ConsumerWidget {
  const MisReservasScreen({super.key});

  static String hoyString() {
    final now = DateTime.now();
    return '${now.year.toString().padLeft(4, '0')}-'
        '${now.month.toString().padLeft(2, '0')}-'
        '${now.day.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(reservasProvider);
    final saving = ref.watch(reservaControllerProvider).isLoading;

    return Scaffold(
      backgroundColor: GriColors.background,
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/reservas/wizard'),
        backgroundColor: GriColors.primary,
        foregroundColor: Colors.white,
        child: const Icon(Icons.add),
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('📅', style: TextStyle(fontSize: 40)),
              const SizedBox(height: 8),
              const Text('Error al cargar tus reservas'),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () => ref.invalidate(reservasProvider),
                icon: const Icon(Icons.refresh),
                label: const Text('Reintentar'),
              ),
            ],
          ),
        ),
        data: (reservas) {
          if (reservas.isEmpty) {
            return const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('📅', style: TextStyle(fontSize: 40)),
                  SizedBox(height: 8),
                  Text('Aún no tienes reservas'),
                  SizedBox(height: 4),
                  Text(
                    'Toca el botón + para crear una',
                    style: TextStyle(color: GriColors.gray),
                  ),
                ],
              ),
            );
          }

          final hoy = hoyString();
          final proximas = reservas.where((r) => r.esProxima(hoy)).toList();
          final pasadas = reservas.where((r) => !r.esProxima(hoy)).toList();

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const Text(
                'Mis reservas',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: GriColors.text,
                ),
              ),
              const SizedBox(height: 16),
              _Seccion(
                titulo: 'Próximas',
                vacio: 'No tienes reservas próximas',
                reservas: proximas,
                esProximaSeccion: true,
                saving: saving,
              ),
              if (pasadas.isNotEmpty) ...[
                const SizedBox(height: 8),
                _Seccion(
                  titulo: 'Pasadas',
                  vacio: '',
                  reservas: pasadas,
                  esProximaSeccion: false,
                  saving: saving,
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _Seccion extends ConsumerWidget {
  const _Seccion({
    required this.titulo,
    required this.vacio,
    required this.reservas,
    required this.esProximaSeccion,
    required this.saving,
  });

  final String titulo;
  final String vacio;
  final List<Reserva> reservas;
  final bool esProximaSeccion;
  final bool saving;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          titulo,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: GriColors.primary,
          ),
        ),
        const SizedBox(height: 8),
        if (reservas.isEmpty) ...[
          if (vacio.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child:
                  Text(vacio, style: const TextStyle(color: GriColors.gray)),
            ),
        ] else ...[
          for (final reserva in reservas)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _ReservaCard(
                reserva: reserva,
                puedeCancelar: esProximaSeccion &&
                    reserva.estadoReserva == EstadoReserva.confirmada,
                saving: saving,
              ),
            ),
        ],
      ],
    );
  }
}

class _ReservaCard extends ConsumerWidget {
  const _ReservaCard({
    required this.reserva,
    required this.puedeCancelar,
    required this.saving,
  });

  final Reserva reserva;
  final bool puedeCancelar;
  final bool saving;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    reserva.restauranteNombre,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: GriColors.text,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                EstadoChip(estado: reserva.estado),
              ],
            ),
            const SizedBox(height: 10),
            Text('📅 ${reserva.fecha} · ${reserva.horaLabel}'),
            const SizedBox(height: 4),
            Text(
              '🪑 Mesa ${reserva.mesaNumero} · 👥 ${reserva.numPersonas} personas',
            ),
            if (puedeCancelar) ...[
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: saving
                      ? null
                      : () => _confirmarCancelacion(context, ref),
                  style: TextButton.styleFrom(
                    foregroundColor: GriColors.chipCanceladaFg,
                  ),
                  child: const Text('Cancelar'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _confirmarCancelacion(
      BuildContext context, WidgetRef ref) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('¿Cancelar esta reserva?'),
        content: Text(
          '${reserva.restauranteNombre} · ${reserva.fecha} a las '
          '${reserva.horaLabel}. Esta acción no se puede deshacer.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Volver'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: TextButton.styleFrom(
              foregroundColor: GriColors.chipCanceladaFg,
            ),
            child: const Text('Sí, cancelar'),
          ),
        ],
      ),
    );
    if (confirmar != true) return;

    try {
      await ref.read(reservaControllerProvider.notifier).cancel(reserva.id);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Reserva cancelada'),
          backgroundColor: GriColors.gray,
        ),
      );
    } on Exception catch (e) {
      if (!context.mounted) return;
      final msg = _statusCodeOf(e) == 409
          ? 'La reserva ya estaba cancelada'
          : 'No se pudo cancelar la reserva';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(msg),
          backgroundColor: GriColors.chipCanceladaFg,
        ),
      );
    }
  }

  int? _statusCodeOf(Object e) {
    try {
      final dynamic dyn = e;
      return dyn.response?.statusCode as int?;
    } catch (_) {
      return null;
    }
  }
}

/// Chip de estado de reserva — colores del mockup (.status):
/// confirmada verde (#dff7eb/#168a52), cancelada rojo suave.
class EstadoChip extends StatelessWidget {
  const EstadoChip({super.key, required this.estado});

  final String estado;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: GriColors.estadoChipBg(estado),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        estado[0].toUpperCase() + estado.substring(1),
        style: TextStyle(
          fontSize: 12,
          color: GriColors.estadoChipFg(estado),
        ),
      ),
    );
  }
}
