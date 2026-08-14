// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'pedidos_staff_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Stream de la cola de pedidos activos EN VIVO (RT-01, 07-02): WS push con
/// kick-to-refetch — antes polling 10s.
///
/// Cada evento WS relevante (`pedido.creado`, `pedido.estado`,
/// `sesion.cuenta` y `mesa.estado` — la cola re-ordena si la mesa cambia)
/// dispara un GET refresh: el evento SOLO es señal, JAMÁS muta la cola
/// local (cero drift — el server ya construye la cola con joins display y
/// orden FIFO FIELD()). `wsResyncProvider` (reconexión restablecida) →
/// re-sync total; Timer de 60s como safety net.
///
/// Watches: authState (tenant del token) + currentRestauranteIdProvider
/// (dropdown super_admin). `queryRid` SOLO se envía si super_admin — un
/// staff jamás filtra client-side. El contrato `Stream<List<PedidoStaff>>`
/// no cambia — los consumers quedan intactos.

@ProviderFor(pedidosStaff)
final pedidosStaffProvider = PedidosStaffProvider._();

/// Stream de la cola de pedidos activos EN VIVO (RT-01, 07-02): WS push con
/// kick-to-refetch — antes polling 10s.
///
/// Cada evento WS relevante (`pedido.creado`, `pedido.estado`,
/// `sesion.cuenta` y `mesa.estado` — la cola re-ordena si la mesa cambia)
/// dispara un GET refresh: el evento SOLO es señal, JAMÁS muta la cola
/// local (cero drift — el server ya construye la cola con joins display y
/// orden FIFO FIELD()). `wsResyncProvider` (reconexión restablecida) →
/// re-sync total; Timer de 60s como safety net.
///
/// Watches: authState (tenant del token) + currentRestauranteIdProvider
/// (dropdown super_admin). `queryRid` SOLO se envía si super_admin — un
/// staff jamás filtra client-side. El contrato `Stream<List<PedidoStaff>>`
/// no cambia — los consumers quedan intactos.

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
  /// Stream de la cola de pedidos activos EN VIVO (RT-01, 07-02): WS push con
  /// kick-to-refetch — antes polling 10s.
  ///
  /// Cada evento WS relevante (`pedido.creado`, `pedido.estado`,
  /// `sesion.cuenta` y `mesa.estado` — la cola re-ordena si la mesa cambia)
  /// dispara un GET refresh: el evento SOLO es señal, JAMÁS muta la cola
  /// local (cero drift — el server ya construye la cola con joins display y
  /// orden FIFO FIELD()). `wsResyncProvider` (reconexión restablecida) →
  /// re-sync total; Timer de 60s como safety net.
  ///
  /// Watches: authState (tenant del token) + currentRestauranteIdProvider
  /// (dropdown super_admin). `queryRid` SOLO se envía si super_admin — un
  /// staff jamás filtra client-side. El contrato `Stream<List<PedidoStaff>>`
  /// no cambia — los consumers quedan intactos.
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

String _$pedidosStaffHash() => r'b5baf62929b2397a7db10a3b52fe1da98f10654f';
