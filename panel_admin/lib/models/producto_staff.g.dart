// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'producto_staff.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_ProductoStaff _$ProductoStaffFromJson(Map<String, dynamic> json) =>
    _ProductoStaff(
      id: (json['id'] as num).toInt(),
      categoriaId: (json['categoria_id'] as num).toInt(),
      nombre: json['nombre'] as String,
      descripcion: json['descripcion'] as String?,
      precio: (json['precio'] as num).toDouble(),
      imagenUrl: json['imagen_url'] as String?,
      disponible: json['disponible'] as bool,
      activo: json['activo'] as bool,
    );

Map<String, dynamic> _$ProductoStaffToJson(_ProductoStaff instance) =>
    <String, dynamic>{
      'id': instance.id,
      'categoria_id': instance.categoriaId,
      'nombre': instance.nombre,
      'descripcion': instance.descripcion,
      'precio': instance.precio,
      'imagen_url': instance.imagenUrl,
      'disponible': instance.disponible,
      'activo': instance.activo,
    };
