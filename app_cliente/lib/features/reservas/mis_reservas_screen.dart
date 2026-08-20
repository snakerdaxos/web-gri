import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/firebase_providers.dart';
import '../../core/gri_icons.dart';
import '../../core/theme.dart';
import '../../models/reserva.dart';
import '../shared/icono_inline.dart';
import '../../core/design_tokens.dart';
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
    final uid = ref.watch(firebaseAuthProvider).currentUser?.uid;
    final AsyncValue<List<Reserva>> async = uid == null
        ? const AsyncLoading()
        : ref.watch(misReservasProvider(uid));
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
              const Icon(GriIcons.reservas, size: 40, color: GriColors.gray),
              const SizedBox(height: GriSpacing.sm),
              const Text('Error al cargar tus reservas'),
              const SizedBox(height: GriSpacing.md),
              ElevatedButton.icon(
                onPressed: () {
                  if (uid != null) ref.invalidate(misReservasProvider(uid));
                },
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
                  Icon(GriIcons.reservas, size: 40, color: GriColors.gray),
                  SizedBox(height: GriSpacing.sm),
                  Text('Aún no tienes reservas'),
                  SizedBox(height: GriSpacing.xs),
                  Text(
                    'Toca el botón + para crear una',
                    style: TextStyle(color: GriColors.textoSecundarioAccesible),
                  ),
                ],
              ),
            );
          }

          final hoy = hoyString();
          final proximas = reservas.where((r) => r.esProxima(hoy)).toList();
          final pasadas = reservas.where((r) => !r.esProxima(hoy)).toList();

          return ListView(
            padding: const EdgeInsets.all(GriSpacing.md),
            children: [
              Text(
                'Mis reservas',
                style: GriText.tituloPantalla.copyWith(color: GriColors.text),
              ),
              const SizedBox(height: GriSpacing.md),
              _Seccion(
                titulo: 'Próximas',
                vacio: 'No tienes reservas próximas',
                reservas: proximas,
                esProximaSeccion: true,
                saving: saving,
              ),
              if (pasadas.isNotEmpty) ...[
                const SizedBox(height: GriSpacing.sm),
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
          style: GriText.botonGrande.copyWith(color: GriColors.primary),
        ),
        const SizedBox(height: GriSpacing.sm),
        if (reservas.isEmpty) ...[
          if (vacio.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: GriSpacing.sm),
              child:
                  Text(vacio, style: const TextStyle(color: GriColors.textoSecundarioAccesible)),
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
        padding: const EdgeInsets.all(GriSpacing.md),
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
                    style: GriText.botonGrande.copyWith(color: GriColors.text),
                  ),
                ),
                const SizedBox(width: GriSpacing.sm),
                EstadoChip(estado: reserva.estado),
              ],
            ),
            const SizedBox(height: 10),
            Text.rich(TextSpan(children: [
              iconoInline(GriIcons.reservas),
              TextSpan(text: ' ${reserva.fechaStr} · ${reserva.horaLabel}'),
            ])),
            const SizedBox(height: GriSpacing.xs),
            Text.rich(TextSpan(children: [
              iconoInline(GriIcons.mesa),
              TextSpan(text: ' Mesa ${reserva.mesaNumero} · '),
              iconoInline(GriIcons.personas),
              TextSpan(text: ' ${reserva.numPersonas} personas'),
            ])),
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
          '${reserva.restauranteNombre} · ${reserva.fechaStr} a las '
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
      await ref.read(reservaControllerProvider.notifier).cancel(reserva);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Reserva cancelada'),
          backgroundColor: GriColors.gray,
        ),
      );
    } on Exception catch (e) {
      if (!context.mounted) return;
      // ReservaException trae el mensaje user-friendly del dominio
      // (ya cancelada / pasada / no encontrada).
      final msg = e is ReservaException
          ? e.message
          : 'No se pudo cancelar la reserva';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(msg),
          backgroundColor: GriColors.chipCanceladaFg,
        ),
      );
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
        style: GriText.auxiliar.copyWith(color: GriColors.estadoChipFg(estado)),
      ),
    );
  }
}
