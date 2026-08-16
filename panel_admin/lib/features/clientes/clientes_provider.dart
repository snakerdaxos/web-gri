import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/firebase_providers.dart';
import '../../models/cliente_resumen.dart';
import '../../models/pedido_staff.dart';
import '../dashboard/restaurante_provider.dart' show ridActivoProvider;

part 'clientes_provider.g.dart';

/// Clientes del restaurante (ADMN-03) — DERIVADOS de pedidos.
///
/// Las rules no permiten al staff leer `usuarios/` ajenos, así que la
/// lista se pliega desde pedidos: `pedidos where restauranteId == rid`
/// (equality-only: sin orderBy compuesto — los índices de campo simple
/// bastan y no exige un índice nuevo) + orden client-side por createdAt
/// DESC + fold distinct por `usuarioId` usando el `clienteNombre`
/// denormalizado de cada doc. Cero lecturas de `usuarios/`.
///
/// NOTA de coste (diseño planner): v1 demo = get + fold en cliente;
/// agregaciones formales server-side = fase futura.
///
/// rid null (super_admin sin selección) → `[]` (patrón mesasProvider).
@riverpod
Future<List<ClienteResumen>> clientes(Ref ref) async {
  final db = ref.watch(firestoreProvider);
  final rid = await ref.watch(ridActivoProvider.future);

  if (rid == null) return const <ClienteResumen>[];

  final snap = await db
      .collection('pedidos')
      .where('restauranteId', isEqualTo: rid)
      .get();

  final docs = snap.docs.toList()
    ..sort((a, b) {
      final fa = (a.data()['createdAt'] as Timestamp?)?.toDate();
      final fb = (b.data()['createdAt'] as Timestamp?)?.toDate();
      return (fb ?? DateTime(0)).compareTo(fa ?? DateTime(0)); // DESC
    });

  // Fold: primer pedido visto (el más reciente) fija nombre y último;
  // los siguientes acumulan nPedidos/totalConsumo.
  final acumulados = <String, _Acumulado>{};
  for (final doc in docs) {
    final d = doc.data();
    final uid = d['usuarioId'] as String? ?? '';
    if (uid.isEmpty) continue;
    final previo = acumulados[uid];
    acumulados[uid] = _Acumulado(
      clienteNombre: d['clienteNombre'] as String? ?? 'Cliente',
      nPedidos: (previo?.nPedidos ?? 0) + 1,
      totalConsumo:
          (previo?.totalConsumo ?? 0) + ((d['total'] as num?)?.toInt() ?? 0),
      ultimoPedido:
          previo?.ultimoPedido ?? (d['createdAt'] as Timestamp?)?.toDate(),
    );
  }

  // La iteración preserva el orden de inserción (DESC por primer visto).
  return [
    for (final e in acumulados.entries)
      ClienteResumen(
        usuarioId: e.key,
        clienteNombre: e.value.clienteNombre,
        nPedidos: e.value.nPedidos,
        totalConsumo: e.value.totalConsumo,
        ultimoPedido: e.value.ultimoPedido,
      ),
  ];
}

class _Acumulado {
  const _Acumulado({
    required this.clienteNombre,
    required this.nPedidos,
    required this.totalConsumo,
    this.ultimoPedido,
  });

  final String clienteNombre;
  final int nPedidos;
  final int totalConsumo;
  final DateTime? ultimoPedido;
}

/// Historial de pedidos de un cliente EN el tenant (family, ADMN-03).
///
/// `pedidos where restauranteId == rid where usuarioId == uid`
/// (dos igualdades: zigzag merge sobre índices simples, sin índice
/// compuesto) + orden DESC client-side por createdAt.
@riverpod
Future<List<PedidoStaff>> clienteHistorial(Ref ref, String usuarioId) async {
  final db = ref.watch(firestoreProvider);
  final rid = await ref.watch(ridActivoProvider.future);

  if (rid == null) return const <PedidoStaff>[];

  final snap = await db
      .collection('pedidos')
      .where('restauranteId', isEqualTo: rid)
      .where('usuarioId', isEqualTo: usuarioId)
      .get();

  final pedidos = [for (final doc in snap.docs) PedidoStaff.fromDoc(doc)]
    ..sort((a, b) => b.createdAt.compareTo(a.createdAt)); // DESC
  return pedidos;
}
