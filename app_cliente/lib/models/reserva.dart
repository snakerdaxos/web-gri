import 'package:freezed_annotation/freezed_annotation.dart';

part 'reserva.freezed.dart';
part 'reserva.g.dart';

/// Estados de una reserva (espejo del enum backend `EstadoReserva`).
enum EstadoReserva { confirmada, cancelada, pendiente }

/// Parsea el string del wire (`estado: "confirmada"`) al enum.
/// Valores desconocidos (futuros) caen a [EstadoReserva.pendiente].
EstadoReserva estadoReservaFromJson(String? raw) => switch (raw) {
      'confirmada' => EstadoReserva.confirmada,
      'cancelada' => EstadoReserva.cancelada,
      _ => EstadoReserva.pendiente,
    };

/// Reserva del cliente (`ReservaRead` del backend) — `GET /cliente/reservas`,
/// `POST /cliente/reservas`, `POST /cliente/reservas/{id}/cancelar`.
///
/// [fecha] ("YYYY-MM-DD") y [horaInicio] ("HH:MM:SS") viajan como String a
/// propósito: el formato ISO-8601 ordena lexicográficamente, así que el
/// split próximas/pasadas es una comparación de strings contra el hoy local.
@freezed
abstract class Reserva with _$Reserva {
  const factory Reserva({
    required int id,
    @JsonKey(name: 'restaurante_id') required int restauranteId,
    @JsonKey(name: 'restaurante_nombre') required String restauranteNombre,
    @JsonKey(name: 'mesa_id') required int mesaId,
    @JsonKey(name: 'mesa_numero') required int mesaNumero,
    required String fecha,
    @JsonKey(name: 'hora_inicio') required String horaInicio,
    @JsonKey(name: 'num_personas') required int numPersonas,
    required String estado,
    @JsonKey(name: 'created_at') required String createdAt,
  }) = _Reserva;

  factory Reserva.fromJson(Map<String, dynamic> json) =>
      _$ReservaFromJson(json);

  const Reserva._();

  EstadoReserva get estadoReserva => estadoReservaFromJson(estado);

  /// True si la reserva es de HOY o futura ([hoy] en formato "YYYY-MM-DD").
  /// La comparación lexicográfica es segura con fechas ISO.
  bool esProxima(String hoy) => fecha.compareTo(hoy) >= 0;

  /// "19:00:00" → "19:00" (display).
  String get horaLabel => horaInicio.length >= 5
      ? horaInicio.substring(0, 5)
      : horaInicio;
}
