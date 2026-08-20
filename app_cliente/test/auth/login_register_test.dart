import 'dart:async';

// Tests de auth sobre FirebaseAuth (10-02 Task 3): validación de UI parity
// (screens intactas) + flujo login/registro/logout con MockFirebaseAuth y
// FakeFirebaseFirestore (helpers). El registro DEBE crear usuarios/{uid}
// con role 'cliente' y restauranteId null — nunca otro role.
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:gri_cliente/core/firebase_providers.dart';
import 'package:gri_cliente/core/password_policy.dart';
import 'package:gri_cliente/features/auth/auth_controller.dart';
import 'package:gri_cliente/features/auth/login_screen.dart';
import 'package:gri_cliente/features/auth/register_screen.dart';
import 'package:gri_cliente/features/shared/password_field.dart';
import 'package:mock_exceptions/mock_exceptions.dart';

import '../helpers/firebase_fakes.dart';

Widget _wrap() {
  final router = GoRouter(
    initialLocation: '/login',
    routes: [
      GoRoute(path: '/login', builder: (_, _) => const LoginScreen()),
      GoRoute(path: '/register', builder: (_, _) => const RegisterScreen()),
    ],
  );
  return ProviderScope(child: MaterialApp.router(routerConfig: router));
}

Future<void> _fill(WidgetTester tester, List<String> values) async {
  final fields = find.byType(TextFormField);
  for (var i = 0; i < values.length; i++) {
    await tester.enterText(fields.at(i), values[i]);
  }
  await tester.pump();
}

/// Container con las instancias fake cableadas (patrón de override de
/// test/helpers/firebase_fakes.dart).
ProviderContainer _container(FirebaseAuth auth, FirebaseFirestore db) {
  final container = ProviderContainer(overrides: [
    firebaseAuthProvider.overrideWithValue(auth),
    firestoreProvider.overrideWithValue(db),
  ]);
  addTearDown(container.dispose);
  return container;
}


/// Rellena el formulario de registro por KEY (no por posición): al añadir la
/// confirmación los índices se desplazan y un helper posicional mentiría.
Future<void> _rellenarRegistro(
  WidgetTester tester, {
  String nombre = 'Carlos Pérez',
  String email = 'carlos@test.gri.dev',
  required String pass,
  required String pass2,
}) async {
  await tester.enterText(find.byKey(const ValueKey('register-nombre')), nombre);
  await tester.enterText(find.byKey(const ValueKey('register-email')), email);
  await tester.enterText(find.byKey(const ValueKey('register-password')), pass);
  await tester.enterText(
      find.byKey(const ValueKey('register-password-2')), pass2);
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
  // ── UI parity: validación pre-red (screens intactas) ──────────────────

  testWidgets('login: email inválido deshabilita el botón', (tester) async {
    await tester.pumpWidget(_wrap());

    await _fill(tester, ['not-an-email', 'Demo!1234']);

    final button = tester.widget<ElevatedButton>(find.byType(ElevatedButton));
    expect(button.onPressed, isNull,
        reason: 'email inválido debe deshabilitar Ingresar (validación pre-red)');
  });

  testWidgets('login: password < 8 deshabilita el botón', (tester) async {
    await tester.pumpWidget(_wrap());

    await _fill(tester, ['carlos@demo.gri.dev', 'abc']);

    final button = tester.widget<ElevatedButton>(find.byType(ElevatedButton));
    expect(button.onPressed, isNull,
        reason: 'password < 8 chars debe deshabilitar Ingresar');
  });

  testWidgets('login: toggle navega a la pantalla de registro', (tester) async {
    await tester.pumpWidget(_wrap());

    expect(find.text('Ingresar'), findsOneWidget);

    // El bloque de Google (11-17) alargó la card: en el viewport de 800x600 del
    // test el enlace queda por debajo del pliegue. Es scrollable (no es un bug
    // de producto), así que el test debe desplazarse como haría el usuario.
    await tester.ensureVisible(find.text('¿No tienes cuenta? Regístrate'));
    await tester.tap(find.text('¿No tienes cuenta? Regístrate'));
    await tester.pumpAndSettle();

    expect(find.byType(RegisterScreen), findsOneWidget);
    expect(find.text('Crear cuenta'), findsWidgets);
  });

  testWidgets(
      'register: requiere nombre + email válido + password ≥ 8 para habilitar',
      (tester) async {
    await tester.pumpWidget(_wrap());
    // El bloque de Google (11-17) alargó la card: en el viewport de 800x600 del
    // test el enlace queda por debajo del pliegue. Es scrollable (no es un bug
    // de producto), así que el test debe desplazarse como haría el usuario.
    await tester.ensureVisible(find.text('¿No tienes cuenta? Regístrate'));
    await tester.tap(find.text('¿No tienes cuenta? Regístrate'));
    await tester.pumpAndSettle();

    // Vacío → disabled.
    expect(
        tester.widget<ElevatedButton>(find.byType(ElevatedButton)).onPressed,
        isNull,
        reason: 'form vacío deshabilita Crear');

    // Solo nombre → disabled.
    await _fill(tester, ['Carlos']);
    expect(
        tester.widget<ElevatedButton>(find.byType(ElevatedButton)).onPressed,
        isNull,
        reason: 'sin email/password deshabilita Crear');

    // Nombre + email inválido → disabled.
    await _fill(tester, ['Carlos', 'not-an-email', 'Demo!1234']);
    expect(
        tester.widget<ElevatedButton>(find.byType(ElevatedButton)).onPressed,
        isNull,
        reason: 'email inválido deshabilita Crear');

    // Nombre + email + password válidos pero SIN confirmar → sigue disabled
    // (11-06: la confirmación es obligatoria).
    await _fill(tester, ['Carlos Pérez', 'carlos@test.gri.dev', 'Demo!1234']);
    expect(
        tester.widget<ElevatedButton>(find.byType(ElevatedButton)).onPressed,
        isNull,
        reason: 'sin confirmar la contraseña, Crear sigue deshabilitado');

    // Todo válido + confirmación coincidente → enabled.
    await _fill(tester,
        ['Carlos Pérez', 'carlos@test.gri.dev', 'Demo!1234', 'Demo!1234']);
    expect(
        tester.widget<ElevatedButton>(find.byType(ElevatedButton)).onPressed,
        isNotNull,
        reason: 'nombre + email válido + password 8+ confirmada habilita Crear');
  });

  // ── Login/logout con MockFirebaseAuth ─────────────────────────────────

  test('login OK firma la sesión', () async {
    final auth = mockAuth(email: 'carlos@demo.gri.dev', signedIn: false);
    final db = await buildFakeFirestoreConSeed();
    final container = _container(auth, db);

    final ok = await container
        .read(loginControllerProvider.notifier)
        .submit('carlos@demo.gri.dev', 'Demo!1234');

    expect(ok, isTrue);
    expect(auth.currentUser, isNotNull,
        reason: 'signInWithEmailAndPassword deja sesión iniciada');
  });

  test('login con credenciales inválidas → Credenciales inválidas',
      () async {
    final auth = mockAuth(signedIn: false);
    whenCalling(Invocation.method(#signInWithEmailAndPassword, null))
        .on(auth)
        .thenThrow(FirebaseAuthException(code: 'invalid-credential'));
    final db = await buildFakeFirestoreConSeed();
    final container = _container(auth, db);

    await expectLater(
      container
          .read(loginControllerProvider.notifier)
          .submit('carlos@demo.gri.dev', 'Mala!2345'),
      throwsA(isA<StateError>()
          .having((e) => e.message, 'message', 'Credenciales inválidas')),
    );
  });

  test('login sin red → mensaje de conexión', () async {
    final auth = mockAuth(signedIn: false);
    whenCalling(Invocation.method(#signInWithEmailAndPassword, null))
        .on(auth)
        .thenThrow(FirebaseAuthException(code: 'network-request-failed'));
    final container = _container(auth, await buildFakeFirestoreConSeed());

    await expectLater(
      container
          .read(loginControllerProvider.notifier)
          .submit('carlos@demo.gri.dev', 'Demo!1234'),
      throwsA(isA<StateError>().having(
          (e) => e.message, 'message', contains('Sin conexión'))),
    );
  });

  test('logout cierra la sesión', () async {
    final auth = mockAuth(email: 'carlos@demo.gri.dev');
    final container = _container(auth, await buildFakeFirestoreConSeed());

    await container.read(logoutControllerProvider.notifier).logout();

    expect(auth.currentUser, isNull);
  });

  // ── Registro: espejo usuarios/{uid} con role cliente ──────────────────

  test('registro crea usuarios/{uid} con role cliente y restauranteId null',
      () async {
    final auth = MockFirebaseAuth(); // sin sesión → createUser auto-loguea
    final db = await buildFakeFirestoreConSeed();
    final container = _container(auth, db);

    final ok = await container.read(registerControllerProvider.notifier).submit(
          'Carlos Pérez',
          'carlos@nuevo.gri.dev',
          'Demo!1234',
        );

    expect(ok, isTrue);
    expect(auth.currentUser, isNotNull, reason: 'auto-login tras registro');

    final uid = auth.currentUser!.uid;
    final doc = await db.collection('usuarios').doc(uid).get();
    expect(doc.exists, isTrue, reason: 'registro escribe el espejo usuarios/{uid}');

    final data = doc.data()!;
    // LOCKED (must_haves): role SIEMPRE 'cliente', restauranteId null.
    expect(data['role'], 'cliente');
    expect(data['restauranteId'], isNull);
    expect(data['nombre'], 'Carlos Pérez');
    expect(data['email'], 'carlos@nuevo.gri.dev');
    expect(data.keys, unorderedEquals(
        ['nombre', 'email', 'role', 'restauranteId', 'createdAt']));

    // DisplayName queda disponible para la UI.
    expect(auth.currentUser!.displayName, 'Carlos Pérez');
  });

  test('registro con email existente → mensaje mapeado', () async {
    final auth = MockFirebaseAuth();
    whenCalling(Invocation.method(#createUserWithEmailAndPassword, null))
        .on(auth)
        .thenThrow(FirebaseAuthException(code: 'email-already-in-use'));
    final container = _container(auth, await buildFakeFirestoreConSeed());

    await expectLater(
      container.read(registerControllerProvider.notifier).submit(
            'Carlos',
            'carlos@demo.gri.dev',
            'Demo!1234',
          ),
      throwsA(isA<StateError>().having((e) => e.message, 'message',
          'Ya existe una cuenta con este email')),
    );
  });

  test('login no toca Firestore (solo Auth)', () async {
    // El login NO escribe nada — la sesión es asunto del SDK.
    final auth = mockAuth(email: 'maria@demo.gri.dev', signedIn: false);
    final db = await buildFakeFirestoreConSeed();
    final container = _container(auth, db);

    await container
        .read(loginControllerProvider.notifier)
        .submit('maria@demo.gri.dev', 'Demo!1234');

    final usuarios = await db.collection('usuarios').get();
    expect(usuarios.docs, isEmpty,
        reason: 'login no crea docs — solo el registro escribe el espejo');
  });

  // -- 11-06: toggle de visibilidad de contraseña (queja del usuario) ------
  //
  // Estos casos leen el ESTADO REAL del widget (`TextField.obscureText`),
  // no la presencia de un icono: si el toggle se cableara al icono pero no
  // al campo, seguirían en rojo.

  testWidgets('login: la contraseña arranca OCULTA y ofrece el ojo para verla',
      (tester) async {
    await tester.pumpWidget(_wrap());

    expect(_obscuro(tester, const ValueKey('login-password')), isTrue,
        reason: 'por defecto SIEMPRE oculta (T-11-06-01)');
    expect(_iconoDe(tester, const ValueKey('login-password')), Icons.visibility);
  });

  testWidgets('login: tocar el ojo revela la contraseña y lo devuelve a oculta',
      (tester) async {
    await tester.pumpWidget(_wrap());
    const k = ValueKey('login-password');

    await tester.enterText(find.byKey(k), 'Demo!1234');
    await tester.tap(_ojo(k));
    await tester.pump();

    expect(_obscuro(tester, k), isFalse, reason: 'el ojo revela lo escrito');
    expect(_iconoDe(tester, k), Icons.visibility_off);
    // El texto sigue siendo el mismo: revelar no borra ni altera el valor.
    expect(tester.widget<TextField>(_campo(k)).controller!.text, 'Demo!1234');

    await tester.tap(_ojo(k));
    await tester.pump();

    expect(_obscuro(tester, k), isTrue,
        reason: 'el segundo toque vuelve a ocultar');
    expect(_iconoDe(tester, k), Icons.visibility);
  });

  testWidgets('login: el ojo está etiquetado y es alcanzable (48x48)',
      (tester) async {
    await tester.pumpWidget(_wrap());
    const k = ValueKey('login-password');

    expect(tester.widget<IconButton>(_ojo(k)).tooltip, 'Mostrar contraseña');
    final size = tester.getSize(_ojo(k));
    expect(size.width, greaterThanOrEqualTo(48.0));
    expect(size.height, greaterThanOrEqualTo(48.0));

    await tester.tap(_ojo(k));
    await tester.pump();
    expect(tester.widget<IconButton>(_ojo(k)).tooltip, 'Ocultar contraseña',
        reason: 'el tooltip describe la ACCIÓN, y la acción cambió');
  });

  testWidgets('login: el email NO lleva ojo (solo las contraseñas)',
      (tester) async {
    await tester.pumpWidget(_wrap());

    expect(
        find.descendant(
            of: find.byKey(const ValueKey('login-email')),
            matching: find.byType(IconButton)),
        findsNothing);
    // Control positivo: si el finder no discriminara, este también daría 0.
    expect(_ojo(const ValueKey('login-password')), findsOneWidget);
  });

  // -- 11-06: confirmar contraseña en el registro ------------------------

  testWidgets('register: contraseñas distintas avisan y bloquean el envío',
      (tester) async {
    await tester.pumpWidget(_wrap());
    // El bloque de Google (11-17) alargó la card: en el viewport de 800x600 del
    // test el enlace queda por debajo del pliegue. Es scrollable (no es un bug
    // de producto), así que el test debe desplazarse como haría el usuario.
    await tester.ensureVisible(find.text('¿No tienes cuenta? Regístrate'));
    await tester.tap(find.text('¿No tienes cuenta? Regístrate'));
    await tester.pumpAndSettle();

    await _rellenarRegistro(tester, pass: 'Demo!1234', pass2: 'Demo!9999');

    expect(find.text('Las contraseñas no coinciden'), findsOneWidget);
    expect(
        tester.widget<ElevatedButton>(find.byType(ElevatedButton)).onPressed,
        isNull,
        reason: 'con contraseñas distintas no se puede enviar');
  });

  testWidgets('register: al corregir la confirmación desaparece el aviso',
      (tester) async {
    await tester.pumpWidget(_wrap());
    // El bloque de Google (11-17) alargó la card: en el viewport de 800x600 del
    // test el enlace queda por debajo del pliegue. Es scrollable (no es un bug
    // de producto), así que el test debe desplazarse como haría el usuario.
    await tester.ensureVisible(find.text('¿No tienes cuenta? Regístrate'));
    await tester.tap(find.text('¿No tienes cuenta? Regístrate'));
    await tester.pumpAndSettle();

    await _rellenarRegistro(tester, pass: 'Demo!1234', pass2: 'Demo!9999');
    expect(find.text('Las contraseñas no coinciden'), findsOneWidget);

    await tester.enterText(
        find.byKey(const ValueKey('register-password-2')), 'Demo!1234');
    await tester.pump();

    expect(find.text('Las contraseñas no coinciden'), findsNothing);
    expect(
        tester.widget<ElevatedButton>(find.byType(ElevatedButton)).onPressed,
        isNotNull);
  });

  testWidgets(
      'register: cambiar la contraseña DESPUÉS de confirmarla vuelve a avisar',
      (tester) async {
    // Caso que un validador mal cableado se come: el usuario confirma bien y
    // luego edita el primer campo. Si el aviso no reapareciera, el botón
    // quedaría habilitado con dos valores distintos.
    await tester.pumpWidget(_wrap());
    // El bloque de Google (11-17) alargó la card: en el viewport de 800x600 del
    // test el enlace queda por debajo del pliegue. Es scrollable (no es un bug
    // de producto), así que el test debe desplazarse como haría el usuario.
    await tester.ensureVisible(find.text('¿No tienes cuenta? Regístrate'));
    await tester.tap(find.text('¿No tienes cuenta? Regístrate'));
    await tester.pumpAndSettle();

    await _rellenarRegistro(tester, pass: 'Demo!1234', pass2: 'Demo!1234');
    expect(
        tester.widget<ElevatedButton>(find.byType(ElevatedButton)).onPressed,
        isNotNull);

    await tester.enterText(
        find.byKey(const ValueKey('register-password')), 'Otra!12345');
    await tester.pump();

    expect(find.text('Las contraseñas no coinciden'), findsOneWidget);
    expect(
        tester.widget<ElevatedButton>(find.byType(ElevatedButton)).onPressed,
        isNull);
  });

  testWidgets('register: los dos campos de contraseña tienen ojo INDEPENDIENTE',
      (tester) async {
    await tester.pumpWidget(_wrap());
    // El bloque de Google (11-17) alargó la card: en el viewport de 800x600 del
    // test el enlace queda por debajo del pliegue. Es scrollable (no es un bug
    // de producto), así que el test debe desplazarse como haría el usuario.
    await tester.ensureVisible(find.text('¿No tienes cuenta? Regístrate'));
    await tester.tap(find.text('¿No tienes cuenta? Regístrate'));
    await tester.pumpAndSettle();

    const k1 = ValueKey('register-password');
    const k2 = ValueKey('register-password-2');

    expect(_obscuro(tester, k1), isTrue);
    expect(_obscuro(tester, k2), isTrue);

    await tester.tap(_ojo(k1));
    await tester.pump();

    expect(_obscuro(tester, k1), isFalse);
    expect(_obscuro(tester, k2), isTrue,
        reason: 'cada campo guarda su propio estado');
  });

  testWidgets(
      'register: la contraseña declara autofillHints.password (paridad con login)',
      (tester) async {
    await tester.pumpWidget(_wrap());
    // El bloque de Google (11-17) alargó la card: en el viewport de 800x600 del
    // test el enlace queda por debajo del pliegue. Es scrollable (no es un bug
    // de producto), así que el test debe desplazarse como haría el usuario.
    await tester.ensureVisible(find.text('¿No tienes cuenta? Regístrate'));
    await tester.tap(find.text('¿No tienes cuenta? Regístrate'));
    await tester.pumpAndSettle();

    final campo =
        tester.widget<TextField>(_campo(const ValueKey('register-password')));
    expect(campo.autofillHints, contains(AutofillHints.password),
        reason: 'T-11-06-03: el gestor de contraseñas debe tratar login y '
            'registro igual');
  });

  testWidgets('register: la confirmación NO viaja al controller (solo 3 datos)',
      (tester) async {
    final spy = _SpyRegisterController();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [registerControllerProvider.overrideWith(() => spy)],
        child: const MaterialApp(home: RegisterScreen()),
      ),
    );

    await _rellenarRegistro(tester, pass: 'Demo!1234', pass2: 'Demo!1234');

    await tester.tap(find.widgetWithText(ElevatedButton, 'Crear cuenta'));
    await tester.pump();

    expect(spy.llamadas, hasLength(1));
    expect(spy.llamadas.single,
        ('Carlos Pérez', 'carlos@test.gri.dev', 'Demo!1234'));
  });

  // -- El widget compartido, aislado -------------------------------------

  testWidgets(
      'PasswordField: sin validator ni autofill sigue ocultando y alternando',
      (tester) async {
    final ctrl = TextEditingController();
    addTearDown(ctrl.dispose);

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: PasswordField(
          fieldKey: const ValueKey('solo'),
          controller: ctrl,
          labelText: 'Clave',
        ),
      ),
    ));

    expect(find.text('Clave'), findsOneWidget);
    expect(_obscuro(tester, const ValueKey('solo')), isTrue);

    await tester.tap(_ojo(const ValueKey('solo')));
    await tester.pump();
    expect(_obscuro(tester, const ValueKey('solo')), isFalse);
  });

  testWidgets(
      'PasswordField: los 48x48 los pone el widget, no el default del framework',
      (tester) async {
    // Sin este caso, el assert de 48x48 pasaría POR CONSTRUCCIÓN: el
    // IconButton de Material ya mide 48x48 por defecto (verificado quitando
    // `constraints` — la suite seguía verde). Aquí el tema ambiente intenta
    // encogerlo a cero; solo el `constraints` explícito lo impide.
    final ctrl = TextEditingController();
    addTearDown(ctrl.dispose);

    await tester.pumpWidget(MaterialApp(
      theme: ThemeData(
        // Los 48x48 del sufijo los da por defecto InputDecoration
        // (`suffixIconConstraints`). Aquí ese default se anula, para que lo
        // único que pueda sostener el area tactil sea el propio widget.
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
        reason: 'el area tactil no puede depender del tema ambiente');
    expect(size.height, greaterThanOrEqualTo(48.0));
  });

  // ── 11-22: la política de contraseñas en el registro ───────────────────
  //
  // Antes de este plan el registro solo miraba la longitud, así que `12345678`
  // pasaba. Los casos de abajo prueban el punto 1 de los cuatro; la regla en sí
  // (bordes, acentos, redacción) vive en `test/core/password_policy_test.dart`
  // contra los vectores canónicos — aquí solo se comprueba que la PANTALLA la
  // consulta y que enseña lo que devuelve.

  Future<void> irARegistro(WidgetTester tester) async {
    await tester.pumpWidget(_wrap());
    await tester.ensureVisible(find.text('¿No tienes cuenta? Regístrate'));
    await tester.tap(find.text('¿No tienes cuenta? Regístrate'));
    await tester.pumpAndSettle();
  }

  ElevatedButton botonCrear(WidgetTester tester) =>
      tester.widget<ElevatedButton>(find.byType(ElevatedButton));

  testWidgets('register: 12345678 apaga el botón y dice QUÉ falta',
      (tester) async {
    await irARegistro(tester);
    await _rellenarRegistro(tester, pass: '12345678', pass2: '12345678');

    expect(
      botonCrear(tester).onPressed,
      isNull,
      reason: 'la contraseña que hoy pasaba ya no puede habilitar el envío',
    );
    // El texto está escrito a mano a propósito: comparar contra
    // `validarPassword(...)` dejaría el caso verde justo cuando la redacción
    // cambie, que es lo que el usuario pidió que NO pasara.
    expect(find.text('Te faltan una mayúscula y una minúscula.'), findsOneWidget);
  });

  testWidgets('register: el mensaje nombra SOLO lo que falta', (tester) async {
    await irARegistro(tester);
    await _rellenarRegistro(tester, pass: 'Abcdefgh', pass2: 'Abcdefgh');

    expect(find.text('Te falta un número.'), findsOneWidget);
    expect(
      find.textContaining('mayúscula'),
      findsNothing,
      reason: 'no puede reclamar algo que la contraseña SÍ tiene',
    );
    expect(botonCrear(tester).onPressed, isNull);
  });

  testWidgets('register: Abcdefg1 (8 justos, los tres tipos) habilita',
      (tester) async {
    await irARegistro(tester);
    await _rellenarRegistro(tester, pass: 'Abcdefg1', pass2: 'Abcdefg1');

    expect(botonCrear(tester).onPressed, isNotNull);
    expect(find.textContaining('Te falta'), findsNothing);
    expect(find.textContaining('al menos 8 caracteres'), findsNothing);
  });

  testWidgets('register: el campo describe la política ANTES de fallar',
      (tester) async {
    await irARegistro(tester);
    // Sin escribir nada: la ayuda ya está ahí.
    expect(find.text(ayudaPolitica), findsOneWidget);
  });

  testWidgets('register: la confirmación sigue mandando aunque la política pase',
      (tester) async {
    await irARegistro(tester);
    await _rellenarRegistro(tester, pass: 'Abcdefg1', pass2: 'Abcdefg2');

    expect(find.text('Las contraseñas no coinciden'), findsOneWidget);
    expect(botonCrear(tester).onPressed, isNull);
  });
}

/// Doble del controller de registro que solo REGISTRA lo que recibe.
/// Demuestra que la confirmación se queda en la UI y nunca llega a Firebase.
class _SpyRegisterController extends RegisterController {
  final llamadas = <(String, String, String)>[];

  @override
  FutureOr<void> build() {}

  @override
  Future<bool> submit(String nombre, String email, String password) async {
    llamadas.add((nombre, email, password));
    return true;
  }
}

