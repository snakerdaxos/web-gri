import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Config cargada desde `assets/.env` vía flutter_dotenv.
///
/// En widget tests (que nunca llaman [dotenv.load]) cae a defaults locales:
/// `dotenv.isInitialized` evita leer el mapa antes de la carga.
class Env {
  Env._();

  static bool get _ready => dotenv.isInitialized;

  /// Origen del backend FastAPI (docker-compose :8000 en dev).
  static String get apiBaseUrl => _ready
      ? (dotenv.env['API_BASE_URL'] ?? 'http://localhost:8000')
      : 'http://localhost:8000';

  /// Intervalo de polling del dashboard en segundos (deuda Phase 7: WS).
  static int get pollSeconds => _ready
      ? (int.tryParse(dotenv.env['PANEL_POLL_SECONDS'] ?? '10') ?? 10)
      : 10;
}
