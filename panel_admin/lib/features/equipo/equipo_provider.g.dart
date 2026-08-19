// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'equipo_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// El equipo del restaurante activo (BOOT-04).
///
/// ⚠️ EL `where('restauranteId', isEqualTo: rid)` ES OBLIGATORIO, NO UN FILTRO
/// DE CONVENIENCIA. Firestore evalúa las security rules contra la CONSULTA, no
/// contra los documentos devueltos: la rama que autoriza esta lectura es
/// `role() == 'admin_restaurante' && resource.data.restauranteId == rid()`
/// (`firestore.rules`, match /usuarios, AMPLIADO EN 11-10), así que sin
/// replicar el filtro la query se deniega ENTERA — no devuelve "menos
/// documentos", falla con `permission-denied`. Es exactamente el modo de fallo
/// del bug del menú del plan 11-03. Lo vigila además `npm run audit:indexes`
/// (tabla `PARIDAD_RULES_QUERY`, entrada `usuarios`).
///
/// El orden por nombre se hace EN CLIENTE a propósito: un `orderBy('nombre')`
/// junto al `where` de igualdad exigiría un índice compuesto nuevo, y el equipo
/// de un restaurante es una lista corta. Con eso `audit:indexes` sigue en 0
/// fallos.
///
/// `rid` efectivo: staff → su claim; `super_admin` → el restaurante elegido en
/// el selector del topbar. Todo eso ya lo resuelve [ridActivoProvider] (10-06);
/// aquí NO se inventa un mecanismo nuevo. Sin selección (super recién entrado)
/// devuelve `[]` y no lanza — patrón de `clientesProvider`.
///
/// Defense in depth (patrón `restaurantesAdminProvider`): si un `mesero` o
/// `cocina` llegara hasta aquí, lanza claro en vez de disparar una query que
/// las rules van a denegar igualmente. El gate REAL es la regla, no esto.

@ProviderFor(equipo)
final equipoProvider = EquipoProvider._();

/// El equipo del restaurante activo (BOOT-04).
///
/// ⚠️ EL `where('restauranteId', isEqualTo: rid)` ES OBLIGATORIO, NO UN FILTRO
/// DE CONVENIENCIA. Firestore evalúa las security rules contra la CONSULTA, no
/// contra los documentos devueltos: la rama que autoriza esta lectura es
/// `role() == 'admin_restaurante' && resource.data.restauranteId == rid()`
/// (`firestore.rules`, match /usuarios, AMPLIADO EN 11-10), así que sin
/// replicar el filtro la query se deniega ENTERA — no devuelve "menos
/// documentos", falla con `permission-denied`. Es exactamente el modo de fallo
/// del bug del menú del plan 11-03. Lo vigila además `npm run audit:indexes`
/// (tabla `PARIDAD_RULES_QUERY`, entrada `usuarios`).
///
/// El orden por nombre se hace EN CLIENTE a propósito: un `orderBy('nombre')`
/// junto al `where` de igualdad exigiría un índice compuesto nuevo, y el equipo
/// de un restaurante es una lista corta. Con eso `audit:indexes` sigue en 0
/// fallos.
///
/// `rid` efectivo: staff → su claim; `super_admin` → el restaurante elegido en
/// el selector del topbar. Todo eso ya lo resuelve [ridActivoProvider] (10-06);
/// aquí NO se inventa un mecanismo nuevo. Sin selección (super recién entrado)
/// devuelve `[]` y no lanza — patrón de `clientesProvider`.
///
/// Defense in depth (patrón `restaurantesAdminProvider`): si un `mesero` o
/// `cocina` llegara hasta aquí, lanza claro en vez de disparar una query que
/// las rules van a denegar igualmente. El gate REAL es la regla, no esto.

final class EquipoProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<MiembroEquipo>>,
          List<MiembroEquipo>,
          FutureOr<List<MiembroEquipo>>
        >
    with
        $FutureModifier<List<MiembroEquipo>>,
        $FutureProvider<List<MiembroEquipo>> {
  /// El equipo del restaurante activo (BOOT-04).
  ///
  /// ⚠️ EL `where('restauranteId', isEqualTo: rid)` ES OBLIGATORIO, NO UN FILTRO
  /// DE CONVENIENCIA. Firestore evalúa las security rules contra la CONSULTA, no
  /// contra los documentos devueltos: la rama que autoriza esta lectura es
  /// `role() == 'admin_restaurante' && resource.data.restauranteId == rid()`
  /// (`firestore.rules`, match /usuarios, AMPLIADO EN 11-10), así que sin
  /// replicar el filtro la query se deniega ENTERA — no devuelve "menos
  /// documentos", falla con `permission-denied`. Es exactamente el modo de fallo
  /// del bug del menú del plan 11-03. Lo vigila además `npm run audit:indexes`
  /// (tabla `PARIDAD_RULES_QUERY`, entrada `usuarios`).
  ///
  /// El orden por nombre se hace EN CLIENTE a propósito: un `orderBy('nombre')`
  /// junto al `where` de igualdad exigiría un índice compuesto nuevo, y el equipo
  /// de un restaurante es una lista corta. Con eso `audit:indexes` sigue en 0
  /// fallos.
  ///
  /// `rid` efectivo: staff → su claim; `super_admin` → el restaurante elegido en
  /// el selector del topbar. Todo eso ya lo resuelve [ridActivoProvider] (10-06);
  /// aquí NO se inventa un mecanismo nuevo. Sin selección (super recién entrado)
  /// devuelve `[]` y no lanza — patrón de `clientesProvider`.
  ///
  /// Defense in depth (patrón `restaurantesAdminProvider`): si un `mesero` o
  /// `cocina` llegara hasta aquí, lanza claro en vez de disparar una query que
  /// las rules van a denegar igualmente. El gate REAL es la regla, no esto.
  EquipoProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'equipoProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$equipoHash();

  @$internal
  @override
  $FutureProviderElement<List<MiembroEquipo>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<MiembroEquipo>> create(Ref ref) {
    return equipo(ref);
  }
}

String _$equipoHash() => r'930ac55ab2faff688d26d66761681fffe8de9da2';
