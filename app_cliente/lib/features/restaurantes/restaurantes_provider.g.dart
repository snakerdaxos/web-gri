// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'restaurantes_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Lista pública de restaurantes activos — Firestore (MIGRA-01).
///
/// `collection('restaurantes').where('activo', isEqualTo: true)` +
/// [Restaurante.fromDoc]; orden estable por nombre (el slug ya no es un
/// secuencia). SIN capa HTTP propia — el override de `firestoreProvider`
/// en tests corta toda la feature del backend real.

@ProviderFor(restaurantesList)
final restaurantesListProvider = RestaurantesListProvider._();

/// Lista pública de restaurantes activos — Firestore (MIGRA-01).
///
/// `collection('restaurantes').where('activo', isEqualTo: true)` +
/// [Restaurante.fromDoc]; orden estable por nombre (el slug ya no es un
/// secuencia). SIN capa HTTP propia — el override de `firestoreProvider`
/// en tests corta toda la feature del backend real.

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
  /// Lista pública de restaurantes activos — Firestore (MIGRA-01).
  ///
  /// `collection('restaurantes').where('activo', isEqualTo: true)` +
  /// [Restaurante.fromDoc]; orden estable por nombre (el slug ya no es un
  /// secuencia). SIN capa HTTP propia — el override de `firestoreProvider`
  /// en tests corta toda la feature del backend real.
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

String _$restaurantesListHash() => r'2dbf6414521be1bf6703537e87dc12d48a20969b';

/// Detalle público con menú anidado — 3 lecturas de Firestore (MIGRA-01):
/// doc `restaurantes/{id}` + categorías + productos del restaurante,
/// agrupados por `categoriaId` (colección plana, research 10).
///
/// Nota de índices: el `orderBy('orden')` de las categorías se hace
/// client-side — el índice compuesto `categorias(restauranteId, orden)` NO
/// existe en 10-01 y el where simple usa índice de campo único (el N por
/// restaurante es chico; comportamiento idéntico).

@ProviderFor(restauranteDetalle)
final restauranteDetalleProvider = RestauranteDetalleFamily._();

/// Detalle público con menú anidado — 3 lecturas de Firestore (MIGRA-01):
/// doc `restaurantes/{id}` + categorías + productos del restaurante,
/// agrupados por `categoriaId` (colección plana, research 10).
///
/// Nota de índices: el `orderBy('orden')` de las categorías se hace
/// client-side — el índice compuesto `categorias(restauranteId, orden)` NO
/// existe en 10-01 y el where simple usa índice de campo único (el N por
/// restaurante es chico; comportamiento idéntico).

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
  /// Detalle público con menú anidado — 3 lecturas de Firestore (MIGRA-01):
  /// doc `restaurantes/{id}` + categorías + productos del restaurante,
  /// agrupados por `categoriaId` (colección plana, research 10).
  ///
  /// Nota de índices: el `orderBy('orden')` de las categorías se hace
  /// client-side — el índice compuesto `categorias(restauranteId, orden)` NO
  /// existe en 10-01 y el where simple usa índice de campo único (el N por
  /// restaurante es chico; comportamiento idéntico).
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
    r'2bd8d3f5aa2f51ed3ff17dfb708e1205881138d7';

/// Detalle público con menú anidado — 3 lecturas de Firestore (MIGRA-01):
/// doc `restaurantes/{id}` + categorías + productos del restaurante,
/// agrupados por `categoriaId` (colección plana, research 10).
///
/// Nota de índices: el `orderBy('orden')` de las categorías se hace
/// client-side — el índice compuesto `categorias(restauranteId, orden)` NO
/// existe en 10-01 y el where simple usa índice de campo único (el N por
/// restaurante es chico; comportamiento idéntico).

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

  /// Detalle público con menú anidado — 3 lecturas de Firestore (MIGRA-01):
  /// doc `restaurantes/{id}` + categorías + productos del restaurante,
  /// agrupados por `categoriaId` (colección plana, research 10).
  ///
  /// Nota de índices: el `orderBy('orden')` de las categorías se hace
  /// client-side — el índice compuesto `categorias(restauranteId, orden)` NO
  /// existe en 10-01 y el where simple usa índice de campo único (el N por
  /// restaurante es chico; comportamiento idéntico).

  RestauranteDetalleProvider call(String id) =>
      RestauranteDetalleProvider._(argument: id, from: this);

  @override
  String toString() => r'restauranteDetalleProvider';
}
