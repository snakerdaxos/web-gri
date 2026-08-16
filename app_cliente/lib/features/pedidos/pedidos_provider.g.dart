// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'pedidos_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Pedidos de la sesión activa EN VIVO (MIGRA-05): `where('sesionId') +
/// orderBy('createdAt') + snapshots()` — sustituye WS + polling + refetch
/// de la era REST (Phase 7). Sin sesión → stream vacío.
///
/// El orden DESC se materializa client-side (`reversed`) — el índice
/// compuesto definido en 10-01 es pedidos/sesionId+createdAt ASC (mismo
/// patrón documentado en 10-03: server-side solo lo que tiene índice).

@ProviderFor(pedidosSession)
final pedidosSessionProvider = PedidosSessionProvider._();

/// Pedidos de la sesión activa EN VIVO (MIGRA-05): `where('sesionId') +
/// orderBy('createdAt') + snapshots()` — sustituye WS + polling + refetch
/// de la era REST (Phase 7). Sin sesión → stream vacío.
///
/// El orden DESC se materializa client-side (`reversed`) — el índice
/// compuesto definido en 10-01 es pedidos/sesionId+createdAt ASC (mismo
/// patrón documentado en 10-03: server-side solo lo que tiene índice).

final class PedidosSessionProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<Pedido>>,
          List<Pedido>,
          Stream<List<Pedido>>
        >
    with $FutureModifier<List<Pedido>>, $StreamProvider<List<Pedido>> {
  /// Pedidos de la sesión activa EN VIVO (MIGRA-05): `where('sesionId') +
  /// orderBy('createdAt') + snapshots()` — sustituye WS + polling + refetch
  /// de la era REST (Phase 7). Sin sesión → stream vacío.
  ///
  /// El orden DESC se materializa client-side (`reversed`) — el índice
  /// compuesto definido en 10-01 es pedidos/sesionId+createdAt ASC (mismo
  /// patrón documentado en 10-03: server-side solo lo que tiene índice).
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

String _$pedidosSessionHash() => r'fc0b987dda8004f36cb1fa6d1bac0baf2d38d87a';

/// Mutaciones de pedidos: [enviar] arma los items desde el carrito
/// (snapshot) y pasa por [crearPedido]; limpia el carrito al éxito.

@ProviderFor(PedidosController)
final pedidosControllerProvider = PedidosControllerProvider._();

/// Mutaciones de pedidos: [enviar] arma los items desde el carrito
/// (snapshot) y pasa por [crearPedido]; limpia el carrito al éxito.
final class PedidosControllerProvider
    extends $AsyncNotifierProvider<PedidosController, void> {
  /// Mutaciones de pedidos: [enviar] arma los items desde el carrito
  /// (snapshot) y pasa por [crearPedido]; limpia el carrito al éxito.
  PedidosControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'pedidosControllerProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$pedidosControllerHash();

  @$internal
  @override
  PedidosController create() => PedidosController();
}

String _$pedidosControllerHash() => r'127c071c13036b820ef7d317c59c33c85d533b30';

/// Mutaciones de pedidos: [enviar] arma los items desde el carrito
/// (snapshot) y pasa por [crearPedido]; limpia el carrito al éxito.

abstract class _$PedidosController extends $AsyncNotifier<void> {
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
