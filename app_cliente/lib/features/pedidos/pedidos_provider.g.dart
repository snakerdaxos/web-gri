// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'pedidos_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Stream de pedidos de la sesión activa EN VIVO (PEDI-04, Phase 7).
///
/// GET inicial (snapshot autoritativo) + kick-to-refetch: los eventos WS
/// (`pedido.creado` / `pedido.estado` / `sesion.cuenta` / `sesion.abierta` /
/// `sesion.cerrada`) NUNCA mutan la lista local — disparan un
/// `GET /cliente/pedidos/actual` (única fuente de verdad de orden/estado).
/// El polling de 10s quedó en safety net de [Env.pollSafetyNetSeconds]
/// (acota half-open tras background, Pitfall 6 del research 07).
///
/// `sesion.cerrada` (anti-zombi del staff o pago) → invalidate de
/// [sesionProvider]: el banner "Estás en la Mesa X" desaparece y este
/// provider colapsa a Stream.empty al reconstruirse con sesión null
/// (el 404 del GET ya se traduce a null). Se refetchea igualmente por si
/// llega una `cerrada` de una sesión vieja.
///
/// Sin sesión activa → stream vacío. autoDispose: al dejar de observarse
/// mueren las suscripciones al broadcast del WsClient y el timer.
///
/// Nota riverpod 3: TODO uso de `ref` (watch/read/onDispose) ocurre ANTES
/// del primer await — riverpod 3.4 lanza `UnmountedRefException` si un
/// rebuild del provider invalida el `ref` mientras el generador está
/// suspendido en un await. Los eventos que llegan durante el GET inicial
/// quedan bufferizados en el controller (stream single-subscription) y se
/// entregan tras el snapshot inicial.

@ProviderFor(pedidosSession)
final pedidosSessionProvider = PedidosSessionProvider._();

/// Stream de pedidos de la sesión activa EN VIVO (PEDI-04, Phase 7).
///
/// GET inicial (snapshot autoritativo) + kick-to-refetch: los eventos WS
/// (`pedido.creado` / `pedido.estado` / `sesion.cuenta` / `sesion.abierta` /
/// `sesion.cerrada`) NUNCA mutan la lista local — disparan un
/// `GET /cliente/pedidos/actual` (única fuente de verdad de orden/estado).
/// El polling de 10s quedó en safety net de [Env.pollSafetyNetSeconds]
/// (acota half-open tras background, Pitfall 6 del research 07).
///
/// `sesion.cerrada` (anti-zombi del staff o pago) → invalidate de
/// [sesionProvider]: el banner "Estás en la Mesa X" desaparece y este
/// provider colapsa a Stream.empty al reconstruirse con sesión null
/// (el 404 del GET ya se traduce a null). Se refetchea igualmente por si
/// llega una `cerrada` de una sesión vieja.
///
/// Sin sesión activa → stream vacío. autoDispose: al dejar de observarse
/// mueren las suscripciones al broadcast del WsClient y el timer.
///
/// Nota riverpod 3: TODO uso de `ref` (watch/read/onDispose) ocurre ANTES
/// del primer await — riverpod 3.4 lanza `UnmountedRefException` si un
/// rebuild del provider invalida el `ref` mientras el generador está
/// suspendido en un await. Los eventos que llegan durante el GET inicial
/// quedan bufferizados en el controller (stream single-subscription) y se
/// entregan tras el snapshot inicial.

final class PedidosSessionProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<Pedido>>,
          List<Pedido>,
          Stream<List<Pedido>>
        >
    with $FutureModifier<List<Pedido>>, $StreamProvider<List<Pedido>> {
  /// Stream de pedidos de la sesión activa EN VIVO (PEDI-04, Phase 7).
  ///
  /// GET inicial (snapshot autoritativo) + kick-to-refetch: los eventos WS
  /// (`pedido.creado` / `pedido.estado` / `sesion.cuenta` / `sesion.abierta` /
  /// `sesion.cerrada`) NUNCA mutan la lista local — disparan un
  /// `GET /cliente/pedidos/actual` (única fuente de verdad de orden/estado).
  /// El polling de 10s quedó en safety net de [Env.pollSafetyNetSeconds]
  /// (acota half-open tras background, Pitfall 6 del research 07).
  ///
  /// `sesion.cerrada` (anti-zombi del staff o pago) → invalidate de
  /// [sesionProvider]: el banner "Estás en la Mesa X" desaparece y este
  /// provider colapsa a Stream.empty al reconstruirse con sesión null
  /// (el 404 del GET ya se traduce a null). Se refetchea igualmente por si
  /// llega una `cerrada` de una sesión vieja.
  ///
  /// Sin sesión activa → stream vacío. autoDispose: al dejar de observarse
  /// mueren las suscripciones al broadcast del WsClient y el timer.
  ///
  /// Nota riverpod 3: TODO uso de `ref` (watch/read/onDispose) ocurre ANTES
  /// del primer await — riverpod 3.4 lanza `UnmountedRefException` si un
  /// rebuild del provider invalida el `ref` mientras el generador está
  /// suspendido en un await. Los eventos que llegan durante el GET inicial
  /// quedan bufferizados en el controller (stream single-subscription) y se
  /// entregan tras el snapshot inicial.
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

String _$pedidosSessionHash() => r'c435084e03b48239512e46f50d3c619c39e05c6a';
