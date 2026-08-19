// Tests del login del panel (Phase 10 — 10-05 Task 2): la suite cubre los
// 4 casos del plan — staff entra con su rid, super va al selector (sin
// rid hasta elegir), cliente RECHAZADO con sesión cerrada, y credenciales
// inválidas mapeadas — más la parity de validación pre-red (screen
// intacta). Claims se proveen con override directo del provider (patrón
// 10-02 — NO se mockea el token).
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gri_panel_admin/core/firebase_providers.dart';
import 'package:gri_panel_admin/features/auth/login_controller.dart';
import 'package:gri_panel_admin/features/auth/login_screen.dart';
import 'package:gri_panel_admin/features/dashboard/restaurante_provider.dart';
import 'package:gri_panel_admin/features/dashboard/restaurantes_list_provider.dart';
import 'package:gri_panel_admin/features/shared/password_field.dart';
import 'package:mock_exceptions/mock_exceptions.dart';

import '../helpers/firebase_fakes.dart';
/// Container con fakes + claims cableados (patrón firebase_fakes.dart).
ProviderContainer _container(
  MockFirebaseAuth auth,
  FakeFirebaseFirestore db, {
  ({String role, String? rid})? claims,
}) {
  final container = ProviderContainer(overrides: [
    firebaseAuthProvider.overrideWithValue(auth),
    firestoreProvider.overrideWithValue(db),
    if (claims != null) claimsProvider.overrideWith((ref) async => claims),
  ]);
  addTearDown(container.dispose);
  return container;
}

/// Riverpod 3: los providers reactivos son autoDispose — un `read`
/// sin listener deja que el scheduler los dispose a mitad del await.
/// Estos listen pasivos los retienen durante el test.
void _retenerStaff(ProviderContainer c) {
  c.listen(ridActivoProvider, (_, _) {});
  c.listen(restauranteActivoProvider, (_, _) {});
}

void _retenerSuper(ProviderContainer c) {
  c.listen(ridActivoProvider, (_, _) {});
  c.listen(restaurantesListProvider, (_, _) {});
}

Future<void> _fillForm(WidgetTester tester, String email, String password) async {
  await tester.enterText(find.byType(TextFormField).first, email);
  await tester.enterText(find.byType(TextFormField).last, password);
  await tester.pump();
}


/// El `TextField` interno del campo con esa key (el `PasswordField` envuelve
/// un `TextFormField`, que a su vez construye un `TextField`).
Finder _campo(Key k) =>
    find.descendant(of: find.byKey(k), matching: find.byType(TextField));

Finder _ojo(Key k) =>
    find.descendant(of: find.byKey(k), matching: find.byType(IconButton));

bool _obscuro(WidgetTester tester, Key k) =>
    tester.widget<TextField>(_campo(k)).obscureText;

IconData _iconoDe(WidgetTester tester, Key k) =>
    (tester.widget<IconButton>(_ojo(k)).icon as Icon).icon!;

void main() {
  // ── UI parity: validación pre-red (screen intacta) ─────────────────────

  testWidgets('form invalid email disables submit', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: LoginScreen())),
    );

    await _fillForm(tester, 'not-an-email', 'Demo!1234');

    final button = tester.widget<ElevatedButton>(find.byType(ElevatedButton));
    expect(button.onPressed, isNull, reason: 'email inválido debe deshabilitar el botón');
  });

  testWidgets('form short password disables submit', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: LoginScreen())),
    );

    await _fillForm(tester, 'admin@demo.gri.dev', 'abc');

    final button = tester.widget<ElevatedButton>(find.byType(ElevatedButton));
    expect(button.onPressed, isNull, reason: 'password < 8 chars debe deshabilitar el botón');
  });

  testWidgets('form valid enables submit', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: LoginScreen())),
    );

    await _fillForm(tester, 'admin@demo.gri.dev', 'Demo!1234');

    final button = tester.widget<ElevatedButton>(find.byType(ElevatedButton));
    expect(button.onPressed, isNotNull, reason: 'email válido + password 8+ chars habilita el botón');
  });

  // ── Caso 4: credenciales inválidas → mensaje mapeado ──────────────────

  testWidgets(
      'submit con credenciales inválidas → SnackBar "Credenciales inválidas"',
      (tester) async {
    final auth = mockAuth(signedIn: false);
    whenCalling(Invocation.method(#signInWithEmailAndPassword, null))
        .on(auth)
        .thenThrow(FirebaseAuthException(code: 'invalid-credential'));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [firebaseAuthProvider.overrideWithValue(auth)],
        child: const MaterialApp(home: LoginScreen()),
      ),
    );

    await _fillForm(tester, 'admin@demo.gri.dev', 'Demo!1234');
    await tester.tap(find.byType(ElevatedButton));
    await tester.pump();
    // Avanza la animación de entrada del SnackBar SIN pumpAndSettle para no
    // disparar el auto-dismiss (4s).
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Credenciales inválidas'), findsOneWidget);
    expect(auth.currentUser, isNull, reason: 'el login fallido no abre sesión');
  });

  // ── Caso 1: staff entra directo al dashboard de SU restaurante ────────

  test('login staff (mesero) → true y ridActivo == claims.rid (dashboard de su restaurante)',
      () async {
    final auth = mockAuth(email: 'mesero@demo.gri.dev', signedIn: false);
    final db = await buildFakeFirestoreConSeed();
    final container = _container(
      auth,
      db,
      claims: (role: 'mesero', rid: 'demo'),
    );

    final ok = await container
        .read(loginControllerProvider.notifier)
        .submit('mesero@demo.gri.dev', 'Demo!1234');

    expect(ok, isTrue);
    expect(auth.currentUser, isNotNull, reason: 'sesión iniciada');

    // El rid SIEMPRE viene de claims (nunca de un input libre).
    _retenerStaff(container);
    final rid = await container.read(ridActivoProvider.future);
    expect(rid, 'demo');

    // El topbar resuelve el nombre del doc restaurantes/{rid}.
    final activo = await container.read(restauranteActivoProvider.future);
    expect(activo?.nombre, 'Restaurante Demo GRI');
  });

  // ── Caso 2: super_admin va al selector (sin rid hasta elegir) ─────────

  test('login super_admin → true, sin rid hasta elegir (selector de restaurantes)',
      () async {
    final auth = mockAuth(email: 'super@demo.gri.dev', signedIn: false);
    final db = await buildFakeFirestoreConSeed();
    final container = _container(
      auth,
      db,
      claims: (role: 'super_admin', rid: null),
    );

    final ok = await container
        .read(loginControllerProvider.notifier)
        .submit('super@demo.gri.dev', 'Demo!1234');

    expect(ok, isTrue);

    // Sin elección → sin rid: las vistas de datos quedan vacías hasta que
    // el super elija (selector del topbar).
    _retenerSuper(container);
    final sinEleccion = await container.read(ridActivoProvider.future);
    expect(sinEleccion, isNull);

    // El selector solo ve restaurantes ACTIVOS (sur inactivo excluido).
    final lista = await container.read(restaurantesListProvider.future);
    expect(lista.map((r) => r.id), ['demo', 'norte']);

    // Al elegir, el rid activo sigue la selección.
    container.read(seleccionRestauranteProvider.notifier).set('norte');
    final conEleccion = await container.read(ridActivoProvider.future);
    expect(conEleccion, 'norte');
  });

  // ── Caso 3: cliente NO entra (defense UX del threat model) ────────────

  test('login cliente → rechazado con mensaje y sesión CERRADA', () async {
    final auth = mockAuth(email: 'carlos@demo.gri.dev');
    final db = await buildFakeFirestoreConSeed();
    final container = _container(
      auth,
      db,
      claims: (role: 'cliente', rid: null),
    );

    await expectLater(
      container
          .read(loginControllerProvider.notifier)
          .submit('carlos@demo.gri.dev', 'Demo!1234'),
      throwsA(isA<StateError>().having((e) => e.message, 'message',
          'Esta aplicación es solo para personal del restaurante')),
    );

    // La sesión NO queda abierta para un usuario sin rol staff/super.
    expect(auth.currentUser, isNull, reason: 'el rechazo hace signOut');
  });

  test('login staff sin rid en claims → rechazado (cuenta mal sembrada)',
      () async {
    final auth = mockAuth(email: 'cocina@demo.gri.dev', signedIn: false);
    final db = await buildFakeFirestoreConSeed();
    final container = _container(
      auth,
      db,
      claims: (role: 'cocina', rid: null),
    );

    await expectLater(
      container
          .read(loginControllerProvider.notifier)
          .submit('cocina@demo.gri.dev', 'Demo!1234'),
      throwsA(isA<StateError>().having(
          (e) => e.message, 'message', contains('restaurante asignado'))),
    );
    expect(auth.currentUser, isNull);
  });

  // -- 11-06: ver/ocultar la contraseña (unico campo de este tipo del panel) --

  testWidgets('login: la contraseña arranca OCULTA y ofrece el ojo para verla',
      (tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: LoginScreen())),
    );

    expect(_obscuro(tester, const ValueKey('login-password')), isTrue,
        reason: 'por defecto SIEMPRE oculta (T-11-06-01)');
    expect(_iconoDe(tester, const ValueKey('login-password')), Icons.visibility);
  });

  testWidgets('login: tocar el ojo revela la contraseña y lo devuelve a oculta',
      (tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: LoginScreen())),
    );
    const k = ValueKey('login-password');

    await tester.enterText(find.byKey(k), 'Demo!1234');
    await tester.tap(_ojo(k));
    await tester.pump();

    expect(_obscuro(tester, k), isFalse);
    expect(_iconoDe(tester, k), Icons.visibility_off);
    expect(tester.widget<TextField>(_campo(k)).controller!.text, 'Demo!1234');

    await tester.tap(_ojo(k));
    await tester.pump();

    expect(_obscuro(tester, k), isTrue);
    expect(_iconoDe(tester, k), Icons.visibility);
  });

  testWidgets('login: el ojo está etiquetado y es alcanzable (48x48)',
      (tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: LoginScreen())),
    );
    const k = ValueKey('login-password');

    expect(tester.widget<IconButton>(_ojo(k)).tooltip, 'Mostrar contraseña');
    final size = tester.getSize(_ojo(k));
    expect(size.width, greaterThanOrEqualTo(48.0));
    expect(size.height, greaterThanOrEqualTo(48.0));

    await tester.tap(_ojo(k));
    await tester.pump();
    expect(tester.widget<IconButton>(_ojo(k)).tooltip, 'Ocultar contraseña');
  });

  testWidgets(
      'PasswordField: los 48x48 los pone el widget, no el default del framework',
      (tester) async {
    // Sin este caso el assert de 48x48 pasaría POR CONSTRUCCIÓN: el default
    // de `InputDecoration.suffixIconConstraints` ya son 48x48. Aquí ese
    // default se anula, así que lo único que puede sostener el área táctil es
    // el `constraints` explícito del propio widget.
    final ctrl = TextEditingController();
    addTearDown(ctrl.dispose);

    await tester.pumpWidget(MaterialApp(
      theme: ThemeData(
        inputDecorationTheme: const InputDecorationTheme(
          suffixIconConstraints: BoxConstraints(minWidth: 0, minHeight: 0),
        ),
        iconButtonTheme: IconButtonThemeData(
          style: IconButton.styleFrom(
            minimumSize: Size.zero,
            padding: EdgeInsets.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ),
      ),
      home: Scaffold(
        body: PasswordField(
          fieldKey: const ValueKey('apretado'),
          controller: ctrl,
          labelText: 'Clave',
        ),
      ),
    ));

    final size = tester.getSize(_ojo(const ValueKey('apretado')));
    expect(size.width, greaterThanOrEqualTo(48.0),
        reason: 'el área táctil no puede depender del tema ambiente');
    expect(size.height, greaterThanOrEqualTo(48.0));
  });

  testWidgets('login: el email NO lleva ojo (solo la contraseña)',
      (tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: LoginScreen())),
    );

    expect(
        find.descendant(
            of: find.byKey(const ValueKey('login-email')),
            matching: find.byType(IconButton)),
        findsNothing);
    // Control positivo: si el finder no discriminara, este también daría 0.
    expect(_ojo(const ValueKey('login-password')), findsOneWidget);
  });

  testWidgets('PasswordField: dos instancias NO comparten estado',
      (tester) async {
    // El panel hoy tiene UN solo campo de contraseña, así que ningún test de
    // pantalla puede detectar un `_obscure` compartido (verificado: hacerlo
    // `static` dejaba la suite entera en verde). Este caso cubre ese hueco
    // antes de que 11-07 traiga formularios con dos campos.
    final a = TextEditingController();
    final b = TextEditingController();
    addTearDown(a.dispose);
    addTearDown(b.dispose);

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Column(children: [
          PasswordField(
              fieldKey: const ValueKey('uno'), controller: a, labelText: 'Uno'),
          PasswordField(
              fieldKey: const ValueKey('dos'), controller: b, labelText: 'Dos'),
        ]),
      ),
    ));

    await tester.tap(_ojo(const ValueKey('uno')));
    await tester.pump();

    expect(_obscuro(tester, const ValueKey('uno')), isFalse);
    expect(_obscuro(tester, const ValueKey('dos')), isTrue,
        reason: 'cada instancia guarda su propio estado');
  });

  testWidgets(
      'login: la ValueKey login-password sigue viva y el campo sigue escribiéndose',
      (tester) async {
    // Contrato con los tests previos del formulario: la extracción del widget
    // no puede llevarse por delante la key ni el cableado del controlador.
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: LoginScreen())),
    );

    await tester.enterText(find.byKey(const ValueKey('login-email')),
        'admin@demo.gri.dev');
    await tester.enterText(
        find.byKey(const ValueKey('login-password')), 'Demo!1234');
    await tester.pump();

    expect(
        tester.widget<ElevatedButton>(find.byType(ElevatedButton)).onPressed,
        isNotNull,
        reason: 'lo escrito por key llega al validador y habilita el botón');
  });
}

