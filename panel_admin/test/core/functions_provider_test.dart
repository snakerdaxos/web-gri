import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Contrato de REGIÓN del cliente de Cloud Functions (11-02, Tarea 2).
///
/// Por qué estos tests leen el CÓDIGO FUENTE en vez de resolver el provider:
/// `FirebaseFunctions.instanceFor(...)` exige una app Firebase inicializada,
/// que en `flutter test` no existe (sin platform channels) — resolver
/// `firebaseFunctionsProvider` reventaría con `No Firebase App '[DEFAULT]'`.
/// Lo que hay que proteger no es el runtime sino el ACUERDO: la región del
/// cliente debe coincidir con la del `onCall` de `functions/`, y el cableado
/// del emulador no puede desaparecer en un refactor.
///
/// Trampa que este gate cubre: una región desalineada NO da un error legible
/// — da un 404 opaco que en Flutter Web se presenta como fallo de CORS, uno
/// de los síntomas más caros de diagnosticar del stack.
void main() {
  final providers = File('lib/core/firebase_providers.dart').readAsStringSync();
  final bootstrap = File('lib/core/firebase_bootstrap.dart').readAsStringSync();

  group('firebaseFunctionsProvider', () {
    test('declara el provider con región explícita us-central1', () {
      expect(providers, contains('FirebaseFunctions firebaseFunctions('));
      expect(
        providers,
        contains("FirebaseFunctions.instanceFor(region: 'us-central1')"),
        reason: 'la región NUNCA puede quedar implícita: sin ella el SDK '
            'asume us-central1 en silencio y cualquier despliegue en otra '
            'región rompe con un 404 opaco',
      );
    });

    test('el provider es keepAlive (instancia única para toda la app)', () {
      expect(providers, contains('@Riverpod(keepAlive: true)'));
    });
  });

  group('bootstrap del emulador de Functions', () {
    test('conecta useFunctionsEmulator en el puerto 5001', () {
      expect(bootstrap, contains('useFunctionsEmulator'));
      expect(bootstrap, contains("useFunctionsEmulator('127.0.0.1', 5001)"));
    });

    test('usa la MISMA región que el provider', () {
      expect(
        bootstrap,
        contains("FirebaseFunctions.instanceFor(region: 'us-central1')"),
      );
    });

    test('el cableado del emulador vive DENTRO del gate useEmulators', () {
      // El gate es `const bool.fromEnvironment` → constante de compilación:
      // sin el --dart-define, la llamada ni siquiera existe en el binario de
      // producción (mitigación T-11-02-03).
      expect(
        bootstrap,
        contains("bool.fromEnvironment('USE_EMULATORS', defaultValue: false)"),
      );

      final gate = bootstrap.indexOf('if (useEmulators) {');
      // La LLAMADA, no la mención en el doc comment de cabecera (que aparece
      // antes del gate): se busca la invocación literal con host y puerto.
      final llamada =
          bootstrap.indexOf(".useFunctionsEmulator('127.0.0.1', 5001)");
      final cierre = bootstrap.indexOf('\n  }', gate);

      expect(gate, greaterThan(-1), reason: 'el gate debe existir');
      expect(llamada, greaterThan(-1), reason: 'la llamada debe existir');
      expect(cierre, greaterThan(gate), reason: 'el gate debe cerrarse');
      expect(
        llamada,
        inInclusiveRange(gate, cierre),
        reason: 'useFunctionsEmulator FUERA del gate se filtraría a '
            'producción y el panel real hablaría con localhost',
      );
    });
  });
}
