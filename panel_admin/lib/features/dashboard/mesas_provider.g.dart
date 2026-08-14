// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'mesas_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Stream de mesas EN VIVO (RT-02, 07-02): WS push con kick-to-refetch —
/// antes polling 10s.
///
/// El evento WS (`mesa.estado`) SOLO dispara el GET refresh: JAMÁS muta la
/// lista local (cero drift — el server es la única fuente de verdad y el
/// snapshot re-GETeado siempre gana). `wsResyncProvider` (reconexión
/// restablecida) → re-sync total; el Timer de 60s es el safety net que
/// acota la ventana de un WS muerto silencioso (half-open).
///
/// Watches: authState (tenant del token) + currentRestauranteIdProvider
/// (dropdown super_admin). El contrato `Stream<List<Mesa>>` no cambia — los
/// consumers quedan intactos.
///
/// Estructura riverpod-3-safe (lección 07-03): TODO el uso de `ref` ocurre
/// ANTES del primer await/yield — un rebuild con el generator suspendido
/// desmonta el ref y un `ref.watch` tardío lanza UnmountedRefException. Los
/// eventos que llegan durante el GET inicial quedan bufferizados en el
/// controller single-subscription.

@ProviderFor(mesas)
final mesasProvider = MesasProvider._();

/// Stream de mesas EN VIVO (RT-02, 07-02): WS push con kick-to-refetch —
/// antes polling 10s.
///
/// El evento WS (`mesa.estado`) SOLO dispara el GET refresh: JAMÁS muta la
/// lista local (cero drift — el server es la única fuente de verdad y el
/// snapshot re-GETeado siempre gana). `wsResyncProvider` (reconexión
/// restablecida) → re-sync total; el Timer de 60s es el safety net que
/// acota la ventana de un WS muerto silencioso (half-open).
///
/// Watches: authState (tenant del token) + currentRestauranteIdProvider
/// (dropdown super_admin). El contrato `Stream<List<Mesa>>` no cambia — los
/// consumers quedan intactos.
///
/// Estructura riverpod-3-safe (lección 07-03): TODO el uso de `ref` ocurre
/// ANTES del primer await/yield — un rebuild con el generator suspendido
/// desmonta el ref y un `ref.watch` tardío lanza UnmountedRefException. Los
/// eventos que llegan durante el GET inicial quedan bufferizados en el
/// controller single-subscription.

final class MesasProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<Mesa>>,
          List<Mesa>,
          Stream<List<Mesa>>
        >
    with $FutureModifier<List<Mesa>>, $StreamProvider<List<Mesa>> {
  /// Stream de mesas EN VIVO (RT-02, 07-02): WS push con kick-to-refetch —
  /// antes polling 10s.
  ///
  /// El evento WS (`mesa.estado`) SOLO dispara el GET refresh: JAMÁS muta la
  /// lista local (cero drift — el server es la única fuente de verdad y el
  /// snapshot re-GETeado siempre gana). `wsResyncProvider` (reconexión
  /// restablecida) → re-sync total; el Timer de 60s es el safety net que
  /// acota la ventana de un WS muerto silencioso (half-open).
  ///
  /// Watches: authState (tenant del token) + currentRestauranteIdProvider
  /// (dropdown super_admin). El contrato `Stream<List<Mesa>>` no cambia — los
  /// consumers quedan intactos.
  ///
  /// Estructura riverpod-3-safe (lección 07-03): TODO el uso de `ref` ocurre
  /// ANTES del primer await/yield — un rebuild con el generator suspendido
  /// desmonta el ref y un `ref.watch` tardío lanza UnmountedRefException. Los
  /// eventos que llegan durante el GET inicial quedan bufferizados en el
  /// controller single-subscription.
  MesasProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'mesasProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$mesasHash();

  @$internal
  @override
  $StreamProviderElement<List<Mesa>> $createElement($ProviderPointer pointer) =>
      $StreamProviderElement(pointer);

  @override
  Stream<List<Mesa>> create(Ref ref) {
    return mesas(ref);
  }
}

String _$mesasHash() => r'e8b6e9bb03e2089a9403b4c1ed268e194af42722';
