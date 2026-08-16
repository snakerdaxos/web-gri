// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'reserva_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Orquesta las mutaciones de reservas del cliente sobre Firestore.
/// [misReservas] es un stream → la lista se refresca sola (REALTIME).

@ProviderFor(ReservaController)
final reservaControllerProvider = ReservaControllerProvider._();

/// Orquesta las mutaciones de reservas del cliente sobre Firestore.
/// [misReservas] es un stream → la lista se refresca sola (REALTIME).
final class ReservaControllerProvider
    extends $AsyncNotifierProvider<ReservaController, void> {
  /// Orquesta las mutaciones de reservas del cliente sobre Firestore.
  /// [misReservas] es un stream → la lista se refresca sola (REALTIME).
  ReservaControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'reservaControllerProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$reservaControllerHash();

  @$internal
  @override
  ReservaController create() => ReservaController();
}

String _$reservaControllerHash() => r'7e69e96dc1cf27c9eb60afd32f7d8d3840968ad4';

/// Orquesta las mutaciones de reservas del cliente sobre Firestore.
/// [misReservas] es un stream → la lista se refresca sola (REALTIME).

abstract class _$ReservaController extends $AsyncNotifier<void> {
  FutureOr<void> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<AsyncValue<void>, void>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<void>, void>,
              AsyncValue<void>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
