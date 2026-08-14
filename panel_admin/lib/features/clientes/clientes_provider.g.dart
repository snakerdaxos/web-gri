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
