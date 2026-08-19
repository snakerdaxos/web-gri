import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gri_panel_admin/core/firebase_providers.dart';
import 'package:gri_panel_admin/features/dashboard/dashboard_screen.dart';
import 'package:gri_panel_admin/features/dashboard/mesas_provider.dart';
import 'package:gri_panel_admin/features/dashboard/restaurante_provider.dart';
import 'package:gri_panel_admin/features/dashboard/stats_provider.dart';
import 'package:gri_panel_admin/models/dashboard_stats.dart';
import 'package:gri_panel_admin/models/mesa.dart';

import '../helpers/firebase_fakes.dart';

/// Tests del dashboard (ADMN-01 + 10-05 Task 3): stats DERIVADAS de los 3
/// streams (mesas por estado + reservas de hoy + pedidos activos — sin
/// endpoint), en vivo por onSnapshot, con aislamiento tenant; y el render
/// de las cards con los contratos de AsyncValue intactos.

DashboardStats _statsFixture() => const DashboardStats(
      mesasDisponibles: 3,
      mesasOcupadas: 2,
      mesasReservadas: 1,
      mesasLimpieza: 1,
      totalMesas: 7,
      reservasHoy: 5,
      pedidosActivos: 2,
    );

const _mesasFixture = <Mesa>[
  Mesa(
    id: 'GRI-MESA-demo-001',
    restauranteId: 'demo',
    numero: 1,
    capacidad: 4,
    estado: EstadoMesa.disponible,
  ),
  Mesa(
    id: 'GRI-MESA-demo-002',
    restauranteId: 'demo',
    numero: 2,
    capacidad: 2,
    estado: EstadoMesa.ocupada,
  ),
  Mesa(
    id: 'GRI-MESA-demo-003',
    restauranteId: 'demo',
    numero: 3,
    capacidad: 6,
    estado: EstadoMesa.reservada,
  ),
];

/// Container de unidad con fakes + claims staff (retiene los autoDispose).
ProviderContainer _container(FakeFirebaseFirestore db) {
  final container = ProviderContainer(overrides: [
    firestoreProvider.overrideWithValue(db),
    claimsProvider.overrideWith(
      (ref) async => (role: 'admin_restaurante', rid: 'demo'),
    ),
  ]);
  addTearDown(container.dispose);
  return container;
}

/// Reserva con fecha Timestamp (doc shape de app_cliente 10-04).
Future<void> _reserva(
  FakeFirebaseFirestore db, {
  required DateTime fecha,
  String mesaId = 'GRI-MESA-demo-001',
  String estado = 'confirmada',
}) {
  return db.collection('reservas').add({
    'restauranteId': 'demo',
    'mesaId': mesaId,
    'usuarioId': 'uid-cli',
    'fecha': Timestamp.fromDate(fecha),
    'fechaStr': '',
    'hora': fecha.hour,
    'numPersonas': 2,
    'estado': estado,
    'createdAt': FieldValue.serverTimestamp(),
  });
}

/// Pedido (doc shape de app_cliente 10-04).
Future<void> _pedido(
  FakeFirebaseFirestore db, {
  required String estado,
  required DateTime createdAt,
}) {
  return db.collection('pedidos').add({
    'restauranteId': 'demo',
    'mesaId': 'GRI-MESA-demo-003',
    'sesionId': 'GRI-MESA-demo-003',
    'usuarioId': 'uid-cli',
    'clienteNombre': 'Carlos',
    'estado': estado,
    'items': [
      {'productoId': 'p1', 'nombre': 'Limonada', 'precio': 8000, 'cantidad': 1},
    ],
    'total': 8000,
    'createdAt': Timestamp.fromDate(createdAt),
    'updatedAt': Timestamp.fromDate(createdAt),
  });
}


/// [SeleccionRestaurante] con un valor inicial fijo — el notifier real
/// arranca en `null` y el AppShell (ausente en estos pumps sueltos) es quien
/// setea el default en producción.
class _SeleccionFija extends SeleccionRestaurante {
  _SeleccionFija(this.inicial);

  final String? inicial;

  @override
  String? build() => inicial;
}

/// Pump del dashboard con los providers REALES sobre un Firestore fake — a
/// diferencia de los tests de render de arriba (que overridean statsProvider y
/// mesasProvider), aquí se ejercita la cadena claims → ridActivo → stats.
Future<void> _pumpDashboard(
  WidgetTester tester,
  FakeFirebaseFirestore db, {
  required String role,
  String? rid,
  String? seleccion,
}) async {
  // 800 de ancho ⇒ el grid de stat cards cae a 1 columna (mismo camino que
  // los tests de render de arriba). A ~1140px el grid pasa a 4 columnas y
  // StatCard desborda 31px por su childAspectRatio 2.6: bug de responsive
  // PREEXISTENTE, ajeno a este plan (anotado en deferred-items.md).
  tester.view.physicalSize = const Size(800, 1800);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        firestoreProvider.overrideWithValue(db),
        claimsProvider.overrideWith((ref) async => (role: role, rid: rid)),
        seleccionRestauranteProvider.overrideWith(
          () => _SeleccionFija(seleccion),
        ),
      ],
      child: const MaterialApp(home: Scaffold(body: DashboardScreen())),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  // ── Derivación de los 3 streams ────────────────────────────────────────

  test(
      'stats derivadas: 3 disponibles/1 ocupada + 2 reservas hoy + 3 pedidos activos',
      () async {
    final db = await buildFakeFirestoreConSeed();
    // 4ª mesa del tenant OCUPADA (001-003 quedan disponibles del seed) —
    // doc nuevo, no update: el comentario del caso define 3+1=4 mesas.
    await db.doc('mesas/GRI-MESA-demo-004').set({
      'restauranteId': 'demo',
      'numero': 4,
      'capacidad': 2,
      'estado': 'ocupada',
      'updatedAt': FieldValue.serverTimestamp(),
    });
    // Mesa de OTRO tenant: NO cuenta (aislamiento).
    await db.doc('mesas/GRI-MESA-norte-001').set({
      'restauranteId': 'norte',
      'numero': 9,
      'capacidad': 2,
      'estado': 'ocupada',
      'updatedAt': FieldValue.serverTimestamp(),
    });

    // Horas FIJAS de hoy (12:00/14:00): `DateTime.now() + 2h` cruzaría la
    // medianoche si el test corre de noche y contaría una reserva de
    // "mañana" — misma aserción (2 dentro de hoy), sin flake.
    final hoy = DateTime.now();
    final mediodia = DateTime(hoy.year, hoy.month, hoy.day, 12, 0);
    await _reserva(db, fecha: mediodia); // hoy
    await _reserva(db, fecha: mediodia.add(const Duration(hours: 2))); // hoy
    await _reserva(db, fecha: mediodia.subtract(const Duration(days: 1))); // ayer

    final t = DateTime(2026, 8, 16, 13, 5);
    await _pedido(db, estado: 'enviado', createdAt: t);
    await _pedido(
        db, estado: 'aceptado', createdAt: t.add(const Duration(minutes: 1)));
    await _pedido(
        db,
        estado: 'en_preparacion',
        createdAt: t.add(const Duration(minutes: 2)));
    await _pedido(
        db, estado: 'servido', createdAt: t.add(const Duration(minutes: 3)));

    final container = _container(db);
    container.listen(statsProvider, (_, _) {});
    final stats = await container.read(statsProvider.future);

    expect(stats.mesasDisponibles, 3);
    expect(stats.mesasOcupadas, 1, reason: 'la mesa de norte NO cuenta');
    expect(stats.mesasReservadas, 0);
    expect(stats.mesasLimpieza, 0);
    expect(stats.totalMesas, 4, reason: '4 mesas del tenant demo');
    expect(stats.reservasHoy, 2, reason: 'la de ayer NO cuenta');
    expect(stats.pedidosActivos, 3, reason: 'servido no es activo');
  });

  test('stats en vivo: cambiar una mesa a ocupada re-emite el conteo',
      () async {
    final db = await buildFakeFirestoreConSeed();
    final container = _container(db);
    container.listen(statsProvider, (_, _) {});
    final inicial = await container.read(statsProvider.future);
    expect(inicial.mesasDisponibles, 3);
    expect(inicial.mesasOcupadas, 0);

    // Mutación por Firestore — nadie invalida nada: el onSnapshot deriva.
    await db.doc('mesas/GRI-MESA-demo-002').update({'estado': 'ocupada'});

    final segunda = await container.read(statsProvider.future);
    expect(segunda.mesasDisponibles, 2);
    expect(segunda.mesasOcupadas, 1);
    expect(segunda.totalMesas, 3);
  });

  // ── Render de las cards (contrato AsyncValue intacto) ──────────────────

  testWidgets('renders 4 stat cards with mock data', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          statsProvider.overrideWithValue(AsyncData(_statsFixture())),
          mesasProvider.overrideWithValue(const AsyncData(_mesasFixture)),
        ],
        child: const MaterialApp(home: DashboardScreen()),
      ),
    );
    await tester.pumpAndSettle();

    // Labels de los 4 cards presentes.
    expect(find.text('Mesas disponibles'), findsOneWidget);
    expect(find.text('Mesas ocupadas'), findsOneWidget);
    expect(find.text('Reservas hoy'), findsOneWidget);
    expect(find.text('Pedidos activos'), findsOneWidget);

    // Valores (3, 2, 5, 2 del fixture) — busca Text widgets con esos strings.
    expect(find.text('3'), findsOneWidget);
    expect(find.text('2'), findsNWidgets(2)); // ocupadas + pedidos activos
    expect(find.text('5'), findsOneWidget);

    // Mesas: tiles presentes con sus números.
    expect(find.text('Mesa 1'), findsOneWidget);
    expect(find.text('Mesa 2'), findsOneWidget);
    expect(find.text('Mesa 3'), findsOneWidget);
  });

  testWidgets('renders loading indicator while stats loading', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          statsProvider.overrideWithValue(const AsyncLoading()),
          mesasProvider.overrideWithValue(const AsyncData(_mesasFixture)),
        ],
        child: const MaterialApp(home: DashboardScreen()),
      ),
    );
    // No hacer pumpAndSettle: AsyncLoading infinito nunca se settle.
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsWidgets);
  });

  testWidgets('renders error message on stats error', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          statsProvider.overrideWithValue(
            AsyncError('boom', StackTrace.current),
          ),
          mesasProvider.overrideWithValue(const AsyncData(_mesasFixture)),
        ],
        child: const MaterialApp(home: DashboardScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('Error'), findsOneWidget);
    expect(find.text('Reintentar'), findsWidgets);
  });

  // ── Guía de arranque con la plataforma vacía (11-02 Tarea 3) ───────────
  //
  // El super_admin sin selección aterrizaba en un tablero de ceros con un
  // selector vacío y sin ninguna indicación de qué hacer — el "selector
  // muerto" que CONCERNS.md señala como parte del síntoma reportado.

  testWidgets(
      '(guía a) super_admin sin rid y con CERO restaurantes: guía de creación, '
      'no tarjetas en cero', (tester) async {
    final db = await buildFakeFirestoreVacio();
    await _pumpDashboard(tester, db, role: 'super_admin');

    expect(tester.takeException(), isNull);
    expect(find.text('Aún no hay restaurantes en la plataforma'), findsOneWidget);
    expect(
      find.textContaining('Configuración'),
      findsOneWidget,
      reason: 'la guía debe decir a dónde ir, no solo que no hay nada',
    );
    // Las tarjetas de estadísticas en cero NO se muestran.
    expect(find.text('Mesas disponibles'), findsNothing);
    expect(find.text('Pedidos activos'), findsNothing);
  });

  testWidgets(
      '(guía b) super_admin sin rid pero CON restaurantes: invita a elegir en '
      'el selector', (tester) async {
    final db = await buildFakeFirestoreConSeed();
    await _pumpDashboard(tester, db, role: 'super_admin');

    expect(tester.takeException(), isNull);
    expect(find.text('Selecciona un restaurante'), findsOneWidget);
    expect(find.textContaining('selector'), findsOneWidget);
    // Mensaje DISTINTO del de plataforma vacía.
    expect(find.text('Aún no hay restaurantes en la plataforma'), findsNothing);
    expect(find.text('Mesas disponibles'), findsNothing);
  });

  testWidgets(
      '(guía c) admin_restaurante (rid por claims): dashboard normal, sin guía',
      (tester) async {
    final db = await buildFakeFirestoreConSeed();
    await _pumpDashboard(tester, db, role: 'admin_restaurante', rid: 'demo');

    expect(tester.takeException(), isNull);
    expect(find.text('Mesas disponibles'), findsOneWidget);
    expect(find.text('Pedidos activos'), findsOneWidget);
    expect(find.text('Aún no hay restaurantes en la plataforma'), findsNothing);
    expect(find.text('Selecciona un restaurante'), findsNothing);
  });

  testWidgets(
      '(guía d) super_admin CON restaurante seleccionado: dashboard normal',
      (tester) async {
    final db = await buildFakeFirestoreConSeed();
    await _pumpDashboard(tester, db, role: 'super_admin', seleccion: 'demo');

    expect(tester.takeException(), isNull);
    expect(find.text('Mesas disponibles'), findsOneWidget);
    expect(find.text('Mesa 1'), findsOneWidget, reason: 'mapa de mesas del seed');
    expect(find.text('Aún no hay restaurantes en la plataforma'), findsNothing);
    expect(find.text('Selecciona un restaurante'), findsNothing);
  });
}
