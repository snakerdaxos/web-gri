import 'package:flutter/material.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

import 'pedido_item.dart';

part 'pedido.freezed.dart';
part 'pedido.g.dart';

/// Pedido del cliente (`PedidoRead` del backend) — creado en estado
/// `enviado` y avanzado por cocina/mesero (chips de estado en la UI).
///
/// [total]/precios son `double` — el backend serializea Decimal→float
/// (lección 05-01). Formatear SIEMPRE con `formatCOP`.
@freezed
abstract class Pedido with _$Pedido {
  const factory Pedido({
    required int id,
    @JsonKey(name: 'sesion_id') required int sesionId,
    @JsonKey(name: 'mesa_numero') required int mesaNumero,
    required String estado,
    required double total,
    String? notas,
    @JsonKey(name: 'created_at') required DateTime createdAt,
    required List<PedidoItem> items,
  }) = _Pedido;

  factory Pedido.fromJson(Map<String, dynamic> json) =>
      _$PedidoFromJson(json);
}

/// Labels y colores de los chips de estado (5 estados del wire).
///
/// Paleta coherente con los chips del theme: enviado azul, aceptado
/// naranja, en_preparacion morado, servido verde, rechazado rojo.
extension PedidoEstadoX on Pedido {
  String get estadoLabel => switch (estado) {
        'enviado' => 'Enviado',
        'aceptado' => 'Aceptado',
        'en_preparacion' => 'En preparación',
        'servido' => 'Servido',
        'rechazado' => 'Rechazado',
        _ => estado,
      };

  Color get estadoColor => switch (estado) {
        'enviado' => const Color(0xFF2563EB),
        'aceptado' => const Color(0xFFD97706),
        'en_preparacion' => const Color(0xFF7C3AED),
        'servido' => const Color(0xFF168A52),
        'rechazado' => const Color(0xFFC83C2E),
        _ => const Color(0xFF777777),
      };

  /// Fondo suave del chip (versión ~12% del color de texto).
  Color get estadoBg => switch (estado) {
        'enviado' => const Color(0xFFE3ECFD),
        'aceptado' => const Color(0xFFFCF0DE),
        'en_preparacion' => const Color(0xFFEFE6FC),
        'servido' => const Color(0xFFDFF7EB),
        'rechazado' => const Color(0xFFFFE9E6),
        _ => const Color(0xFFEEEEEE),
      };
}
