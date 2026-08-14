import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/reserva.dart';
import '../models/reserva_create.dart';
import '../models/restaurante.dart';
import '../models/restaurante_detalle.dart';
import '../models/token_pair.dart';
import '../models/user.dart';
import 'auth_storage.dart';
import 'env.dart';

final apiClientProvider = Provider<ApiClient>((ref) {
  return ApiClient(storage: ref.watch(authStorageProvider));
});

/// Cliente HTTP de la app cliente — la ÚNICA vía al backend.
///
/// Envuelve una instancia [Dio] con:
///  * [AuthInterceptor] (extends [QueuedInterceptor]): attacha `Authorization:
///    Bearer` en cada request y, ante un 401 (fuera de /auth/login y
///    /auth/refresh), hace UN solo `POST /auth/refresh` protegido por un
///    [Completer] compartido (anti refresh-storm, copiado del panel T-04-06)
///    y reintenta la request original con el token nuevo.
///  * Si el refresh falla: limpia storage, dispara [onSessionExpired]
///    (logueo upstream via AuthState) y propaga el error.
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
    _dio.interceptors.add(AuthInterceptor(_dio, _storage, this));
  }

  final Dio _dio;
  final AuthStorage _storage;

  /// Lo cablea `AuthState.build` (token_provider.dart): refresh fallido →
  /// logout upstream → goRouter redirect a /login.
  void Function()? onSessionExpired;

  Future<TokenPair> login(String email, String password) async {
    final r = await _dio.post<Map<String, dynamic>>(
      '/auth/login',
      data: {'email': email, 'password': password},
    );
    return TokenPair.fromJson(r.data!);
  }

  /// `POST /auth/register` — crea la cuenta cliente y loguea de una
  /// (el backend devuelve el UserRead 201; luego hacemos login para los JWTs).
  Future<User> register(String nombre, String email, String password) async {
    final r = await _dio.post<Map<String, dynamic>>(
      '/auth/register',
      data: {'nombre': nombre, 'email': email, 'password': password},
    );
    return User.fromJson(r.data!);
  }

  Future<User> me() async {
    final r = await _dio.get<Map<String, dynamic>>('/auth/me');
    return User.fromJson(r.data!);
  }

  /// `GET /public/restaurantes` — lista de restaurantes activos (sin auth).
  Future<List<Restaurante>> getPublicRestaurantes() async {
    final r = await _dio.get<List<dynamic>>('/public/restaurantes');
    return [
      for (final e in r.data ?? const <dynamic>[])
        Restaurante.fromJson(e as Map<String, dynamic>),
    ];
  }

  /// `GET /public/restaurantes/{id}` — detalle con menú anidado (sin auth).
  Future<RestauranteDetalle> getPublicRestaurante(int id) async {
    final r = await _dio.get<Map<String, dynamic>>('/public/restaurantes/$id');
    return RestauranteDetalle.fromJson(r.data!);
  }

  /// `GET /cliente/reservas` — las reservas del cliente autenticado.
  Future<List<Reserva>> getMisReservas() async {
    final r = await _dio.get<List<dynamic>>('/cliente/reservas');
    return [
      for (final e in r.data ?? const <dynamic>[])
        Reserva.fromJson(e as Map<String, dynamic>),
    ];
  }

  /// `POST /cliente/reservas` — crea la reserva (asignación de mesa
  /// automática server-side). Puede lanzar 400/409 (capacidad/slot tomado).
  Future<Reserva> createReserva(ReservaCreate body) async {
    final r = await _dio.post<Map<String, dynamic>>(
      '/cliente/reservas',
      data: body.toJson(),
    );
    return Reserva.fromJson(r.data!);
  }

  /// `POST /cliente/reservas/{id}/cancelar`.
  Future<Reserva> cancelReserva(int reservaId) async {
    final r = await _dio.post<Map<String, dynamic>>(
      '/cliente/reservas/$reservaId/cancelar',
    );
    return Reserva.fromJson(r.data!);
  }

  /// `GET /cliente/perfil`.
  Future<User> getPerfil() async {
    final r = await _dio.get<Map<String, dynamic>>('/cliente/perfil');
    return User.fromJson(r.data!);
  }

  /// `PATCH /cliente/perfil` — nombre siempre; password solo si viene.
  /// El email NO se envía (immutable server-side).
  Future<User> updatePerfil({required String nombre, String? password}) async {
    final r = await _dio.patch<Map<String, dynamic>>(
      '/cliente/perfil',
      data: {
        'nombre': nombre,
        if (password != null && password.isNotEmpty) 'password': password,
      },
    );
    return User.fromJson(r.data!);
  }
}

/// QueuedInterceptor: serializa errores concurrentes para que N 401s
/// simultáneos deriven en UN solo refresh (anti refresh-storm).
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
