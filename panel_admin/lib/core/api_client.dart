// core/api_client.dart — LEGACY (era REST).
//
// SUPERFICIE MÍNIMA hasta el purge de 10-06 Task 3: todo el CRUD ya vive
// en Firestore (mesas/menú/clientes/reservas/config migrados en 10-05 y
// 10-06). Quedan SOLO los métodos que aún consumen:
//   * token_provider (me + onSessionExpired)
//   * ws_client (refreshTokens)
//   * reportes_screen (getReporteVentas/getTopPlatos — migra en Task 3)
// El archivo completo se ELIMINA en 10-06 Task 3 junto a sus consumers.
import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/reporte.dart';
import '../models/token_pair.dart';
import '../models/user.dart';
import 'auth_storage.dart';
import 'env.dart';

final apiClientProvider = Provider<ApiClient>((ref) {
  return ApiClient(storage: ref.watch(authStorageProvider));
});

/// Cliente HTTP del panel (legado REST — purge en 10-06 Task 3).
class ApiClient {
  ApiClient({AuthStorage? storage, Dio? dio})
      : _storage = storage ?? AuthStorage(),
        _dio = dio ??
            Dio(
              BaseOptions(
                baseUrl: Env.apiBaseUrl,
                connectTimeout: const Duration(seconds: 10),
                receiveTimeout: const Duration(seconds: 15),
              ),
            ) {
    _auth = AuthInterceptor(_dio, _storage, this);
    _dio.interceptors.add(_auth);
  }

  final Dio _dio;
  final AuthStorage _storage;
  late final AuthInterceptor _auth;

  /// Lo cablea `AuthState.build` (token_provider.dart): refresh fallido →
  /// logout upstream → goRouter redirect a /login.
  void Function()? onSessionExpired;

  Future<User> me() async {
    final r = await _dio.get<Map<String, dynamic>>('/auth/me');
    return User.fromJson(r.data!);
  }

  /// Refresh público para el WsClient (07-02): ante close 4401 del WS,
  /// refresca y reintenta. Delega en el mismo [Completer] anti refresh-storm
  /// del interceptor (N 401s + 4401s concurrentes → 1 solo POST /auth/refresh).
  /// Retorna el access nuevo o null (sesión muerta — el refresh fallido ya
  /// disparó el logout upstream via [onSessionExpired]).
  Future<String?> refreshTokens() => _auth._refreshOnce();

  // ── Reportes (REPO-01/02 — migra a Firestore en 10-06 Task 3) ──────────

  /// `GET /staff/reportes/ventas` — venta = servido|pagado, rango efectivo
  /// en la respuesta. 422 si desde > hasta.
  Future<VentasReporte> getReporteVentas({
    String? desde,
    String? hasta,
    int? restauranteId,
  }) async {
    final r = await _dio.get<Map<String, dynamic>>(
      '/staff/reportes/ventas',
      queryParameters: {
        'desde': ?desde,
        'hasta': ?hasta,
        'restaurante_id': ?restauranteId,
      },
    );
    return VentasReporte.fromJson(r.data!);
  }

  /// `GET /staff/reportes/top-platos` — top-N platos por SUM(cantidad) DESC.
  Future<List<TopPlato>> getTopPlatos({
    String? desde,
    String? hasta,
    int? limit,
    int? restauranteId,
  }) async {
    final r = await _dio.get<List<dynamic>>(
      '/staff/reportes/top-platos',
      queryParameters: {
        'desde': ?desde,
        'hasta': ?hasta,
        'limit': ?limit,
        'restaurante_id': ?restauranteId,
      },
    );
    return [
      for (final e in r.data ?? const <dynamic>[])
        TopPlato.fromJson(e as Map<String, dynamic>),
    ];
  }
}

/// QueuedInterceptor: serializa errores concurrentes para que N 401s
/// simultáneos deriven en UN solo refresh (T-04-06).
class AuthInterceptor extends QueuedInterceptor {
  AuthInterceptor(this._dio, this._storage, this._client);

  final Dio _dio;
  final AuthStorage _storage;
  final ApiClient _client;

  Completer<String?>? _refreshCompleter;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) async {
    final token = await _storage.readAccess();
    if (token != null) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    final status = err.response?.statusCode;
    final path = err.requestOptions.path;
    final isAuthPath = path == '/auth/login' || path == '/auth/refresh';

    if (status != 401 || isAuthPath) {
      return handler.next(err);
    }

    final newToken = await _refreshOnce();
    if (newToken == null) {
      _client.onSessionExpired?.call();
      return handler.next(err);
    }

    final opts = err.requestOptions..headers['Authorization'] = 'Bearer $newToken';
    try {
      final retried = await _dio.fetch(opts);
      handler.resolve(retried);
    } on DioException catch (e) {
      handler.next(e);
    } catch (_) {
      handler.next(err);
    }
  }

  /// UN refresh a la vez: el primer 401 crea el [Completer]; los N-1
  /// restantes esperan su future y reciben el mismo token nuevo.
  Future<String?> _refreshOnce() async {
    final existing = _refreshCompleter;
    if (existing != null) return existing.future;

    final completer = Completer<String?>();
    _refreshCompleter = completer;
    try {
      final refresh = await _storage.readRefresh();
      if (refresh == null) {
        completer.complete(null);
        return null;
      }
      final r = await _dio.post<Map<String, dynamic>>(
        '/auth/refresh',
        data: {'refresh_token': refresh},
      );
      final pair = TokenPair.fromJson(r.data!);
      await _storage.write(pair.access, pair.refresh);
      completer.complete(pair.access);
      return pair.access;
    } catch (_) {
      await _storage.clear();
      completer.complete(null);
      return null;
    } finally {
      _refreshCompleter = null;
    }
  }
}
