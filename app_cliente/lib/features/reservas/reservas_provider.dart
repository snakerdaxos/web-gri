import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/api_client.dart';
import '../../models/reserva.dart';

part 'reservas_provider.g.dart';

/// Reservas del cliente autenticado — `GET /cliente/reservas`.
///
/// Sin polling (Pattern 4 del research 05): se refresca por invalidate tras
/// cada mutación (crear/cancelar). Phase 7 las vuelve tiempo real vía WS.
@riverpod
Future<List<Reserva>> reservas(Ref ref) async {
  return ref.read(apiClientProvider).getMisReservas();
}
