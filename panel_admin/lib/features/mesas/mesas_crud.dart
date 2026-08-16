import 'package:cloud_firestore/cloud_firestore.dart';

import '../../models/mesa.dart';

/// Doc ID determinista de una mesa = su código QR (Phase 10, locked):
/// `GRI-MESA-{rid}-{numero:03d}` (paridad con el seed 10-01). Crear una
/// mesa con un número ya usado colisiona el doc ID → [MesaDuplicadaException]
/// — jamás dos mesas comparten QR por construcción (threat model 10-06).
String docIdDeMesa(String rid, int numero) =>
    'GRI-MESA-$rid-${numero.toString().padLeft(3, '0')}';

/// Número de mesa ya ocupado en el tenant (el doc determinista existe).
class MesaDuplicadaException implements Exception {
  const MesaDuplicadaException(this.numero);

  final int numero;

  @override
  String toString() => 'Ya existe una mesa con ese número ($numero)';
}

/// Crea `mesas/GRI-MESA-{rid}-{numero:03d}` en estado `disponible`.
///
/// La existencia del doc determinista se verifica ANTES del write (tx):
/// un número repetido lanza [MesaDuplicadaException] SIN tocar el doc
/// original. Rules re-fuerzan create con `menuStaffOf(rid)`.
Future<void> crearMesa(
  FirebaseFirestore db, {
  required String rid,
  required int numero,
  required int capacidad,
}) async {
  final ref = db.doc('mesas/${docIdDeMesa(rid, numero)}');
  await db.runTransaction((tx) async {
    final snap = await tx.get(ref);
    if (snap.exists) throw MesaDuplicadaException(numero);
    tx.set(ref, <String, dynamic>{
      'restauranteId': rid,
      'numero': numero,
      'capacidad': capacidad,
      'estado': 'disponible',
      'updatedAt': FieldValue.serverTimestamp(),
    });
  });
}

/// Actualiza la ficha de la mesa (numero/capacidad — rules:
/// `hasOnly([numero, capacidad, updatedAt])`).
///
/// * Solo [capacidad] (o numero igual) → `update` quirúrgico
///   `{capacidad?, updatedAt}` — el resto del doc queda INTACTO.
/// * [numero] distinto → el doc ID (= código QR) DERIVA del número, así
///   que la mesa se MUEVE: tx que crea el doc nuevo (estado/capacidad
///   preservados) y borra el viejo — el QR impreso anterior queda
///   obsoleto (warning del form). El destino ocupado lanza
///   [MesaDuplicadaException].
Future<void> actualizarMesa(
  FirebaseFirestore db, {
  required Mesa mesa,
  required String rid,
  int? numero,
  int? capacidad,
}) async {
  final nuevoNumero = numero ?? mesa.numero;

  if (nuevoNumero != mesa.numero) {
    final nuevoRef = db.doc('mesas/${docIdDeMesa(rid, nuevoNumero)}');
    final viejoRef = db.doc('mesas/${mesa.id}');
    await db.runTransaction((tx) async {
      final snap = await tx.get(nuevoRef);
      if (snap.exists) throw MesaDuplicadaException(nuevoNumero);
      tx.set(nuevoRef, <String, dynamic>{
        'restauranteId': rid,
        'numero': nuevoNumero,
        'capacidad': capacidad ?? mesa.capacidad,
        'estado': mesa.estado.name,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      tx.delete(viejoRef);
    });
    return;
  }

  final changes = <String, dynamic>{'updatedAt': FieldValue.serverTimestamp()};
  if (capacidad != null && capacidad != mesa.capacidad) {
    changes['capacidad'] = capacidad;
  }
  if (changes.length > 1) {
    await db.doc('mesas/${mesa.id}').update(changes);
  }
}

/// Elimina el doc de la mesa (rules: `menuStaffOf(rid)` sobre el doc
/// EXISTENTE). El onSnapshot del mapa refleja la baja en vivo.
Future<void> eliminarMesa(
  FirebaseFirestore db, {
  required String mesaId,
}) {
  return db.doc('mesas/$mesaId').delete();
}
