// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'categoria_staff.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_CategoriaStaff _$CategoriaStaffFromJson(Map<String, dynamic> json) =>
    _CategoriaStaff(
      id: (json['id'] as num).toInt(),
      nombre: json['nombre'] as String,
      orden: (json['orden'] as num).toInt(),
      activo: json['activo'] as bool,
      productos: (json['productos'] as List<dynamic>)
          .map((e) => ProductoStaff.fromJson(e as Map<String, dynamic>))
          .toList(),
    );

Map<String, dynamic> _$CategoriaStaffToJson(_CategoriaStaff instance) =>
    <String, dynamic>{
      'id': instance.id,
      'nombre': instance.nombre,
      'orden': instance.orden,
      'activo': instance.activo,
      'productos': instance.productos,
    };
