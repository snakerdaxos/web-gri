// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'reportes_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Reporte de ventas del rango [desde, hasta] (REPO-01/02, 10-06):
/// family por rango — la pantalla consulta on-demand con las fechas de
/// los pickers.
///
/// Query (índice 10-01 restauranteId+estado+createdAt la cubre):
/// `pedidos where restauranteId == rid where estado == 'servido' where
/// createdAt >= desde && createdAt <= hasta → get()` y FOLD en cliente:
///  * totalVentas = Σ total (int COP).
///  * numeroPedidos = count.
///  * topPlatos = map nombre→(Σ cantidad, Σ precio×cantidad) desde el
///    snapshot de items, ordenado por cantidad DESC (top 10).
///
/// Threat model: venta = `servido` únicamente; montos client-side =
/// display hasta Functions (fase pagos). rid null (super sin selección)
/// → reporte en cero.

@ProviderFor(reporte)
final reporteProvider = ReporteFamily._();

/// Reporte de ventas del rango [desde, hasta] (REPO-01/02, 10-06):
/// family por rango — la pantalla consulta on-demand con las fechas de
/// los pickers.
///
/// Query (índice 10-01 restauranteId+estado+createdAt la cubre):
/// `pedidos where restauranteId == rid where estado == 'servido' where
/// createdAt >= desde && createdAt <= hasta → get()` y FOLD en cliente:
///  * totalVentas = Σ total (int COP).
///  * numeroPedidos = count.
///  * topPlatos = map nombre→(Σ cantidad, Σ precio×cantidad) desde el
///    snapshot de items, ordenado por cantidad DESC (top 10).
///
/// Threat model: venta = `servido` únicamente; montos client-side =
/// display hasta Functions (fase pagos). rid null (super sin selección)
/// → reporte en cero.

final class ReporteProvider
    extends $FunctionalProvider<AsyncValue<Reporte>, Reporte, FutureOr<Reporte>>
    with $FutureModifier<Reporte>, $FutureProvider<Reporte> {
  /// Reporte de ventas del rango [desde, hasta] (REPO-01/02, 10-06):
  /// family por rango — la pantalla consulta on-demand con las fechas de
  /// los pickers.
  ///
  /// Query (índice 10-01 restauranteId+estado+createdAt la cubre):
  /// `pedidos where restauranteId == rid where estado == 'servido' where
  /// createdAt >= desde && createdAt <= hasta → get()` y FOLD en cliente:
  ///  * totalVentas = Σ total (int COP).
  ///  * numeroPedidos = count.
  ///  * topPlatos = map nombre→(Σ cantidad, Σ precio×cantidad) desde el
  ///    snapshot de items, ordenado por cantidad DESC (top 10).
  ///
  /// Threat model: venta = `servido` únicamente; montos client-side =
  /// display hasta Functions (fase pagos). rid null (super sin selección)
  /// → reporte en cero.
  ReporteProvider._({
    required ReporteFamily super.from,
    required (DateTime, DateTime) super.argument,
  }) : super(
         retry: null,
         name: r'reporteProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$reporteHash();

  @override
  String toString() {
    return r'reporteProvider'
        ''
        '$argument';
  }

  @$internal
  @override
  $FutureProviderElement<Reporte> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<Reporte> create(Ref ref) {
    final argument = this.argument as (DateTime, DateTime);
    return reporte(ref, argument.$1, argument.$2);
  }

  @override
  bool operator ==(Object other) {
    return other is ReporteProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$reporteHash() => r'db4e944c0198cd36c25385c64b6e96d78a0353cf';

/// Reporte de ventas del rango [desde, hasta] (REPO-01/02, 10-06):
/// family por rango — la pantalla consulta on-demand con las fechas de
/// los pickers.
///
/// Query (índice 10-01 restauranteId+estado+createdAt la cubre):
/// `pedidos where restauranteId == rid where estado == 'servido' where
/// createdAt >= desde && createdAt <= hasta → get()` y FOLD en cliente:
///  * totalVentas = Σ total (int COP).
///  * numeroPedidos = count.
///  * topPlatos = map nombre→(Σ cantidad, Σ precio×cantidad) desde el
///    snapshot de items, ordenado por cantidad DESC (top 10).
///
/// Threat model: venta = `servido` únicamente; montos client-side =
/// display hasta Functions (fase pagos). rid null (super sin selección)
/// → reporte en cero.

final class ReporteFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<Reporte>, (DateTime, DateTime)> {
  ReporteFamily._()
    : super(
        retry: null,
        name: r'reporteProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Reporte de ventas del rango [desde, hasta] (REPO-01/02, 10-06):
  /// family por rango — la pantalla consulta on-demand con las fechas de
  /// los pickers.
  ///
  /// Query (índice 10-01 restauranteId+estado+createdAt la cubre):
  /// `pedidos where restauranteId == rid where estado == 'servido' where
  /// createdAt >= desde && createdAt <= hasta → get()` y FOLD en cliente:
  ///  * totalVentas = Σ total (int COP).
  ///  * numeroPedidos = count.
  ///  * topPlatos = map nombre→(Σ cantidad, Σ precio×cantidad) desde el
  ///    snapshot de items, ordenado por cantidad DESC (top 10).
  ///
  /// Threat model: venta = `servido` únicamente; montos client-side =
  /// display hasta Functions (fase pagos). rid null (super sin selección)
  /// → reporte en cero.

  ReporteProvider call(DateTime desde, DateTime hasta) =>
      ReporteProvider._(argument: (desde, hasta), from: this);

  @override
  String toString() => r'reporteProvider';
}
