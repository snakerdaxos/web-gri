import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gri_panel_admin/core/api_client.dart';
import 'package:gri_panel_admin/core/token_provider.dart';
import 'package:gri_panel_admin/core/ws_client.dart';
import 'package:gri_panel_admin/features/dashboard/mesas_provider.dart';
import 'package:gri_panel_admin/features/dashboard/restaurante_provider.dart';
import 'package:gri_panel_admin/models/mesa.dart';
import 'package:gri_panel_admin/models/user.dart';

/// Tests del kick-to-refetch WS sobre [mesasProvider] (07-02, RT-02/RT-03).
///
/// El evento WS es SEÑAL, no estado: dispara un GET refresh y JAMÁS muta la
/// lista local. Verifica: evento relevante → re-fetch; evento irrelevante →
/// nada; resync (reconexión restablecida) → re-fetch.
///
/// Andamiaje sin red (patrón cola_test): ApiClient contador + fake
/// AuthState + rid fijo + wsEventsProvider como StreamController broadcast
/// controlado por el test. NUNCA sockets reales en el runner. Riverpod 3.4.2
/// no exporta `Override` → cada test inlinea su ProviderContainer.

class _FakeAuthState extends AuthState {
  _FakeAuthState(this.user);

  final User? user;

  @override
  Future<User?> build() async => user;
}

/// Fija el restaurante activo sin depender del build real (lee authState).
class _FixedRid extends CurrentRestauranteId {
  _FixedRid(this.rid);

  final int? rid;

  @override
  int? build() => rid;
}

class _CountingMesasClient extends ApiClient {
  int mesasCalls = 0;

  @override
  Future<List<Mesa>> getMesas({int? restauranteId}) async {
    mesasCalls++;
    return const [
      Mesa(
        id: 1,
        numero: 1,
        capacidad: 4,
        codigoQr: 'GRI-MESA-001',
        estado: EstadoMesa.disponible,
      ),
    ];
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
  test('(1) evento WS mesa.estado → GET re-fetch (kick-to-refetch)', () async {
    final client = _CountingMesasClient();
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

    // Resuelve authState ANTES de escuchar mesas: evita el rebuild
    // AsyncLoading→AsyncData que dispararía un 2º GET inicial espurio.
    await container.read(authStateProvider.future);

    var valores = 0;
    final segundo = Completer<void>();
    container.listen(mesasProvider, (_, next) {
      if (next.hasValue) {
        valores++;
        if (valores == 2 && !segundo.isCompleted) segundo.complete();
      }
    });
    await container.read(mesasProvider.future); // primer valor → 1 GET
    expect(client.mesasCalls, 1);

    // El evento SOLO es señal: el mapa no se muta localmente con el payload.
    events.add(
      const WsEvent(
        type: 'mesa.estado',
        seq: 1,
        data: {'mesa_id': 1, 'estado': 'ocupada'},
      ),
    );
    await segundo.future.timeout(const Duration(seconds: 2));

    expect(client.mesasCalls, 2, reason: 'el evento WS debe disparar un GET');
  });

  test('(2) evento irrelevante (reserva.creado) → NO hay nuevo GET', () async {
    final client = _CountingMesasClient();
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
    container.listen(mesasProvider, (_, __) {});
    await container.read(mesasProvider.future);
    expect(client.mesasCalls, 1);

    events.add(const WsEvent(type: 'reserva.creado', seq: 2));
    await Future<void>.delayed(const Duration(milliseconds: 150));

    expect(client.mesasCalls, 1, reason: 'tipo irrelevante no refresca nada');
  });

  test('(3) wsResync emite → GET re-fetch (re-sync tras reconexión)', () async {
    final client = _CountingMesasClient();
    final resync = StreamController<void>.broadcast();
    final container = ProviderContainer(
      overrides: [
        apiClientProvider.overrideWithValue(client),
        authStateProvider.overrideWith(() => _FakeAuthState(_staffUser)),
        currentRestauranteIdProvider.overrideWith(() => _FixedRid(1)),
        wsEventsProvider.overrideWithValue(const Stream<WsEvent>.empty()),
        wsResyncProvider.overrideWithValue(resync.stream),
      ],
    );
    addTearDown(() {
      container.dispose();
      return resync.close();
    });

    await container.read(authStateProvider.future);

    var valores = 0;
    final segundo = Completer<void>();
    container.listen(mesasProvider, (_, next) {
      if (next.hasValue) {
        valores++;
        if (valores == 2 && !segundo.isCompleted) segundo.complete();
      }
    });
    await container.read(mesasProvider.future);
    expect(client.mesasCalls, 1);

    resync.add(null); // reconexión restablecida → snapshot autoritativo
    await segundo.future.timeout(const Duration(seconds: 2));

    expect(client.mesasCalls, 2, reason: 'el resync debe disparar un GET');
  });
}
