import 'package:cloud_functions/cloud_functions.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gri_panel_admin/core/firebase_providers.dart';
import 'package:gri_panel_admin/features/dashboard/restaurante_provider.dart';
import 'package:gri_panel_admin/features/equipo/equipo_controller.dart';
import 'package:gri_panel_admin/features/equipo/equipo_provider.dart';

/// Provider de listado y controlador de alta de `/equipo` (11-10, Tarea 2).
///
/// ⚠️ LO QUE ESTOS TESTS **NO** PRUEBAN: la AUTORIZACIÓN.
/// `fake_cloud_firestore` no tiene motor de rules, así que aquí un `mesero`
/// también podría leer `usuarios/` si el provider le dejara. Que la lectura
/// esté acotada al rid del admin lo prueba
/// `scripts/test/rules/usuarios.test.mjs` contra el emulador REAL, y que el
/// alta esté acotada lo prueba
/// `scripts/test/functions/crear-usuario-staff.e2e.mjs`.
/// Lo de aquí es el CONTRATO DEL CLIENTE: que la query lleve el filtro que la
/// regla exige y que el payload lleve —o no— el `restauranteId`.

/// `FirebaseFunctionsException` tiene el constructor `@protected`; una
/// subclase SÍ puede invocarlo, y es lo que ve el `catch` del controlador
/// (mismo truco que `bootstrap_screen_test.dart`).
class _ErrorCallable extends FirebaseFunctionsException {
  _ErrorCallable(String code, {String? message})
      : super(code: code, message: message ?? 'texto crudo del servidor');
}

Future<FakeFirebaseFirestore> _dbConEquipo() async {
  final db = FakeFirebaseFirestore();

  Future<void> usuario(
    String uid,
    String nombre,
    String email,
    String role,
    String? rid,
  ) =>
      db.doc('usuarios/$uid').set({
        'nombre': nombre,
        'email': email,
        'role': role,
        'restauranteId': rid,
      });

  // Equipo de `demo`, sembrado DESORDENADO a propósito: si el provider no
  // ordenara, el test del orden pasaría por casualidad.
  await usuario('u-zoe', 'Zoe Mesera', 'zoe@demo.com', 'mesero', 'demo');
  await usuario(
      'u-ana', 'Ana Admin', 'ana@demo.com', 'admin_restaurante', 'demo');
  await usuario('u-beto', 'Beto Cocina', 'beto@demo.com', 'cocina', 'demo');
  // Otro tenant + un cliente: NINGUNO debe aparecer en la lista de `demo`.
  await usuario(
      'u-otro', 'Otro Admin', 'otro@norte.com', 'admin_restaurante', 'norte');
  await usuario('u-cli', 'Cliente Suelto', 'cli@gmail.com', 'cliente', null);

  return db;
}

ProviderContainer _container({
  required FakeFirebaseFirestore db,
  required String role,
  String? rid,
  String? seleccion,
  CrearStaffCallable? callable,
}) {
  final c = ProviderContainer(
    overrides: [
      firestoreProvider.overrideWithValue(db),
      claimsProvider.overrideWith((ref) async => (role: role, rid: rid)),
      if (callable != null)
        crearStaffCallableProvider.overrideWithValue(callable),
    ],
  );
  if (seleccion != null) {
    c.read(seleccionRestauranteProvider.notifier).set(seleccion);
  }
  addTearDown(c.dispose);
  return c;
}

void main() {
  group('equipoProvider — listado acotado al restaurante activo', () {
    test('admin_restaurante de demo: solo su equipo, ordenado por nombre',
        () async {
      final c = _container(
        db: await _dbConEquipo(),
        role: 'admin_restaurante',
        rid: 'demo',
      );

      final equipo = await c.read(equipoProvider.future);

      expect(
        equipo.map((m) => m.nombre).toList(),
        ['Ana Admin', 'Beto Cocina', 'Zoe Mesera'],
      );
      // El del otro tenant y el cliente quedan fuera — lo mismo que haría la
      // regla, replicado por el `where` de la query.
      expect(equipo.map((m) => m.uid), isNot(contains('u-otro')));
      expect(equipo.map((m) => m.uid), isNot(contains('u-cli')));
      expect(equipo.first.email, 'ana@demo.com');
      expect(equipo.first.rol, 'admin_restaurante');
    });

    test('super_admin SIN restaurante seleccionado: lista vacía y no lanza',
        () async {
      final c = _container(
        db: await _dbConEquipo(),
        role: 'super_admin',
      );

      await expectLater(c.read(equipoProvider.future), completion(isEmpty));
    });

    test(
        'super_admin CON restaurante seleccionado: el equipo de ESE restaurante',
        () async {
      final c = _container(
        db: await _dbConEquipo(),
        role: 'super_admin',
        seleccion: 'norte',
      );

      final equipo = await c.read(equipoProvider.future);

      expect(equipo.map((m) => m.uid).toList(), ['u-otro']);
    });

    test('mesero: error controlado (defense in depth, patrón restaurantesAdmin)',
        () async {
      final c = _container(
        db: await _dbConEquipo(),
        role: 'mesero',
        rid: 'demo',
      );

      await expectLater(
        c.read(equipoProvider.future),
        throwsA(isA<StateError>()),
      );
    });

    test('cocina tampoco', () async {
      final c = _container(
        db: await _dbConEquipo(),
        role: 'cocina',
        rid: 'demo',
      );

      await expectLater(
        c.read(equipoProvider.future),
        throwsA(isA<StateError>()),
      );
    });
  });

  group('crearStaffAccion — forma del payload', () {
    test('un admin_restaurante NO manda restauranteId (lo deriva su claim)',
        () async {
      Map<String, dynamic>? visto;
      final c = _container(
        db: FakeFirebaseFirestore(),
        role: 'admin_restaurante',
        rid: 'demo',
        callable: (payload) async {
          visto = payload;
          return {
            'uid': 'u-nuevo',
            'creado': true,
            'rol': 'mesero',
            'restauranteId': 'demo',
          };
        },
      );

      final res = await c.read(crearStaffAccionProvider)(
        nombre: '  Nuevo Mesero  ',
        email: '  Nuevo@Demo.COM ',
        password: 'clave1234',
        rol: 'mesero',
      );

      expect(visto, isNotNull);
      expect(
        visto!.containsKey('restauranteId'),
        isFalse,
        reason:
            'mandarlo sería redundante y un dedazo daría permission-denied',
      );
      expect(visto!['email'], 'nuevo@demo.com'); // normalizado
      expect(visto!['nombre'], 'Nuevo Mesero'); // trim
      expect(visto!['rol'], 'mesero');
      expect(res.uid, 'u-nuevo');
      expect(res.creado, isTrue);
    });

    test('un super_admin SÍ manda el restauranteId elegido', () async {
      Map<String, dynamic>? visto;
      final c = _container(
        db: FakeFirebaseFirestore(),
        role: 'super_admin',
        callable: (payload) async {
          visto = payload;
          return {
            'uid': 'u-x',
            'creado': false,
            'rol': 'cocina',
            'restauranteId': 'norte',
          };
        },
      );

      final res = await c.read(crearStaffAccionProvider)(
        nombre: 'Cocinero',
        email: 'coci@norte.com',
        password: 'clave1234',
        rol: 'cocina',
        restauranteId: 'norte',
      );

      expect(visto!['restauranteId'], 'norte');
      // `creado: false` = el alta fue una REPARACIÓN idempotente, no un alta
      // nueva. La pantalla lo distingue en su copy.
      expect(res.creado, isFalse);
      expect(res.restauranteId, 'norte');
    });
  });

  group('crearStaffAccion — traducción de errores', () {
    Future<String> mensajeDe(String code, {String? message}) async {
      final c = _container(
        db: FakeFirebaseFirestore(),
        role: 'admin_restaurante',
        rid: 'demo',
        callable: (_) async => throw _ErrorCallable(code, message: message),
      );
      try {
        await c.read(crearStaffAccionProvider)(
          nombre: 'X',
          email: 'x@demo.com',
          password: 'clave1234',
          rol: 'mesero',
        );
        fail('debía lanzar');
      } on EquipoException catch (e) {
        return e.message;
      }
    }

    test('permission-denied', () async {
      expect(await mensajeDe('permission-denied'),
          'No tienes permiso para crear ese usuario.');
    });

    test('invalid-argument propaga el mensaje del servidor (el único que sí)',
        () async {
      expect(
        await mensajeDe('invalid-argument',
            message: 'La contraseña debe tener al menos 8 caracteres.'),
        'La contraseña debe tener al menos 8 caracteres.',
      );
    });

    test('already-exists', () async {
      final m = await mensajeDe('already-exists');
      expect(m, contains('ya está en uso'));
      // NO afirma cuál de las dos ramas del anti-secuestro fue: la callable usa
      // este código tanto para "otro restaurante" como para "cuenta de
      // cliente", y decir una de las dos mentiría en la otra.
      expect(m, contains('cliente'));
    });

    test('not-found CON mensaje del servidor sigue siendo el del rid', () async {
      // `mensajeDe` manda «texto crudo del servidor» por defecto, así que este
      // caso ejercita el `not-found` que emite la CALLABLE
      // (`crear-usuario-staff.js:152`), no el de la función sin desplegar.
      // Los dos se separan desde 11-26; el segundo vive en
      // `equipo_sin_functions_test.dart`.
      expect(await mensajeDe('not-found'), 'El restaurante no existe.');
    });

    test('unauthenticated', () async {
      expect(await mensajeDe('unauthenticated'),
          'Tu sesión expiró. Vuelve a iniciar sesión.');
    });

    test(
        'failed-precondition NO dice "intenta de nuevo" (reintentar no arregla nada)',
        () async {
      final m = await mensajeDe('failed-precondition');
      expect(m, contains('no tiene restaurante asignado'));
      expect(m, isNot(contains('Intenta de nuevo')));
    });

    test('un código desconocido cae en el genérico y NO filtra el texto crudo',
        () async {
      // Era `internal`, que desde 11-26 significa «la callable no está
      // desplegada» y tiene su propio texto. El caso que este test protege es
      // otro —código que nadie maneja → genérico, sin filtrar el crudo— y
      // `aborted` lo ejercita igual: no lo emite ninguna de las dos callables
      // ni está en el grupo de indisponibilidad. Que `internal` tampoco filtre
      // el crudo se comprueba en `equipo_sin_functions_test.dart`.
      final m = await mensajeDe('aborted', message: 'stack interno del SDK');
      expect(m, 'No se pudo crear el usuario. Intenta de nuevo.');
      expect(m, isNot(contains('stack interno')));
    });

    test('un error que NO es de Functions tampoco filtra nada', () async {
      final c = _container(
        db: FakeFirebaseFirestore(),
        role: 'admin_restaurante',
        rid: 'demo',
        callable: (_) async => throw StateError('detalle interno feo'),
      );
      await expectLater(
        c.read(crearStaffAccionProvider)(
          nombre: 'X',
          email: 'x@demo.com',
          password: 'clave1234',
          rol: 'mesero',
        ),
        throwsA(
          isA<EquipoException>().having((e) => e.message, 'message',
              'No se pudo crear el usuario. Intenta de nuevo.'),
        ),
      );
    });
  });
}
