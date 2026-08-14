import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:gri_panel_admin/core/api_client.dart';
import 'package:gri_panel_admin/core/auth_storage.dart';
import 'package:gri_panel_admin/core/ws_client.dart';
import 'package:stream_channel/stream_channel.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

/// Tests unitarios del [WsClient] (07-02, RT-03) con las seams inyectables
/// (factory de canal + backoffBuilder): NUNCA sockets reales.
///
/// Cubre: derivación ws:// + token/query mergeado por intento, idempotencia
/// por path, dedup por seq, close 4401 → refreshTokens → retry inmediato
/// (y refresh fallido → NO reconecta), y caída → backoff → reconexión con
/// señal de re-sync.

class _FakeStorage extends AuthStorage {
  _FakeStorage(this.access);

  String? access;

  @override
  Future<String?> readAccess() async => access;

  @override
  Future<String?> readRefresh() async => 'refresh-token';
}

class _FakeApi extends ApiClient {
  int refreshCalls = 0;
  String? refreshResult;

  @override
  Future<String?> refreshTokens() async {
    refreshCalls++;
    return refreshResult;
  }
}

class _FakeSink implements WebSocketSink {
  int closeCalls = 0;

  @override
  void add(dynamic event) {}

  @override
  void addError(Object error, [StackTrace? stackTrace]) {}

  @override
  Future<dynamic> addStream(Stream<dynamic> stream) async {}

  @override
  Future<dynamic> close([int? closeCode, String? closeReason]) async {
    closeCalls++;
  }

  @override
  Future<dynamic> get done async {}
}

/// Canal falso: ready completa (o falla) al construirse; [emit] inyecta
/// eventos JSON como el server; [closeWith] simula el close con código.
class _FakeChannel extends StreamChannelMixin<dynamic>
    implements WebSocketChannel {
  _FakeChannel({Object? readyError}) {
    if (readyError != null) {
      _ready.completeError(readyError);
    } else {
      _ready.complete();
    }
  }

  final _ctl = StreamController<dynamic>.broadcast();
  final _ready = Completer<void>();

  @override
  final sink = _FakeSink();

  @override
  int? closeCode;

  @override
  String? get closeReason => null;

  @override
  String? get protocol => null;

  @override
  Stream<dynamic> get stream => _ctl.stream;

  @override
  Future<void> get ready => _ready.future;

  void emit(String type, int? seq) {
    _ctl.add(jsonEncode({'type': type, 'seq': seq, 'data': const {}}));
  }

  Future<void> closeWith(int? code) async {
    closeCode = code;
    await _ctl.close();
  }
}

void main() {
  late _FakeStorage storage;
  late _FakeApi api;
  late List<_FakeChannel> channels;
  late List<Uri> uris;

  WsClient build() => WsClient(
        storage,
        api,
        connect: (uri) {
          uris.add(uri);
          final ch = _FakeChannel();
          channels.add(ch);
          return ch;
        },
        backoffBuilder: (_) => const Duration(milliseconds: 10),
      );

  setUp(() {
    storage = _FakeStorage('token-1');
    api = _FakeApi();
    channels = [];
    uris = [];
  });

  test('URI: scheme ws derivado de Env, token y query mergeados por intento',
      () async {
    final client = build();
    addTearDown(client.dispose);

    await client.connect('/ws/staff');
    await client.connect('/ws/staff?restaurante_id=3');

    expect(uris[0].isScheme('ws'), isTrue, reason: 'http→ws de Env');
    expect(uris[0].path, '/ws/staff');
    expect(uris[0].queryParameters['token'], 'token-1');

    // El replace(queryParameters) del ingenuo BORRARÍA restaurante_id —
    // el merge lo conserva.
    expect(uris[1].queryParameters, {'restaurante_id': '3', 'token': 'token-1'});
  });

  test('idempotente por path; sin token no conecta', () async {
    final client = build();
    addTearDown(client.dispose);

    await client.connect('/ws/staff');
    await client.connect('/ws/staff'); // mismo path + canal vivo → no-op
    expect(channels, hasLength(1));

    storage.access = null; // logout: sin sesión
    await client.connect('/ws/staff');
    expect(channels, hasLength(1), reason: 'token null → no conectar');
  });

  test('dedup: eventos con seq <= lastSeq se ignoran', () async {
    final client = build();
    addTearDown(client.dispose);

    final seqs = <int?>[];
    client.events.listen((e) => seqs.add(e.seq));

    await client.connect('/ws/staff');
    final ch = channels.single;

    ch.emit('mesa.estado', 5); // nuevo
    ch.emit('mesa.estado', 5); // duplicado
    ch.emit('pedido.creado', 4); // retrocedió (re-entrega)
    ch.emit('pedido.estado', 6); // nuevo
    await Future<void>.delayed(Duration.zero);

    expect(seqs, [5, 6], reason: 'solo seq estrictamente crecientes pasan');
  });

  test('close 4401 → refreshTokens → reconexión inmediata con token fresco',
      () async {
    final client = build();
    addTearDown(client.dispose);

    await client.connect('/ws/staff');
    storage.access = 'token-2'; // como si el refresh lo hubiera persistido
    api.refreshResult = 'token-2';

    await channels[0].closeWith(4401);
    await Future<void>.delayed(const Duration(milliseconds: 100));

    expect(api.refreshCalls, 1, reason: '4401 → un solo refresh (completer)');
    expect(channels, hasLength(2), reason: 'retry inmediato sin backoff');
    expect(uris[1].queryParameters['token'], 'token-2',
        reason: 'el retry lee el token FRESCO del storage');
  });

  test('close 4401 con refresh fallido (null) → NO reconecta', () async {
    final client = build();
    addTearDown(client.dispose);

    await client.connect('/ws/staff');
    api.refreshResult = null; // sesión muerta

    await channels[0].closeWith(4401);
    await Future<void>.delayed(const Duration(milliseconds: 100));

    expect(api.refreshCalls, 1);
    expect(channels, hasLength(1),
        reason: 'logout upstream ya disparado — nada que reconectar');
  });

  test('caída no-auth → backoff → reconexión → señal de re-sync', () async {
    final client = build();
    addTearDown(client.dispose);

    var resyncs = 0;
    client.resync.listen((_) => resyncs++);

    await client.connect('/ws/staff');
    expect(resyncs, 0, reason: 'la PRIMERA conexión no es re-sync');

    await channels[0].closeWith(null); // server cayó / red cortada
    await Future<void>.delayed(const Duration(milliseconds: 200));

    expect(channels, hasLength(2), reason: 'backoff → reconectó');
    expect(resyncs, 1, reason: 'reconexión restablecida → resync (RT-03)');
  });
}
