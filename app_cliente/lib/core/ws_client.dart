import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import 'api_client.dart';
import 'auth_storage.dart';
import 'env.dart';
import 'token_provider.dart';

/// Un evento WS del backend (contrato 07-01):
/// `{"type": str, "restaurante_id": int|null, "seq": int, "ts": str, "data": dict}`.
///
/// El campo [seq] es monotónico POR ROOM y sirve para dedup client-side;
/// [data] es mínimo (ids + estado) porque la estrategia es kick-to-refetch.
class WsEvent {
  const WsEvent({required this.type, required this.seq, required this.data});

  factory WsEvent.fromJson(String raw) {
    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    return WsEvent(
      type: decoded['type'] as String,
      seq: decoded['seq'] as int?,
      data: (decoded['data'] as Map<String, dynamic>?) ?? const {},
    );
  }

  final String type;
  final int? seq;
  final Map<String, dynamic> data;
}

/// Close code app-defined del backend: token inválido/expirado (07-01).
const int _kCloseUnauthorized = 4401;

typedef WsConnectFn = Future<WebSocketChannel> Function(Uri uri);
typedef WsBackoffBuilder = Duration Function(int failures);

Future<WebSocketChannel> _defaultConnect(Uri uri) async =>
    WebSocketChannel.connect(uri);

/// Backoff exponencial 1→2→4→8→16→30s cap ×2 + jitter 0-500ms
/// (anti reconnect-storm). El seam [WsBackoffBuilder] permite a los tests
/// inyectar 1ms (suite sin esperas reales).
Duration _defaultBackoff(int failures) {
  final base = min(30000, 1000 * pow(2, failures - 1).toInt());
  return Duration(milliseconds: base + Random().nextInt(500));
}

/// Cliente WebSocket resiliente (RT-03) — copia del patrón core/ del
/// proyecto (idéntico conceptualmente al de panel_admin; path /ws/cliente).
///
/// Responsabilidades:
///  * Token FRESCO leído del [AuthStorage] en CADA intento de conexión
///    (el access expira en 15 min — jamás se cachea en un campo).
///  * `await channel.ready` — el fallo de handshake cae al backoff.
///  * Reconexión con backoff 1→30s ×2 + jitter.
///  * Dedup por [seq]: `seq <= lastSeq` se ignora; `lastSeq` se resetea al
///    (re)conectar (el GET de re-sync reordena el mundo).
///  * `resync` stream: emite SOLO cuando una conexión exitosa viene tras un
///    fallo previo → los providers re-sincronizan con GET.
///  * Close 4401 → `api.refreshTokens()` → retry inmediato; refresh fallido
///    (null) → NO reconecta (logout delegado al flujo existente).
///  * `disconnect()` cierra el canal y MANTIENE los controllers (re-conectable);
///    `dispose()` es final.
class WsClient {
  WsClient(
    this._storage,
    this._api, {
    WsConnectFn? connect,
    WsBackoffBuilder? backoffBuilder,
  })  : _connect = connect ?? _defaultConnect,
        _backoffBuilder = backoffBuilder ?? _defaultBackoff;

  final AuthStorage _storage;
  final ApiClient _api;
  final WsConnectFn _connect;
  final WsBackoffBuilder _backoffBuilder;

  final _events = StreamController<WsEvent>.broadcast();

  /// Eventos entrantes (post-dedup por seq).
  Stream<WsEvent> get events => _events.stream;

  final _resync = StreamController<void>.broadcast();

  /// Se dispara al RESTABLECER una conexión que había fallado → re-sync GET.
  Stream<void> get resync => _resync.stream;

  WebSocketChannel? _channel;
  StreamSubscription<dynamic>? _sub;
  String? _path;
  int _failures = 0;
  int? _lastSeq;
  bool _disposed = false;

  /// `ws(s)://` derivado del `http(s)://` de [Env.apiBaseUrl] — misma infra
  /// dev/prod, nunca hardcodeado (Pitfall 8 del research 07).
  static Uri _wsUri(String path) => Uri.parse(
        '${Env.apiBaseUrl.replaceFirst('https://', 'wss://').replaceFirst('http://', 'ws://')}$path',
      );

  /// Conecta a [path] (p. ej. `/ws/cliente`). Idempotente mientras viva la
  /// conexión actual; el token se lee FRESCO en cada llamada.
  Future<void> connect(String path) async {
    if (_disposed || _channel != null) return;
    _path = path;

    final token = await _storage.readAccess(); // FRESCO (TTL 15 min)
    if (token == null) return; // sin sesión: no conectar (AuthState manda)
    if (_disposed || _channel != null) return;

    final uri = _wsUri(path).replace(queryParameters: {'token': token});
    final WebSocketChannel channel;
    try {
      channel = await _connect(uri);
      await channel.ready; // handshake: conecta o lanza
    } catch (_) {
      await _scheduleReconnect();
      return;
    }
    if (_disposed) {
      await channel.sink.close();
      return;
    }

    _channel = channel;
    _lastSeq = null; // reset dedup: el re-sync GET es la nueva base
    if (_failures > 0) _resync.add(null); // reconexión → re-sync
    _failures = 0;

    _sub = channel.stream.listen(
      (msg) {
        final ev = WsEvent.fromJson(msg as String);
        if (_lastSeq != null && ev.seq != null && ev.seq! <= _lastSeq!) {
          return; // dedup: re-entrega o eco con seq viejo
        }
        _lastSeq = ev.seq;
        _events.add(ev);
      },
      onDone: () => _onClosed(channel),
      onError: (_) => _onClosed(channel),
      cancelOnError: true,
    );
  }

  /// Canal cerrado (server down / red cayó / 4401). El [channel] parámetro
  /// distingue el canal viejo de uno nuevo (reconexiones superpuestas).
  Future<void> _onClosed(WebSocketChannel channel) async {
    if (!identical(channel, _channel)) return; // cierre de canal reemplazado
    _channel = null;
    await _sub?.cancel();
    _sub = null;
    if (_disposed) return;

    if (channel.closeCode == _kCloseUnauthorized) {
      // 4401 = token expirado → refresh (Completer anti-storm del ApiClient)
      // → retry YA, sin backoff (flujo más ejercitado en producción).
      final token = await _api.refreshTokens();
      if (token == null) return; // sesión muerta → logout existente
      await connect(_path!);
      return;
    }
    await _scheduleReconnect();
  }

  Future<void> _scheduleReconnect() async {
    if (_disposed) return;
    _failures++;
    await Future.delayed(_backoffBuilder(_failures));
    if (_disposed || _path == null) return;
    await connect(_path!);
  }

  /// Cierra el canal (si vive) y MANTIENE los controllers — re-conectable
  /// con un nuevo `connect()` (logout/login dentro de la misma vida del app).
  Future<void> disconnect() async {
    await _sub?.cancel();
    _sub = null;
    final channel = _channel;
    _channel = null;
    await channel?.sink.close();
  }

  /// Final: canal + controllers. Solo al desechar la app.
  void dispose() {
    _disposed = true;
    unawaited(disconnect());
    unawaited(_events.close());
    unawaited(_resync.close());
  }
}

/// Singleton de la app — vive todo el ciclo de vida del proceso.
final wsClientProvider = Provider<WsClient>((ref) {
  final client = WsClient(
    ref.watch(authStorageProvider),
    ref.watch(apiClientProvider),
  );
  ref.onDispose(client.dispose);
  return client;
});

/// Ciclo de vida de la conexión: vive CON la sesión del usuario (manual
/// Provider → keepAlive). Re-watchea [authStateProvider]: login → connect a
/// `/ws/cliente` (room `user:{id}` server-side — el cliente NUNCA especifica
/// restaurante: privacidad, no ve pedidos de otros comensales); logout →
/// disconnect.
///
/// Quien quiera eventos/events o resync watchea [wsEventsProvider] /
/// [wsResyncProvider] — ellos mantienen viva esta conexión.
final wsConnectionProvider = Provider<WsClient>((ref) {
  final client = ref.watch(wsClientProvider);
  final user = ref.watch(authStateProvider).value;
  if (user != null) {
    unawaited(client.connect('/ws/cliente'));
  } else {
    unawaited(client.disconnect());
  }
  ref.onDispose(() => unawaited(client.disconnect()));
  return client;
});

/// Stream de eventos (post-dedup) — contrato para los kick-to-refetch.
final wsEventsProvider = Provider<Stream<WsEvent>>((ref) {
  ref.watch(wsConnectionProvider); // asegura conexión viva
  return ref.watch(wsClientProvider).events;
});

/// Señal de re-sync: se restableció una conexión que había fallado.
final wsResyncProvider = Provider<Stream<void>>((ref) {
  ref.watch(wsConnectionProvider); // asegura conexión viva
  return ref.watch(wsClientProvider).resync;
});
