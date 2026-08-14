import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../features/dashboard/restaurante_provider.dart';
import 'api_client.dart';
import 'auth_storage.dart';
import 'env.dart';
import 'token_provider.dart';

/// Evento WS del backend (contrato 07-01):
/// `{"type": str, "restaurante_id": int|None, "seq": int, "ts": str, "data": dict}`.
///
/// `ts` y `restaurante_id` no se usan client-side: el room al que el server
/// publicó ya delimita el alcance, y la hora relevante es la de recepción.
///
/// La estrategia consumer es kick-to-refetch: `data` solo es señal, no estado.
class WsEvent {
  const WsEvent({required this.type, this.seq, this.data = const {}});

  factory WsEvent.fromJson(dynamic msg) {
    final map = jsonDecode(msg as String) as Map<String, dynamic>;
    return WsEvent(
      type: map['type'] as String,
      // num→int defensivo: jsonDecode puede dar double según el transporte.
      seq: (map['seq'] as num?)?.toInt(),
      data: (map['data'] as Map<String, dynamic>?) ?? const {},
    );
  }

  final String type;

  /// Monotónico POR ROOM (resetea al reiniciar el server — el reconnect
  /// resetea [WsClient._lastSeq], así la comparación nunca ve "retrocedió").
  final int? seq;

  /// Payload mínimo (ids + estado) — nunca se aplica como estado local.
  final Map<String, dynamic> data;
}

/// Cliente WS del panel con reconexión resiliente (07-02, RT-03).
///
/// * Token FRESCO del [AuthStorage] en cada intento (access TTL 15 min —
///   cachearlo condena toda reconexión posterior a un loop 4401).
/// * Close 4401 (o handshake 401/403, forma observada del rechazo pre-accept
///   en 07-01) → [ApiClient.refreshTokens] → retry inmediato sin backoff.
///   Refresh fallido (null) → no reconectar: el logout upstream ya disparó.
/// * Backoff exponencial 1,2,4,8,16,30s cap ×2 + jitter 0-500ms (anti storm).
/// * Dedup por `seq <= lastSeq` por room; `lastSeq` se resetea al reconectar.
/// * [resync] emite SOLO cuando una conexión se restablece tras fallos —
///   señal para que los providers re-GETeen el snapshot autoritativo.
///
/// [connect] y [backoffBuilder] son seams de test (producción:
/// [WebSocketChannel.connect] y [_defaultBackoff]).
class WsClient {
  WsClient(
    this._storage,
    this._api, {
    WebSocketChannel Function(Uri uri)? connect,
    Duration Function(int failures)? backoffBuilder,
  })  : _connect = connect ?? WebSocketChannel.connect,
        _backoffBuilder = backoffBuilder ?? _defaultBackoff;

  final AuthStorage _storage;
  final ApiClient _api;
  final WebSocketChannel Function(Uri uri) _connect;
  final Duration Function(int failures) _backoffBuilder;

  final _events = StreamController<WsEvent>.broadcast();

  /// Eventos dedupeados por seq (broadcast: N providers sin conflicto).
  Stream<WsEvent> get events => _events.stream;

  final _resync = StreamController<void>.broadcast();

  /// Señal de re-sync: se dispara al RESTABLECER una conexión que había
  /// fallado (no en la primera conexión — ahí el GET inicial basta).
  Stream<void> get resync => _resync.stream;

  WebSocketChannel? _channel;
  String? _path;
  int _failures = 0;
  int? _lastSeq;

  /// Generación del ciclo de vida: cada connect/disconnect la incrementa.
  /// Un reconnect agendado por un canal muerto obsoleto se descarta si la
  /// generación cambió (ej: super_admin cambió de restaurante durante el
  /// backoff — no debe reconectar al room viejo).
  int _gen = 0;
  bool _disposed = false;

  static Duration _defaultBackoff(int failures) {
    final base = math.min(30000, 1000 * math.pow(2, failures - 1).toInt());
    return Duration(milliseconds: base + math.Random().nextInt(500));
  }

  /// ws(s):// SIEMPRE derivado de [Env.apiBaseUrl] (nunca hardcodear: la
  /// misma derivación da `wss://` sobre HTTPS en producción — Pitfall 8).
  /// Merguea el query del path (`restaurante_id` del super_admin) con el
  /// token — `Uri.replace(queryParameters:)` solo sobreescribiría.
  Uri _wsUri(String path, {required String token}) {
    final wsBase = Env.apiBaseUrl.replaceFirst('http', 'ws'); // http→ws|https→wss
    final uri = Uri.parse('$wsBase$path');
    return uri.replace(
      queryParameters: {...uri.queryParameters, 'token': token},
    );
  }

  /// Conecta a [path] (`/ws/staff[?restaurante_id=]`). Idempotente por path:
  /// si ya hay canal vivo al MISMO path → no-op (el provider puede rebuild).
  Future<void> connect(String path) async {
    if (_disposed) return;
    if (_path == path && _channel != null) return;
    if (_channel != null) disconnect(); // path distinto → corta el anterior

    final gen = ++_gen;

    // Token FRESCO por intento — JAMÁS cachear en campo (expira a 15 min).
    final token = await _storage.readAccess();
    if (token == null) return; // sin sesión: no conectar

    final channel = _connect(_wsUri(path, token: token));
    try {
      await channel.ready; // conecta o lanza
    } catch (e) {
      // 07-01: el rechazo del auth PRE-accept viaja como handshake HTTP 403
      // (el close code 4401 no cruza el handshake) — mismo caso → refresh.
      // En web el status es opaco: cae al backoff y el safety net refresca
      // el token (GET 401 → interceptor) para el próximo intento.
      if (_isAuthHandshakeError(e)) {
        unawaited(_onAuthClosed(path));
      } else {
        unawaited(_scheduleReconnect(path));
      }
      return;
    }
    if (_disposed || gen != _gen) {
      // Ciclo obsoleto: disconnect/cambio de room mientras conectaba.
      channel.sink.close().ignore();
      return;
    }

    _channel = channel;
    _path = path;
    _lastSeq = null; // reset: el re-sync GET reordena (seq por room)
    if (_failures > 0 && !_resync.isClosed) {
      _resync.add(null); // reconexión restablecida → señal de re-sync
    }
    _failures = 0;

    channel.stream.listen(
      (msg) {
        if (gen != _gen) return; // evento de un canal reemplazado
        final ev = WsEvent.fromJson(msg);
        // Dedup por seq: re-entregas no disparan un 2º GET kick-to-refetch.
        if (_lastSeq != null && ev.seq != null && ev.seq! <= _lastSeq!) return;
        _lastSeq = ev.seq;
        if (!_events.isClosed) _events.add(ev);
      },
      onDone: () {
        if (gen != _gen) return;
        if (_channel == channel) _channel = null; // muere → permitir reconnect
        if (channel.closeCode == 4401) {
          unawaited(_onAuthClosed(path));
        } else {
          unawaited(_scheduleReconnect(path));
        }
      },
      onError: (Object _) {
        if (gen != _gen) return;
        unawaited(_scheduleReconnect(path));
      },
    );
  }

  static bool _isAuthHandshakeError(Object e) =>
      e.toString().contains('403') || e.toString().contains('401');

  /// Backoff + reintento. La generación capturada descarta reconexiones de
  /// ciclos obsoletos (cambio de restaurante/logout durante la espera).
  Future<void> _scheduleReconnect(String path) async {
    if (_disposed) return;
    _failures++;
    final gen = _gen;
    await Future<void>.delayed(_backoffBuilder(_failures));
    if (_disposed || gen != _gen) return;
    await connect(path);
  }

  /// Close 4401 / handshake 401-403: refresh + retry inmediato (sin backoff).
  Future<void> _onAuthClosed(String path) async {
    if (_disposed) return;
    final token = await _api.refreshTokens(); // Completer anti-storm interno
    if (token == null) return; // sesión muerta: logout ya disparado upstream
    await connect(path); // lee el token FRESCO que refreshTokens persistió
  }

  /// Cierra el canal actual. Los StreamControllers PERMANECEN abiertos: el
  /// WsClient vive toda la sesión del panel (solo [dispose] los cierra).
  void disconnect() {
    _gen++; // invalida reconexiones pendientes de este ciclo
    final ch = _channel;
    _channel = null;
    _path = null;
    ch?.sink.close().ignore(); // silent
  }

  /// Teardown de app (nunca en el ciclo sesión/room).
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    disconnect();
    _events.close();
    _resync.close();
  }
}

/// WsClient de sesión (keepAlive: los Provider manuales de Riverpod 3 no son
/// autoDispose por defecto — vive toda la sesión del panel).
final wsClientProvider = Provider<WsClient>((ref) {
  return WsClient(ref.read(authStorageProvider), ref.read(apiClientProvider));
});

/// Ciclo de vida de la conexión WS del panel:
///  * login (authState → User) → connect a `/ws/staff` (super_admin con
///    `?restaurante_id=` del dropdown).
///  * cambio de dropdown super_admin → rebuild → dispose (disconnect) +
///    connect al room nuevo.
///  * logout (authState → null) → dispose → disconnect.
///
/// Los providers de features NUNCA consumen esto directo: leen
/// [wsEventsProvider]/[wsResyncProvider].
final wsConnectionProvider = Provider<WsClient>((ref) {
  final client = ref.watch(wsClientProvider);
  final user = ref.watch(authStateProvider).value;
  final selectedRid = ref.watch(currentRestauranteIdProvider);
  final rid = selectedRid ?? user?.restaurantId;
  if (user != null && rid != null) {
    final path =
        user.isSuperAdmin ? '/ws/staff?restaurante_id=$rid' : '/ws/staff';
    unawaited(client.connect(path));
  }
  ref.onDispose(() => client.disconnect());
  return client;
});

/// Stream broadcast de eventos del room del restaurante activo.
final wsEventsProvider = Provider<Stream<WsEvent>>(
  (ref) => ref.watch(wsConnectionProvider).events,
);

/// Señal de re-sync (reconexión restablecida tras fallos).
final wsResyncProvider = Provider<Stream<void>>(
  (ref) => ref.watch(wsConnectionProvider).resync,
);
