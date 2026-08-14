import 'package:flutter/material.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

import '../core/theme.dart';

part 'pedido_staff.freezed.dart';
part 'pedido_staff.g.dart';

/// Estados de un pedido (espejo del enum backend `EstadoPedido`).
///
/// La cola activa (`GET /staff/pedidos?activos=true`) solo entrega los 4
/// primeros; `rechazado`/`pagado` son terminales (F9) pero `rechazado` es
/// destino válido del botón "Rechazar" y puede llegar en la respuesta del
/// `POST /staff/pedidos/{id}/estado`.
enum EstadoPedido {
  enviado,
  aceptado,
  enPreparacion,
  servido,
  rechazado,
  pagado,
}

/// Traduce el string del backend al enum — switch exhaustivo, valor
/// desconocido explota temprano (patrón estadoMesaFromJson).
EstadoPedido estadoPedidoFromJson(String raw) => switch (raw) {
  'enviado' => EstadoPedido.enviado,
  'aceptado' => EstadoPedido.aceptado,
  'en_preparacion' => EstadoPedido.enPreparacion,
  'servido' => EstadoPedido.servido,
  'rechazado' => EstadoPedido.rechazado,
  'pagado' => EstadoPedido.pagado,
  _ => throw ArgumentError('EstadoPedido desconocido: $raw'),
};

/// Nombre en el wire (snake_case del backend) para el body de
/// `POST /staff/pedidos/{id}/estado`.
String estadoPedidoToJson(EstadoPedido e) => switch (e) {
  EstadoPedido.enviado => 'enviado',
  EstadoPedido.aceptado => 'aceptado',
  EstadoPedido.enPreparacion => 'en_preparacion',
  EstadoPedido.servido => 'servido',
  EstadoPedido.rechazado => 'rechazado',
  EstadoPedido.pagado => 'pagado',
};

/// Una línea de pedido con el snapshot de precio (nombre = join display).
@freezed
abstract class PedidoStaffItem with _$PedidoStaffItem {
  const factory PedidoStaffItem({
    @JsonKey(name: 'producto_id') required int productoId,
    required String nombre,
    required int cantidad,
    @JsonKey(name: 'precio_unitario') required double precioUnitario,
    required double subtotal,
  }) = _PedidoStaffItem;

  factory PedidoStaffItem.fromJson(Map<String, dynamic> json) =>
      _$PedidoStaffItemFromJson(json);
}

/// Pedido de la cola de cocina/mesero (`PedidoStaffRead`, ADMN-05) —
/// incluye `usuarioNombre` y el badge `solicitaCuenta` (PAGO-01).
@freezed
abstract class PedidoStaff with _$PedidoStaff {
  const factory PedidoStaff({
    required int id,
    @JsonKey(name: 'sesion_id') required int? sesionId,
    @JsonKey(name: 'mesa_numero') required int mesaNumero,
    @JsonKey(fromJson: estadoPedidoFromJson, toJson: estadoPedidoToJson)
    required EstadoPedido estado,
    required double total,
    required String? notas,
    @JsonKey(name: 'created_at') required DateTime createdAt,
    required List<PedidoStaffItem> items,
    @JsonKey(name: 'usuario_nombre') required String usuarioNombre,
    @JsonKey(name: 'solicita_cuenta', defaultValue: false)
    required bool solicitaCuenta,
    @JsonKey(name: 'solicitada_en') required DateTime? solicitadaEn,
  }) = _PedidoStaff;

  factory PedidoStaff.fromJson(Map<String, dynamic> json) =>
      _$PedidoStaffFromJson(json);
}

/// Una acción de avance de estado que la UI muestra como botón.
typedef AccionPedido = ({String label, EstadoPedido destino});

/// Roles que pueden aceptar/rechazar/preparar (TODO menos mesero — espejo
/// client-side de TRANSITION_ROLES del backend, que es la autoridad).
const _rolesCocina = {'cocina', 'admin_restaurante', 'super_admin'};

/// Extensión de presentación — botones según la matriz rol×transición
/// (PEDI-05). Ocultar es UX: el server re-valida (403) y la transición
/// (409) sobre el wire.
extension PedidoStaffActions on PedidoStaff {
  List<AccionPedido> nextActions(String role) => switch (estado) {
    EstadoPedido.enviado =>
      _rolesCocina.contains(role)
          ? const [
              (label: 'Aceptar', destino: EstadoPedido.aceptado),
              (label: 'Rechazar', destino: EstadoPedido.rechazado),
            ]
          : const [],
    EstadoPedido.aceptado =>
      _rolesCocina.contains(role)
          ? const [
              (label: 'En preparación', destino: EstadoPedido.enPreparacion),
            ]
          : const [],
    EstadoPedido.enPreparacion => [
      (
        label: role == 'mesero' ? 'Marcar servido' : 'Servido',
        destino: EstadoPedido.servido,
      ),
    ],
    EstadoPedido.servido ||
    EstadoPedido.rechazado ||
    EstadoPedido.pagado => const [],
  };
}

/// Extensión visual del estado — colores coherentes con [GriColors]:
/// enviado azul, aceptado naranja, en_preparación morado, servido verde.
extension EstadoPedidoUI on EstadoPedido {
  Color get color => switch (this) {
    EstadoPedido.enviado => GriColors.mesaLimpiezaDot, // azul #3478F6
    EstadoPedido.aceptado => GriColors.primary, // naranja #ff4c05
    EstadoPedido.enPreparacion => const Color(0xFF8E44AD), // morado
    EstadoPedido.servido => GriColors.mesaDisponibleDot, // verde #20b26b
    EstadoPedido.rechazado => GriColors.mesaOcupadaDot, // rojo #e74c3c
    EstadoPedido.pagado => GriColors.mesaDisponibleDot,
  };

  String get label => switch (this) {
    EstadoPedido.enviado => 'Enviado',
    EstadoPedido.aceptado => 'Aceptado',
    EstadoPedido.enPreparacion => 'En preparación',
    EstadoPedido.servido => 'Servido',
    EstadoPedido.rechazado => 'Rechazado',
    EstadoPedido.pagado => 'Pagado',
  };
}
