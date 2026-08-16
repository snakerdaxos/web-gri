// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'clientes_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Clientes del restaurante (ADMN-03) — DERIVADOS de pedidos.
///
/// Las rules no permiten al staff leer `usuarios/` ajenos, así que la
/// lista se pliega desde pedidos: `pedidos where restauranteId == rid`
/// (equality-only: sin orderBy compuesto — los índices de campo simple
/// bastan y no exige un índice nuevo) + orden client-side por createdAt
/// DESC + fold distinct por `usuarioId` usando el `clienteNombre`
/// denormalizado de cada doc. Cero lecturas de `usuarios/`.
///
/// NOTA de coste (diseño planner): v1 demo = get + fold en cliente;
/// agregaciones formales server-side = fase futura.
///
/// rid null (super_admin sin selección) → `[]` (patrón mesasProvider).

@ProviderFor(clientes)
final clientesProvider = ClientesProvider._();

/// Clientes del restaurante (ADMN-03) — DERIVADOS de pedidos.
///
/// Las rules no permiten al staff leer `usuarios/` ajenos, así que la
/// lista se pliega desde pedidos: `pedidos where restauranteId == rid`
/// (equality-only: sin orderBy compuesto — los índices de campo simple
/// bastan y no exige un índice nuevo) + orden client-side por createdAt
/// DESC + fold distinct por `usuarioId` usando el `clienteNombre`
/// denormalizado de cada doc. Cero lecturas de `usuarios/`.
///
/// NOTA de coste (diseño planner): v1 demo = get + fold en cliente;
/// agregaciones formales server-side = fase futura.
///
/// rid null (super_admin sin selección) → `[]` (patrón mesasProvider).

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
  /// Clientes del restaurante (ADMN-03) — DERIVADOS de pedidos.
  ///
  /// Las rules no permiten al staff leer `usuarios/` ajenos, así que la
  /// lista se pliega desde pedidos: `pedidos where restauranteId == rid`
  /// (equality-only: sin orderBy compuesto — los índices de campo simple
  /// bastan y no exige un índice nuevo) + orden client-side por createdAt
  /// DESC + fold distinct por `usuarioId` usando el `clienteNombre`
  /// denormalizado de cada doc. Cero lecturas de `usuarios/`.
  ///
  /// NOTA de coste (diseño planner): v1 demo = get + fold en cliente;
  /// agregaciones formales server-side = fase futura.
  ///
  /// rid null (super_admin sin selección) → `[]` (patrón mesasProvider).
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

String _$clientesHash() => r'3243b121521f0d6dc26ad75f22bb3bcc4c7cc537';

/// Historial de pedidos de un cliente EN el tenant (family, ADMN-03).
///
/// `pedidos where restauranteId == rid where usuarioId == uid`
/// (dos igualdades: zigzag merge sobre índices simples, sin índice
/// compuesto) + orden DESC client-side por createdAt.

@ProviderFor(clienteHistorial)
final clienteHistorialProvider = ClienteHistorialFamily._();

/// Historial de pedidos de un cliente EN el tenant (family, ADMN-03).
///
/// `pedidos where restauranteId == rid where usuarioId == uid`
/// (dos igualdades: zigzag merge sobre índices simples, sin índice
/// compuesto) + orden DESC client-side por createdAt.

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
  /// Historial de pedidos de un cliente EN el tenant (family, ADMN-03).
  ///
  /// `pedidos where restauranteId == rid where usuarioId == uid`
  /// (dos igualdades: zigzag merge sobre índices simples, sin índice
  /// compuesto) + orden DESC client-side por createdAt.
  ClienteHistorialProvider._({
    required ClienteHistorialFamily super.from,
    required String super.argument,
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
    final argument = this.argument as String;
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

String _$clienteHistorialHash() => r'a5d709a149030f37f0c5d2135766089e18eee2d6';

/// Historial de pedidos de un cliente EN el tenant (family, ADMN-03).
///
/// `pedidos where restauranteId == rid where usuarioId == uid`
/// (dos igualdades: zigzag merge sobre índices simples, sin índice
/// compuesto) + orden DESC client-side por createdAt.

final class ClienteHistorialFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<List<PedidoStaff>>, String> {
  ClienteHistorialFamily._()
    : super(
        retry: null,
        name: r'clienteHistorialProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Historial de pedidos de un cliente EN el tenant (family, ADMN-03).
  ///
  /// `pedidos where restauranteId == rid where usuarioId == uid`
  /// (dos igualdades: zigzag merge sobre índices simples, sin índice
  /// compuesto) + orden DESC client-side por createdAt.

  ClienteHistorialProvider call(String usuarioId) =>
      ClienteHistorialProvider._(argument: usuarioId, from: this);

  @override
  String toString() => r'clienteHistorialProvider';
}
