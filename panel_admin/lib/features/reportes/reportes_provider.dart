import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/firebase_providers.dart';
import '../../models/reporte.dart';
import '../dashboard/restaurante_provider.dart' show ridActivoProvider;

part 'reportes_provider.g.dart';

/// Reporte de ventas del rango [desde, hasta] (REPO-01/02, 10-06):
/// family por rango — la pantalla consulta on-demand con las fechas de
/// los pickers.
///
/// Query (índice 10-01 restauranteId+estado+createdAt la cubre):
/// `pedidos where restauranteId == rid where estado == 'servido' where
/// createdAt >= desde && createdAt <= hasta → get()` y FOLD en cliente:
///  * totalVentas = Σ total (int COP).
///  * numeroPedidos = count.
///  * topPlatos = map nombre→(Σ cantidad, Σ precio×cantidad) desde el
///    snapshot de items, ordenado por cantidad DESC (top 10).
///
/// Threat model: venta = `servido` únicamente; montos client-side =
/// display hasta Functions (fase pagos). rid null (super sin selección)
/// → reporte en cero.
@riverpod
Future<Reporte> reporte(Ref ref, DateTime desde, DateTime hasta) async {
  final db = ref.watch(firestoreProvider);
  final rid = await ref.watch(ridActivoProvider.future);

  if (rid == null) {
    return const Reporte(totalVentas: 0, numeroPedidos: 0);
  }

  final snap = await db
      .collection('pedidos')
      .where('restauranteId', isEqualTo: rid)
      .where('estado', isEqualTo: 'servido')
      .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(desde))
      .where('createdAt', isLessThanOrEqualTo: Timestamp.fromDate(hasta))
      .get();

  var totalVentas = 0;
  final porPlato = <String, _AcumuladoPlato>{};

  for (final doc in snap.docs) {
    final data = doc.data();
    totalVentas += (data['total'] as num?)?.toInt() ?? 0;
    for (final raw in (data['items'] as List? ?? const [])) {
      final item = (raw as Map).cast<String, dynamic>();
      final nombre = item['nombre'] as String? ?? '';
      if (nombre.isEmpty) continue;
      final cantidad = (item['cantidad'] as num?)?.toInt() ?? 0;
      final precio = (item['precio'] as num?)?.toInt() ?? 0;
      final previo = porPlato[nombre];
      porPlato[nombre] = _AcumuladoPlato(
        cantidad: (previo?.cantidad ?? 0) + cantidad,
        venta: (previo?.venta ?? 0) + precio * cantidad,
      );
    }
  }

  final topPlatos = [
    for (final e in porPlato.entries)
      TopPlato(nombre: e.key, cantidad: e.value.cantidad, venta: e.value.venta),
  ]..sort((a, b) {
      // Cantidad DESC; desempate por venta DESC.
      final porCantidad = b.cantidad.compareTo(a.cantidad);
      if (porCantidad != 0) return porCantidad;
      return b.venta.compareTo(a.venta);
    });

  return Reporte(
    totalVentas: totalVentas,
    numeroPedidos: snap.size,
    topPlatos: topPlatos.take(10).toList(),
  );
}

class _AcumuladoPlato {
  const _AcumuladoPlato({required this.cantidad, required this.venta});

  final int cantidad;
  final int venta;
}
