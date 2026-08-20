import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/design_tokens.dart';
import '../../../core/gri_icons.dart';
import '../../../core/reloj.dart';
import '../../../core/theme.dart';
import '../../../models/mesa.dart';
import '../../mesas/mesa_actions_sheet.dart';
import '../../reservas/reservas_provider.dart';
import '../bloqueo_reserva.dart';
import '../dashboard_screen.dart' show mesaGridDelegate;
import 'mesa_tile.dart';

/// La rejilla de mesas COLOREADA POR LA VENTANA DE RESERVA (11-34).
///
/// Existe como widget compartido porque la pintan DOS pantallas —el mapa del
/// dashboard y `/mesas`— y la lógica de color ya no es «pinta `mesa.estado`»
/// sino un cruce con las reservas del día y con la hora. Duplicarlo en dos
/// sitios garantizaba que en algún momento discreparan.
///
/// ── QUÉ HACE SI NO PUEDE LEER LAS RESERVAS ────────────────────────────────
/// Pinta el mapa igualmente, con el estado guardado, y DICE que le falta la
/// información de reservas. Las dos alternativas son peores:
///   · Ocultar el mapa entero deja al mesero sin la herramienta que usa todo
///     el día por no poder leer un dato accesorio.
///   · Pintarlo callado le haría creer que hay mesas libres que quizá estén
///     reservadas — que es exactamente la clase de mentira que 11-33 quitó de
///     las cifras de dinero.
class MapaDeMesas extends ConsumerWidget {
  const MapaDeMesas({
    super.key,
    required this.mesas,
    required this.showEdit,
  });

  final List<Mesa> mesas;

  /// `true` en `/mesas` (gestión), `false` en el mapa del dashboard.
  final bool showEdit;

  static final DateFormat _hora = DateFormat('HH:mm');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reservasAsync = ref.watch(reservasHoyProvider);
    final relojAsync = ref.watch(relojDeSalaProvider);

    // `.value ?? DateTime.now()`: mientras el primer tick del reloj no ha
    // llegado se usa la hora de este build. No es un fallback silencioso de
    // algo que pueda faltar — `relojDeSala` emite su primer valor sin
    // esperar; esto solo cubre el frame inicial.
    final ahora = relojAsync.value ?? DateTime.now();

    // Un error del listener de reservas NO vacía el mapa: se pinta con lo que
    // hay (lista vacía = nada bloquea) y se avisa arriba.
    final reservasIlegibles = reservasAsync.error != null;
    final mapa = componerMapaDeMesas(
      mesas: mesas,
      reservasDelDia: reservasAsync.value ?? const [],
      ahora: ahora,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (reservasIlegibles) ...[
          _AvisoSinReservas(),
          const SizedBox(height: GriSpacing.md),
        ],
        GridView(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: mesaGridDelegate,
          children: [
            for (final m in mapa)
              MesaTile(
                mesa: m.mesa,
                estadoVisual: m.estadoVisual,
                detalleReserva: m.reserva == null
                    ? null
                    : '${_hora.format(m.reserva!.fecha)} · '
                        '${m.reserva!.numPersonas} personas',
                onTap: () => showMesaActionsSheet(
                  context,
                  ref,
                  m.mesa,
                  showEdit: showEdit,
                ),
              ),
          ],
        ),
      ],
    );
  }
}

/// «El mapa está pintado, pero le falta un dato y lo sabes».
class _AvisoSinReservas extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: GriSpacing.md,
        vertical: GriSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: GriColors.mesaReservadaBg,
        borderRadius: BorderRadius.circular(GriRadius.tile),
      ),
      child: Row(
        children: [
          const Icon(GriIcons.aviso,
              size: 16, color: GriColors.mesaReservadaFg),
          const SizedBox(width: GriSpacing.sm),
          const Expanded(
            child: Text(
              'No pudimos leer las reservas de hoy: el mapa no marca las '
              'mesas reservadas. Consulta la pantalla de Reservas antes de '
              'sentar a nadie.',
              style: TextStyle(
                color: GriColors.mesaReservadaFg,
                fontSize: 13,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
