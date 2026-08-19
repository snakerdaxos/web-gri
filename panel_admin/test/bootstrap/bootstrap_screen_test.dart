import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:gri_panel_admin/core/firebase_providers.dart';
import 'package:gri_panel_admin/features/bootstrap/bootstrap_controller.dart';
import 'package:gri_panel_admin/features/bootstrap/bootstrap_screen.dart';
import 'package:mock_exceptions/mock_exceptions.dart';

/// Pantalla `/bootstrap` y su controlador (11-07, Tarea 3).
///
/// Dos capas, con costuras distintas:
///  * FORMULARIO → se overridea `bootstrapAccionProvider` con dobles. Prueba
///    validación, traducción de errores y bloqueo del doble envío.
///  * CONTROLADOR → se usa el `bootstrapAccionProvider` REAL con
///    `firebaseAuthProvider` (MockFirebaseAuth) y `bootstrapCallableProvider`
///    (doble) overrideados. Es la única forma de comprobar de VERDAD que los
///    claims se invalidan y que la cuenta se revierte: con la acción entera
///    mockeada, ambas cosas serían afirmaciones, no verificaciones.

/// `FirebaseFunctionsException` tiene el constructor `@protected`; una
/// subclase SÍ puede invocarlo y es lo que el catch del controlador ve.
class _ErrorCallable extends FirebaseFunctionsException {
  _ErrorCallable(String code)
      : super(code: code, message: 'error simulado del emulador');
}

/// Usuario que REGISTRA su borrado. Sin esto, "la cuenta se elimina" pasaría
/// con solo el `signOut` (que también deja `currentUser` en null) — un verde
/// por el motivo equivocado.
///
/// `MockUser` ya se salta `@immutable` (lo declara el propio paquete con un
/// `ignore_for_file`), y un espía necesita estado mutable por definición.
// ignore: must_be_immutable
class _UsuarioEspia extends MockUser {
  _UsuarioEspia() : super(uid: 'u-espia', email: 'fundador@demo.gri.dev');
  bool borrado = false;

  @override
  Future<void> delete() async => borrado = true;
}

class _AuthEspia extends MockFirebaseAuth {
  _AuthEspia();
  final _UsuarioEspia espia = _UsuarioEspia();

  @override
  User? get currentUser => super.currentUser == null ? null : espia;
}

/// Router mínimo: la pantalla navega con `context.go('/')` al terminar y aquí
/// el destino es un marcador. El GoRouter REAL del panel lo ejercita
/// `bootstrap_router_test.dart`; arrastrar el dashboard hasta aquí solo
/// añadiría fakes sin añadir cobertura.
Widget _app() => MaterialApp.router(
      routerConfig: GoRouter(
        initialLocation: '/bootstrap',
        routes: [
          GoRoute(path: '/bootstrap', builder: (_, _) => const BootstrapScreen()),
          GoRoute(
            path: '/',
            builder: (_, _) => const Scaffold(body: Text('DESTINO-PANEL')),
          ),
        ],
      ),
    );

/// El formulario tiene 5 campos + aviso + botón: con el viewport de 800x600
/// por defecto el botón cae fuera de la ventana y `tap` no acierta.
void _viewportPanel(WidgetTester tester) {
  tester.view.physicalSize = const Size(900, 1400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

Future<void> _rellenar(
  WidgetTester tester, {
  String nombre = 'Fundador GRI',
  String email = 'fundador@demo.gri.dev',
  String password = 'Demo!1234',
  String? password2,
  String secreto = 'secreto-de-despliegue',
}) async {
  await tester.enterText(find.byKey(const ValueKey('bootstrap-nombre')), nombre);
  await tester.enterText(find.byKey(const ValueKey('bootstrap-email')), email);
  await tester.enterText(
      find.byKey(const ValueKey('bootstrap-password')), password);
  await tester.enterText(
      find.byKey(const ValueKey('bootstrap-password-2')), password2 ?? password);
  await tester.enterText(
      find.byKey(const ValueKey('bootstrap-secreto')), secreto);
  await tester.pump();
}

Finder get _boton => find.byKey(const ValueKey('bootstrap-submit'));

void main() {
  group('formulario', () {
    testWidgets('pide los cinco campos', (tester) async {
      _viewportPanel(tester);
      await tester.pumpWidget(ProviderScope(
        overrides: [
          bootstrapAccionProvider.overrideWithValue(
            ({
              required nombre,
              required email,
              required password,
              required secreto,
            }) async {},
          ),
        ],
        child: _app(),
      ));
      await tester.pumpAndSettle();

      for (final k in [
        'bootstrap-nombre',
        'bootstrap-email',
        'bootstrap-password',
        'bootstrap-password-2',
        'bootstrap-secreto',
      ]) {
        expect(find.byKey(ValueKey(k)), findsOneWidget, reason: 'falta $k');
      }
    });

    testWidgets('el botón arranca deshabilitado y se habilita al completar',
        (tester) async {
      _viewportPanel(tester);
      await tester.pumpWidget(ProviderScope(
        overrides: [
          bootstrapAccionProvider.overrideWithValue(
            ({
              required nombre,
              required email,
              required password,
              required secreto,
            }) async {},
          ),
        ],
        child: _app(),
      ));
      await tester.pumpAndSettle();

      expect(tester.widget<ElevatedButton>(_boton).onPressed, isNull);
      await _rellenar(tester);
      expect(tester.widget<ElevatedButton>(_boton).onPressed, isNotNull);
    });

    testWidgets('contraseñas distintas: avisa y bloquea el envío',
        (tester) async {
      _viewportPanel(tester);
      await tester.pumpWidget(ProviderScope(
        overrides: [
          bootstrapAccionProvider.overrideWithValue(
            ({
              required nombre,
              required email,
              required password,
              required secreto,
            }) async {},
          ),
        ],
        child: _app(),
      ));
      await tester.pumpAndSettle();

      await _rellenar(tester, password2: 'Otra!5678');
      expect(find.text('Las contraseñas no coinciden'), findsOneWidget);
      expect(tester.widget<ElevatedButton>(_boton).onPressed, isNull);
    });

    testWidgets('envío exitoso: pasa los datos a la acción y navega al panel',
        (tester) async {
      final recibido = <Map<String, String>>[];
      _viewportPanel(tester);
      await tester.pumpWidget(ProviderScope(
        overrides: [
          bootstrapAccionProvider.overrideWithValue(
            ({
              required nombre,
              required email,
              required password,
              required secreto,
            }) async {
              recibido.add({
                'nombre': nombre,
                'email': email,
                'password': password,
                'secreto': secreto,
              });
            },
          ),
        ],
        child: _app(),
      ));
      await tester.pumpAndSettle();

      await _rellenar(tester);
      await tester.tap(_boton);
      await tester.pumpAndSettle();

      expect(recibido, hasLength(1));
      expect(recibido.single['nombre'], 'Fundador GRI');
      expect(recibido.single['email'], 'fundador@demo.gri.dev');
      expect(recibido.single['secreto'], 'secreto-de-despliegue');
      expect(find.text('DESTINO-PANEL'), findsOneWidget);
    });

    testWidgets('doble envío imposible con una operación en vuelo',
        (tester) async {
      var llamadas = 0;
      _viewportPanel(tester);
      await tester.pumpWidget(ProviderScope(
        overrides: [
          bootstrapAccionProvider.overrideWithValue(
            ({
              required nombre,
              required email,
              required password,
              required secreto,
            }) async {
              llamadas++;
              await Future<void>.delayed(const Duration(milliseconds: 300));
            },
          ),
        ],
        child: _app(),
      ));
      await tester.pumpAndSettle();

      await _rellenar(tester);
      await tester.tap(_boton);
      await tester.pump(); // arranca la operación, no la completa
      expect(tester.widget<ElevatedButton>(_boton).onPressed, isNull,
          reason: 'el botón se apaga mientras la operación está en vuelo');

      await tester.tap(_boton, warnIfMissed: false);
      await tester.pump();
      await tester.pumpAndSettle(const Duration(seconds: 1));

      expect(llamadas, 1);
    });

    for (final caso in [
      ('permission-denied',
          'No se pudo inicializar: revisa el correo, que esté verificado, y el secreto.'),
      ('failed-precondition',
          'Falta configurar la inicialización en el despliegue.'),
      ('unauthenticated', 'Vuelve a intentarlo.'),
    ]) {
      testWidgets('error ${caso.$1} se muestra en español', (tester) async {
        _viewportPanel(tester);
      await tester.pumpWidget(ProviderScope(
          overrides: [
            bootstrapAccionProvider.overrideWithValue(
              ({
                required nombre,
                required email,
                required password,
                required secreto,
              }) async =>
                  throw BootstrapException(caso.$2),
            ),
          ],
          child: _app(),
        ));
        await tester.pumpAndSettle();

        await _rellenar(tester);
        await tester.tap(_boton);
        await tester.pumpAndSettle();

        expect(find.text(caso.$2), findsOneWidget);
        expect(find.text('DESTINO-PANEL'), findsNothing,
            reason: 'un fallo no puede llevar al panel');
      });
    }
  });

  group('controlador REAL (auth mock + callable doble)', () {
    ProviderContainer contenedor({
      required FirebaseAuth auth,
      required BootstrapCallable callable,
      required void Function() alConstruirClaims,
    }) {
      final c = ProviderContainer(overrides: [
        firebaseAuthProvider.overrideWithValue(auth),
        bootstrapCallableProvider.overrideWithValue(callable),
        claimsProvider.overrideWith((ref) async {
          alConstruirClaims();
          return (role: 'super_admin', rid: null);
        }),
      ]);
      addTearDown(c.dispose);
      return c;
    }

    test('tras la callable INVALIDA claimsProvider (si no, el nuevo '
        'super_admin aterriza como cliente)', () async {
      var construcciones = 0;
      final c = contenedor(
        auth: MockFirebaseAuth(),
        callable: (payload) async {},
        alConstruirClaims: () => construcciones++,
      );

      // Se fuerza una PRIMERA construcción antes de la acción: sin esto el
      // caso pasaría igual sin `invalidate`, porque el provider se construiría
      // por primera vez dentro de la acción de todos modos.
      await c.read(claimsProvider.future);
      expect(construcciones, 1);

      await c.read(bootstrapAccionProvider)(
        nombre: 'Fundador',
        email: 'fundador@demo.gri.dev',
        password: 'Demo!1234',
        secreto: 'secreto',
      );

      expect(construcciones, 2,
          reason: 'claimsProvider es keepAlive y solo se recomputa con eventos '
              'de authStateChanges; getIdToken(true) no genera ninguno');
    });

    test('la callable recibe SOLO nombre y secreto (nunca uid ni email '
        'destino)', () async {
      final payloads = <Map<String, dynamic>>[];
      final c = contenedor(
        auth: MockFirebaseAuth(),
        callable: (payload) async => payloads.add(payload),
        alConstruirClaims: () {},
      );

      await c.read(bootstrapAccionProvider)(
        nombre: '  Fundador GRI  ',
        email: 'Fundador@Demo.GRI.dev',
        password: 'Demo!1234',
        secreto: 'secreto-de-despliegue',
      );

      expect(payloads, hasLength(1));
      expect(payloads.single.keys.toSet(), {'nombre', 'secreto'});
      expect(payloads.single['nombre'], 'Fundador GRI');
    });

    test('si la callable falla y la cuenta se creó aquí: se elimina y se '
        'cierra sesión', () async {
      final auth = _AuthEspia();
      final c = contenedor(
        auth: auth,
        callable: (_) async => throw _ErrorCallable('permission-denied'),
        alConstruirClaims: () {},
      );

      await expectLater(
        c.read(bootstrapAccionProvider)(
          nombre: 'Fundador',
          email: 'fundador@demo.gri.dev',
          password: 'Demo!1234',
          secreto: 'malo',
        ),
        throwsA(isA<BootstrapException>().having(
          (e) => e.message,
          'message',
          'No se pudo inicializar: revisa el correo, que esté verificado, y el secreto.',
        )),
      );

      expect(auth.espia.borrado, isTrue,
          reason: 'una cuenta huérfana con el bootstrap cerrado bloquearía la '
              'plataforma');
      expect(auth.currentUser, isNull, reason: 'y se cierra la sesión');
    });

    test('si el correo YA existía: se inicia sesión y NO se elimina la cuenta '
        'pase lo que pase', () async {
      final auth = _AuthEspia();
      whenCalling(Invocation.method(#createUserWithEmailAndPassword, null))
          .on(auth)
          .thenThrow(FirebaseAuthException(code: 'email-already-in-use'));
      final c = contenedor(
        auth: auth,
        callable: (_) async => throw _ErrorCallable('permission-denied'),
        alConstruirClaims: () {},
      );

      await expectLater(
        c.read(bootstrapAccionProvider)(
          nombre: 'Fundador',
          email: 'fundador@demo.gri.dev',
          password: 'Demo!1234',
          secreto: 'malo',
        ),
        throwsA(isA<BootstrapException>()),
      );

      expect(auth.espia.borrado, isFalse,
          reason: 'borrar una cuenta preexistente sería destrucción de datos '
              'ajenos');
      expect(auth.currentUser, isNotNull,
          reason: 'la sesión de una cuenta que ya existía no se cierra');
    });

    test('failed-precondition y unauthenticated tienen mensaje propio',
        () async {
      for (final caso in [
        ('failed-precondition',
            'Falta configurar la inicialización en el despliegue.'),
        ('unauthenticated', 'Vuelve a intentarlo.'),
        ('internal', 'No se pudo inicializar la plataforma. Intenta de nuevo.'),
      ]) {
        final c = contenedor(
          auth: MockFirebaseAuth(),
          callable: (_) async => throw _ErrorCallable(caso.$1),
          alConstruirClaims: () {},
        );
        await expectLater(
          c.read(bootstrapAccionProvider)(
            nombre: 'Fundador',
            email: 'fundador@demo.gri.dev',
            password: 'Demo!1234',
            secreto: 's',
          ),
          throwsA(isA<BootstrapException>()
              .having((e) => e.message, 'message', caso.$2)),
        );
      }
    });
  });
}
