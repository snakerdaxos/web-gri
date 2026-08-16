import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'sesion_mesa.freezed.dart';
part 'sesion_mesa.g.dart';

/// Sesión de mesa — doc `sesiones/{mesaId}` (Phase 10, doc shapes del
/// research): el doc ID es determinista (= mesaId) lo que garantiza UNA
/// sesión por mesa (MIGRA-06). Nace del QR escaneado (o del código
/// manual) y la cierra el staff (mesa → limpieza) o expira.
///
/// [restauranteNombre] y [mesaNumero] NO viven en el doc: se enriquecen
/// client-side (join con `mesas/` y `restaurantes/`) para el banner.
@freezed
abstract class SesionMesa with _$SesionMesa {
  const factory SesionMesa({
    /// Doc ID (= mesaId = código QR de la mesa).
    required String id,
    required String restauranteId,
    required String mesaId,
    required String usuarioId,

    /// `activa | cerrada | expirada` (sesionTransitions de state_machines).
    @Default('activa') String estado,

    /// Flag "pedir la cuenta" — visible para el staff en vivo.
    @Default(false) bool cuentaSolicitada,
    DateTime? cuentaPedidaAt,
    DateTime? inicioAt,
    DateTime? cerradaAt,

    // ── Enriquecidos client-side (join) — NO se escriben al doc ─────────
    @Default('') String restauranteNombre,
    @Default(0) int mesaNumero,
  }) = _SesionMesa;

  /// Mapea el `DocumentSnapshot` de `sesiones/{mesaId}`.
  factory SesionMesa.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const <String, dynamic>{};
    return SesionMesa(
      id: doc.id,
      restauranteId: data['restauranteId'] as String? ?? '',
      mesaId: data['mesaId'] as String? ?? doc.id,
      usuarioId: data['usuarioId'] as String? ?? '',
      estado: data['estado'] as String? ?? 'activa',
      cuentaSolicitada: data['cuentaSolicitada'] as bool? ?? false,
      cuentaPedidaAt: (data['cuentaPedidaAt'] as Timestamp?)?.toDate(),
      inicioAt: (data['inicioAt'] as Timestamp?)?.toDate(),
      cerradaAt: (data['cerradaAt'] as Timestamp?)?.toDate(),
    );
  }

  /// `fromJson` heredado de la era REST — sin uso tras la migración; la
  /// vía canónica es [fromDoc].
  factory SesionMesa.fromJson(Map<String, dynamic> json) =>
      _$SesionMesaFromJson(json);
}
