import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

import '../core/theme.dart';
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
/// ── 11-11: aquí YA NO hay paleta ──────────────────────────────────────────
/// Hasta 11-11 este archivo tenía sus propios literales de color, una SEGUNDA
/// paleta en paralelo a la de `core/theme.dart`. Un modelo de datos no es
/// sitio para decidir colores, y con dos fuentes nadie sabía cuál mandaba.
///
/// Ahora los colores salen de `GriSemanticColors`, el `ThemeExtension` que
/// registra `griTheme`. Los hex NO cambiaron: se copiaron literalmente a la
/// extensión (la identidad visual es una decisión BLOQUEADA de la fase 11).
///
/// Consecuencia de API: [estadoColor] y [estadoBg] pasaron de getters a
/// MÉTODOS que reciben el `BuildContext`, porque leer del tema lo exige. El
/// único punto de uso (`features/pedidos/pedido_estado_screen.dart`, el
/// `_EstadoChip`) ya tiene contexto.
extension PedidoEstadoX on Pedido {
  String get estadoLabel => switch (estado) {
        'enviado' => 'Enviado',
        'aceptado' => 'Aceptado',
        'en_preparacion' => 'En preparación',
        'servido' => 'Servido',
        'rechazado' => 'Rechazado',
        _ => estado,
      };

  /// Color del TEXTO del chip, leído del tema.
  Color estadoColor(BuildContext context) =>
      GriSemanticColors.of(context).pedidoFg(estado);

  /// Fondo suave del chip (versión ~12% del color de texto), leído del tema.
  Color estadoBg(BuildContext context) =>
      GriSemanticColors.of(context).pedidoBg(estado);
}
