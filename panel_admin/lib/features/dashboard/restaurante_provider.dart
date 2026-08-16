import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/firebase_providers.dart';
import '../../core/token_provider.dart' show authStateProvider;
import '../../models/restaurante.dart';

part 'restaurante_provider.g.dart';

/// Resumen de restaurante para las vistas del panel (selector del super +
/// topbar). Proyección mínima del doc `restaurantes/{rid}`.
typedef RestauranteResumen = ({String id, String nombre, bool activo});

// ═══════════════════════════════ PHASE 10 (Firebase) ═════════════════════

/// Elección del restaurante activo para `super_admin` (el staff NO elige:
/// su rid viene de claims). El panel arranca sin selección; el AppShell
/// setea el default (primer activo) apenas carga la lista.
///
/// Threat model: el rid JAMÁS viene de un input libre del usuario — solo
/// de claims (staff) o de esta selección sobre docs que super ya puede
/// leer por rules.
class SeleccionRestaurante extends Notifier<String?> {
  @override
  String? build() => null;

  void set(String? rid) => state = rid;
}

final seleccionRestauranteProvider =
    NotifierProvider<SeleccionRestaurante, String?>(
  SeleccionRestaurante.new,
);

/// El restaurante activo del operador actual:
///  * staff → `claims.rid` (SU tenant — inamovible desde la UI).
///  * super_admin → [seleccionRestauranteProvider].
///
/// TODAS las queries staff del panel derivan su `where restauranteId`
/// de aquí (aislamiento tenant, Pitfall 4 del research).
///
/// Estructura riverpod-3-safe (lección 07-03): TODO el uso de `ref` ocurre
/// ANTES del primer await.
@riverpod
Future<String?> ridActivo(Ref ref) async {
  final seleccion = ref.watch(seleccionRestauranteProvider);
  final claims = await ref.watch(claimsProvider.future);
  if (claims.role == 'super_admin') {
    return seleccion;
  }
  return claims.rid;
}

/// Restaurante activo EN VIVO para el TopBar — stream del doc
/// `restaurantes/{rid}` (nombre/activo). Sin rid (super sin selección)
/// emite `null` → el topbar muestra el selector en su lugar.
@riverpod
Stream<RestauranteResumen?> restauranteActivo(Ref ref) async* {
  // Watches ANTES del primer await (lección 07-03).
  final db = ref.watch(firestoreProvider);
  final rid = await ref.watch(ridActivoProvider.future);

  if (rid == null) {
    yield null;
    return;
  }

  yield* db.doc('restaurantes/$rid').snapshots().map((snap) {
    final data = snap.data();
    if (!snap.exists || data == null) return null;
    return (
      id: snap.id,
      nombre: data['nombre'] as String? ?? '',
      activo: data['activo'] as bool? ?? false,
    );
  });
}

/// Ficha COMPLETA del restaurante activo (10-06): stream del doc
/// `restaurantes/{rid}` — la alimenta el tab 'Restaurante' de
/// /configuracion (read-only en v1).
///
/// Sin rid (super sin selección) o doc inexistente → error controlado
/// ('No hay restaurante seleccionado') — la UI ya lo trata.
@riverpod
Stream<Restaurante> restaurante(Ref ref) async* {
  final db = ref.watch(firestoreProvider);
  final rid = await ref.watch(ridActivoProvider.future);

  if (rid == null) {
    throw StateError('No hay restaurante seleccionado');
  }

  yield* db.doc('restaurantes/$rid').snapshots().map((snap) {
    if (!snap.exists) {
      throw StateError('No hay restaurante seleccionado');
    }
    return Restaurante.fromDoc(snap);
  });
}

// ════════════════ LEGACY (era REST — vivo hasta el purge 10-06) ═══════════
// Consumido SOLO por ws_client (core legacy que se elimina en 10-06 Task 3).
// NO tocar: el purge lo elimina junto al api_client/token_provider.

/// Restaurante activo en el panel: staff siempre su tenant; super_admin el
/// que elija en el dropdown del AppShell (default al primero activo).
///
/// Notifier custom (Riverpod 3.x: StateProvider se deprecó en favor de
/// NotifierProvider). El estado se setea vía [set] desde el AppShell.
class CurrentRestauranteId extends Notifier<int?> {
  @override
  int? build() {
    final user = ref.read(authStateProvider).value;
    return user?.restaurantId;
  }

  void set(int? id) {
    state = id;
  }
}

final currentRestauranteIdProvider =
    NotifierProvider<CurrentRestauranteId, int?>(
  CurrentRestauranteId.new,
);
