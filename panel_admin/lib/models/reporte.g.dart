// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'reporte.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_VentaDia _$VentaDiaFromJson(Map<String, dynamic> json) => _VentaDia(
  fecha: json['fecha'] as String,
  total: (json['total'] as num).toDouble(),
  numPedidos: (json['num_pedidos'] as num).toInt(),
);

Map<String, dynamic> _$VentaDiaToJson(_VentaDia instance) => <String, dynamic>{
  'fecha': instance.fecha,
  'total': instance.total,
  'num_pedidos': instance.numPedidos,
};

_VentasReporte _$VentasReporteFromJson(Map<String, dynamic> json) =>
    _VentasReporte(
      desde: json['desde'] as String,
      hasta: json['hasta'] as String,
      total: (json['total'] as num).toDouble(),
      numPedidos: (json['num_pedidos'] as num).toInt(),
      porDia: (json['por_dia'] as List<dynamic>)
          .map((e) => VentaDia.fromJson(e as Map<String, dynamic>))
          .toList(),
    );

Map<String, dynamic> _$VentasReporteToJson(_VentasReporte instance) =>
    <String, dynamic>{
      'desde': instance.desde,
      'hasta': instance.hasta,
      'total': instance.total,
      'num_pedidos': instance.numPedidos,
      'por_dia': instance.porDia,
    };

_TopPlato _$TopPlatoFromJson(Map<String, dynamic> json) => _TopPlato(
  productoId: (json['producto_id'] as num).toInt(),
  nombre: json['nombre'] as String,
  cantidad: (json['cantidad'] as num).toInt(),
  total: (json['total'] as num).toDouble(),
);

Map<String, dynamic> _$TopPlatoToJson(_TopPlato instance) => <String, dynamic>{
  'producto_id': instance.productoId,
  'nombre': instance.nombre,
  'cantidad': instance.cantidad,
  'total': instance.total,
};
