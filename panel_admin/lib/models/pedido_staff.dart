import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

import '../../core/theme.dart';

part 'pedido_staff.freezed.dart';
part 'pedido_staff.g.dart';

/// Estados de un pedido (espejo del enum backend `EstadoPedido` — Firestore
/// guarda los mismos strings).
///
/// La cola activa solo entrega los 4 primeros; `rechazado`/`pagado` son
/// terminales pero `rechazado` es destino válido del botón "Rechazar".
enum EstadoPedido {
  enviado,
  aceptado,
  enPreparacion,
  servido,
  rechazado,
  pagado,
}

/// Traduce el string del doc al enum — switch exhaustivo, valor
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

/// Nombre en el wire (snake_case) para el update de `pedidos/{id}`.
String estadoPedidoToJson(EstadoPedido e) => switch (e) {
  EstadoPedido.enviado => 'enviado',
  EstadoPedido.aceptado => 'aceptado',
  EstadoPedido.enPreparacion => 'en_preparacion',
  EstadoPedido.servido => 'servido',
  EstadoPedido.rechazado => 'rechazado',
  EstadoPedido.pagado => 'pagado',
};

/// Extrae el número de mesa del código QR del doc ID: `GRI-MESA-demo-003`
/// → 3. El doc de pedido lleva `mesaId` (= código QR); el número para la
/// UI se deriva del sufijo numérico (construcción determinista del ID).
int mesaNumeroDeQr(String mesaId) {
  final partes = mesaId.split('-');
  return int.tryParse(partes.isEmpty ? '' : partes.last) ?? 0;
}

/// Una línea de pedido con el snapshot de precio (int COP — research 10:
/// sin floats). El subtotal se re-deriva del snapshot al mapear el doc.
@freezed
abstract class PedidoStaffItem with _$PedidoStaffItem {
  const factory PedidoStaffItem({
    required String productoId,
    required String nombre,
    required int cantidad,
    required int precio,
    required int subtotal,
  }) = _PedidoStaffItem;

  factory PedidoStaffItem.fromJson(Map<String, dynamic> json) =>
      _$PedidoStaffItemFromJson(json);
}

/// Pedido de la cola de cocina/mesero — doc `pedidos/{autoId}` (Phase 10).
///
/// `fromDoc` mapea el shape del research: items snapshot, total int COP,
/// `clienteNombre` → [usuarioNombre], `mesaId` (código QR) → [mesaNumero]
/// derivado. `notas`/`solicitaCuenta` quedan como superficie de la UI
/// (null/false siempre en v1: las notas no viven en el doc shape y el
/// aviso de cuenta llega por el stream de `sesiones` — 10-05 Task 3).
@freezed
abstract class PedidoStaff with _$PedidoStaff {
  const factory PedidoStaff({
    /// AutoId de Firestore.
    required String id,
    @Default('') String restauranteId,

    /// Código QR de la mesa (doc ID determinista).
    @Default('') String mesaId,
    required String? sesionId,

    /// Derivado de [mesaId] (sufijo numérico del QR).
    required int mesaNumero,
    @JsonKey(fromJson: estadoPedidoFromJson, toJson: estadoPedidoToJson)
    required EstadoPedido estado,
    required int total,
    required String? notas,
    required DateTime createdAt,
    required List<PedidoStaffItem> items,
    required String usuarioNombre,
    @Default(false) bool solicitaCuenta,
    DateTime? solicitadaEn,
  }) = _PedidoStaff;

  /// Mapea el doc `pedidos/{autoId}`.
  factory PedidoStaff.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const <String, dynamic>{};
    final items = <PedidoStaffItem>[];
    for (final raw in (data['items'] as List? ?? const [])) {
      final m = (raw as Map).cast<String, dynamic>();
      final precio = (m['precio'] as num?)?.toInt() ?? 0;
      final cantidad = (m['cantidad'] as num?)?.toInt() ?? 0;
      items.add(PedidoStaffItem(
        productoId: m['productoId']?.toString() ?? '',
        nombre: m['nombre'] as String? ?? '',
        cantidad: cantidad,
        precio: precio,
        subtotal: precio * cantidad,
      ));
    }
    final mesaId = data['mesaId'] as String? ?? '';
    return PedidoStaff(
      id: doc.id,
      restauranteId: data['restauranteId'] as String? ?? '',
      mesaId: mesaId,
      sesionId: data['sesionId'] as String?,
      mesaNumero: mesaNumeroDeQr(mesaId),
      estado: estadoPedidoFromJson(data['estado'] as String? ?? 'enviado'),
      total: (data['total'] as num?)?.toInt() ?? 0,
      notas: data['notas'] as String?,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      items: items,
      usuarioNombre: data['clienteNombre'] as String? ?? '',
      solicitaCuenta: false,
      solicitadaEn: null,
    );
  }

  factory PedidoStaff.fromJson(Map<String, dynamic> json) =>
      _$PedidoStaffFromJson(json);
}

/// Una acción de avance de estado que la UI muestra como botón.
typedef AccionPedido = ({String label, EstadoPedido destino});

/// Roles que pueden aceptar/rechazar/preparar (TODO menos mesero — espejo
/// client-side de la matriz rol×transición de las rules, que son la
/// autoridad).
const _rolesCocina = {'cocina', 'admin_restaurante', 'super_admin'};

/// Extensión de presentación — botones según la matriz rol×transición.
/// Ocultar es UX: las rules re-validan la transición Y el rol sobre el
/// doc (doble barrera del threat model).
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
    EstadoPedido.enPreparacion => GriColors.pedidoEnPreparacion, // morado
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
