// ============================================================================
// GRI — CERRAR SESIÓN en el panel (plan 11-34).
//
// ── EL HALLAZGO ───────────────────────────────────────────────────────────
// `LoginController.logout()` existe desde 10-05 y está bien escrito: hace
// `signOut()` e invalida `claimsProvider`, y el `refreshListenable` del router
// redirige a `/login`. Pero NINGÚN widget lo llamaba. Un grep de
// `logout`/`cerrarSesion` en todo `panel_admin/lib` no devolvía una sola
// llamada fuera del propio controlador.
//
// Consecuencia real: una vez dentro del panel no se podía salir salvo borrando
// los datos del navegador. El caso de uso de un panel de gestión es el equipo
// COMPARTIDO del restaurante, así que eso significa dejar la sesión del
// administrador abierta para quien se siente después.
//
// ── QUÉ AFIRMA ESTA SUITE ────────────────────────────────────────────────
// El RECORRIDO COMPLETO y no solo que el botón exista: pulsar → confirmación
// → `signOut` → el router redirige a `/login`. Un test que solo buscase el
// icono se quedaría verde con un `onPressed: () {}`.
//
// Se monta la app REAL (GriApp → goRouterProvider real → ShellRoute →
// AppShell), con los mismos dobles que ya usa `app_shell_layout_test.dart`:
// `authStateChangesProvider` sobre un StreamController que el test controla,
// para poder representar el momento exacto en que Auth emite null.
// ============================================================================

import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gri_panel_admin/app.dart';
import 'package:gri_panel_admin/core/firebase_providers.dart';
import 'package:gri_panel_admin/core/gri_icons.dart';

import '../helpers/firebase_fakes.dart';

/// Lo que el test necesita manipular después de montar.
typedef _Montaje = ({
  StreamController<User?> auth,
  MockFirebaseAuth mock,
});

void main() {
  Future<_Montaje> montar(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final ctrl = StreamController<User?>.broadcast();
    final mock = MockFirebaseAuth(
      signedIn: true,
      mockUser: MockUser(uid: 'u-admin', email: 'admin@demo.gri.dev'),
    );
    final db = await buildFakeFirestoreConSeed();
    final container = ProviderContainer(overrides: [
      authStateChangesProvider.overrideWith((ref) => ctrl.stream),
      firestoreProvider.overrideWithValue(db),
      firebaseAuthProvider.overrideWithValue(mock),
      claimsProvider.overrideWith(
        (ref) async => (role: 'admin_restaurante', rid: 'demo'),
      ),
    ]);
    addTearDown(() {
      container.dispose();
      ctrl.close();
    });

    await tester.pumpWidget(
      UncontrolledProviderScope(container: container, child: const GriApp()),
    );
    ctrl.add(MockUser(uid: 'u-admin', email: 'admin@demo.gri.dev'));
    await tester.pumpAndSettle(
      const Duration(milliseconds: 100),
      EnginePhase.sendSemanticsUpdate,
      const Duration(seconds: 30),
    );
    return (auth: ctrl, mock: mock);
  }

  testWidgets('el botón EXISTE en el topbar, con etiqueta y 48dp de área',
      (tester) async {
    await montar(tester);

    final boton = find.byWidgetPredicate(
      (w) => w is IconButton && w.tooltip == 'Cerrar sesión',
    );
    expect(boton, findsOneWidget,
        reason: 'el topbar es donde ya se muestra QUIÉN eres');

    // 48dp de área táctil MEDIDOS, no heredados de un default de Material que
    // puede cambiar.
    final tamano = tester.getSize(boton);
    expect(tamano.width, greaterThanOrEqualTo(48));
    expect(tamano.height, greaterThanOrEqualTo(48));

    // El icono lleva su propia etiqueta: sin ella el nodo pulsable sería
    // anónimo para un lector de pantalla.
    final icono = tester.widget<Icon>(
      find.descendant(of: boton, matching: find.byType(Icon)),
    );
    expect(icono.icon, GriIcons.cerrarSesion);
    expect(icono.semanticLabel, 'Cerrar sesión');
  });

  testWidgets('pulsar PIDE CONFIRMACIÓN y cancelar NO cierra la sesión',
      (tester) async {
    final m = await montar(tester);

    await tester.tap(find.byWidgetPredicate(
      (w) => w is IconButton && w.tooltip == 'Cerrar sesión',
    ));
    await tester.pumpAndSettle();

    expect(find.text('¿Cerrar sesión?'), findsOneWidget);
    expect(find.textContaining('perderás lo que no hayas guardado'),
        findsOneWidget);

    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();

    expect(find.text('¿Cerrar sesión?'), findsNothing);
    expect(m.mock.currentUser, isNotNull,
        reason: 'cancelar no puede tirar el trabajo a medias de un formulario');
  });

  testWidgets(
      'RECORRIDO COMPLETO: confirmar → signOut → el router redirige a /login',
      (tester) async {
    final m = await montar(tester);
    expect(m.mock.currentUser, isNotNull, reason: 'punto de partida: dentro');

    await tester.tap(find.byWidgetPredicate(
      (w) => w is IconButton && w.tooltip == 'Cerrar sesión',
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ElevatedButton, 'Cerrar sesión'));
    await tester.pumpAndSettle();

    // 1) La sesión de Auth se cerró de verdad. Esto es lo que un test que
    //    solo buscase el icono NO vería: con un `onPressed: () {}` el botón
    //    existiría igual.
    expect(m.mock.currentUser, isNull);

    // 2) Auth emite null y el `refreshListenable` del router saca al usuario.
    m.auth.add(null);
    await tester.pumpAndSettle(
      const Duration(milliseconds: 100),
      EnginePhase.sendSemanticsUpdate,
      const Duration(seconds: 30),
    );

    expect(find.text('Iniciar sesión'), findsWidgets,
        reason: 'la redirección a /login la hace el router, no la pantalla');
    expect(
      find.byWidgetPredicate(
        (w) => w is IconButton && w.tooltip == 'Cerrar sesión',
      ),
      findsNothing,
      reason: 'fuera del shell no hay topbar del que salir',
    );
  });
}
