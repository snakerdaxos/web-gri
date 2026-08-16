import 'package:freezed_annotation/freezed_annotation.dart';

part 'reserva_create.freezed.dart';
part 'reserva_create.g.dart';

/// DTO del wizard de reserva (Phase 10): lo que el cliente elige —
/// restaurante/fecha/hora/personas. La mesa la asigna `crearReserva`
/// (transacción determinista) — el cliente NUNCA elige mesa.
///
/// * [restauranteId] es el slug String del doc `restaurantes/{slug}`.
/// * [fecha] = "YYYY-MM-DD", [hora] = slot 0..23 (siempre :00).
///
/// SIN `fromDoc`: nunca se lee de Firestore. `fromJson`/`toJson`
/// heredados de la era REST — sin uso tras la migración.
@freezed
abstract class ReservaCreate with _$ReservaCreate {
  const factory ReservaCreate({
    required String restauranteId,
    required String fecha,
    required int hora,
    required int numPersonas,
  }) = _ReservaCreate;

  factory ReservaCreate.fromJson(Map<String, dynamic> json) =>
      _$ReservaCreateFromJson(json);
}
