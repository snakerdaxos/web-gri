import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Config cargada desde `assets/.env` vía flutter_dotenv.
///
/// En widget tests (que nunca llaman [dotenv.load]) cae a defaults locales:
/// `dotenv.isInitialized` evita leer el mapa antes de la carga.
///
/// La app cliente NO hace polling (Pattern 4 del research 05): los datos se
/// refrescan por invalidate tras cada mutación. Phase 7 los vuelve tiempo
/// real vía WebSocket.
class Env {
  Env._();

  static bool get _ready => dotenv.isInitialized;

  /// Origen del backend FastAPI (docker-compose :8000 en dev).
  static String get apiBaseUrl => _ready
      ? (dotenv.env['API_BASE_URL'] ?? 'http://localhost:8000')
      : 'http://localhost:8000';

  /// Intervalo de polling de pedidos de la sesión (Phase 6, PEDI-04).
  /// Phase 7 lo reemplaza por WebSocket — las screens nunca hardcodean
  /// este valor.
  static int get pollSeconds => 10;
}
