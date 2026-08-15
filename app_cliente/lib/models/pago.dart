import 'package:freezed_annotation/freezed_annotation.dart';

part 'pago.freezed.dart';
part 'pago.g.dart';

/// Intención de pago (`POST /cliente/pagos/intencion` — 09-01).
///
/// El [monto] se calcula SERVER-SIDE (Σ pedidos servido de la sesión) —
/// el body jamás lleva montos (threat: anti-fraude). [checkoutUrl] es
/// RELATIVA en sandbox (`/pagos/sandbox/{ref}`) → anteponer
/// `Env.apiBaseUrl`; absoluta ya en Wompi real (Web Checkout).
@freezed
abstract class PagoIntencion with _$PagoIntencion {
  const factory PagoIntencion({
    @JsonKey(name: 'pago_id') required int pagoId,
    required String referencia,
    required double monto,
    required String estado,
    @JsonKey(name: 'checkout_url') required String checkoutUrl,
  }) = _PagoIntencion;

  factory PagoIntencion.fromJson(Map<String, dynamic> json) =>
      _$PagoIntencionFromJson(json);
}

/// Estado del pago (`GET /cliente/pagos/{id}` — polling post-checkout).
///
/// [pedidoIds] alimenta el sheet de calificación post-pago: la sesión ya
/// está cerrada al aprobarse, así que estos ids son la ÚNICA forma de
/// saber qué calificar (Pitfall 6 del research 09).
@freezed
abstract class PagoEstado with _$PagoEstado {
  const factory PagoEstado({
    @JsonKey(name: 'pago_id') required int pagoId,
    required String estado,
    required String referencia,
    required double monto,
    @JsonKey(name: 'pedido_ids') required List<int> pedidoIds,
  }) = _PagoEstado;

  factory PagoEstado.fromJson(Map<String, dynamic> json) =>
      _$PagoEstadoFromJson(json);
}
