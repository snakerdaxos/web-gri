import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/api_client.dart';
import '../../models/reserva.dart';
import '../../models/reserva_create.dart';
import 'reservas_provider.dart';

part 'reserva_controller.g.dart';

/// Orquesta las mutaciones de reservas del cliente:
/// * [create] → `POST /cliente/reservas` (201) — los errores 400/409 se
///   propagan al widget, que los traduce a mensajes user-friendly
///   (threat 6: "Ese horario acaba de ser reservado, elige otro").
/// * [cancel] → `POST /cliente/reservas/{id}/cancelar`.
///
/// Ambos invalidan [reservasProvider] (sin polling — Pattern 4 del
/// research; Phase 7 lo vuelve WS).
@riverpod
class ReservaController extends _$ReservaController {
  @override
  FutureOr<void> build() {}

  Future<Reserva> create(ReservaCreate body) async {
    state = const AsyncLoading<void>();
    try {
      final reserva = await ref.read(apiClientProvider).createReserva(body);
      ref.invalidate(reservasProvider);
      return reserva;
    } finally {
      state = const AsyncData<void>(null);
    }
  }

  Future<Reserva> cancel(String reservaId) async {
    state = const AsyncLoading<void>();
    try {
      final reserva = await ref.read(apiClientProvider).cancelReserva(reservaId);
      ref.invalidate(reservasProvider);
      return reserva;
    } finally {
      state = const AsyncData<void>(null);
    }
  }
}
