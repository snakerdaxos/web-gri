import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/firebase_providers.dart';
import '../../core/state_machines.dart';
import '../../models/pedido_staff.dart';
import '../dashboard/restaurante_provider.dart';

part 'pedidos_staff_provider.g.dart';

/// Aviso de cuenta en vivo: sesión ACTIVA con `cuentaSolicitada == true`
/// (PAGO-01 — sustituye el badge del WS de la era REST).
typedef AvisoCuenta = ({String mesaId, int mesaNumero});

/// Cola de cocina EN VIVO (MIGRA-05): `pedidos where restauranteId == rid
/// where estado in [enviado, aceptado, en_preparacion] orderBy createdAt
/// ASC → snapshots()` (índice compuesto 10-01). Un pedido que pasa a
/// `servido`/`rechazado` desaparece del stream SOLO — sin invalidate ni
/// refetch (el server es la fuente de verdad).
///
/// El rid viene de [ridActivoProvider] (claims/selección — nunca input
/// libre; Pitfall 4). Watches ANTES del primer await (lección 07-03).
@riverpod
Stream<List<PedidoStaff>> pedidosStaff(Ref ref) async* {
  final db = ref.watch(firestoreProvider);
  final rid = await ref.watch(ridActivoProvider.future);

  if (rid == null) {
    yield const <PedidoStaff>[];
    return;
  }

  yield* db
      .collection('pedidos')
      .where('restauranteId', isEqualTo: rid)
      .where(
        'estado',
        whereIn: const ['enviado', 'aceptado', 'en_preparacion'],
      )
      .orderBy('createdAt')
      .snapshots()
      .map((snap) => [for (final doc in snap.docs) PedidoStaff.fromDoc(doc)]);
}

/// Avisos de cuenta EN VIVO para el badge de cocina: `sesiones where
/// restauranteId == rid where cuentaSolicitada == true where estado ==
/// 'activa' → snapshots()`. Cuando el mesero entrega la cuenta la sesión
/// pasa a `cerrada` y el aviso desaparece solo.
@riverpod
Stream<List<AvisoCuenta>> avisoCuenta(Ref ref) async* {
  final db = ref.watch(firestoreProvider);
  final rid = await ref.watch(ridActivoProvider.future);

  if (rid == null) {
    yield const <AvisoCuenta>[];
    return;
  }

  yield* db
      .collection('sesiones')
      .where('restauranteId', isEqualTo: rid)
      .where('cuentaSolicitada', isEqualTo: true)
      .where('estado', isEqualTo: 'activa')
      .snapshots()
      .map((snap) => [
            for (final doc in snap.docs)
              (
                mesaId: doc.data()['mesaId'] as String? ?? doc.id,
                mesaNumero: mesaNumeroDeQr(
                  doc.data()['mesaId'] as String? ?? doc.id,
                ),
              ),
          ]);
}

/// Matriz rol×transición de pedidos (espejo client-side de las rules 10-01
/// — la autoridad). `enviado→aceptado|rechazado` y
/// `aceptado→en_preparacion`: cocina/admin/super; `en_preparacion→
/// servido`: además mesero. `pagado` es inalcanzable desde el panel (v1).
const Map<(String, String), Set<String>> matrizRolPedido = {
  ('enviado', 'aceptado'): {'cocina', 'admin_restaurante', 'super_admin'},
  ('enviado', 'rechazado'): {'cocina', 'admin_restaurante', 'super_admin'},
  ('aceptado', 'en_preparacion'): {
    'cocina',
    'admin_restaurante',
    'super_admin',
  },
  ('en_preparacion', 'servido'): {
    'cocina',
    'admin_restaurante',
    'mesero',
    'super_admin',
  },
};

/// Avance de estado de un pedido — doble barrera ANTES del update:
///
/// 1. [validarTransicion] de la máquina `pedido`: un salto (p.ej.
///    enviado→servido) lanza [TransicionInvalidaException] SIN escribir.
/// 2. [matrizRolPedido]: el rol que no puede hacer esa transición recibe
///    `StateError('Tu rol no puede hacer esta acción')` SIN escribir.
/// 3. Update de SOLO `{estado, updatedAt}` — las rules re-validan
///    transición Y rol sobre el doc (la autoridad final).
Future<void> avanzarPedidoStaff(
  FirebaseFirestore db, {
  required String rol,
  required PedidoStaff pedido,
  required EstadoPedido destino,
}) async {
  final actual = estadoPedidoToJson(pedido.estado);
  final nueva = estadoPedidoToJson(destino);

  // 1) Máquina de estados (salto inválido → TransicionInvalidaException).
  validarTransicion('pedido', actual, nueva);

  // 2) Matriz rol×transición (espejo de las rules).
  final roles = matrizRolPedido[(actual, nueva)];
  if (roles == null || !roles.contains(rol)) {
    throw StateError('Tu rol no puede hacer esta acción');
  }

  // 3) Update mínimo.
  await db.doc('pedidos/${pedido.id}').update(<String, dynamic>{
    'estado': nueva,
    'updatedAt': FieldValue.serverTimestamp(),
  });
}
