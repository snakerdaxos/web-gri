import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gri_panel_admin/app.dart';
import 'package:gri_panel_admin/core/firebase_providers.dart';
import 'package:gri_panel_admin/features/dashboard/dashboard_screen.dart';
import 'package:gri_panel_admin/features/equipo/equipo_provider.dart';
import 'package:gri_panel_admin/features/equipo/equipo_screen.dart';

import '../helpers/firebase_fakes.dart';

/// Gating por rol de `/equipo` (11-10, Tarea 3).
///
/// ⚠️ ESTO NO ES SEGURIDAD, Y EL TEST NO DEBE HACER CREER QUE LO ES.
/// El ítem del sidebar y el `redirect` del router son CORTESÍA: evitan que un
/// mesero se tropiece con una pantalla que no le sirve. La seguridad real son
/// (a) `firestore.rules`, que solo deja listar `usuarios` al
/// `admin_restaurante` de ese rid, y (b) la callable `crearUsuarioStaff`, que
/// decide el alta en el servidor. Las dos tienen su propia suite contra
/// emuladores.
///
/// Los casos montan `GriApp`, que resuelve el `goRouterProvider` REAL. Pumpear
/// `EquipoScreen` suelta pasaría en verde con el router sin cablear.
void main() {
  late StreamController<User?> ctrl;
  late ProviderContainer container;

  Future<void> montar(
    WidgetTester tester, {
    required String role,
    String? rid,
  }) async {
    tester.view.physicalSize = const Size(1000, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    // DEUDA PREEXISTENTE, NO DE ESTE PLAN (heredado de
    // bootstrap_router_test.dart): el Row del logo del sidebar desborda a
    // cualquier ancho. Se filtra SOLO el desborde de RenderFlex; cualquier
    // otra excepción sigue haciendo fallar el test.
    final onErrorPrevio = FlutterError.onError;
    FlutterError.onError = (details) {
      if (details.exceptionAsString().contains('A RenderFlex overflowed')) {
        return;
      }
      onErrorPrevio?.call(details);
    };
    addTearDown(() => FlutterError.onError = onErrorPrevio);

    ctrl = StreamController<User?>.broadcast();
    final db = await buildFakeFirestoreConSeed();
    container = ProviderContainer(overrides: [
      authStateChangesProvider.overrideWith((ref) => ctrl.stream),
      firestoreProvider.overrideWithValue(db),
      firebaseAuthProvider.overrideWithValue(MockFirebaseAuth()),
      claimsProvider.overrideWith((ref) async => (role: role, rid: rid)),
      // El listado no es lo que se prueba aquí; se fija para que la pantalla
      // no dependa de la forma del seed.
      equipoProvider.overrideWith((ref) async => const <MiembroEquipo>[]),
    ]);
    addTearDown(() {
      container.dispose();
      ctrl.close();
    });

    await tester.pumpWidget(
      UncontrolledProviderScope(container: container, child: const GriApp()),
    );
    await tester.pumpAndSettle();
    // Sesión abierta: sin esto el guard manda todo a /login y los casos de rol
    // pasarían por el motivo equivocado.
    ctrl.add(MockUser(uid: 'u-$role', email: '$role@demo.gri.dev'));
    await tester.pumpAndSettle();
  }

  group('ítem "Equipo" del sidebar', () {
    testWidgets('VISIBLE para admin_restaurante', (tester) async {
      await montar(tester, role: 'admin_restaurante', rid: 'demo');
      expect(find.text('Equipo'), findsOneWidget);
    });

    testWidgets('VISIBLE para super_admin', (tester) async {
      await montar(tester, role: 'super_admin');
      expect(find.text('Equipo'), findsOneWidget);
    });

    testWidgets('OCULTO para mesero', (tester) async {
      await montar(tester, role: 'mesero', rid: 'demo');
      expect(find.text('Equipo'), findsNothing);
      // No se ocultó el sidebar entero por accidente. Se comprueba con
      // 'Configuración' y NO con 'Dashboard': ese texto sale DOS veces
      // (ítem del sidebar + título del topbar en '/') y el aserto habría
      // fallado por un motivo que no tiene nada que ver con el gating.
      expect(find.text('Configuración'), findsOneWidget);
    });

    testWidgets('OCULTO para cocina', (tester) async {
      await montar(tester, role: 'cocina', rid: 'demo');
      expect(find.text('Equipo'), findsNothing);
      expect(find.text('Configuración'), findsOneWidget);
    });
  });

  group('redirect de /equipo (el que impide llegar por URL en web)', () {
    testWidgets('un mesero que escribe /equipo acaba en /', (tester) async {
      await montar(tester, role: 'mesero', rid: 'demo');

      container.read(goRouterProvider).go('/equipo');
      await tester.pumpAndSettle();

      expect(find.byType(EquipoScreen), findsNothing);
      expect(find.byType(DashboardScreen), findsOneWidget);
    });

    testWidgets('cocina igual', (tester) async {
      await montar(tester, role: 'cocina', rid: 'demo');

      container.read(goRouterProvider).go('/equipo');
      await tester.pumpAndSettle();

      expect(find.byType(EquipoScreen), findsNothing);
      expect(find.byType(DashboardScreen), findsOneWidget);
    });

    testWidgets('EL CONTRARIO: un admin_restaurante SÍ entra a /equipo',
        (tester) async {
      // Sin este caso, un redirect que expulsara a TODO el mundo dejaría los
      // dos anteriores en verde y la funcionalidad rota.
      await montar(tester, role: 'admin_restaurante', rid: 'demo');

      container.read(goRouterProvider).go('/equipo');
      await tester.pumpAndSettle();

      expect(find.byType(EquipoScreen), findsOneWidget);
    });

    testWidgets('y un super_admin también', (tester) async {
      await montar(tester, role: 'super_admin');

      container.read(goRouterProvider).go('/equipo');
      await tester.pumpAndSettle();

      expect(find.byType(EquipoScreen), findsOneWidget);
    });
  });
}
