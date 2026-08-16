// core/tx_mutex.dart — mutex en-proceso para mutaciones Firestore del
// cliente (patrón estrenado en reservas 10-03, ahora compartido por
// sesiones/pedidos/calificaciones — "Notes for Continuation" del plan 04).
//
// POR QUÉ: (1) en Firestore REAL la transacción serializa writers entre
// dispositivos (OCC + reintentos) — este mutex serializa las llamadas del
// MISMO proceso (doble tap, crear/solicitar cuenta solapados); (2) los
// fakes de test ejecutan runTransaction SIN control de concurrencia
// (writes inmediatos — `_DummyTransaction` de fake_cloud_firestore 4.2.0),
// así que el mutex es lo que hace deterministas los tests de concurrencia
// (MIGRA-06) bajo fakes. En producción nunca sostiene la sección más que
// la propia transacción.
//
// Gotcha de zonas (tests): los callbacks de `.then` sobre un future YA
// completado corren en la zona donde ese future fue CREADO — si el tail
// quedó completado en la zona de un test anterior (ya muerta), esperar
// esa cadena cuelga al test siguiente (FakeAsync). Por eso el estado se
// rastrea con un token: libre ⇒ ejecutar YA sin encadenar; encadenar
// SOLO cuando hay una acción en vuelo (siempre de la misma zona, porque
// los tests esperan sus propios futures).

/// Token non-null mientras hay una acción en vuelo.
Object? _txToken;

/// Cadena de acciones en vuelo.
Future<void> _txTail = Future<void>.value();

/// Ejecuta [accion] serializada contra otras `seccionCritica` del mismo
/// proceso. El future devuelto propaga el resultado/error original.
Future<T> seccionCritica<T>(Future<T> Function() accion) {
  final libre = _txToken == null;
  final token = _txToken = Object();
  final Future<T> resultado;
  if (libre) {
    resultado = accion();
  } else {
    resultado = _txTail.then<T>((_) => accion());
  }
  _txTail = resultado.then((_) {}, onError: (_) {});
  // Liberar el lock al terminar. OJO: usar `.then` con onError (NO
  // `whenComplete`): whenComplete PROPAGA el error al future que devuelve
  // y, al ignorarlo, queda como unhandled async error que rompe los tests
  // aunque el caller haya capturado el error original.
  resultado.then((_) {
    if (identical(_txToken, token)) _txToken = null;
  }, onError: (_) {
    if (identical(_txToken, token)) _txToken = null;
  });
  return resultado;
}
