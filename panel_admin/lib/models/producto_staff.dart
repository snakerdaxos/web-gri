import 'package:freezed_annotation/freezed_annotation.dart';

part 'producto_staff.freezed.dart';
part 'producto_staff.g.dart';

/// Producto del menú visto por staff (`ProductoStaff`, 08-01).
///
/// Dos flags con semánticas DISTINTAS (threat model 08-04):
///  * [disponible] — agotado transitorio: SIGUE visible en /public con flag.
///  * [activo] — soft-delete: desaparece de /public (el staff lo sigue viendo).
///
/// `precio` viaja como JSON number (backend coercea Decimal→float vía
/// field_serializer — Pitfall 1 de 08-01): double directo, jamás parse manual.
@freezed
abstract class ProductoStaff with _$ProductoStaff {
  const factory ProductoStaff({
    required int id,
    @JsonKey(name: 'categoria_id') required int categoriaId,
    required String nombre,
    required String? descripcion,
    required double precio,
    @JsonKey(name: 'imagen_url') required String? imagenUrl,
    required bool disponible,
    required bool activo,
  }) = _ProductoStaff;

  factory ProductoStaff.fromJson(Map<String, dynamic> json) =>
      _$ProductoStaffFromJson(json);
}
