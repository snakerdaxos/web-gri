import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/firebase_providers.dart';
import '../../core/tx_mutex.dart';
import '../../models/pedido.dart';
import '../../models/pedido_item.dart';
import '../sesion_qr/sesion_provider.dart';
import 'carrito_controller.dart';

part 'pedidos_provider.g.dart';

/// Error de dominio de pedidos con mensaje user-friendly directo
/// (contrato de la UI — mismo rol que el `detail` de la era REST).
class PedidoException implements Exception {
  const PedidoException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Crea el pedido de la sesión — `runTransaction` (MIGRA-06, anti-spoofing
/// Phase 6):
///
/// 1. `tx.get(sesiones/{mesaId})` — debe existir, estar 'activa' y ser del
///    emisor (`usuarioId == uid`); si no → error controlado SIN doc creado.
/// 2. `tx.get(mesas/{codigo})` — restauranteId de la mesa.
/// 3. [items] llegan ARMADOS con snapshot de nombre/precio (congelados al
///    armar el carrito); `total` = Σ precio×cantidad (`int` COP).
/// 4. `tx.set(pedidos.doc(), {estado 'enviado', ...})` — autoId para
///    pedidos (la unicidad vive en la sesión, no en el pedido).
///
/// El mutex en-proceso serializa doble-taps; en Firestore real el OCC de
/// la tx serializa writers entre dispositivos.
Future<String> crearPedido(
  FirebaseFirestore db, {
  required String uid,
  required String mesaCodigo,
  required List<PedidoItem> items,
  String clienteNombre = '',
}) {
  if (items.isEmpty) {
    // UX anticipa la regla (items 1..50) — sin vuelo a Firestore.
    return Future.error(const PedidoException('Tu carrito está vacío'));
  }
  return seccionCritica(
    () => _crearPedido(db, uid: uid, mesaCodigo: mesaCodigo, items: items,
        clienteNombre: clienteNombre),
  );
}

Future<String> _crearPedido(
  FirebaseFirestore db, {
  required String uid,
  required String mesaCodigo,
  required List<PedidoItem> items,
  String clienteNombre = '',
}) {
  return db.runTransaction<String>((tx) async {
    // 1) La sesión debe estar ACTIVA y ser del emisor (anti-spoofing P6).
    //    Sin diferenciar el motivo exacto al usuario: mismo mensaje neutro.
    final sesionSnap = await tx.get(db.doc('sesiones/$mesaCodigo'));
    final sesionData = sesionSnap.data();
    if (!sesionSnap.exists ||
        sesionData == null ||
        sesionData['usuarioId'] != uid) {
      throw const PedidoException(
          'No pudimos enviar el pedido: tu sesión en la mesa no está activa');
    }
    if (sesionData['estado'] != 'activa') {
      throw const PedidoException(
          'La sesión de la mesa fue cerrada — pide al mesero reabrir la mesa');
    }

    // 2) restauranteId de la mesa (consistencia con la sesión).
    final mesaSnap = await tx.get(db.doc('mesas/$mesaCodigo'));
    final restauranteId =
        mesaSnap.data()?['restauranteId'] as String? ?? sesionData['restauranteId'] as String? ?? '';

    // 3) Total = Σ precio×cantidad del MISMO snapshot que viaja en el doc.
    final total =
        items.fold<int>(0, (suma, item) => suma + item.precio * item.cantidad);

    // 4) autoId para pedidos — la unicidad del dominio vive en la sesión.
    final ref = db.collection('pedidos').doc();
    tx.set(ref, <String, dynamic>{
      'restauranteId': restauranteId,
      'mesaId': mesaCodigo,
      'sesionId': mesaCodigo,
      'usuarioId': uid,
      'clienteNombre': clienteNombre,
      'estado': 'enviado',
      'items': [
        for (final item in items)
          <String, dynamic>{
            'productoId': item.productoId,
            'nombre': item.nombre,
            'precio': item.precio,
            'cantidad': item.cantidad,
          },
      ],
      'total': total,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    return ref.id;
  });
}

/// Solicita la cuenta — flag visible para el staff en VIVO (la pantalla de
/// pedidos y el banner lo reflejan por el stream del doc de sesión).
/// Idempotente: repetir el update escribe los mismos valores.
/// Solo el dueño de la sesión activa (guard UX; rules re-validan).
Future<void> solicitarCuenta(
  FirebaseFirestore db, {
  required String uid,
  required String mesaId,
}) async {
  final snap = await db.doc('sesiones/$mesaId').get();
  final data = snap.data();
  if (!snap.exists || data == null || data['usuarioId'] != uid) {
    throw const PedidoException(
        'No pudimos solicitar la cuenta: tu sesión en la mesa no está activa');
  }
  if (data['estado'] != 'activa') {
    throw const PedidoException('La sesión de la mesa fue cerrada');
  }
  await db.doc('sesiones/$mesaId').update(<String, dynamic>{
    'cuentaSolicitada': true,
    'cuentaPedidaAt': FieldValue.serverTimestamp(),
  });
}

/// Pedidos de la sesión activa EN VIVO (MIGRA-05): `where('sesionId') +
/// where('usuarioId') + orderBy('createdAt') + snapshots()` — sustituye WS +
/// polling + refetch de la era REST (Phase 7). Sin sesión → stream vacío.
///
/// El orden DESC se materializa client-side (`reversed`) — el índice
/// compuesto es pedidos/sesionId+usuarioId+createdAt ASC (11-28).
///
/// ── POR QUÉ ESTÁ EL `where('usuarioId')` (11-28 — P0 en producción) ────────
///
/// 1) SIN ÉL LA QUERY SE DENIEGA ENTERA. La regla de lectura de `pedidos`
///    concede al cliente sus PROPIOS pedidos (`resource.data.usuarioId ==
///    request.auth.uid`), y Firestore evalúa las rules contra la CONSULTA, no
///    contra los documentos devueltos: una query que no restringe `usuarioId`
///    no es demostrable y el backend responde `permission-denied` con
///    «Property usuarioId is undefined on object. for 'list'». Ese es el
///    origen literal de la pantalla en blanco tras enviar el primer pedido: la
///    caché local pintaba el pedido recién escrito y el rechazo del listener
///    la vaciaba un instante después. Mismo modo de fallo que el menú (11-03).
///
/// 2) ADEMÁS ES UN ARREGLO DE CORRECCIÓN, no solo de permisos. El `sesionId`
///    es el `mesaId` y el doc `sesiones/{mesaId}` se REUTILIZA: `abrirSesion()`
///    hace `tx.set()` sobre el mismo id cuando la sesión anterior está cerrada
///    (sesion_provider.dart). Sin filtrar por usuario, el siguiente comensal de
///    esa mesa vería en su pantalla los pedidos del comensal anterior.
///
/// NO CAMBIA LO QUE VE EL DUEÑO DE LA SESIÓN: las rules de `create` exigen que
/// el pedido lo emita el dueño de la sesión (`get(sesiones/…).usuarioId ==
/// request.auth.uid`), así que todo pedido de SU sesión ya lleva SU uid.
@riverpod
Stream<List<Pedido>> pedidosSession(Ref ref) async* {
  final sesion = ref.watch(sesionActualProvider).value;
  // El uid sale de Auth, no del doc de sesión: la regla compara contra
  // `request.auth.uid` y la query debe llevar EXACTAMENTE ese valor.
  final uid = ref.watch(firebaseAuthProvider).currentUser?.uid;
  if (sesion == null || uid == null) {
    yield* const Stream<List<Pedido>>.empty();
    return;
  }

  final db = ref.watch(firestoreProvider);

  yield* db
      .collection('pedidos')
      .where('sesionId', isEqualTo: sesion.mesaId)
      .where('usuarioId', isEqualTo: uid)
      .orderBy('createdAt')
      .snapshots()
      .map((snap) => [
            for (final doc in snap.docs) Pedido.fromDoc(doc),
          ].reversed.toList());
}

/// Mutaciones de pedidos: [enviar] arma los items desde el carrito
/// (snapshot) y pasa por [crearPedido]; limpia el carrito al éxito.
@riverpod
class PedidosController extends _$PedidosController {
  @override
  FutureOr<void> build() {}

  Future<String> enviar() async {
    final cart = ref.read(carritoProvider);
    if (cart.isEmpty) {
      throw const PedidoException('Tu carrito está vacío');
    }
    final auth = ref.read(firebaseAuthProvider);
    final uid = auth.currentUser?.uid;
    if (uid == null) {
      throw const PedidoException('Debes iniciar sesión para pedir');
    }
    final sesion = ref.read(sesionActualProvider).value;
    if (sesion == null || sesion.estado != 'activa') {
      throw const PedidoException(
          'Escanea el QR de la mesa para hacer tu pedido');
    }

    state = const AsyncLoading<void>();
    try {
      final id = await crearPedido(
        ref.read(firestoreProvider),
        uid: uid,
        mesaCodigo: sesion.mesaId,
        items: [
          for (final linea in cart.values) linea.toPedidoItem(),
        ],
        clienteNombre: auth.currentUser?.displayName ?? '',
      );
      ref.read(carritoProvider.notifier).limpiar();
      return id;
    } finally {
      state = const AsyncData<void>(null);
    }
  }
}
