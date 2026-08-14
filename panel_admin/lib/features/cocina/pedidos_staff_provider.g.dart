// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'pedidos_staff_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Stream de la cola de pedidos activos con polling 10s — espejo de
/// [mesasProvider] sobre `GET /staff/pedidos?activos=true` (ADMN-05).
///
/// Watches: authState (tenant del token) + currentRestauranteIdProvider
/// (dropdown super_admin). `queryRid` SOLO se envía si super_admin — un
/// staff jamás filtra client-side. Phase 7 (WS) retira el Timer sin
/// tocar los consumers.

@ProviderFor(pedidosStaff)
final pedidosStaffProvider = PedidosStaffProvider._();

/// Stream de la cola de pedidos activos con polling 10s — espejo de
/// [mesasProvider] sobre `GET /staff/pedidos?activos=true` (ADMN-05).
///
/// Watches: authState (tenant del token) + currentRestauranteIdProvider
/// (dropdown super_admin). `queryRid` SOLO se envía si super_admin — un
/// staff jamás filtra client-side. Phase 7 (WS) retira el Timer sin
/// tocar los consumers.

final class PedidosStaffProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<PedidoStaff>>,
          List<PedidoStaff>,
          Stream<List<PedidoStaff>>
        >
    with
        $FutureModifier<List<PedidoStaff>>,
        $StreamProvider<List<PedidoStaff>> {
  /// Stream de la cola de pedidos activos con polling 10s — espejo de
  /// [mesasProvider] sobre `GET /staff/pedidos?activos=true` (ADMN-05).
  ///
  /// Watches: authState (tenant del token) + currentRestauranteIdProvider
  /// (dropdown super_admin). `queryRid` SOLO se envía si super_admin — un
  /// staff jamás filtra client-side. Phase 7 (WS) retira el Timer sin
  /// tocar los consumers.
  PedidosStaffProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'pedidosStaffProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$pedidosStaffHash();

  @$internal
  @override
  $StreamProviderElement<List<PedidoStaff>> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<List<PedidoStaff>> create(Ref ref) {
    return pedidosStaff(ref);
  }
}

String _$pedidosStaffHash() => r'a720d003415c52a9d787100913a1e4b64992fb52';
