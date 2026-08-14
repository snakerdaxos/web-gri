// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'restaurante_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// FutureProvider que resuelve el [Restaurante] a mostrar en el topbar (nombre).
///
/// Staff: siempre su propio tenant. Super_admin: el seleccionado en el
/// dropdown (o el default). Si super_admin sin selección → lanza StateError
/// (no debería ocurrir porque AppShell setea el default apenas carga la lista).

@ProviderFor(restaurante)
final restauranteProvider = RestauranteProvider._();

/// FutureProvider que resuelve el [Restaurante] a mostrar en el topbar (nombre).
///
/// Staff: siempre su propio tenant. Super_admin: el seleccionado en el
/// dropdown (o el default). Si super_admin sin selección → lanza StateError
/// (no debería ocurrir porque AppShell setea el default apenas carga la lista).

final class RestauranteProvider
    extends
        $FunctionalProvider<
          AsyncValue<Restaurante>,
          Restaurante,
          FutureOr<Restaurante>
        >
    with $FutureModifier<Restaurante>, $FutureProvider<Restaurante> {
  /// FutureProvider que resuelve el [Restaurante] a mostrar en el topbar (nombre).
  ///
  /// Staff: siempre su propio tenant. Super_admin: el seleccionado en el
  /// dropdown (o el default). Si super_admin sin selección → lanza StateError
  /// (no debería ocurrir porque AppShell setea el default apenas carga la lista).
  RestauranteProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'restauranteProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$restauranteHash();

  @$internal
  @override
  $FutureProviderElement<Restaurante> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<Restaurante> create(Ref ref) {
    return restaurante(ref);
  }
}

String _$restauranteHash() => r'c69884d90a2827b4db4f9247df4d4b245ed16d90';
