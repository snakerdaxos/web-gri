// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'reservas_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Reservas del día (`GET /staff/reservas?fecha=`, RESV-05) — family por
/// fecha `YYYY-MM-DD`. La UI invalida con la fecha-key al cambiar el picker
/// o tras marcar una mesa ocupada (refresh on-demand, sin WS — decisión
/// research 08).
///
/// Patrón rid/queryRid (mesasProvider): staff manda su tenant implícito
/// (token); super_admin manda el del dropdown. rid null (super_admin sin
/// selección) → `[]` (patrón clientesProvider).

@ProviderFor(reservasDelDia)
final reservasDelDiaProvider = ReservasDelDiaFamily._();

/// Reservas del día (`GET /staff/reservas?fecha=`, RESV-05) — family por
/// fecha `YYYY-MM-DD`. La UI invalida con la fecha-key al cambiar el picker
/// o tras marcar una mesa ocupada (refresh on-demand, sin WS — decisión
/// research 08).
///
/// Patrón rid/queryRid (mesasProvider): staff manda su tenant implícito
/// (token); super_admin manda el del dropdown. rid null (super_admin sin
/// selección) → `[]` (patrón clientesProvider).

final class ReservasDelDiaProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<Reserva>>,
          List<Reserva>,
          FutureOr<List<Reserva>>
        >
    with $FutureModifier<List<Reserva>>, $FutureProvider<List<Reserva>> {
  /// Reservas del día (`GET /staff/reservas?fecha=`, RESV-05) — family por
  /// fecha `YYYY-MM-DD`. La UI invalida con la fecha-key al cambiar el picker
  /// o tras marcar una mesa ocupada (refresh on-demand, sin WS — decisión
  /// research 08).
  ///
  /// Patrón rid/queryRid (mesasProvider): staff manda su tenant implícito
  /// (token); super_admin manda el del dropdown. rid null (super_admin sin
  /// selección) → `[]` (patrón clientesProvider).
  ReservasDelDiaProvider._({
    required ReservasDelDiaFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'reservasDelDiaProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$reservasDelDiaHash();

  @override
  String toString() {
    return r'reservasDelDiaProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<List<Reserva>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<Reserva>> create(Ref ref) {
    final argument = this.argument as String;
    return reservasDelDia(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is ReservasDelDiaProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$reservasDelDiaHash() => r'2370d7c3ba775cd2637a3b25b328338ee5cefe9b';

/// Reservas del día (`GET /staff/reservas?fecha=`, RESV-05) — family por
/// fecha `YYYY-MM-DD`. La UI invalida con la fecha-key al cambiar el picker
/// o tras marcar una mesa ocupada (refresh on-demand, sin WS — decisión
/// research 08).
///
/// Patrón rid/queryRid (mesasProvider): staff manda su tenant implícito
/// (token); super_admin manda el del dropdown. rid null (super_admin sin
/// selección) → `[]` (patrón clientesProvider).

final class ReservasDelDiaFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<List<Reserva>>, String> {
  ReservasDelDiaFamily._()
    : super(
        retry: null,
        name: r'reservasDelDiaProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Reservas del día (`GET /staff/reservas?fecha=`, RESV-05) — family por
  /// fecha `YYYY-MM-DD`. La UI invalida con la fecha-key al cambiar el picker
  /// o tras marcar una mesa ocupada (refresh on-demand, sin WS — decisión
  /// research 08).
  ///
  /// Patrón rid/queryRid (mesasProvider): staff manda su tenant implícito
  /// (token); super_admin manda el del dropdown. rid null (super_admin sin
  /// selección) → `[]` (patrón clientesProvider).

  ReservasDelDiaProvider call(String fechaYYYYMMDD) =>
      ReservasDelDiaProvider._(argument: fechaYYYYMMDD, from: this);

  @override
  String toString() => r'reservasDelDiaProvider';
}
