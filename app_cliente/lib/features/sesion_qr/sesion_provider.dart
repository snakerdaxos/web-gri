import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/api_client.dart';
import '../../models/sesion_mesa.dart';

part 'sesion_provider.g.dart';

/// Sesión de mesa activa del usuario (o null) — `GET /cliente/sesiones/actual`.
///
/// keepAlive como [AuthState]: la sesión debe sobrevivir la navegación entre
/// tabs y pantallas (home banner / menú / pedidos la observan). Un 404 del
/// backend se traduce a null (sin sesión), cualquier otro error queda como
/// AsyncError — los watchers leen `.value` y lo tratan como "sin sesión".
@Riverpod(keepAlive: true)
Future<SesionMesa?> sesion(Ref ref) async {
  return ref.read(apiClientProvider).getSesionActual();
}

/// Mutaciones de la sesión: [abrir] por código QR (cámara o input manual).
///
/// Los errores (404 código inexistente / 409 mesa ocupada / limpieza /
/// sesión en otra mesa) se propagan a la screen, que muestra el `detail`
/// del server en un SnackBar rojo — nunca crash.
@riverpod
class SesionController extends _$SesionController {
  @override
  FutureOr<void> build() {}

  Future<SesionMesa> abrir(String codigoQr) async {
    state = const AsyncLoading<void>();
    try {
      final sesion =
          await ref.read(apiClientProvider).abrirSesion(codigoQr);
      ref.invalidate(sesionProvider);
      return sesion;
    } finally {
      state = const AsyncData<void>(null);
    }
  }
}
