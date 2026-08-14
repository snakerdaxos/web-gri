import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/categoria_staff.dart';
import '../models/cliente_resumen.dart';
import '../models/dashboard_stats.dart';
import '../models/mesa.dart';
import '../models/pedido_staff.dart';
import '../models/producto_staff.dart';
import '../models/restaurante.dart';
import '../models/token_pair.dart';
import '../models/user.dart';
import 'auth_storage.dart';
import 'env.dart';

final apiClientProvider = Provider<ApiClient>((ref) {
  return ApiClient(storage: ref.watch(authStorageProvider));
});

/// Cliente HTTP del panel — la ÚNICA vía al backend (T-04-07).
///
/// Envuelve una instancia [Dio] con:
///  * [AuthInterceptor] (extends [QueuedInterceptor]): attacha `Authorization:
///    Bearer` en cada request y, ante un 401 (fuera de /auth/login y
///    /auth/refresh), hace UN solo `POST /auth/refresh` protegido por un
///    [Completer] compartido (T-04-06 anti refresh-storm) y reintenta la
///    request original con el token nuevo.
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

  Future<TokenPair> login(String email, String password) async {
    final r = await _dio.post<Map<String, dynamic>>(
      '/auth/login',
      data: {'email': email, 'password': password},
    );
    return TokenPair.fromJson(r.data!);
  }

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

  Future<List<Mesa>> getMesas({int? restauranteId}) async {
    final r = await _dio.get<List<dynamic>>(
      '/staff/mesas',
      queryParameters: restauranteId == null
          ? null
          : {'restaurante_id': restauranteId},
    );
    return [
      for (final e in r.data ?? const <dynamic>[])
        Mesa.fromJson(e as Map<String, dynamic>),
    ];
  }

  /// `POST /staff/mesas` — crea una mesa con QR determinista autogenerado
  /// por el server (`GRI-MESA-R{rid}-{numero:03d}`, 08-02). 409 si ya existe
  /// una mesa con ese número en el tenant. [restauranteId] SOLO lo manda el
  /// caller para super_admin (patrón [getMesas]).
  Future<Mesa> createMesa(
    int numero,
    int capacidad, {
    int? restauranteId,
  }) async {
    final r = await _dio.post<Map<String, dynamic>>(
      '/staff/mesas',
      data: {'numero': numero, 'capacidad': capacidad},
      queryParameters: restauranteId == null
          ? null
          : {'restaurante_id': restauranteId},
    );
    return Mesa.fromJson(r.data!);
  }

  /// `PATCH /staff/mesas/{id}` — update parcial. Cambiar `numero` REGENERA
  /// el QR en el server (el impreso anterior queda obsoleto — la UI avisa
  /// antes de guardar). Solo los campos no-null viajan en el body.
  Future<Mesa> updateMesa(
    int mesaId, {
    int? numero,
    int? capacidad,
    int? restauranteId,
  }) async {
    final r = await _dio.patch<Map<String, dynamic>>(
      '/staff/mesas/$mesaId',
      // Null-aware elements: claves omitidas si el valor es null (PATCH
      // parcial — solo los campos modificados viajan).
      data: {'numero': ?numero, 'capacidad': ?capacidad},
      queryParameters: restauranteId == null
          ? null
          : {'restaurante_id': restauranteId},
    );
    return Mesa.fromJson(r.data!);
  }

  /// `POST /staff/mesas/{id}/estado` — transición de estado de la mesa.
  /// El server es la autoridad: 409 si la transición no es válida (carrera
  /// entre dos staff), 404 cross-tenant (existence hiding).
  Future<Mesa> setMesaEstado(
    int mesaId,
    String estado, {
    int? restauranteId,
  }) async {
    final r = await _dio.post<Map<String, dynamic>>(
      '/staff/mesas/$mesaId/estado',
      data: {'estado': estado},
      queryParameters: restauranteId == null
          ? null
          : {'restaurante_id': restauranteId},
    );
    return Mesa.fromJson(r.data!);
  }

  Future<DashboardStats> getStats({int? restauranteId}) async {
    final r = await _dio.get<Map<String, dynamic>>(
      '/staff/stats',
      queryParameters: restauranteId == null
          ? null
          : {'restaurante_id': restauranteId},
    );
    return DashboardStats.fromJson(r.data!);
  }

  /// `GET /staff/pedidos?activos=true` — cola FIFO de pedidos activos con
  /// items, total, notas, usuario y el badge `solicita_cuenta` (ADMN-05).
  /// [restauranteId] SOLO lo manda el caller para super_admin (patrón
  /// [getMesas]); el staff jamás filtra client-side.
  Future<List<PedidoStaff>> getPedidosActivos({int? restauranteId}) async {
    final r = await _dio.get<List<dynamic>>(
      '/staff/pedidos',
      queryParameters: {
        'activos': 'true',
        'restaurante_id': ?restauranteId,
      },
    );
    return [
      for (final e in r.data ?? const <dynamic>[])
        PedidoStaff.fromJson(e as Map<String, dynamic>),
    ];
  }

  /// `POST /staff/pedidos/{id}/estado` — avanza el estado de un pedido.
  /// El server es la autoridad: 409 transición inválida, 403 rol no
  /// autorizado para ESA transición, 404 cross-tenant (existence hiding).
  Future<PedidoStaff> avanzarPedido(
    int pedidoId,
    String estado, {
    int? restauranteId,
  }) async {
    final r = await _dio.post<Map<String, dynamic>>(
      '/staff/pedidos/$pedidoId/estado',
      data: {'estado': estado},
      queryParameters: restauranteId == null
          ? null
          : {'restaurante_id': restauranteId},
    );
    return PedidoStaff.fromJson(r.data!);
  }

  // ── Menú CRUD (MENU-01/02, 08-01) ─────────────────────────────────────

  /// `GET /staff/menu` — categorías con productos anidados del tenant.
  /// Incluye inactivos/agotados con flags (staff ve TODO; /public filtra).
  /// [restauranteId] SOLO lo manda el caller para super_admin (patrón
  /// [getMesas]).
  Future<List<CategoriaStaff>> getStaffMenu({int? restauranteId}) async {
    final r = await _dio.get<List<dynamic>>(
      '/staff/menu',
      queryParameters: restauranteId == null
          ? null
          : {'restaurante_id': restauranteId},
    );
    return [
      for (final e in r.data ?? const <dynamic>[])
        CategoriaStaff.fromJson(e as Map<String, dynamic>),
    ];
  }

  /// `POST /staff/categorias` — 201; 409 si ya existe una categoría con ese
  /// nombre en el tenant.
  Future<CategoriaStaff> createCategoria(
    String nombre, {
    int? orden,
    int? restauranteId,
  }) async {
    final r = await _dio.post<Map<String, dynamic>>(
      '/staff/categorias',
      data: {'nombre': nombre, 'orden': ?orden},
      queryParameters: restauranteId == null
          ? null
          : {'restaurante_id': restauranteId},
    );
    return CategoriaStaff.fromJson(r.data!);
  }

  /// `PATCH /staff/categorias/{id}` — update parcial (solo campos no-null
  /// viajan). 404 cross-tenant (existence hiding), 409 nombre dup.
  Future<CategoriaStaff> updateCategoria(
    int categoriaId, {
    String? nombre,
    int? orden,
    bool? activo,
    int? restauranteId,
  }) async {
    final r = await _dio.patch<Map<String, dynamic>>(
      '/staff/categorias/$categoriaId',
      data: {'nombre': ?nombre, 'orden': ?orden, 'activo': ?activo},
      queryParameters: restauranteId == null
          ? null
          : {'restaurante_id': restauranteId},
    );
    return CategoriaStaff.fromJson(r.data!);
  }

  /// `POST /staff/productos` — 201; 404 categoría inexistente/ajena; 422
  /// precio ≤ 0 (server re-valida — la UI también valida antes de enviar).
  Future<ProductoStaff> createProducto({
    required int categoriaId,
    required String nombre,
    String? descripcion,
    required double precio,
    String? imagenUrl,
    int? restauranteId,
  }) async {
    final r = await _dio.post<Map<String, dynamic>>(
      '/staff/productos',
      data: {
        'categoria_id': categoriaId,
        'nombre': nombre,
        'descripcion': ?descripcion,
        'precio': precio,
        'imagen_url': ?imagenUrl,
      },
      queryParameters: restauranteId == null
          ? null
          : {'restaurante_id': restauranteId},
    );
    return ProductoStaff.fromJson(r.data!);
  }

  /// `PATCH /staff/productos/{id}` — update parcial. `disponible` (agotado
  /// transitorio) y `activo` (soft-delete) son semánticas separadas.
  Future<ProductoStaff> updateProducto(
    int productoId, {
    String? nombre,
    String? descripcion,
    double? precio,
    String? imagenUrl,
    bool? disponible,
    bool? activo,
    int? restauranteId,
  }) async {
    final r = await _dio.patch<Map<String, dynamic>>(
      '/staff/productos/$productoId',
      data: {
        'nombre': ?nombre,
        'descripcion': ?descripcion,
        'precio': ?precio,
        'imagen_url': ?imagenUrl,
        'disponible': ?disponible,
        'activo': ?activo,
      },
      queryParameters: restauranteId == null
          ? null
          : {'restaurante_id': restauranteId},
    );
    return ProductoStaff.fromJson(r.data!);
  }

  // ── Clientes (ADMN-03, 08-01) ─────────────────────────────────────────

  /// `GET /staff/clientes` — usuarios CON pedidos en el tenant (JOIN
  /// pedido→usuario): num_pedidos, total_gastado, ultimo_pedido_at.
  Future<List<ClienteResumen>> getClientes({int? restauranteId}) async {
    final r = await _dio.get<List<dynamic>>(
      '/staff/clientes',
      queryParameters: restauranteId == null
          ? null
          : {'restaurante_id': restauranteId},
    );
    return [
      for (final e in r.data ?? const <dynamic>[])
        ClienteResumen.fromJson(e as Map<String, dynamic>),
    ];
  }

  /// `GET /staff/clientes/{usuario_id}/historial` — pedidos del usuario EN
  /// el tenant (misma shape que /staff/pedidos). Vacío → 404 (existence
  /// hiding relacional: no revela que el usuario_id existe globalmente).
  Future<List<PedidoStaff>> getClienteHistorial(
    int usuarioId, {
    int? restauranteId,
  }) async {
    final r = await _dio.get<List<dynamic>>(
      '/staff/clientes/$usuarioId/historial',
      queryParameters: restauranteId == null
          ? null
          : {'restaurante_id': restauranteId},
    );
    return [
      for (final e in r.data ?? const <dynamic>[])
        PedidoStaff.fromJson(e as Map<String, dynamic>),
    ];
  }

  /// `GET /admin/restaurantes` — lista para el selector del super_admin.
  Future<List<Restaurante>> listRestaurantes() async {
    final r = await _dio.get<List<dynamic>>('/admin/restaurantes');
    return [
      for (final e in r.data ?? const <dynamic>[])
        Restaurante.fromJson(e as Map<String, dynamic>),
    ];
  }

  /// `GET /admin/restaurantes/{id}` — nombre del restaurante para el topbar
  /// (staff: propio tenant; super_admin: el seleccionado).
  Future<Restaurante> getRestaurante(int id) async {
    final r = await _dio.get<Map<String, dynamic>>('/admin/restaurantes/$id');
    return Restaurante.fromJson(r.data!);
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
