import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/firebase_providers.dart';
import '../../core/state_machines.dart';
import '../../core/async_fallo.dart';
import '../../core/firebase_error_mapper.dart';
import '../../core/theme.dart';
import '../../models/reserva.dart';
import 'reservas_provider.dart';
import '../shared/responsive_page.dart';
import '../../core/design_tokens.dart';
import '../../core/gri_icons.dart';

/// Pantalla /reservas (RESV-05 UI, 10-06): reservas de HOY del tenant EN
/// VIVO (`reservasHoyProvider` — misma query del dashboard, onSnapshot).
///
/// * 'Marcar ocupada' (confirmadas): la MESA pasa a `ocupada` desde el
///   estado que tenga —`reservada` si la reserva se creó hoy, `disponible`
///   si se creó ayer para hoy (11-29)— vía [marcarMesaOcupada]; la
///   transición se valida ANTES del write ([cambiarEstadoMesa] 10-05; las
///   rules re-fuerzan `transMesa`). Un [TransicionInvalidaException] (otro
///   staff movió la mesa primero) se traduce a SnackBar — el stream ya
///   muestra la verdad.
///
/// DEUDA DECLARADA (11-29): el mapa de mesas del dashboard pinta el campo
/// `estado`, así que una reserva para MÁS TARDE HOY creada en un día anterior
/// no tiñe la mesa de amarillo. Es correcto respecto del momento presente
/// —la mesa está libre ahora— pero el operador pierde el aviso. El modelo
/// correcto es que el mapa lea las reservas del día; el usuario eligió el
/// cambio mínimo. ESTA pantalla no se ve afectada: lee la colección
/// `reservas`, no el estado de la mesa.
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
      child: ResponsivePage(
        padding: const EdgeInsets.all(GriSpacing.lg),
        builder: (context, ancho) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(GriIcons.reservas, size: 18, color: GriColors.text),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Reservas de hoy (${DateFormat('dd/MM/yyyy').format(DateTime.now())})',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: GriColors.text,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            const Text(
              'En vivo — al llegar el cliente marca la mesa ocupada',
              style: TextStyle(color: GriColors.textoSecundarioAccesible, fontSize: 13),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: reservasAsync.cuandoConFallo(
                cargando: () =>
                    const Center(child: CircularProgressIndicator()),
                fallo: (e) => Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        mensajeDeFallo(e, contexto: Contexto.reservas),
                        textAlign: TextAlign.center,
                        style: TextStyle(color: GriColors.textoSecundarioAccesible),
                      ),
                      TextButton(
                        onPressed: () => ref.invalidate(reservasHoyProvider),
                        child: const Text('Reintentar'),
                      ),
                    ],
                  ),
                ),
                datos: (reservas) => reservas.isEmpty
                    ? const Center(
                        child: Text(
                          'Sin reservas para hoy',
                          style: TextStyle(color: GriColors.textoSecundarioAccesible),
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

  /// Ancho de tarjeta por debajo del cual las acciones bajan a una segunda
  /// fila.
  ///
  /// La fila única necesita, con la métrica de fuente más ancha posible,
  /// ~650px solo para las partes de tamaño FIJO (hora + chip + los dos
  /// botones). 900 deja margen de sobra y, sobre todo, está por encima de
  /// cualquier ancho de escritorio en el que hoy se ve el panel: a 1200 la
  /// disposición es EXACTAMENTE la de siempre, una sola fila.
  static const double _anchoFilaUnica = 900;

  @override
  Widget build(BuildContext context) {
    final viva = reserva.estado == 'confirmada' || reserva.estado == 'pendiente';

    final hora = Text(
      _hora.format(reserva.fecha),
      style: const TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.bold,
        color: GriColors.text,
      ),
    );
    final info = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Mesa ${reserva.mesaNumero}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: GriColors.text,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          '${reserva.numPersonas} personas',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: GriColors.textoSecundarioAccesible, fontSize: 13),
        ),
      ],
    );
    final botonNoShow = OutlinedButton(
      onPressed: () => onNoShow(reserva),
      child: const Text('No-show'),
    );
    final botonOcupada = reserva.estado == 'confirmada'
        ? ElevatedButton(
            onPressed: () => onMarcarOcupada(reserva),
            child: const Text('Marcar ocupada'),
          )
        : null;
    // Con la separación EXACTA de siempre (8) para la fila única.
    final acciones = <Widget>[
      botonNoShow,
      if (botonOcupada != null) ...[const SizedBox(width: 8), botonOcupada],
    ];

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        // LayoutBuilder y no MediaQuery: lo que decide es el ancho de la
        // TARJETA (que depende del sidebar y del techo de ResponsivePage), no
        // el de la ventana.
        child: LayoutBuilder(
          builder: (context, constraints) {
            final filaUnica = constraints.maxWidth >= _anchoFilaUnica;

            if (filaUnica) {
              // Disposición histórica, intacta.
              return Row(
                children: [
                  hora,
                  const SizedBox(width: 16),
                  Expanded(child: info),
                  _EstadoChip(estado: reserva.estado),
                  if (viva) ...[
                    const SizedBox(width: 12),
                    ...acciones,
                  ],
                ],
              );
            }

            // Tarjeta estrecha: los botones bajan enteros a una segunda fila
            // en vez de empujar el chip fuera de la tarjeta.
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    hora,
                    const SizedBox(width: 16),
                    Expanded(child: info),
                    _EstadoChip(estado: reserva.estado),
                  ],
                ),
                if (viva) ...[
                  const SizedBox(height: 12),
                  // Wrap y no Row: en una columna MUY estrecha los dos
                  // botones tampoco caben uno al lado del otro (medido: 60px
                  // de desborde a 420px de ancho de pantalla).
                  Wrap(
                    alignment: WrapAlignment.end,
                    spacing: GriSpacing.sm,
                    runSpacing: GriSpacing.sm,
                    children: [botonNoShow, ?botonOcupada],
                  ),
                ],
              ],
            );
          },
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
