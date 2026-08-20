import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/firebase_error_mapper.dart';
import '../../core/firebase_providers.dart';
import '../../core/state_machines.dart';
import '../../core/tx_mutex.dart';
import '../../models/sesion_mesa.dart';

part 'sesion_provider.g.dart';

/// Forma canónica del código QR de una mesa: `GRI-MESA-{slug}-{NNN}`
/// (p. ej. `GRI-MESA-demo-001`). El doc ID de la mesa ES el código.
///
/// FUENTE ÚNICA de la regla. Vivía en `scan_screen.dart` como campo privado y
/// se mudó aquí en 11-23 porque la validación NO puede vivir solo en la
/// pantalla: la cámara (`_onDetect`) entrega el texto crudo del QR
/// directamente al dominio, sin pasar por el validator del campo manual. Con
/// la regla solo arriba, un QR de otra app llegaba a Firestore, no encontraba
/// documento, y salía por el mensaje de «mesa inexistente» — que es falso: la
/// mesa no es que no exista, es que eso no era un código de mesa.
///
/// AVISO: hay comentarios que citan esta expresión y todavía apuntan a
/// `app_cliente/.../scan_screen.dart` (`panel_admin/lib/features/configuracion/
/// slug.dart`, `panel_admin/test/configuracion/slug_test.dart`,
/// `functions/src/auth-matrix.js` y `scripts/test/rules/mesas.test.mjs`). El
/// VALOR no ha cambiado, solo el archivo; esos punteros están desactualizados
/// en la ubicación, no en la regla.
final RegExp codigoMesaRegExp = RegExp(r'^GRI-MESA-[a-z0-9-]+-\d{3}$');

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
/// 0. El código debe tener la forma de [codigoMesaRegExp]; si no, el fallo es
///    de FORMATO y se dice así (11-23: antes se confundía con el siguiente).
/// 1. `tx.get(mesas/{codigoQR})` — si no existe, la mesa NO EXISTE (mensaje
///    propio, distinto del de formato).
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
  // 0) FORMATO, antes de gastar un viaje a Firestore. Esta comprobación es la
  //    única que ve lo que entrega la CÁMARA: el validator del campo manual no
  //    está en ese camino. Un QR de otra app muere aquí, con su mensaje.
  if (!codigoMesaRegExp.hasMatch(codigoQR)) {
    return Future.error(SesionException(
        mensajeDe(CausaFallo.formatoInvalido, contexto: Contexto.abrirMesa)));
  }
  return db.runTransaction<SesionMesa>((tx) async {
    // 1) La mesa debe existir — el código QR ES el doc ID (get O(1)).
    //    Llegados aquí el formato ya es bueno, así que esto significa
    //    exactamente «esa mesa no existe», y NO «revisa el código».
    final mesaRef = db.doc('mesas/$codigoQR');
    final mesaSnap = await tx.get(mesaRef);
    if (!mesaSnap.exists) {
      throw SesionException(
          mensajeDe(CausaFallo.noEncontrado, contexto: Contexto.abrirMesa));
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

/// Sesión más reciente del usuario autenticado (o null) — query realtime
/// `sesiones where usuarioId == uid`. NO filtra por estado: tras el cierre
/// la sigue emitiendo (estado 'cerrada') para que el cliente pueda calificar
/// sus pedidos servidos (locked: calificación tras cierre) y el banner se
/// despida al detectar el cierre (la UI discrimina por `estado`).
/// keepAlive: el banner de home / menú / pedidos la observan a través de
/// la navegación. Sin usuario → emite null (banner fuera).
@Riverpod(keepAlive: true)
Stream<SesionMesa?> sesionActual(Ref ref) {
  final db = ref.watch(firestoreProvider);
  final auth = ref.watch(firebaseAuthProvider);
  return _usuarios(auth).asyncExpand((user) {
    if (user == null) return Stream.value(null);
    return db
        .collection('sesiones')
        .where('usuarioId', isEqualTo: user.uid)
        .snapshots()
        .asyncMap((snap) async {
      if (snap.docs.isEmpty) return null;
      // La más reciente por inicioAt (mix Timestamp|DateTime según writer).
      // Loop manual (NO reduce): los fakes tipan docs como subclase y el
      // chequeo de varianza del combine explota en runtime.
      int ms(dynamic v) => v is Timestamp
          ? v.millisecondsSinceEpoch
          : v is DateTime
              ? v.millisecondsSinceEpoch
              : 0;
      QueryDocumentSnapshot<Map<String, dynamic>>? doc;
      for (final d in snap.docs) {
        if (doc == null || ms(d.data()['inicioAt']) > ms(doc.data()['inicioAt'])) {
          doc = d;
        }
      }
      return _enriquecer(db, SesionMesa.fromDoc(doc!));
    });
  });
}

/// Usuarios de auth: el actual YA (el SDK real emite el usuario vigente a
/// cada nuevo listener; los mocks usan broadcast sin replay y se saltan el
/// evento del constructor — el yield inicial los pone en paridad).
Stream<User?> _usuarios(FirebaseAuth auth) async* {
  yield auth.currentUser;
  yield* auth.authStateChanges();
}

/// Mutaciones de la sesión: [abrir] por código QR (cámara o input manual).
///
/// TODO fallo sale como [SesionException] con un mensaje que dice la VERDAD
/// sobre su causa (11-23). Cinco causas, cinco mensajes:
/// formato del código, mesa inexistente, mesa no disponible, permiso denegado
/// y backend inalcanzable. Los tres primeros los produce el dominio; los dos
/// últimos salen de `clasificarFallo`/`mensajeDe`
/// (`core/firebase_error_mapper.dart`). Nunca un stack trace al usuario, y
/// nunca —esto es lo que arregla 11-23— un mensaje que culpe al código
/// cuando el problema es la cuenta o la red.
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
      // El texto sale del mapeador para que haya UNA sola redacción por causa.
      throw SesionException(
          mensajeDe(CausaFallo.noDisponible, contexto: Contexto.abrirMesa));
    } catch (e) {
      // AQUÍ ESTABA EL BUG. Este `catch` decía «No pudimos abrir la mesa.
      // Verifica el código e intenta de nuevo.» para CUALQUIER cosa, y por él
      // pasaban las dos causas del incidente real: el `permission-denied` de
      // una cuenta que no es de cliente y el `unavailable` de unos emuladores
      // apagados. Ninguna de las dos tenía que ver con el código.
      //
      // Ahora se clasifica y se dice la verdad; y si de verdad no sabemos qué
      // pasó, el mensaje de `desconocido` tampoco lo inventa.
      debugPrint('abrirSesion falló [${clasificarFallo(e)}]: $e');
      throw SesionException(mensajeDeFallo(e, contexto: Contexto.abrirMesa));
    } finally {
      state = const AsyncData<void>(null);
    }
  }
}
