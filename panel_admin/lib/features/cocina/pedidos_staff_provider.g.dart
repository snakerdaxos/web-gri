// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'pedidos_staff_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(pedidosStaff)
final pedidosStaffProvider = PedidosStaffProvider._();

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

String _$pedidosStaffHash() => r'3c234d91b985b043f682d665d6d8a9713b7c942d';

@ProviderFor(avisoCuenta)
final avisoCuentaProvider = AvisoCuentaProvider._();

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

String _$avisoCuentaHash() => r'1f619cf2b60b8bf1987aa42f05907b6da9835aeb';
