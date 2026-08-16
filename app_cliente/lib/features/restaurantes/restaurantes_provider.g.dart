// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'restaurantes_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Lista de restaurantes activos — INTERINO Task 1: sigue legacy REST
/// (api_client) con ids String; Task 2 lo reescribe sobre Firestore
/// (`collection('restaurantes').where('activo')` + fromDoc).

@ProviderFor(restaurantesList)
final restaurantesListProvider = RestaurantesListProvider._();

/// Lista de restaurantes activos — INTERINO Task 1: sigue legacy REST
/// (api_client) con ids String; Task 2 lo reescribe sobre Firestore
/// (`collection('restaurantes').where('activo')` + fromDoc).

final class RestaurantesListProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<Restaurante>>,
          List<Restaurante>,
          FutureOr<List<Restaurante>>
        >
    with
        $FutureModifier<List<Restaurante>>,
        $FutureProvider<List<Restaurante>> {
  /// Lista de restaurantes activos — INTERINO Task 1: sigue legacy REST
  /// (api_client) con ids String; Task 2 lo reescribe sobre Firestore
  /// (`collection('restaurantes').where('activo')` + fromDoc).
  RestaurantesListProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'restaurantesListProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$restaurantesListHash();

  @$internal
  @override
  $FutureProviderElement<List<Restaurante>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<Restaurante>> create(Ref ref) {
    return restaurantesList(ref);
  }
}

String _$restaurantesListHash() => r'821aea668fd1e1cae71e1c909cd1c484d85ed3be';

/// Detalle con menú anidado — INTERINO Task 1 (legacy REST, id String).

@ProviderFor(restauranteDetalle)
final restauranteDetalleProvider = RestauranteDetalleFamily._();

/// Detalle con menú anidado — INTERINO Task 1 (legacy REST, id String).

final class RestauranteDetalleProvider
    extends
        $FunctionalProvider<
          AsyncValue<RestauranteDetalle>,
          RestauranteDetalle,
          FutureOr<RestauranteDetalle>
        >
    with
        $FutureModifier<RestauranteDetalle>,
        $FutureProvider<RestauranteDetalle> {
  /// Detalle con menú anidado — INTERINO Task 1 (legacy REST, id String).
  RestauranteDetalleProvider._({
    required RestauranteDetalleFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'restauranteDetalleProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$restauranteDetalleHash();

  @override
  String toString() {
    return r'restauranteDetalleProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<RestauranteDetalle> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<RestauranteDetalle> create(Ref ref) {
    final argument = this.argument as String;
    return restauranteDetalle(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is RestauranteDetalleProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$restauranteDetalleHash() =>
    r'60daccafdb92e70e3554b3f982a891765d22e728';

/// Detalle con menú anidado — INTERINO Task 1 (legacy REST, id String).

final class RestauranteDetalleFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<RestauranteDetalle>, String> {
  RestauranteDetalleFamily._()
    : super(
        retry: null,
        name: r'restauranteDetalleProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Detalle con menú anidado — INTERINO Task 1 (legacy REST, id String).

  RestauranteDetalleProvider call(String id) =>
      RestauranteDetalleProvider._(argument: id, from: this);

  @override
  String toString() => r'restauranteDetalleProvider';
}
