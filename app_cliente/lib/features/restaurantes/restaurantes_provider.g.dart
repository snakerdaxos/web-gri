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
/// ⚠️ POR QUÉ LOS FILTROS SON SERVER-SIDE (11-03 — NO "optimizar" quitándolos):
/// la razón NO es rendimiento, es AUTORIZACIÓN. Firestore evalúa las security
/// rules contra la CONSULTA, nunca contra los documentos devueltos: si la query
/// pudiera alcanzar un solo doc que la regla no permite, se rechaza la petición
/// ENTERA con `permission-denied`. Filtrar client-side después de traer los
/// documentos no sirve de nada, porque nunca llegan.
///
/// Las reglas vigentes son (`firestore.rules`, matches /categorias y
/// /productos):
///
///     categorias → activo == true            || menuStaffOf(restauranteId)
///     productos  → activo == true
///                  && disponible == true     || menuStaffOf(restauranteId)
///
/// Regla mental permanente: **si la rule menciona `resource.data.X`, la query
/// DEBE llevar `where('X', …)`**. De ahí que `productos` lleve DOS filtros:
/// replicar la regla a medias (solo `activo`) también deniega la query.
/// Cobertura: `scripts/test/rules/categorias.test.mjs` y `productos.test.mjs`
/// lo afirman contra el emulador con las rules reales.
///
/// Nota de índices: el `orderBy('orden')` de las categorías se sigue haciendo
/// client-side, y es una decisión deliberada de 11-03 — hacerlo server-side
/// obligaría al índice compuesto `categorias(restauranteId, activo, orden)`.
/// El N de categorías por restaurante es pequeño y evitar un índice extra
/// elimina un punto de fallo más: los índices tardan minutos en construirse y
/// el emulador de Firestore ni siquiera los valida, así que un índice que falte
/// solo se descubre en producción. Los `where` de igualdad de arriba se
/// resuelven con los índices automáticos de campo único: no requieren
/// compuesto.

@ProviderFor(restauranteDetalle)
final restauranteDetalleProvider = RestauranteDetalleFamily._();

/// Detalle público con menú anidado — 3 lecturas de Firestore (MIGRA-01):
/// doc `restaurantes/{id}` + categorías + productos del restaurante,
/// agrupados por `categoriaId` (colección plana, research 10).
///
/// ⚠️ POR QUÉ LOS FILTROS SON SERVER-SIDE (11-03 — NO "optimizar" quitándolos):
/// la razón NO es rendimiento, es AUTORIZACIÓN. Firestore evalúa las security
/// rules contra la CONSULTA, nunca contra los documentos devueltos: si la query
/// pudiera alcanzar un solo doc que la regla no permite, se rechaza la petición
/// ENTERA con `permission-denied`. Filtrar client-side después de traer los
/// documentos no sirve de nada, porque nunca llegan.
///
/// Las reglas vigentes son (`firestore.rules`, matches /categorias y
/// /productos):
///
///     categorias → activo == true            || menuStaffOf(restauranteId)
///     productos  → activo == true
///                  && disponible == true     || menuStaffOf(restauranteId)
///
/// Regla mental permanente: **si la rule menciona `resource.data.X`, la query
/// DEBE llevar `where('X', …)`**. De ahí que `productos` lleve DOS filtros:
/// replicar la regla a medias (solo `activo`) también deniega la query.
/// Cobertura: `scripts/test/rules/categorias.test.mjs` y `productos.test.mjs`
/// lo afirman contra el emulador con las rules reales.
///
/// Nota de índices: el `orderBy('orden')` de las categorías se sigue haciendo
/// client-side, y es una decisión deliberada de 11-03 — hacerlo server-side
/// obligaría al índice compuesto `categorias(restauranteId, activo, orden)`.
/// El N de categorías por restaurante es pequeño y evitar un índice extra
/// elimina un punto de fallo más: los índices tardan minutos en construirse y
/// el emulador de Firestore ni siquiera los valida, así que un índice que falte
/// solo se descubre en producción. Los `where` de igualdad de arriba se
/// resuelven con los índices automáticos de campo único: no requieren
/// compuesto.

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
  /// ⚠️ POR QUÉ LOS FILTROS SON SERVER-SIDE (11-03 — NO "optimizar" quitándolos):
  /// la razón NO es rendimiento, es AUTORIZACIÓN. Firestore evalúa las security
  /// rules contra la CONSULTA, nunca contra los documentos devueltos: si la query
  /// pudiera alcanzar un solo doc que la regla no permite, se rechaza la petición
  /// ENTERA con `permission-denied`. Filtrar client-side después de traer los
  /// documentos no sirve de nada, porque nunca llegan.
  ///
  /// Las reglas vigentes son (`firestore.rules`, matches /categorias y
  /// /productos):
  ///
  ///     categorias → activo == true            || menuStaffOf(restauranteId)
  ///     productos  → activo == true
  ///                  && disponible == true     || menuStaffOf(restauranteId)
  ///
  /// Regla mental permanente: **si la rule menciona `resource.data.X`, la query
  /// DEBE llevar `where('X', …)`**. De ahí que `productos` lleve DOS filtros:
  /// replicar la regla a medias (solo `activo`) también deniega la query.
  /// Cobertura: `scripts/test/rules/categorias.test.mjs` y `productos.test.mjs`
  /// lo afirman contra el emulador con las rules reales.
  ///
  /// Nota de índices: el `orderBy('orden')` de las categorías se sigue haciendo
  /// client-side, y es una decisión deliberada de 11-03 — hacerlo server-side
  /// obligaría al índice compuesto `categorias(restauranteId, activo, orden)`.
  /// El N de categorías por restaurante es pequeño y evitar un índice extra
  /// elimina un punto de fallo más: los índices tardan minutos en construirse y
  /// el emulador de Firestore ni siquiera los valida, así que un índice que falte
  /// solo se descubre en producción. Los `where` de igualdad de arriba se
  /// resuelven con los índices automáticos de campo único: no requieren
  /// compuesto.
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
    r'2a21ff09b4cc1b273208a796037b538abb25bec5';

/// Detalle público con menú anidado — 3 lecturas de Firestore (MIGRA-01):
/// doc `restaurantes/{id}` + categorías + productos del restaurante,
/// agrupados por `categoriaId` (colección plana, research 10).
///
/// ⚠️ POR QUÉ LOS FILTROS SON SERVER-SIDE (11-03 — NO "optimizar" quitándolos):
/// la razón NO es rendimiento, es AUTORIZACIÓN. Firestore evalúa las security
/// rules contra la CONSULTA, nunca contra los documentos devueltos: si la query
/// pudiera alcanzar un solo doc que la regla no permite, se rechaza la petición
/// ENTERA con `permission-denied`. Filtrar client-side después de traer los
/// documentos no sirve de nada, porque nunca llegan.
///
/// Las reglas vigentes son (`firestore.rules`, matches /categorias y
/// /productos):
///
///     categorias → activo == true            || menuStaffOf(restauranteId)
///     productos  → activo == true
///                  && disponible == true     || menuStaffOf(restauranteId)
///
/// Regla mental permanente: **si la rule menciona `resource.data.X`, la query
/// DEBE llevar `where('X', …)`**. De ahí que `productos` lleve DOS filtros:
/// replicar la regla a medias (solo `activo`) también deniega la query.
/// Cobertura: `scripts/test/rules/categorias.test.mjs` y `productos.test.mjs`
/// lo afirman contra el emulador con las rules reales.
///
/// Nota de índices: el `orderBy('orden')` de las categorías se sigue haciendo
/// client-side, y es una decisión deliberada de 11-03 — hacerlo server-side
/// obligaría al índice compuesto `categorias(restauranteId, activo, orden)`.
/// El N de categorías por restaurante es pequeño y evitar un índice extra
/// elimina un punto de fallo más: los índices tardan minutos en construirse y
/// el emulador de Firestore ni siquiera los valida, así que un índice que falte
/// solo se descubre en producción. Los `where` de igualdad de arriba se
/// resuelven con los índices automáticos de campo único: no requieren
/// compuesto.

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
  /// ⚠️ POR QUÉ LOS FILTROS SON SERVER-SIDE (11-03 — NO "optimizar" quitándolos):
  /// la razón NO es rendimiento, es AUTORIZACIÓN. Firestore evalúa las security
  /// rules contra la CONSULTA, nunca contra los documentos devueltos: si la query
  /// pudiera alcanzar un solo doc que la regla no permite, se rechaza la petición
  /// ENTERA con `permission-denied`. Filtrar client-side después de traer los
  /// documentos no sirve de nada, porque nunca llegan.
  ///
  /// Las reglas vigentes son (`firestore.rules`, matches /categorias y
  /// /productos):
  ///
  ///     categorias → activo == true            || menuStaffOf(restauranteId)
  ///     productos  → activo == true
  ///                  && disponible == true     || menuStaffOf(restauranteId)
  ///
  /// Regla mental permanente: **si la rule menciona `resource.data.X`, la query
  /// DEBE llevar `where('X', …)`**. De ahí que `productos` lleve DOS filtros:
  /// replicar la regla a medias (solo `activo`) también deniega la query.
  /// Cobertura: `scripts/test/rules/categorias.test.mjs` y `productos.test.mjs`
  /// lo afirman contra el emulador con las rules reales.
  ///
  /// Nota de índices: el `orderBy('orden')` de las categorías se sigue haciendo
  /// client-side, y es una decisión deliberada de 11-03 — hacerlo server-side
  /// obligaría al índice compuesto `categorias(restauranteId, activo, orden)`.
  /// El N de categorías por restaurante es pequeño y evitar un índice extra
  /// elimina un punto de fallo más: los índices tardan minutos en construirse y
  /// el emulador de Firestore ni siquiera los valida, así que un índice que falte
  /// solo se descubre en producción. Los `where` de igualdad de arriba se
  /// resuelven con los índices automáticos de campo único: no requieren
  /// compuesto.

  RestauranteDetalleProvider call(String id) =>
      RestauranteDetalleProvider._(argument: id, from: this);

  @override
  String toString() => r'restauranteDetalleProvider';
}
