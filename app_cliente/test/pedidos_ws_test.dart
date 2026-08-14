import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gri_cliente/core/api_client.dart';
import 'package:gri_cliente/core/ws_client.dart';
import 'package:gri_cliente/features/pedidos/pedidos_provider.dart';
import 'package:gri_cliente/features/sesion_qr/sesion_provider.dart';
import 'package:gri_cliente/models/pedido.dart';
import 'package:gri_cliente/models/pedido_item.dart';
import 'package:gri_cliente/models/sesion_mesa.dart';

/// Tests del pedidosSession en vivo (RT-01 cliente): evento WS →
/// kick-to-refetch (GET), y sesion.cerrada → invalidate de sesionProvider.
///
/// Patrón del proyecto: ProviderContainer inline con overrides (riverpod
/// 3.4.2 sin Override tipado — gotcha STATE.md).

Future<void> _settle([int ms = 50]) =>
    Future<void>.delayed(Duration(milliseconds: ms));

SesionMesa _sesion() => SesionMesa(
      id: 10,
      restauranteId: 1,
      restauranteNombre: 'Restaurante Demo GRI',
      mesaId: 3,
      mesaNumero: 3,
      abiertaEn: DateTime(2026, 8, 14, 12, 30),
      solicitaCuenta: false,
      solicitadaEn: null,
    );

Pedido _pedido(int id, String estado) => Pedido(
      id: id,
      sesionId: 10,
      mesaNumero: 3,
      estado: estado,
      total: 57000,
      notas: null,
      createdAt: DateTime(2026, 8, 14, 13, id),
      items: const [
        PedidoItem(
            productoId: 1,
            nombre: 'Pasta',
            cantidad: 2,
            precioUnitario: 25000,
            subtotal: 50000),
      ],
    );

/// ApiClient fake: cuenta los GET /cliente/pedidos/actual.
class _FakeApi extends ApiClient {
  _FakeApi() : super(dio: Dio(BaseOptions(baseUrl: 'http://localhost:9')));

  int getCalls = 0;

  @override
  Future<List<Pedido>> getPedidosActuales() async {
    getCalls++;
    return [_pedido(getCalls, 'enviado')];
  }
}

void main() {
  test('evento pedido.estado → kick-to-refetch (GET extra, sin mutación local)',
      () async {
    final api = _FakeApi();
    final ws = StreamController<WsEvent>.broadcast();
    final container = ProviderContainer(
      overrides: [
        apiClientProvider.overrideWithValue(api),
        sesionProvider.overrideWithValue(AsyncData(_sesion())),
        wsEventsProvider.overrideWithValue(ws.stream),
        wsResyncProvider.overrideWithValue(const Stream<void>.empty()),
      ],
    );
    addTearDown(container.dispose);
    addTearDown(ws.close);

    final valores = <List<Pedido>>[];
    container.listen(
      pedidosSessionProvider,
      (prev, next) => next.whenData(valores.add),
    );

    await _settle();
    expect(api.getCalls, 1, reason: 'GET inicial (snapshot)');
    expect(valores.length, 1);

    // El staff avanza el pedido → evento push → re-fetch automático.
    ws.add(const WsEvent(type: 'pedido.estado', seq: 2, data: {}));
    await _settle();
    expect(api.getCalls, 2, reason: 'kick-to-refetch por evento WS');
    expect(valores.length, 2);
  });

  test('sesion.cerrada → invalidate de sesionProvider (anti-zombi/pago)',
      () async {
    final api = _FakeApi();
    final ws = StreamController<WsEvent>.broadcast();
    var sesionViva = true;
    var sesionBuilds = 0;
    final container = ProviderContainer(
      overrides: [
        apiClientProvider.overrideWithValue(api),
        sesionProvider.overrideWith((ref) {
          sesionBuilds++;
          return sesionViva ? _sesion() : null; // 404 → null en producción
        }),
        wsEventsProvider.overrideWithValue(ws.stream),
        wsResyncProvider.overrideWithValue(const Stream<void>.empty()),
      ],
    );
    addTearDown(container.dispose);
    addTearDown(ws.close);

    container.listen(pedidosSessionProvider, (_, _) {});

    await _settle();
    expect(sesionBuilds, 1);
    expect(api.getCalls, 1);

    // Staff pasa la mesa a limpieza → anti-zombi cierra la sesión → push.
    sesionViva = false;
    ws.add(const WsEvent(type: 'sesion.cerrada', seq: 5, data: {}));
    await _settle();

    expect(sesionBuilds, 2,
        reason: 'ref.invalidate(sesionProvider) disparó el rebuild');
    expect(api.getCalls, greaterThanOrEqualTo(2),
        reason: 'el kick refetchea igual (sesión vieja posible)');

    // Reconstruido con sesión null → colapsó a Stream.empty: los eventos
    // posteriores ya NO disparan GETs.
    final trasColapso = api.getCalls;
    ws.add(const WsEvent(type: 'pedido.estado', seq: 6, data: {}));
    await _settle();
    expect(api.getCalls, trasColapso,
        reason: 'sin sesión no hay suscripción ni refetch');
  });
}
