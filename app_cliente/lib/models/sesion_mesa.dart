import 'package:freezed_annotation/freezed_annotation.dart';

part 'sesion_mesa.freezed.dart';
part 'sesion_mesa.g.dart';

/// Sesión de mesa activa del cliente (`SesionRead` del backend) — nace del
/// QR escaneado (o del código manual) y vive hasta el pago (F9) o hasta que
/// staff pasa la mesa a limpieza (anti-zombi, 06-01).
///
/// `GET /cliente/sesiones/actual` · `POST /cliente/sesiones` ·
/// `POST /cliente/sesiones/actual/cuenta`.
@freezed
abstract class SesionMesa with _$SesionMesa {
  const factory SesionMesa({
    required int id,
    @JsonKey(name: 'restaurante_id') required int restauranteId,
    @JsonKey(name: 'restaurante_nombre') required String restauranteNombre,
    @JsonKey(name: 'mesa_id') required int mesaId,
    @JsonKey(name: 'mesa_numero') required int mesaNumero,
    @JsonKey(name: 'abierta_en') required DateTime abiertaEn,
    @JsonKey(name: 'solicita_cuenta') required bool solicitaCuenta,
    @JsonKey(name: 'solicitada_en') DateTime? solicitadaEn,
  }) = _SesionMesa;

  factory SesionMesa.fromJson(Map<String, dynamic> json) =>
      _$SesionMesaFromJson(json);
}
