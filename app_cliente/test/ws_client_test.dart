import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gri_cliente/core/api_client.dart';
import 'package:gri_cliente/core/auth_storage.dart';
import 'package:gri_cliente/core/ws_client.dart';
import 'package:stream_channel/stream_channel.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

/// Tests del WsClient del cliente (RT-03): dedup por seq, reconexión con
/// resync, 4401 → refresh → retry inmediato, refresh fallido sin reconnect
/// y token ausente sin conexión.
///
/// Sin delays reales: backoffBuilder inyectado en 1ms; los settles son
/// microtasks + ~30ms (criterio del plan: nada >100ms).

Future<void> _settle([int ms = 30]) =>
    Future<void>.delayed(Duration(milliseconds: ms));

/// Storage fake: el token sale de un setter (para test de token ausente).
class FakeAuthStorage extends AuthStorage {
  String? token;

  @override
  Future<String?> readAccess() async => token;
}

/// ApiClient fake: cuenta refreshTokens() y decide su resultado.
/// (El constructor real de ApiClient solo arma el Dio — cero red.)
class FakeApiClient extends ApiClient {
  FakeApiClient() : super(dio: Dio(BaseOptions(baseUrl: 'http://localhost:9')));

  int refreshCalls = 0;
  String? refreshResult = 'tok-nuevo';

  @override
  Future<String?> refreshTokens() async {
    refreshCalls++;
    return refreshResult;
  }
}

/// Sink no-op: el server descarta el entrante (receive loop de 07-01), el
/// WsClient jamás envía — solo `sink.close()` en disconnect/dispose.
class _NoopSink implements WebSocketSink {
  @override
  Future close([int? closeCode, String? closeReason]) async {}

  @override
  void add(Object? data) {}

  @override
  void addError(Object error, [StackTrace? stackTrace]) {}

  @override
  Future addStream(Stream stream) async {}

  @override
  Future get done => Future.value();
}

/// Canal fake: el test controla el inbound (broadcast) y setea el
/// [closeCode] ANTES de cerrar para simular el close frame del server.
///
/// web_socket_channel 3.0.3 declara `WebSocketChannel` como
/// `abstract interface class` (no extensible): el stub extiende
/// [StreamChannelMixin] para la superficie heredada (pipe/transform/cast…,
/// no usada por WsClient) e implementa la superficie que WsClient sí usa:
/// stream / sink / ready / closeCode / closeReason / protocol.
class FakeWebSocketChannel extends StreamChannelMixin<dynamic>
    implements WebSocketChannel {
  FakeWebSocketChannel(this.inbound);

  /// Eventos que "llegan del server" — el test hace inbound.add(json).
  final StreamController<String> inbound;

  @override
  int? closeCode;

  @override
  Stream get stream => inbound.stream;

  @override
  WebSocketSink get sink => _NoopSink();

  @override
  Future<void> get ready async {}

  @override
  String? get protocol => null;

  @override
  String? get closeReason => null;

  /// Simula el cierre del server (onDone del lado del WsClient).
  Future<void> close() => inbound.close();
}

/// Montaje completo del WsClient con seams inyectados.
class _Harness {
  _Harness() {
    client = WsClient(
      storage,
      api,
      connect: (uri) async {
        final c = FakeWebSocketChannel(StreamController<String>.broadcast());
        channels.add(c);
        return c;
      },
      backoffBuilder: (_) => const Duration(milliseconds: 1),
    );
  }

  final storage = FakeAuthStorage()..token = 'tok';
  final api = FakeApiClient();
  late final WsClient client;

  /// Un FakeWebSocketChannel por intento de conexión (counter de connects).
  final channels = <FakeWebSocketChannel>[];

  int get connectCalls => channels.length;
  FakeWebSocketChannel get active => channels.last;

  Future<void> connect() => client.connect('/ws/cliente');

  /// Evento tal cual lo envía el backend (contrato 07-01) — ejercita
  /// WsEvent.fromJson de paso.
  void emit(String type, int seq) {
    active.inbound.add(jsonEncode({
      'type': type,
      'restaurante_id': null,
      'seq': seq,
      'ts': '2026-08-14T12:00:00Z',
      'data': const <String, dynamic>{},
    }));
  }
}

void main() {
  test('dedup: seq re-entregado NO se re-emite (RT-03)', () async {
    final h = _Harness();
    addTearDown(h.client.dispose);
    await h.connect();

    final emitted = <WsEvent>[];
    final sub = h.client.events.listen(emitted.add);

    h.emit('pedido.creado', 1);
    h.emit('pedido.estado', 2);
    h.emit('pedido.estado', 3);
    await _settle();
    expect(emitted.map((e) => e.seq), const [1, 2, 3]);

    // Re-entrega del seq 2 (eco/duplicado) → ignorada por lastSeq=3.
    h.emit('pedido.estado', 2);
    await _settle();
    expect(emitted.map((e) => e.seq), const [1, 2, 3]);
    await sub.cancel();
  });

  test('reconexión tras onDone: re-connect + resync (solo si hubo fallo)',
      () async {
    final h = _Harness();
    addTearDown(h.client.dispose);

    final resyncs = <void>[];
    final sub = h.client.resync.listen(resyncs.add);

    await h.connect();
    expect(h.connectCalls, 1);
    expect(resyncs, isEmpty, reason: 'conexión limpia: sin resync inicial');

    await h.channels.first.close(); // server down → onDone
    await _settle();

    expect(h.connectCalls, 2, reason: 'backoff 1ms inyectado → reintenta');
    expect(resyncs.length, 1,
        reason: 'reconexión exitosa TRAS fallo → señal de re-sync');
    await sub.cancel();
  });

  test('close 4401 → refreshTokens + retry inmediato', () async {
    final h = _Harness();
    addTearDown(h.client.dispose);
    await h.connect();

    h.channels.first.closeCode = 4401; // token expirado (contrato 07-01)
    await h.channels.first.close();
    await _settle();

    expect(h.api.refreshCalls, 1, reason: 'el 4401 disparó el refresh');
    expect(h.connectCalls, 2, reason: 'refresh OK → retry YA (sin backoff)');
  });

  test('close 4401 con refresh fallido → NO reconecta (logout delegado)',
      () async {
    final h = _Harness()..api.refreshResult = null;
    addTearDown(h.client.dispose);
    await h.connect();

    h.channels.first.closeCode = 4401;
    await h.channels.first.close();
    await _settle();

    expect(h.api.refreshCalls, 1);
    expect(h.connectCalls, 1,
        reason: 'refresh null → sesión muerta → el logout existente manda');
  });

  test('token ausente → connect no intenta ninguna conexión', () async {
    final h = _Harness()..storage.token = null;
    addTearDown(h.client.dispose);

    await h.connect();
    await _settle();

    expect(h.connectCalls, 0);
  });
}
