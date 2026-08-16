import 'package:cloud_firestore/cloud_firestore.dart';

import '../../models/mesa.dart';

/// Doc ID determinista de una mesa = su código QR (Phase 10):
/// `GRI-MESA-{rid}-{numero:03d}` (paridad con el seed 10-01). Crear una
/// mesa con un número ya usado colisiona el doc ID → [MesaDuplicadaException].
String docIdDeMesa(String rid, int numero) =>
    'GRI-MESA-$rid-${numero.toString().padLeft(3, '0')}';

/// Número de mesa ya ocupado en el tenant (el doc determinista existe).
class MesaDuplicadaException implements Exception {
  const MesaDuplicadaException(this.numero);

  final int numero;

  @override
  String toString() => 'Ya existe una mesa con ese número ($numero)';
}

// ── STUBS (RED del TDD 10-06 Task 1 — GREEN en el commit feat) ─────────────

/// Crea la mesa `mesas/GRI-MESA-{rid}-{numero:03d}` en estado disponible.
Future<void> crearMesa(
  FirebaseFirestore db, {
  required String rid,
  required int numero,
  required int capacidad,
}) {
  throw UnimplementedError();
}

/// Actualiza la ficha de la mesa (numero/capacidad).
Future<void> actualizarMesa(
  FirebaseFirestore db, {
  required Mesa mesa,
  required String rid,
  int? numero,
  int? capacidad,
}) {
  throw UnimplementedError();
}

/// Elimina el doc de la mesa.
Future<void> eliminarMesa(
  FirebaseFirestore db, {
  required String mesaId,
}) {
  throw UnimplementedError();
}
