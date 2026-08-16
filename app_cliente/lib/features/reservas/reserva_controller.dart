import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../models/reserva.dart';
import '../../models/reserva_create.dart';

part 'reserva_controller.g.dart';

/// Error de dominio de reservas con mensaje user-friendly directo
/// (contrato de la UI — mismo rol que el `detail` de la era REST).
class ReservaException implements Exception {
  const ReservaException(this.message);

  final String message;

  @override
  String toString() => message;
}

// ── RED (TDD Task 3): las firmas existen; implementación en GREEN. ──────

/// Doc ID determinista de la reserva: `{mesaId}_{yyyyMMdd}_{HH}` con la
/// fecha del SLOT en TZ local (Pitfall 3: NUNCA serverTimestamp para el
/// id — la unicidad mesa+slot vive en el propio doc ID).
String docIdReserva(String mesaId, DateTime slot) => throw UnimplementedError();

/// Port de `backend/app/services/reserva_service.py` (MIGRA-06):
/// asignación automática de mesa sin sobre-reservas.
Future<Reserva> crearReserva(
  FirebaseFirestore db, {
  required String uid,
  required String restauranteId,
  required DateTime slot,
  required int personas,
}) =>
    throw UnimplementedError();

/// Cancela una reserva futura propia (transición de state machine) y
/// revierte la mesa SOLO si estaba 'reservada'.
Future<void> cancelarReserva(
  FirebaseFirestore db, {
  required String uid,
  required Reserva reserva,
}) =>
    throw UnimplementedError();

/// Orquesta las mutaciones de reservas del cliente sobre Firestore.
/// [misReservas] es un stream → la lista se refresca sola (REALTIME).
@riverpod
class ReservaController extends _$ReservaController {
  @override
  FutureOr<void> build() {}

  Future<Reserva> create(ReservaCreate body) => throw UnimplementedError();

  Future<void> cancel(Reserva reserva) => throw UnimplementedError();
}
