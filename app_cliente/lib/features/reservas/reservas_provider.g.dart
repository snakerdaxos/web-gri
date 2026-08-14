// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'reservas_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Reservas del cliente autenticado — `GET /cliente/reservas`.
///
/// Sin polling (Pattern 4 del research 05): se refresca por invalidate tras
/// cada mutación (crear/cancelar). Phase 7 las vuelve tiempo real vía WS.

@ProviderFor(reservas)
final reservasProvider = ReservasProvider._();

/// Reservas del cliente autenticado — `GET /cliente/reservas`.
///
/// Sin polling (Pattern 4 del research 05): se refresca por invalidate tras
/// cada mutación (crear/cancelar). Phase 7 las vuelve tiempo real vía WS.

final class ReservasProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<Reserva>>,
          List<Reserva>,
          FutureOr<List<Reserva>>
        >
    with $FutureModifier<List<Reserva>>, $FutureProvider<List<Reserva>> {
  /// Reservas del cliente autenticado — `GET /cliente/reservas`.
  ///
  /// Sin polling (Pattern 4 del research 05): se refresca por invalidate tras
  /// cada mutación (crear/cancelar). Phase 7 las vuelve tiempo real vía WS.
  ReservasProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'reservasProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$reservasHash();

  @$internal
  @override
  $FutureProviderElement<List<Reserva>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<Reserva>> create(Ref ref) {
    return reservas(ref);
  }
}

String _$reservasHash() => r'424a523f4f2743d9eb67b488bba1bd2a4b23d58f';
