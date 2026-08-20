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

/// Los pedidos YA SERVIDOS de la sesión abierta en [mesaId] — la cuenta que
/// el mesero tiene que cobrar (plan 11-32).
///
/// ── POR QUÉ ESTA FORMA DE CONSULTA Y NO OTRA ─────────────────────────
/// Lo natural sería `where('sesionId') + where('estado')`. No se puede, por
/// dos motivos independientes y los dos verificables sin desplegar:
///
///  1. RULES. Firestore evalúa las rules contra la CONSULTA, no contra los
///     documentos devueltos. La rama de staff de `/pedidos` es
///     `staffOf(resource.data.restauranteId)`, así que la query DEBE llevar
///     `where('restauranteId', isEqualTo: rid)` o se deniega ENTERA — el
///     mismo modo de fallo del menú (11-03) y del listener del cliente
///     (11-28). Lo vigila `scripts/audit_indexes.mjs` (AUDIT 2/4).
///  2. ÍNDICES. `pedidos(restauranteId, estado, createdAt ASC)` YA existe en
///     `firestore.indexes.json` (lo usa la cola de cocina). Con igualdad en
///     los dos primeros campos y RANGO en `createdAt`, ese mismo índice sirve
///     a esta consulta: 11-32 no necesita índice nuevo ni despliegue.
///
/// ── LA VENTANA `createdAt >= inicioAt` NO ES UNA OPTIMIZACIÓN ──────────
/// `sesiones/{mesaId}` tiene doc ID DETERMINISTA y `abrirSesion()` hace
/// `tx.set()` sobre el MISMO documento en cada visita. Los pedidos de la
/// visita anterior conservan su `sesionId`, así que sin acotar por el
/// `inicioAt` de la sesión VIGENTE el mesero le cobraría a este comensal la
/// cena del anterior. Además acota lo que se lee: sin ella la consulta
/// crecería con todo el histórico de pedidos servidos del restaurante.
///
/// Si no hay doc de sesión (o no trae `inicioAt`) se cae a una ventana de 24
/// horas: la FORMA de la consulta no cambia nunca — el audit estático la
/// parsea siempre igual y el índice sirve en los dos casos.
///
/// El filtro final por `sesionId` es client-side a propósito: añadirlo a la
/// query obligaría a un índice nuevo y el conjunto que llega ya está acotado
/// al restaurante y a la ventana de la sesión.
@riverpod
Stream<List<PedidoStaff>> pedidosServidosMesa(Ref ref, String mesaId) async* {
  final db = ref.watch(firestoreProvider);
  final rid = await ref.watch(ridActivoProvider.future);

  if (rid == null) {
    yield const <PedidoStaff>[];
    return;
  }

  final sesionSnap = await db.doc('sesiones/$mesaId').get();
  final inicio = (sesionSnap.data()?['inicioAt'] as Timestamp?)?.toDate() ??
      DateTime.now().subtract(const Duration(hours: 24));

  yield* db
      .collection('pedidos')
      .where('restauranteId', isEqualTo: rid)
      .where('estado', isEqualTo: 'servido')
      .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(inicio))
      .snapshots()
      .map((snap) => [
            for (final doc in snap.docs)
              if (doc.data()['sesionId'] == mesaId) PedidoStaff.fromDoc(doc),
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

/// Entrega la cuenta de una mesa (PAGO-04 manual — el checkout en línea
/// quedó diferido v1): en UNA transacción cierra la sesión
/// `sesiones/{mesaId}` (activa→cerrada) y pasa la MESA ocupada→limpieza.
///
/// * Cierra el ciclo del aviso: al commitear, `avisoCuenta` deja de ver la
///   sesión (filtra por `estado == 'activa'`) y el badge desaparece SOLO.
/// * Habilita la calificación del cliente (su tx exige sesión cerrada) y
///   su stream del doc refleja el cierre EN VIVO.
/// * Escrituras de SOLO `{estado, updatedAt}` — `soloEstado()` de las
///   rules; `validarTransicion` client-side ANTES de escribir y las rules
///   re-fuerzan staff+transición por doc (doble barrera, la autoridad).
/// * La mesa solo se mueve si está 'ocupada' (una sesión activa con mesa
///   en otro estado no bloquea el cierre de la sesión).
Future<void> entregarCuenta(
  FirebaseFirestore db, {
  required String mesaId,
}) async {
  await db.runTransaction((tx) async {
    // TODOS los gets antes de TODOS los writes (requisito de las tx de
    // Firestore — mismo patrón que abrirSesion/crearPedido del cliente).
    final sesionSnap = await tx.get(db.doc('sesiones/$mesaId'));
    final mesaSnap = await tx.get(db.doc('mesas/$mesaId'));

    if (!sesionSnap.exists || sesionSnap.data()?['estado'] != 'activa') {
      throw StateError('La sesión de la mesa ya no está activa');
    }
    validarTransicion('sesion_mesa', 'activa', 'cerrada');
    tx.update(db.doc('sesiones/$mesaId'), <String, dynamic>{
      'estado': 'cerrada',
      'updatedAt': FieldValue.serverTimestamp(),
    });

    if (mesaSnap.data()?['estado'] == 'ocupada') {
      validarTransicion('mesa', 'ocupada', 'limpieza');
      tx.update(db.doc('mesas/$mesaId'), <String, dynamic>{
        'estado': 'limpieza',
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }
  });
}
