// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'pago_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Orquesta el pago en línea de la cuenta de la sesión:
/// * [iniciar] → `POST /cliente/pagos/intencion` (idempotente server-side)
///   y queda `pendiente` SIN lanzar — el monto se muestra antes del tap.
/// * [pagar] → abre el checkout (launcher inyectable). User action only.
/// * [poll] → `GET /cliente/pagos/{id}`: la ÚNICA fuente de verdad del
///   estado (el retorno del checkout jamás muta nada — threat 1).
///
/// La screen monta el Timer 2.5s (solo poll() mientras `pendiente`) y
/// dispara poll() inmediato al volver del navegador (lifecycle resumed).

@ProviderFor(PagoController)
final pagoControllerProvider = PagoControllerProvider._();

/// Orquesta el pago en línea de la cuenta de la sesión:
/// * [iniciar] → `POST /cliente/pagos/intencion` (idempotente server-side)
///   y queda `pendiente` SIN lanzar — el monto se muestra antes del tap.
/// * [pagar] → abre el checkout (launcher inyectable). User action only.
/// * [poll] → `GET /cliente/pagos/{id}`: la ÚNICA fuente de verdad del
///   estado (el retorno del checkout jamás muta nada — threat 1).
///
/// La screen monta el Timer 2.5s (solo poll() mientras `pendiente`) y
/// dispara poll() inmediato al volver del navegador (lifecycle resumed).
final class PagoControllerProvider
    extends $NotifierProvider<PagoController, PagoFlowState> {
  /// Orquesta el pago en línea de la cuenta de la sesión:
  /// * [iniciar] → `POST /cliente/pagos/intencion` (idempotente server-side)
  ///   y queda `pendiente` SIN lanzar — el monto se muestra antes del tap.
  /// * [pagar] → abre el checkout (launcher inyectable). User action only.
  /// * [poll] → `GET /cliente/pagos/{id}`: la ÚNICA fuente de verdad del
  ///   estado (el retorno del checkout jamás muta nada — threat 1).
  ///
  /// La screen monta el Timer 2.5s (solo poll() mientras `pendiente`) y
  /// dispara poll() inmediato al volver del navegador (lifecycle resumed).
  PagoControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'pagoControllerProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$pagoControllerHash();

  @$internal
  @override
  PagoController create() => PagoController();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(PagoFlowState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<PagoFlowState>(value),
    );
  }
}

String _$pagoControllerHash() => r'95ded5745880aebadb0a2cf254e899be28615b48';

/// Orquesta el pago en línea de la cuenta de la sesión:
/// * [iniciar] → `POST /cliente/pagos/intencion` (idempotente server-side)
///   y queda `pendiente` SIN lanzar — el monto se muestra antes del tap.
/// * [pagar] → abre el checkout (launcher inyectable). User action only.
/// * [poll] → `GET /cliente/pagos/{id}`: la ÚNICA fuente de verdad del
///   estado (el retorno del checkout jamás muta nada — threat 1).
///
/// La screen monta el Timer 2.5s (solo poll() mientras `pendiente`) y
/// dispara poll() inmediato al volver del navegador (lifecycle resumed).

abstract class _$PagoController extends $Notifier<PagoFlowState> {
  PagoFlowState build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<PagoFlowState, PagoFlowState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<PagoFlowState, PagoFlowState>,
              PagoFlowState,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
