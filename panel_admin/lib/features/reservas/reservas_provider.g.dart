// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'reservas_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Reservas de HOY del restaurante EN VIVO (RESV-05): la MISMA query del
/// dashboard 10-05 — `reservas where restauranteId == rid where fecha >=
/// inicioHoy && fecha < inicioMañana → snapshots()` (índice
/// restauranteId+fecha de 10-01) con la ventana computada en la TZ local
/// del operador.
///
/// rid null (super_admin sin selección) → `[]` (patrón mesasProvider).

@ProviderFor(reservasHoy)
final reservasHoyProvider = ReservasHoyProvider._();

/// Reservas de HOY del restaurante EN VIVO (RESV-05): la MISMA query del
/// dashboard 10-05 — `reservas where restauranteId == rid where fecha >=
/// inicioHoy && fecha < inicioMañana → snapshots()` (índice
/// restauranteId+fecha de 10-01) con la ventana computada en la TZ local
/// del operador.
///
/// rid null (super_admin sin selección) → `[]` (patrón mesasProvider).

final class ReservasHoyProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<Reserva>>,
          List<Reserva>,
          Stream<List<Reserva>>
        >
    with $FutureModifier<List<Reserva>>, $StreamProvider<List<Reserva>> {
  /// Reservas de HOY del restaurante EN VIVO (RESV-05): la MISMA query del
  /// dashboard 10-05 — `reservas where restauranteId == rid where fecha >=
  /// inicioHoy && fecha < inicioMañana → snapshots()` (índice
  /// restauranteId+fecha de 10-01) con la ventana computada en la TZ local
  /// del operador.
  ///
  /// rid null (super_admin sin selección) → `[]` (patrón mesasProvider).
  ReservasHoyProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'reservasHoyProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$reservasHoyHash();

  @$internal
  @override
  $StreamProviderElement<List<Reserva>> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<List<Reserva>> create(Ref ref) {
    return reservasHoy(ref);
  }
}

String _$reservasHoyHash() => r'4edbe17dd41ff94b6922c846bf2278c0fc3208e6';

/// Reservas FUTURAS del restaurante EN VIVO (11-34): desde el inicio de MAÑANA
/// hasta [diasDeReservasProximas] días después.
///
/// ── EL AGUJERO QUE ESTO TAPA ──────────────────────────────────────────────
/// `reservasHoy` acota a `fecha >= inicioHoy && fecha < inicioMañana`: hoy y
/// solo hoy. Y hasta 11-31 el cliente únicamente podía reservar de mañana en
/// adelante (`firstDate: mañana`). Combinando las dos cosas: **ninguna reserva
/// había sido nunca visible para el restaurante hasta el día en que ocurría.**
/// Un restaurante que no ve las reservas de mañana no puede planificar ni las
/// compras ni los turnos — y la pantalla no daba ninguna pista de que hubiera
/// algo que no estaba viendo.
///
/// ── SEPARADA DE `reservasHoy` A PROPÓSITO ─────────────────────────────────
/// Podría ser una sola consulta con una ventana más ancha, pero el uso es
/// distinto y por eso la interfaz las separa (decisión del usuario): hoy se
/// OPERA —marcar ocupada, no-show— y mañana se PLANIFICA. Además `reservasHoy`
/// alimenta el color del mapa de mesas, que solo puede mirar hoy; mezclarlas
/// obligaría a re-filtrar en cada consumidor.
///
/// ── ÍNDICE ────────────────────────────────────────────────────────────────
/// Ninguno nuevo. `reservas(restauranteId ASC, fecha ASC)` ya existe en
/// `firestore.indexes.json` desde 10-01 y sirve igual a una ventana más ancha:
/// igualdad en `restauranteId` + rango y orden en `fecha`. El `orderBy('fecha')`
/// es explícito porque aquí el ORDEN es parte del producto (una agenda
/// desordenada no es una agenda) y no una casualidad del rango.

@ProviderFor(reservasProximas)
final reservasProximasProvider = ReservasProximasProvider._();

/// Reservas FUTURAS del restaurante EN VIVO (11-34): desde el inicio de MAÑANA
/// hasta [diasDeReservasProximas] días después.
///
/// ── EL AGUJERO QUE ESTO TAPA ──────────────────────────────────────────────
/// `reservasHoy` acota a `fecha >= inicioHoy && fecha < inicioMañana`: hoy y
/// solo hoy. Y hasta 11-31 el cliente únicamente podía reservar de mañana en
/// adelante (`firstDate: mañana`). Combinando las dos cosas: **ninguna reserva
/// había sido nunca visible para el restaurante hasta el día en que ocurría.**
/// Un restaurante que no ve las reservas de mañana no puede planificar ni las
/// compras ni los turnos — y la pantalla no daba ninguna pista de que hubiera
/// algo que no estaba viendo.
///
/// ── SEPARADA DE `reservasHoy` A PROPÓSITO ─────────────────────────────────
/// Podría ser una sola consulta con una ventana más ancha, pero el uso es
/// distinto y por eso la interfaz las separa (decisión del usuario): hoy se
/// OPERA —marcar ocupada, no-show— y mañana se PLANIFICA. Además `reservasHoy`
/// alimenta el color del mapa de mesas, que solo puede mirar hoy; mezclarlas
/// obligaría a re-filtrar en cada consumidor.
///
/// ── ÍNDICE ────────────────────────────────────────────────────────────────
/// Ninguno nuevo. `reservas(restauranteId ASC, fecha ASC)` ya existe en
/// `firestore.indexes.json` desde 10-01 y sirve igual a una ventana más ancha:
/// igualdad en `restauranteId` + rango y orden en `fecha`. El `orderBy('fecha')`
/// es explícito porque aquí el ORDEN es parte del producto (una agenda
/// desordenada no es una agenda) y no una casualidad del rango.

final class ReservasProximasProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<Reserva>>,
          List<Reserva>,
          Stream<List<Reserva>>
        >
    with $FutureModifier<List<Reserva>>, $StreamProvider<List<Reserva>> {
  /// Reservas FUTURAS del restaurante EN VIVO (11-34): desde el inicio de MAÑANA
  /// hasta [diasDeReservasProximas] días después.
  ///
  /// ── EL AGUJERO QUE ESTO TAPA ──────────────────────────────────────────────
  /// `reservasHoy` acota a `fecha >= inicioHoy && fecha < inicioMañana`: hoy y
  /// solo hoy. Y hasta 11-31 el cliente únicamente podía reservar de mañana en
  /// adelante (`firstDate: mañana`). Combinando las dos cosas: **ninguna reserva
  /// había sido nunca visible para el restaurante hasta el día en que ocurría.**
  /// Un restaurante que no ve las reservas de mañana no puede planificar ni las
  /// compras ni los turnos — y la pantalla no daba ninguna pista de que hubiera
  /// algo que no estaba viendo.
  ///
  /// ── SEPARADA DE `reservasHoy` A PROPÓSITO ─────────────────────────────────
  /// Podría ser una sola consulta con una ventana más ancha, pero el uso es
  /// distinto y por eso la interfaz las separa (decisión del usuario): hoy se
  /// OPERA —marcar ocupada, no-show— y mañana se PLANIFICA. Además `reservasHoy`
  /// alimenta el color del mapa de mesas, que solo puede mirar hoy; mezclarlas
  /// obligaría a re-filtrar en cada consumidor.
  ///
  /// ── ÍNDICE ────────────────────────────────────────────────────────────────
  /// Ninguno nuevo. `reservas(restauranteId ASC, fecha ASC)` ya existe en
  /// `firestore.indexes.json` desde 10-01 y sirve igual a una ventana más ancha:
  /// igualdad en `restauranteId` + rango y orden en `fecha`. El `orderBy('fecha')`
  /// es explícito porque aquí el ORDEN es parte del producto (una agenda
  /// desordenada no es una agenda) y no una casualidad del rango.
  ReservasProximasProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'reservasProximasProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$reservasProximasHash();

  @$internal
  @override
  $StreamProviderElement<List<Reserva>> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<List<Reserva>> create(Ref ref) {
    return reservasProximas(ref);
  }
}

String _$reservasProximasHash() => r'150aecd6ee8c6ba244ae41cc32fc63bfaeda4743';
