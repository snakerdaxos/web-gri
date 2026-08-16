// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'reservas_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Reservas del cliente autenticado — STREAM Firestore (REALTIME,
/// MIGRA-06: sustituye al refetch de la era REST y al polling):
/// `where('usuarioId') + orderBy('fecha', descending)` + `snapshots()`
/// (índice compuesto reservas/usuarioId+fecha DESC de 10-01).
///
/// El join de `restauranteNombre` es client-side (el doc NO lo guarda):
/// un get por restaurante distinto del snapshot.

@ProviderFor(misReservas)
final misReservasProvider = MisReservasFamily._();

/// Reservas del cliente autenticado — STREAM Firestore (REALTIME,
/// MIGRA-06: sustituye al refetch de la era REST y al polling):
/// `where('usuarioId') + orderBy('fecha', descending)` + `snapshots()`
/// (índice compuesto reservas/usuarioId+fecha DESC de 10-01).
///
/// El join de `restauranteNombre` es client-side (el doc NO lo guarda):
/// un get por restaurante distinto del snapshot.

final class MisReservasProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<Reserva>>,
          List<Reserva>,
          Stream<List<Reserva>>
        >
    with $FutureModifier<List<Reserva>>, $StreamProvider<List<Reserva>> {
  /// Reservas del cliente autenticado — STREAM Firestore (REALTIME,
  /// MIGRA-06: sustituye al refetch de la era REST y al polling):
  /// `where('usuarioId') + orderBy('fecha', descending)` + `snapshots()`
  /// (índice compuesto reservas/usuarioId+fecha DESC de 10-01).
  ///
  /// El join de `restauranteNombre` es client-side (el doc NO lo guarda):
  /// un get por restaurante distinto del snapshot.
  MisReservasProvider._({
    required MisReservasFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'misReservasProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$misReservasHash();

  @override
  String toString() {
    return r'misReservasProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $StreamProviderElement<List<Reserva>> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<List<Reserva>> create(Ref ref) {
    final argument = this.argument as String;
    return misReservas(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is MisReservasProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$misReservasHash() => r'5e80a315f21309b9ea7325d6592ce00bd8e5b614';

/// Reservas del cliente autenticado — STREAM Firestore (REALTIME,
/// MIGRA-06: sustituye al refetch de la era REST y al polling):
/// `where('usuarioId') + orderBy('fecha', descending)` + `snapshots()`
/// (índice compuesto reservas/usuarioId+fecha DESC de 10-01).
///
/// El join de `restauranteNombre` es client-side (el doc NO lo guarda):
/// un get por restaurante distinto del snapshot.

final class MisReservasFamily extends $Family
    with $FunctionalFamilyOverride<Stream<List<Reserva>>, String> {
  MisReservasFamily._()
    : super(
        retry: null,
        name: r'misReservasProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Reservas del cliente autenticado — STREAM Firestore (REALTIME,
  /// MIGRA-06: sustituye al refetch de la era REST y al polling):
  /// `where('usuarioId') + orderBy('fecha', descending)` + `snapshots()`
  /// (índice compuesto reservas/usuarioId+fecha DESC de 10-01).
  ///
  /// El join de `restauranteNombre` es client-side (el doc NO lo guarda):
  /// un get por restaurante distinto del snapshot.

  MisReservasProvider call(String uid) =>
      MisReservasProvider._(argument: uid, from: this);

  @override
  String toString() => r'misReservasProvider';
}
