import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

import 'pedido_item.dart';

part 'pedido.freezed.dart';
part 'pedido.g.dart';

/// Pedido del cliente — doc `pedidos/{autoId}` (doc shapes research 10).
/// Nace en estado `enviado` y avanza por cocina/mesero (rules 10-01);
/// `sesionId` == `mesaId` (la sesión vive en `sesiones/{mesaId}`) y los
/// items llevan SNAPSHOT de nombre/precio. [total] es `int` COP.
@freezed
abstract class Pedido with _$Pedido {
  const factory Pedido({
    required String id,
    required String restauranteId,
    required String mesaId,

    /// == [mesaId] (sesión única por mesa, doc ID determinista).
    required String sesionId,
    required String usuarioId,
    @Default('') String clienteNombre,
    required String estado,
    required int total,
    required List<PedidoItem> items,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) = _Pedido;

  factory Pedido.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const <String, dynamic>{};
    return Pedido(
      id: doc.id,
      restauranteId: data['restauranteId'] as String? ?? '',
      mesaId: data['mesaId'] as String? ?? '',
      sesionId: data['sesionId'] as String? ?? '',
      usuarioId: data['usuarioId'] as String? ?? '',
      clienteNombre: data['clienteNombre'] as String? ?? '',
      estado: data['estado'] as String? ?? 'enviado',
      total: (data['total'] as num?)?.toInt() ?? 0,
      items: [
        for (final item in (data['items'] as List? ?? const []))
          PedidoItem.fromMap((item as Map).cast<String, dynamic>()),
      ],
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
    );
  }

  /// `fromJson` heredado de la era REST — sin uso tras la migración; la
  /// vía canónica es [fromDoc].
  factory Pedido.fromJson(Map<String, dynamic> json) =>
      _$PedidoFromJson(json);

  const Pedido._();

  /// Label corto del autoId (20 chars) para la UI: `#X3K9QZ`.
  String get codigoCorto =>
      id.length <= 6 ? id : id.substring(0, 6).toUpperCase();
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
