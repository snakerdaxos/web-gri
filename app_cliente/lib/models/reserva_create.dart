import 'package:freezed_annotation/freezed_annotation.dart';

part 'reserva_create.freezed.dart';
part 'reserva_create.g.dart';

/// Body de `POST /cliente/reservas`.
///
/// El servidor asigna la mesa automáticamente (Phase 5 Concurrency Design
/// §3) — el cliente SOLO elige restaurante/fecha/hora/personas.
/// [fecha] = "YYYY-MM-DD", [horaInicio] = "HH:00:00" (slots hourly :00).
@freezed
abstract class ReservaCreate with _$ReservaCreate {
  const factory ReservaCreate({
    @JsonKey(name: 'restaurante_id') required int restauranteId,
    required String fecha,
    @JsonKey(name: 'hora_inicio') required String horaInicio,
    @JsonKey(name: 'num_personas') required int numPersonas,
  }) = _ReservaCreate;

  factory ReservaCreate.fromJson(Map<String, dynamic> json) =>
      _$ReservaCreateFromJson(json);
}
