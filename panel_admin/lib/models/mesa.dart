import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'mesa.freezed.dart';
part 'mesa.g.dart';

/// Estados del ciclo de vida de una mesa (espejo del enum backend
/// `app.models.mesa.EstadoMesa` — Firestore guarda los mismos strings).
enum EstadoMesa { disponible, ocupada, reservada, limpieza }

/// Traduce el string del doc (`estado: "disponible" | ...`) al enum —
/// switch exhaustivo, valor desconocido explota temprano.
EstadoMesa estadoMesaFromJson(String raw) => switch (raw) {
      'disponible' => EstadoMesa.disponible,
      'ocupada' => EstadoMesa.ocupada,
      'reservada' => EstadoMesa.reservada,
      'limpieza' => EstadoMesa.limpieza,
      _ => throw ArgumentError('EstadoMesa desconocido: $raw'),
    };

/// Mesa física — doc `mesas/{codigoQR}` (Phase 10, doc shapes research):
/// el doc ID es determinista (= código QR de la mesa), garantizando QR
/// UNIQUE por construcción (O(1) al escanear).
///
/// Phase 10-05: [id] pasa a ser el código QR (String, doc ID) y se agregan
/// [restauranteId]/[updatedAt]. El getter [codigoQr] preserva la superficie
/// legacy (qr_dialog) hasta el purge 10-06. `fromJson` heredado de la era
/// REST — sin uso en runtime; la vía canónica es [fromDoc].
@freezed
abstract class Mesa with _$Mesa {
  const factory Mesa({
    /// Doc ID = código QR (ej. `GRI-MESA-demo-001`).
    required String id,

    /// Tenant de la mesa — TODA query del panel filtra por el rid de claims.
    @Default('') String restauranteId,
    required int numero,
    required int capacidad,
    @JsonKey(fromJson: estadoMesaFromJson) required EstadoMesa estado,
    DateTime? updatedAt,
  }) = _Mesa;

  /// Mapea el doc `mesas/{codigoQR}`.
  factory Mesa.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const <String, dynamic>{};
    return Mesa(
      id: doc.id,
      restauranteId: data['restauranteId'] as String? ?? '',
      numero: (data['numero'] as num?)?.toInt() ?? 0,
      capacidad: (data['capacidad'] as num?)?.toInt() ?? 0,
      estado: estadoMesaFromJson(data['estado'] as String? ?? 'disponible'),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
    );
  }

  factory Mesa.fromJson(Map<String, dynamic> json) => _$MesaFromJson(json);

  const Mesa._();

  /// Compat legacy: el QR ES el id del doc.
  String get codigoQr => id;
}
