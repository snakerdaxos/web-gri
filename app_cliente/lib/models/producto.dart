import 'package:freezed_annotation/freezed_annotation.dart';

part 'producto.freezed.dart';
part 'producto.g.dart';

/// Plato/bebida del menú (`ProductoRead` del backend).
///
/// ⚠️ [precio] es `double` — el backend coercea el Decimal a float en el
/// wire (Pitfall 3 resuelto en 05-01). Formatear SIEMPRE con
/// `formatCOP` (core/format.dart), nunca concatenar strings.
@freezed
abstract class Producto with _$Producto {
  const factory Producto({
    required int id,
    required String nombre,
    String? descripcion,
    required double precio,
    @JsonKey(name: 'imagen_url') String? imagenUrl,
    required bool disponible,
  }) = _Producto;

  factory Producto.fromJson(Map<String, dynamic> json) =>
      _$ProductoFromJson(json);
}
