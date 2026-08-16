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
