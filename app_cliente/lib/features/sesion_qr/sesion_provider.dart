import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/firebase_providers.dart';
import '../../core/state_machines.dart';
import '../../core/tx_mutex.dart';
import '../../models/sesion_mesa.dart';

part 'sesion_provider.g.dart';

/// Error de dominio de sesión con mensaje user-friendly directo
/// (contrato de la UI — mismo rol que el `detail` de la era REST).
class SesionException implements Exception {
  const SesionException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Abre sesión en la mesa por su código QR — `runTransaction` sobre
/// `sesiones/{mesaId}` con doc ID determinista (UNA sesión activa por
/// mesa, MIGRA-06):
///
/// 1. `tx.get(mesas/{codigoQR})` — si no existe → 'Código de mesa inválido'.
/// 2. `tx.get(sesiones/{mesaId})` — existe con estado 'activa' → 'Mesa
///    ocupada' (sesión ajena o propia: no se re-entra por el scanner).
/// 3. `validarTransicion('mesa', actual → ocupada)` — acepta desde
///    disponible|reservada; limpieza lanza [TransicionInvalidaException].
/// 4. `tx.set(sesiones/{mesaId}, {...estado 'activa'})` + `tx.update(mesa,
///    estado 'ocupada')`.
///
/// Contendientes concurrentes se serializan (mutex en-proceso + OCC real):
/// uno gana, el otro lee la sesión ya activa → 'Mesa ocupada'.
Future<SesionMesa> abrirSesion(
  FirebaseFirestore db, {
  required String uid,
  required String codigoQR,
}) {
  return seccionCritica(
    () => _abrirSesion(db, uid: uid, codigoQR: codigoQR),
  );
}

Future<SesionMesa> _abrirSesion(
  FirebaseFirestore db, {
  required String uid,
  required String codigoQR,
}) {
  return db.runTransaction<SesionMesa>((tx) async {
    // 1) La mesa debe existir — el código QR ES el doc ID (get O(1)).
    final mesaRef = db.doc('mesas/$codigoQR');
    final mesaSnap = await tx.get(mesaRef);
    if (!mesaSnap.exists) {
      throw const SesionException('Código de mesa inválido');
    }
    final mesaData = mesaSnap.data()!;
    final mesaEstado = mesaData['estado'] as String? ?? 'disponible';

    // 2) UNA sesión activa por mesa (doc ID determinista): si existe y está
    //    activa — sea de quien sea — esta apertura pierde (MIGRA-06).
    final sesionRef = db.doc('sesiones/$codigoQR');
    final sesionSnap = await tx.get(sesionRef);
    if (sesionSnap.exists && sesionSnap.data()?['estado'] == 'activa') {
      throw const SesionException('Mesa ocupada');
    }

    // 3) Máquina de estados: disponible|reservada → ocupada; limpieza y
    //    terminales lanzan TransicionInvalidaException (el controller la
    //    traduce a mensaje controlado).
    validarTransicion('mesa', mesaEstado, 'ocupada');

    // 4) set (no update): una sesión cerrada/expirada previa se REEMPLAZA
    //    por la nueva sesión limpia (cuentaSolicitada false).
    tx.set(sesionRef, <String, dynamic>{
      'restauranteId': mesaData['restauranteId'] as String? ?? '',
      'mesaId': codigoQR,
      'usuarioId': uid,
      'estado': 'activa',
      'cuentaSolicitada': false,
      'inicioAt': FieldValue.serverTimestamp(),
    });
    tx.update(mesaRef, <String, dynamic>{
      'estado': 'ocupada',
      'updatedAt': FieldValue.serverTimestamp(),
    });

    // Retorno YA enriquecido con el numero leído en la misma tx (el
    // banner/menu lo muestran al instante, sin segunda lectura).
    return SesionMesa(
      id: codigoQR,
      restauranteId: mesaData['restauranteId'] as String? ?? '',
      mesaId: codigoQR,
      usuarioId: uid,
      estado: 'activa',
      cuentaSolicitada: false,
      mesaNumero: (mesaData['numero'] as num?)?.toInt() ?? 0,
    );
  });
}

/// Enriquece la sesión con `mesaNumero` y `restauranteNombre` (join
/// client-side — NO viven en el doc de sesión). Caché corto-circuito:
/// si ya viene enriquecida (p.ej. del retorno de [abrirSesion] con el
/// numero leído en la tx) solo completa lo que falte.
Future<SesionMesa> _enriquecer(FirebaseFirestore db, SesionMesa s) async {
  var resultado = s;
  if (resultado.mesaNumero == 0) {
    final mesaSnap = await db.doc('mesas/${s.mesaId}').get();
    resultado = resultado.copyWith(
      mesaNumero: (mesaSnap.data()?['numero'] as num?)?.toInt() ?? 0,
    );
  }
  if (resultado.restauranteNombre.isEmpty) {
    final restSnap = await db.doc('restaurantes/${s.restauranteId}').get();
    resultado = resultado.copyWith(
      restauranteNombre: restSnap.data()?['nombre'] as String? ?? '',
    );
  }
  return resultado;
}

/// Stream del doc `sesiones/{mesaId}` (banner vivo): refleja
/// `cuentaSolicitada`, cambios de estado del staff y el cierre de sesión
/// — detección de cierre → la UI trata estado != 'activa' como fin de la
/// sesión (mismo rol que el evento `sesion.cerrada` del WS de Phase 7).
@riverpod
Stream<SesionMesa> sesion(Ref ref, String mesaId) {
  final db = ref.watch(firestoreProvider);
  return db
      .doc('sesiones/$mesaId')
      .snapshots()
      .asyncMap((snap) => _enriquecer(db, SesionMesa.fromDoc(snap)));
}

/// Sesión activa del usuario autenticado (o null) — query realtime
/// `sesiones where usuarioId == uid` + filtro de estado client-side.
/// keepAlive: el banner de home / menú / pedidos la observan a través de
/// la navegación. Al cerrar sesión el stream emite null (banner fuera).
@Riverpod(keepAlive: true)
Stream<SesionMesa?> sesionActual(Ref ref) {
  final db = ref.watch(firestoreProvider);
  final auth = ref.watch(firebaseAuthProvider);
  return auth.authStateChanges().asyncExpand((user) {
    if (user == null) return Stream.value(null);
    return db
        .collection('sesiones')
        .where('usuarioId', isEqualTo: user.uid)
        .snapshots()
        .asyncMap((snap) async {
      final doc = snap.docs
          .where((d) => d.data()['estado'] == 'activa')
          .firstOrNull;
      if (doc == null) return null;
      return _enriquecer(db, SesionMesa.fromDoc(doc));
    });
  });
}

/// Mutaciones de la sesión: [abrir] por código QR (cámara o input manual).
///
/// Los errores de dominio ('Código de mesa inválido' / 'Mesa ocupada')
/// llegan como [SesionException] con mensaje user-friendly; la mesa en
/// limpieza ([TransicionInvalidaException]) se traduce a mensaje
/// controlado — nunca un stack trace al usuario.
@riverpod
class SesionController extends _$SesionController {
  @override
  FutureOr<void> build() {}

  Future<SesionMesa> abrir(String codigoQr) async {
    final db = ref.read(firestoreProvider);
    final uid = ref.read(firebaseAuthProvider).currentUser?.uid;
    if (uid == null) {
      throw const SesionException('Debes iniciar sesión para abrir la mesa');
    }

    state = const AsyncLoading<void>();
    try {
      return await abrirSesion(db, uid: uid, codigoQR: codigoQr);
    } on SesionException {
      rethrow; // ya trae mensaje user-friendly del dominio
    } on TransicionInvalidaException {
      // Mesa en limpieza (o transición no permitida) — mensaje controlado.
      throw const SesionException('La mesa no está disponible en este momento');
    } catch (_) {
      throw const SesionException(
          'No pudimos abrir la mesa. Verifica el código e intenta de nuevo.');
    } finally {
      state = const AsyncData<void>(null);
    }
  }
}
