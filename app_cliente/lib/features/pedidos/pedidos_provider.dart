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
  throw UnimplementedError();
}

/// Solicita la cuenta — flag visible para el staff en VIVO (la pantalla de
/// pedidos y el banner lo reflejan por el stream del doc de sesión).
/// Idempotente: repetir el update escribe los mismos valores.
/// Solo el dueño de la sesión activa (guard UX; rules re-validan).
Future<void> solicitarCuenta(
  FirebaseFirestore db, {
  required String uid,
  required String mesaId,
}) {
  throw UnimplementedError();
}

/// Pedidos de la sesión activa EN VIVO (MIGRA-05): `where('sesionId') +
/// orderBy('createdAt') + snapshots()` — sustituye WS + polling + refetch
/// de la era REST (Phase 7). Sin sesión → stream vacío.
///
/// El orden DESC se materializa client-side (`reversed`) — el índice
/// compuesto definido en 10-01 es pedidos/sesionId+createdAt ASC (mismo
/// patrón documentado en 10-03: server-side solo lo que tiene índice).
@riverpod
Stream<List<Pedido>> pedidosSession(Ref ref) async* {
  final sesion = ref.watch(sesionActualProvider).value;
  if (sesion == null) {
    yield* const Stream<List<Pedido>>.empty();
    return;
  }

  final db = ref.watch(firestoreProvider);

  yield* db
      .collection('pedidos')
      .where('sesionId', isEqualTo: sesion.mesaId)
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
