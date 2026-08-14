// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'reserva_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Orquesta las mutaciones de reservas del cliente:
/// * [create] → `POST /cliente/reservas` (201) — los errores 400/409 se
///   propagan al widget, que los traduce a mensajes user-friendly
///   (threat 6: "Ese horario acaba de ser reservado, elige otro").
/// * [cancel] → `POST /cliente/reservas/{id}/cancelar`.
///
/// Ambos invalidan [reservasProvider] (sin polling — Pattern 4 del
/// research; Phase 7 lo vuelve WS).

@ProviderFor(ReservaController)
final reservaControllerProvider = ReservaControllerProvider._();

/// Orquesta las mutaciones de reservas del cliente:
/// * [create] → `POST /cliente/reservas` (201) — los errores 400/409 se
///   propagan al widget, que los traduce a mensajes user-friendly
///   (threat 6: "Ese horario acaba de ser reservado, elige otro").
/// * [cancel] → `POST /cliente/reservas/{id}/cancelar`.
///
/// Ambos invalidan [reservasProvider] (sin polling — Pattern 4 del
/// research; Phase 7 lo vuelve WS).
final class ReservaControllerProvider
    extends $AsyncNotifierProvider<ReservaController, void> {
  /// Orquesta las mutaciones de reservas del cliente:
  /// * [create] → `POST /cliente/reservas` (201) — los errores 400/409 se
  ///   propagan al widget, que los traduce a mensajes user-friendly
  ///   (threat 6: "Ese horario acaba de ser reservado, elige otro").
  /// * [cancel] → `POST /cliente/reservas/{id}/cancelar`.
  ///
  /// Ambos invalidan [reservasProvider] (sin polling — Pattern 4 del
  /// research; Phase 7 lo vuelve WS).
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

String _$reservaControllerHash() => r'e0e0c4787df6a80f9d8204c4d09635d431ab3155';

/// Orquesta las mutaciones de reservas del cliente:
/// * [create] → `POST /cliente/reservas` (201) — los errores 400/409 se
///   propagan al widget, que los traduce a mensajes user-friendly
///   (threat 6: "Ese horario acaba de ser reservado, elige otro").
/// * [cancel] → `POST /cliente/reservas/{id}/cancelar`.
///
/// Ambos invalidan [reservasProvider] (sin polling — Pattern 4 del
/// research; Phase 7 lo vuelve WS).

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
