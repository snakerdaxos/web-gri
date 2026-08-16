import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'reserva.freezed.dart';

/// Reserva del restaurante — doc `reservas/{mesaId}_{yyyyMMdd}_{HH}`
/// (doc ID determinista: 1 por slot, Phase 10).
///
/// [fecha] es el Timestamp del slot; [mesaId] es el código QR de la mesa
/// (doc ID determinista) y [mesaNumero] se deriva de él (construcción
/// determinista del ID — paridad con pedidos). [estado]:
/// `pendiente | confirmada | cancelada` (cancelada terminal).
@freezed
abstract class Reserva with _$Reserva {
  const factory Reserva({
    required String id,

    /// Tenant de la reserva — TODA query filtra por el rid activo.
    @Default('') String restauranteId,

    /// Código QR de la mesa (doc ID determinista).
    required String mesaId,

    /// Derivado del sufijo numérico del [mesaId].
    required int mesaNumero,
    required DateTime fecha,
    required int numPersonas,
    required String estado,

    /// UID del cliente (solo identidad — el nombre vive denormalizado en
    /// pedidos; las reservas no lo llevan en v1).
    @Default('') String usuarioId,
  }) = _Reserva;

  /// Mapea el doc `reservas/{mesaId}_{fecha}_{hh}`.
  factory Reserva.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const <String, dynamic>{};
    final mesaId = data['mesaId'] as String? ?? '';
    final partes = mesaId.split('-');
    return Reserva(
      id: doc.id,
      restauranteId: data['restauranteId'] as String? ?? '',
      mesaId: mesaId,
      mesaNumero: int.tryParse(partes.isEmpty ? '' : partes.last) ?? 0,
      fecha: (data['fecha'] as Timestamp?)?.toDate() ?? DateTime.now(),
      numPersonas: (data['numPersonas'] as num?)?.toInt() ?? 0,
      estado: data['estado'] as String? ?? 'pendiente',
      usuarioId: data['usuarioId'] as String? ?? '',
    );
  }
}
