// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'pedidos_staff_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Cola de cocina EN VIVO (MIGRA-05): `pedidos where restauranteId == rid
/// where estado in [enviado, aceptado, en_preparacion] orderBy createdAt
/// ASC → snapshots()` (índice compuesto 10-01). Un pedido que pasa a
/// `servido`/`rechazado` desaparece del stream SOLO — sin invalidate ni
/// refetch (el server es la fuente de verdad).
///
/// El rid viene de [ridActivoProvider] (claims/selección — nunca input
/// libre; Pitfall 4). Watches ANTES del primer await (lección 07-03).

@ProviderFor(pedidosStaff)
final pedidosStaffProvider = PedidosStaffProvider._();

/// Cola de cocina EN VIVO (MIGRA-05): `pedidos where restauranteId == rid
/// where estado in [enviado, aceptado, en_preparacion] orderBy createdAt
/// ASC → snapshots()` (índice compuesto 10-01). Un pedido que pasa a
/// `servido`/`rechazado` desaparece del stream SOLO — sin invalidate ni
/// refetch (el server es la fuente de verdad).
///
/// El rid viene de [ridActivoProvider] (claims/selección — nunca input
/// libre; Pitfall 4). Watches ANTES del primer await (lección 07-03).

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
  /// Cola de cocina EN VIVO (MIGRA-05): `pedidos where restauranteId == rid
  /// where estado in [enviado, aceptado, en_preparacion] orderBy createdAt
  /// ASC → snapshots()` (índice compuesto 10-01). Un pedido que pasa a
  /// `servido`/`rechazado` desaparece del stream SOLO — sin invalidate ni
  /// refetch (el server es la fuente de verdad).
  ///
  /// El rid viene de [ridActivoProvider] (claims/selección — nunca input
  /// libre; Pitfall 4). Watches ANTES del primer await (lección 07-03).
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

String _$pedidosStaffHash() => r'54251b25f744c875c7a2326921362e8edb7b1690';

/// Avisos de cuenta EN VIVO para el badge de cocina: `sesiones where
/// restauranteId == rid where cuentaSolicitada == true where estado ==
/// 'activa' → snapshots()`. Cuando el mesero entrega la cuenta la sesión
/// pasa a `cerrada` y el aviso desaparece solo.

@ProviderFor(avisoCuenta)
final avisoCuentaProvider = AvisoCuentaProvider._();

/// Avisos de cuenta EN VIVO para el badge de cocina: `sesiones where
/// restauranteId == rid where cuentaSolicitada == true where estado ==
/// 'activa' → snapshots()`. Cuando el mesero entrega la cuenta la sesión
/// pasa a `cerrada` y el aviso desaparece solo.

final class AvisoCuentaProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<AvisoCuenta>>,
          List<AvisoCuenta>,
          Stream<List<AvisoCuenta>>
        >
    with
        $FutureModifier<List<AvisoCuenta>>,
        $StreamProvider<List<AvisoCuenta>> {
  /// Avisos de cuenta EN VIVO para el badge de cocina: `sesiones where
  /// restauranteId == rid where cuentaSolicitada == true where estado ==
  /// 'activa' → snapshots()`. Cuando el mesero entrega la cuenta la sesión
  /// pasa a `cerrada` y el aviso desaparece solo.
  AvisoCuentaProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'avisoCuentaProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$avisoCuentaHash();

  @$internal
  @override
  $StreamProviderElement<List<AvisoCuenta>> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<List<AvisoCuenta>> create(Ref ref) {
    return avisoCuenta(ref);
  }
}

String _$avisoCuentaHash() => r'1a29e5641a3029f59dcec1001a94ae177b5aa684';
