import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gri_panel_admin/core/api_client.dart';
import 'package:gri_panel_admin/core/token_provider.dart';
import 'package:gri_panel_admin/core/ws_client.dart';
import 'package:gri_panel_admin/features/cocina/pedidos_staff_provider.dart';
import 'package:gri_panel_admin/features/dashboard/restaurante_provider.dart';
import 'package:gri_panel_admin/models/pedido_staff.dart';
import 'package:gri_panel_admin/models/user.dart';

/// Tests del kick-to-refetch WS sobre [pedidosStaffProvider] (07-02, RT-01).
///
/// La cola de cocina se actualiza sola: pedido.creado/pedido.estado/
/// sesion.cuenta/mesa.estado disparan un GET refresh (el evento JAMÁS muta
/// la cola local). Tipos irrelevantes (sesion.abierta) no hacen nada.
///
/// Nota: mesa.estado SÍ refresca la cola (acción del plan 07-02 + research
/// Pattern 6: la cola re-ordena si la mesa cambia). Sesión.abierta llega al
/// room staff pero no afecta la cola → irrelevante.
///
/// Andamiaje sin red (patrón cola_test): ApiClient contador + fake AuthState
/// + rid fijo + streams WS controlados. NUNCA sockets reales. Riverpod 3.4.2
/// no exporta `Override` → ProviderContainer inline.

class _FakeAuthState extends AuthState {
  _FakeAuthState(this.user);

  final User? user;

  @override
  Future<User?> build() async => user;
}

class _FixedRid extends CurrentRestauranteId {
  _FixedRid(this.rid);

  final int? rid;

  @override
  int? build() => rid;
}

/// ApiClient contador — retorna una lista FRESCA por llamada (dos `[]` son
/// instancias distintas para ==, así Riverpod no dedupe el AsyncValue y los
/// listeners sí se notifican por cada re-fetch).
class _CountingPedidosClient extends ApiClient {
  int pedidosCalls = 0;

  @override
  Future<List<PedidoStaff>> getPedidosActivos({int? restauranteId}) async {
    pedidosCalls++;
    return [];
  }
}

const _staffUser = User(
  id: 9,
  nombre: 'Cocina Demo',
  email: 'cocina@demo.gri.dev',
  role: 'cocina',
  restaurantId: 1,
);

void main() {
  test('(4) pedido.creado/estado/sesion.cuenta → un GET por evento', () async {
    final client = _CountingPedidosClient();
    final events = StreamController<WsEvent>.broadcast();
    final container = ProviderContainer(
      overrides: [
        apiClientProvider.overrideWithValue(client),
        authStateProvider.overrideWith(() => _FakeAuthState(_staffUser)),
        currentRestauranteIdProvider.overrideWith(() => _FixedRid(1)),
        wsEventsProvider.overrideWithValue(events.stream),
        wsResyncProvider.overrideWithValue(const Stream<void>.empty()),
      ],
    );
    addTearDown(() {
      container.dispose();
      return events.close();
    });

    await container.read(authStateProvider.future);

    var valores = 0;
    final esperas = List.generate(4, (_) => Completer<void>());
    container.listen(pedidosStaffProvider, (_, next) {
      if (next.hasValue && valores < esperas.length) {
        final c = esperas[valores];
        if (!c.isCompleted) c.complete();
        valores++;
      }
    });
    await container.read(pedidosStaffProvider.future); // 1er valor → 1 GET
    expect(client.pedidosCalls, 1);

    // Deja que el generador reanude tras el yield y subscribe los streams
    // (un broadcast sin listener aún pierde el evento).
    await Future<void>.delayed(const Duration(milliseconds: 100));

    events.add(
      const WsEvent(type: 'pedido.creado', seq: 1, data: {'pedido_id': 10}),
    );
    await esperas[1].future.timeout(const Duration(seconds: 2));
    expect(client.pedidosCalls, 2, reason: 'pedido.creado → refetch');

    events.add(
      const WsEvent(
        type: 'pedido.estado',
        seq: 2,
        data: {'pedido_id': 10, 'estado': 'aceptado'},
      ),
    );
    await esperas[2].future.timeout(const Duration(seconds: 2));
    expect(client.pedidosCalls, 3, reason: 'pedido.estado → refetch');

    events.add(
      const WsEvent(type: 'sesion.cuenta', seq: 3, data: {'sesion_id': 5}),
    );
    await esperas[3].future.timeout(const Duration(seconds: 2));
    expect(client.pedidosCalls, 4, reason: 'sesion.cuenta → refetch');
  });

  test('(5) evento irrelevante (sesion.abierta) → NO refresca la cola', () async {
    final client = _CountingPedidosClient();
    final events = StreamController<WsEvent>.broadcast();
    final container = ProviderContainer(
      overrides: [
        apiClientProvider.overrideWithValue(client),
        authStateProvider.overrideWith(() => _FakeAuthState(_staffUser)),
        currentRestauranteIdProvider.overrideWith(() => _FixedRid(1)),
        wsEventsProvider.overrideWithValue(events.stream),
        wsResyncProvider.overrideWithValue(const Stream<void>.empty()),
      ],
    );
    addTearDown(() {
      container.dispose();
      return events.close();
    });

    await container.read(authStateProvider.future);

    // Listener que mantiene vivo el autoDispose provider (read solo no).
    container.listen(pedidosStaffProvider, (_, _) {});
    await container.read(pedidosStaffProvider.future);
    expect(client.pedidosCalls, 1);

    events.add(const WsEvent(type: 'sesion.abierta', seq: 4));
    await Future<void>.delayed(const Duration(milliseconds: 150));

    expect(client.pedidosCalls, 1, reason: 'tipo irrelevante no refresca');
  });
}
