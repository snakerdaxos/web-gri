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
/// ── HOY Y PRÓXIMAS, SEPARADAS (11-34) ──────────────────────────────────
/// Hasta 11-34 esta pantalla acotaba a HOY, y el cliente solo podía reservar
/// de mañana en adelante: **ninguna reserva había sido nunca visible para el
/// restaurante hasta el día en que ocurría.** Ahora hay dos pestañas porque el
/// uso es distinto (decisión del usuario): en «Hoy» se OPERA —marcar ocupada,
/// no-show— y en «Próximas» se PLANIFICA, agrupado por día. Las acciones de
/// sala NO aparecen en «Próximas»: marcar ocupada una mesa por una reserva de
/// pasado mañana no significa nada.
///
/// ── LA DEUDA DE 11-29, SALDADA ─────────────────────────────────────────
/// El mapa del dashboard pintaba el campo `estado`, así que una reserva para
/// más tarde HOY creada en un día anterior no teñía la mesa. Desde 11-34 el
/// mapa DERIVA el color de las reservas del día (`bloqueo_reserva.dart`) y esa
/// incoherencia desaparece. Esta pantalla no cambió por eso: siempre leyó la
/// colección `reservas`, no el estado de la mesa.
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
    final hoyAsync = ref.watch(reservasHoyProvider);
    final proximasAsync = ref.watch(reservasProximasProvider);

    return Material(
      // Material ancestor: en producción lo provee el Scaffold del AppShell;
      // standalone (tests) sin esto Flutter inyecta estilos fallback.
      color: GriColors.background,
      child: DefaultTabController(
        length: 2,
        child: ResponsivePage(
          padding: const EdgeInsets.all(GriSpacing.lg),
          builder: (context, ancho) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Icon(GriIcons.reservas,
                      size: 18, color: GriColors.text),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Reservas · hoy '
                      '${DateFormat('dd/MM/yyyy').format(DateTime.now())}',
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
              const SizedBox(height: 8),
              // Las CUENTAS van en la etiqueta de la pestaña: separar las dos
              // vistas no puede significar esconder una de las dos. El
              // restaurante tiene que ver de un vistazo que la semana que
              // viene hay 12 reservas aunque esté mirando las de hoy.
              TabBar(
                labelColor: GriColors.primary,
                unselectedLabelColor: GriColors.textoSecundarioAccesible,
                indicatorColor: GriColors.primary,
                tabs: [
                  Tab(text: 'Hoy${_sufijoCuenta(hoyAsync)}'),
                  Tab(
                    text: 'Próximos $diasDeReservasProximas días'
                        '${_sufijoCuenta(proximasAsync)}',
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Expanded(
                child: TabBarView(
                  children: [
                    _ListaDeReservas(
                      estado: hoyAsync,
                      vacio: 'Sin reservas para hoy',
                      subtitulo: 'En vivo — al llegar el cliente marca la '
                          'mesa ocupada',
                      conAcciones: true,
                      agruparPorDia: false,
                      onReintentar: () => ref.invalidate(reservasHoyProvider),
                      onMarcarOcupada: (r) => _marcarOcupada(context, ref, r),
                      onNoShow: (r) => _cancelarNoShow(context, ref, r),
                    ),
                    _ListaDeReservas(
                      estado: proximasAsync,
                      vacio: 'Sin reservas en los próximos '
                          '$diasDeReservasProximas días',
                      subtitulo: 'Para planificar compras y turnos. Las '
                          'acciones de sala aparecen el día de la reserva',
                      conAcciones: false,
                      agruparPorDia: true,
                      onReintentar: () =>
                          ref.invalidate(reservasProximasProvider),
                      onMarcarOcupada: (_) {},
                      onNoShow: (_) {},
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// ' (3)' cuando hay datos; NADA mientras cargan o si fallan.
  ///
  /// Deliberadamente no pinta un 0 ante un fallo: «Próximas (0)» leído por un
  /// encargado significa «no hay nada la semana que viene», y eso es
  /// exactamente lo que no sabemos si el listener se cayó. Mismo criterio que
  /// 11-33 aplicó a las cifras de dinero.
  static String _sufijoCuenta(AsyncValue<List<Reserva>> a) =>
      a.error != null || !a.hasValue ? '' : ' (${a.requireValue.length})';
}

/// Una de las dos listas de la pantalla. Misma tarjeta y mismo tratamiento
/// del fallo; cambian el texto de vacío, si hay acciones de sala y si se
/// agrupa por día.
class _ListaDeReservas extends StatelessWidget {
  const _ListaDeReservas({
    required this.estado,
    required this.vacio,
    required this.subtitulo,
    required this.conAcciones,
    required this.agruparPorDia,
    required this.onReintentar,
    required this.onMarcarOcupada,
    required this.onNoShow,
  });

  final AsyncValue<List<Reserva>> estado;
  final String vacio;
  final String subtitulo;
  final bool conAcciones;
  final bool agruparPorDia;
  final VoidCallback onReintentar;
  final void Function(Reserva) onMarcarOcupada;
  final void Function(Reserva) onNoShow;

  static final DateFormat _dia = DateFormat('EEEE d/MM');

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          subtitulo,
          style: const TextStyle(
            color: GriColors.textoSecundarioAccesible,
            fontSize: 13,
          ),
        ),
        const SizedBox(height: 12),
        Expanded(
          // `cuandoConFallo` y NO `when` (11-33): durante los reintentos de
          // Riverpod el estado es AsyncLoading CON el error dentro, y `when`
          // pintaría la rama de carga durante ~38 s.
          child: estado.cuandoConFallo(
            cargando: () => const Center(child: CircularProgressIndicator()),
            fallo: (e) => Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    mensajeDeFallo(e, contexto: Contexto.reservas),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        color: GriColors.textoSecundarioAccesible),
                  ),
                  TextButton(
                    onPressed: onReintentar,
                    child: const Text('Reintentar'),
                  ),
                ],
              ),
            ),
            datos: (reservas) {
              if (reservas.isEmpty) {
                return Center(
                  child: Text(
                    vacio,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        color: GriColors.textoSecundarioAccesible),
                  ),
                );
              }
              if (!agruparPorDia) {
                return ListView.builder(
                  itemCount: reservas.length,
                  itemBuilder: (context, i) => _ReservaCard(
                    reserva: reservas[i],
                    conAcciones: conAcciones,
                    onMarcarOcupada: onMarcarOcupada,
                    onNoShow: onNoShow,
                  ),
                );
              }
              // Agrupado por día: una agenda de siete días sin cabeceras es
              // una lista de horas sueltas y no hay forma de leerla.
              final filas = <Widget>[];
              DateTime? diaAnterior;
              for (final r in reservas) {
                final dia = DateTime(r.fecha.year, r.fecha.month, r.fecha.day);
                if (diaAnterior == null || dia != diaAnterior) {
                  filas.add(Padding(
                    padding: EdgeInsets.only(
                      top: diaAnterior == null ? 0 : GriSpacing.md,
                      bottom: GriSpacing.sm,
                    ),
                    child: Text(
                      _dia.format(dia),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: GriColors.text,
                      ),
                    ),
                  ));
                  diaAnterior = dia;
                }
                filas.add(_ReservaCard(
                  reserva: r,
                  conAcciones: conAcciones,
                  onMarcarOcupada: onMarcarOcupada,
                  onNoShow: onNoShow,
                ));
              }
              return ListView(children: filas);
            },
          ),
        ),
      ],
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
    required this.conAcciones,
    required this.onMarcarOcupada,
    required this.onNoShow,
  });

  final Reserva reserva;

  /// Las acciones de SALA (marcar ocupada / no-show) solo existen el día de
  /// la reserva. En «Próximas» no significan nada: marcar ocupada una mesa
  /// por una reserva de pasado mañana la bloquearía hoy, que es justo el bug
  /// que 11-34 viene a quitar.
  final bool conAcciones;
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
    final viva = conAcciones &&
        (reserva.estado == 'confirmada' || reserva.estado == 'pendiente');

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
