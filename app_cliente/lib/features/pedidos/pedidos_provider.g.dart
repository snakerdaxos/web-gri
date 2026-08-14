// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'pedidos_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Stream de pedidos de la sesión activa con polling 10s (PEDI-04) —
/// clon EXACTO del patrón mesas_provider del panel (Pitfall 8: el timer
/// se cancela en `ref.onDispose`; Phase 7 lo reemplaza por WebSocket).
///
/// Sin sesión activa → stream vacío (la screen muestra el estado vacío).
/// autoDispose: al dejar de observarse (salir de la pantalla) el timer
/// muere — sin timers zombis entre navegación.

@ProviderFor(pedidosSession)
final pedidosSessionProvider = PedidosSessionProvider._();

/// Stream de pedidos de la sesión activa con polling 10s (PEDI-04) —
/// clon EXACTO del patrón mesas_provider del panel (Pitfall 8: el timer
/// se cancela en `ref.onDispose`; Phase 7 lo reemplaza por WebSocket).
///
/// Sin sesión activa → stream vacío (la screen muestra el estado vacío).
/// autoDispose: al dejar de observarse (salir de la pantalla) el timer
/// muere — sin timers zombis entre navegación.

final class PedidosSessionProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<Pedido>>,
          List<Pedido>,
          Stream<List<Pedido>>
        >
    with $FutureModifier<List<Pedido>>, $StreamProvider<List<Pedido>> {
  /// Stream de pedidos de la sesión activa con polling 10s (PEDI-04) —
  /// clon EXACTO del patrón mesas_provider del panel (Pitfall 8: el timer
  /// se cancela en `ref.onDispose`; Phase 7 lo reemplaza por WebSocket).
  ///
  /// Sin sesión activa → stream vacío (la screen muestra el estado vacío).
  /// autoDispose: al dejar de observarse (salir de la pantalla) el timer
  /// muere — sin timers zombis entre navegación.
  PedidosSessionProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'pedidosSessionProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$pedidosSessionHash();

  @$internal
  @override
  $StreamProviderElement<List<Pedido>> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<List<Pedido>> create(Ref ref) {
    return pedidosSession(ref);
  }
}

String _$pedidosSessionHash() => r'a2d8e84b9d9b75937153779a9b536c477586f956';
