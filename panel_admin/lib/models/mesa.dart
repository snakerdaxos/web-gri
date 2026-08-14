import 'package:freezed_annotation/freezed_annotation.dart';

part 'mesa.freezed.dart';
part 'mesa.g.dart';

/// Estados del ciclo de vida de una mesa (espejo del enum backend
/// `app.models.mesa.EstadoMesa`).
enum EstadoMesa { disponible, ocupada, reservada, limpieza }

/// Traduce el string del backend ("disponible" | "ocupada" | "reservada" |
/// "limpieza") al enum — switch exhaustivo, valor desconocido explota temprano.
EstadoMesa estadoMesaFromJson(String raw) => switch (raw) {
      'disponible' => EstadoMesa.disponible,
      'ocupada' => EstadoMesa.ocupada,
      'reservada' => EstadoMesa.reservada,
      'limpieza' => EstadoMesa.limpieza,
      _ => throw ArgumentError('EstadoMesa desconocido: $raw'),
    };

/// Mesa física (`GET /staff/mesas`, ADMN-02).
@freezed
abstract class Mesa with _$Mesa {
  const factory Mesa({
    required int id,
    required int numero,
    required int capacidad,
    @JsonKey(name: 'codigo_qr') required String codigoQr,
    @JsonKey(fromJson: estadoMesaFromJson) required EstadoMesa estado,
  }) = _Mesa;

  factory Mesa.fromJson(Map<String, dynamic> json) => _$MesaFromJson(json);
}
