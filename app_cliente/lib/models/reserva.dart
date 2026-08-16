import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'reserva.freezed.dart';
part 'reserva.g.dart';

/// Estados de una reserva (espejo del enum backend `EstadoReserva`).
enum EstadoReserva { confirmada, cancelada, pendiente }

/// Parsea el string del doc (`estado: "confirmada"`) al enum.
/// Valores desconocidos (futuros) caen a [EstadoReserva.pendiente].
EstadoReserva estadoReservaFromJson(String? raw) => switch (raw) {
      'confirmada' => EstadoReserva.confirmada,
      'cancelada' => EstadoReserva.cancelada,
      _ => EstadoReserva.pendiente,
    };

/// Reserva del cliente — doc `reservas/{mesaId}_{yyyyMMdd}_{HH}` (doc ID
/// determinista: la unicidad mesa+slot vive en el ID, paridad del
/// UNIQUE(mesa,fecha,hora) de MySQL — MIGRA-06).
///
/// * [fecha] es el DateTime del slot (Timestamp en el doc) y [fechaStr]
///   "yyyy-MM-dd" para comparaciones lexicográficas (próximas/pasadas).
/// * [hora] es el int del slot (0..23, siempre :00).
/// * [restauranteNombre] NO vive en el doc: lo enriquece el provider
///   (join client-side con `restaurantes/{id}`).
///
/// `fromJson` heredado de la era REST — sin uso tras la migración.
@freezed
abstract class Reserva with _$Reserva {
  const factory Reserva({
    required String id,
    required String restauranteId,
    @Default('') String restauranteNombre,
    required String mesaId,
    required int mesaNumero,
    required String usuarioId,
    required DateTime fecha,
    required String fechaStr,
    required int hora,
    required int numPersonas,
    required String estado,
    DateTime? createdAt,
  }) = _Reserva;

  /// Mapea el doc `reservas/{mesaId}_{yyyyMMdd}_{HH}`.
  factory Reserva.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const <String, dynamic>{};
    return Reserva(
      id: doc.id,
      restauranteId: data['restauranteId'] as String? ?? '',
      restauranteNombre: data['restauranteNombre'] as String? ?? '',
      mesaId: data['mesaId'] as String? ?? '',
      mesaNumero: (data['mesaNumero'] as num?)?.toInt() ?? 0,
      usuarioId: data['usuarioId'] as String? ?? '',
      fecha: _dateTimeDe(data['fecha']),
      fechaStr: data['fechaStr'] as String? ?? '',
      hora: (data['hora'] as num?)?.toInt() ?? 0,
      numPersonas: (data['numPersonas'] as num?)?.toInt() ?? 0,
      estado: data['estado'] as String? ?? 'pendiente',
      createdAt: data['createdAt'] == null ? null : _dateTimeDe(data['createdAt']),
    );
  }

  factory Reserva.fromJson(Map<String, dynamic> json) =>
      _$ReservaFromJson(json);

  const Reserva._();

  EstadoReserva get estadoReserva => estadoReservaFromJson(estado);

  /// True si la reserva es de HOY o futura ([hoy] en formato "YYYY-MM-DD").
  /// La comparación lexicográfica es segura con fechas ISO.
  bool esProxima(String hoy) => fechaStr.compareTo(hoy) >= 0;

  /// "19:00" (display) — el slot siempre es :00.
  String get horaLabel => '${hora.toString().padLeft(2, '0')}:00';
}

/// Timestamp (Firestore real) → DateTime, tolerando DateTime/String
/// (fakes y seeds de test) — nunca la fuente de verdad del orden (para
/// eso está el `orderBy` server-side sobre el Timestamp).
DateTime _dateTimeDe(Object? raw) {
  if (raw is Timestamp) return raw.toDate();
  if (raw is DateTime) return raw;
  if (raw is String) return DateTime.parse(raw);
  throw ArgumentError.value(raw, 'fecha', 'tipo de fecha no soportado');
}
