import 'package:freezed_annotation/freezed_annotation.dart';

part 'reserva.freezed.dart';
part 'reserva.g.dart';

/// Reserva (`GET /staff/reservas?fecha=`, endpoint F5 existente — RESV-05).
///
/// Shape `ReservaRead` con joins display: [restauranteNombre] y [mesaNumero]
/// vienen del JOIN server-side. [estado]: `confirmada` | `pendiente` |
/// `cancelada` (la lista incluye canceladas — el campo discrimina).
/// [fecha] `YYYY-MM-DD`; [horaInicio] `HH:MM:SS`.
@freezed
abstract class Reserva with _$Reserva {
  const factory Reserva({
    required int id,
    @JsonKey(name: 'restaurante_nombre') required String restauranteNombre,
    @JsonKey(name: 'mesa_id') required int mesaId,
    @JsonKey(name: 'mesa_numero') required int mesaNumero,
    required String fecha,
    @JsonKey(name: 'hora_inicio') required String horaInicio,
    @JsonKey(name: 'num_personas') required int numPersonas,
    required String estado,
  }) = _Reserva;

  factory Reserva.fromJson(Map<String, dynamic> json) =>
      _$ReservaFromJson(json);
}
