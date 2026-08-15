import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/pago.dart';
import '../models/pedido.dart';
import '../models/reserva.dart';
import '../models/reserva_create.dart';
import '../models/restaurante.dart';
import '../models/restaurante_detalle.dart';
import '../models/sesion_mesa.dart';
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
    _auth = AuthInterceptor(_dio, _storage, this);
    _dio.interceptors.add(_auth);
  }

  final Dio _dio;
  final AuthStorage _storage;
  late final AuthInterceptor _auth;

  /// Lo cablea `AuthState.build` (token_provider.dart): refresh fallido →
  /// logout upstream → goRouter redirect a /login.
  void Function()? onSessionExpired;

  /// Refresh público para el [WsClient] (Phase 7): ante un close 4401 del
  /// WS el cliente refresca tokens y reintenta SIN logout. Reusa el
  /// Completer compartido del interceptor (anti refresh-storm: N 401s
  /// HTTP + un 4401 WS simultáneos derivan en UN solo POST /auth/refresh).
  ///
  /// Retorna el nuevo access token, o null si el refresh falló (sesión
  /// muerta — el WS delega al logout existente, no reconecta).
  Future<String?> refreshTokens() => _auth._refreshOnce();

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

  // ── Sesión de mesa (Phase 6 — QR / cuenta) ─────────────────────────────

  /// `POST /cliente/sesiones` — abre (o re-abre idempotente: 201 Y 200 son
  /// éxito) la sesión de la mesa con ese código QR.
  /// Errores esperados: 404 QR/restaurante · 409 mesa ocupada / limpieza /
  /// usuario con sesión en otra mesa (detail del server describe el caso).
  Future<SesionMesa> abrirSesion(String codigoQr) async {
    final r = await _dio.post<Map<String, dynamic>>(
      '/cliente/sesiones',
      data: {'codigo_qr': codigoQr},
    );
    return SesionMesa.fromJson(r.data!);
  }

  /// `GET /cliente/sesiones/actual` — la sesión activa del usuario, o null
  /// si no tiene ninguna (404 → null, no error).
  Future<SesionMesa?> getSesionActual() async {
    try {
      final r =
          await _dio.get<Map<String, dynamic>>('/cliente/sesiones/actual');
      return SesionMesa.fromJson(r.data!);
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) return null;
      rethrow;
    }
  }

  /// `POST /cliente/sesiones/actual/cuenta` — marca solicita_cuenta=true.
  /// Idempotente server-side (doble tap seguro, PAGO-01).
  Future<SesionMesa> pedirCuenta() async {
    final r = await _dio.post<Map<String, dynamic>>(
      '/cliente/sesiones/actual/cuenta',
    );
    return SesionMesa.fromJson(r.data!);
  }

  // ── Pedidos de la sesión (Phase 6) ─────────────────────────────────────

  /// `GET /cliente/pedidos/actual` — TODOS los pedidos de mi sesión activa
  /// (cualquier estado, newest first). 404 sin sesión: el provider que lo
  /// consume lo evita guardando en sesionProvider.
  Future<List<Pedido>> getPedidosActuales() async {
    final r = await _dio.get<List<dynamic>>('/cliente/pedidos/actual');
    return [
      for (final e in r.data ?? const <dynamic>[])
        Pedido.fromJson(e as Map<String, dynamic>),
    ];
  }

  /// `POST /cliente/pedidos` — crea el pedido en estado `enviado`.
  ///
  /// Sin `sesion_id` en el body: el backend usa la sesión ACTIVA del
  /// usuario (contrato 06-01). El total se calcula server-side con
  /// snapshot de precio — el total del carrito es solo informativo.
  /// Errores: 404 sin sesión/producto cross-restaurante · 409 agotado.
  Future<Pedido> createPedido({
    required List<({int productoId, int cantidad})> items,
    String? notas,
  }) async {
    final r = await _dio.post<Map<String, dynamic>>(
      '/cliente/pedidos',
      data: {
        'items': [
          for (final i in items)
            {'producto_id': i.productoId, 'cantidad': i.cantidad},
        ],
        if (notas != null && notas.isNotEmpty) 'notas': notas,
      },
    );
    return Pedido.fromJson(r.data!);
  }

  // ── Pago en línea (Phase 9 — PAGO-02) ──────────────────────────────────

  /// `POST /cliente/pagos/intencion` — crea (o reutiliza idempotente: 201 Y
  /// 200 son éxito) la intención de pago de la cuenta de la sesión activa.
  /// El monto lo calcula el backend SERVER-SIDE (Σ pedidos servido) — el
  /// body va vacío (threat: montos jamás vienen del cliente).
  /// Errores esperados: 404 sin sesión · 409 pedidos en curso / sin pedidos.
  Future<PagoIntencion> crearIntencionPago() async {
    final r = await _dio.post<Map<String, dynamic>>('/cliente/pagos/intencion');
    return PagoIntencion.fromJson(r.data!);
  }

  /// `GET /cliente/pagos/{pagoId}` — estado del pago para el polling
  /// post-checkout. La UI JAMÁS marca un pago como aprobado por el
  /// retorno del checkout: este endpoint (backend + webhook verificado)
  /// es la única fuente de verdad (threat 1 del research 09).
  /// 404 si el pago no es de este usuario (existence hiding).
  Future<PagoEstado> getPagoEstado(int pagoId) async {
    final r = await _dio.get<Map<String, dynamic>>('/cliente/pagos/$pagoId');
    return PagoEstado.fromJson(r.data!);
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
