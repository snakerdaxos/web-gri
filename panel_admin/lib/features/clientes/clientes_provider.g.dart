// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'clientes_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Clientes del restaurante (usuarios con pedidos en el tenant, ADMN-03).
///
/// Sin WS (decisión research 08): la tabla vive de este FutureProvider y la
/// UI lo invalida cuando corresponde. rid null (super_admin sin selección)
/// → `[]` (patrón mesasProvider).

@ProviderFor(clientes)
final clientesProvider = ClientesProvider._();

/// Clientes del restaurante (usuarios con pedidos en el tenant, ADMN-03).
///
/// Sin WS (decisión research 08): la tabla vive de este FutureProvider y la
/// UI lo invalida cuando corresponde. rid null (super_admin sin selección)
/// → `[]` (patrón mesasProvider).

final class ClientesProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<ClienteResumen>>,
          List<ClienteResumen>,
          FutureOr<List<ClienteResumen>>
        >
    with
        $FutureModifier<List<ClienteResumen>>,
        $FutureProvider<List<ClienteResumen>> {
  /// Clientes del restaurante (usuarios con pedidos en el tenant, ADMN-03).
  ///
  /// Sin WS (decisión research 08): la tabla vive de este FutureProvider y la
  /// UI lo invalida cuando corresponde. rid null (super_admin sin selección)
  /// → `[]` (patrón mesasProvider).
  ClientesProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'clientesProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$clientesHash();

  @$internal
  @override
  $FutureProviderElement<List<ClienteResumen>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<ClienteResumen>> create(Ref ref) {
    return clientes(ref);
  }
}

String _$clientesHash() => r'9dcf1092e54c6c499d8ac3bcbea1b197a6b08248';

/// Historial de pedidos de un cliente EN el tenant (family, ADMN-03) —
/// misma shape que la cola de pedidos (`PedidoStaffRead` reusado, 08-01).
///
/// 404 existence hiding relacional cuando el usuario no tiene pedidos aquí:
/// el dialog lo traduce a 'Sin pedidos en este restaurante' (el error y el
/// vacío son indistinguibles por diseño).

@ProviderFor(clienteHistorial)
final clienteHistorialProvider = ClienteHistorialFamily._();

/// Historial de pedidos de un cliente EN el tenant (family, ADMN-03) —
/// misma shape que la cola de pedidos (`PedidoStaffRead` reusado, 08-01).
///
/// 404 existence hiding relacional cuando el usuario no tiene pedidos aquí:
/// el dialog lo traduce a 'Sin pedidos en este restaurante' (el error y el
/// vacío son indistinguibles por diseño).

final class ClienteHistorialProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<PedidoStaff>>,
          List<PedidoStaff>,
          FutureOr<List<PedidoStaff>>
        >
    with
        $FutureModifier<List<PedidoStaff>>,
        $FutureProvider<List<PedidoStaff>> {
  /// Historial de pedidos de un cliente EN el tenant (family, ADMN-03) —
  /// misma shape que la cola de pedidos (`PedidoStaffRead` reusado, 08-01).
  ///
  /// 404 existence hiding relacional cuando el usuario no tiene pedidos aquí:
  /// el dialog lo traduce a 'Sin pedidos en este restaurante' (el error y el
  /// vacío son indistinguibles por diseño).
  ClienteHistorialProvider._({
    required ClienteHistorialFamily super.from,
    required int super.argument,
  }) : super(
         retry: null,
         name: r'clienteHistorialProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$clienteHistorialHash();

  @override
  String toString() {
    return r'clienteHistorialProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<List<PedidoStaff>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<PedidoStaff>> create(Ref ref) {
    final argument = this.argument as int;
    return clienteHistorial(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is ClienteHistorialProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$clienteHistorialHash() => r'4b1bc33a70d5492918511145be21870539b029c2';

/// Historial de pedidos de un cliente EN el tenant (family, ADMN-03) —
/// misma shape que la cola de pedidos (`PedidoStaffRead` reusado, 08-01).
///
/// 404 existence hiding relacional cuando el usuario no tiene pedidos aquí:
/// el dialog lo traduce a 'Sin pedidos en este restaurante' (el error y el
/// vacío son indistinguibles por diseño).

final class ClienteHistorialFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<List<PedidoStaff>>, int> {
  ClienteHistorialFamily._()
    : super(
        retry: null,
        name: r'clienteHistorialProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Historial de pedidos de un cliente EN el tenant (family, ADMN-03) —
  /// misma shape que la cola de pedidos (`PedidoStaffRead` reusado, 08-01).
  ///
  /// 404 existence hiding relacional cuando el usuario no tiene pedidos aquí:
  /// el dialog lo traduce a 'Sin pedidos en este restaurante' (el error y el
  /// vacío son indistinguibles por diseño).

  ClienteHistorialProvider call(int usuarioId) =>
      ClienteHistorialProvider._(argument: usuarioId, from: this);

  @override
  String toString() => r'clienteHistorialProvider';
}
