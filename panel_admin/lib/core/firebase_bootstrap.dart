// core/firebase_bootstrap.dart — bootstrap secuencial de Firebase (Phase 10).
//
// Módulo PURO de arranque (patrón verificado de app_cliente 10-02):
// `main()` hace `WidgetsFlutterBinding.ensureInitialized()` y luego
// `await bootstrap()` ANTES de `runApp`.
//
// ORDEN crítico (Pitfall 2 del research 10): initApp → useAuthEmulator →
// useFirestoreEmulator → useFunctionsEmulator. Si `FirebaseAuth.instance`
// resuelve antes del `useAuthEmulator`, la app toca el proyecto REAL — por
// eso el gate se evalúa aquí, antes de que cualquier provider esté vivo.
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

import '../firebase_options.dart';

/// Inicializa Firebase y (solo con `--dart-define=USE_EMULATORS=true`)
/// conecta Auth (9099) + Firestore (8080) + Functions (5001) a los
/// emuladores locales.
///
/// El gate es `const bool.fromEnvironment` → constante en tiempo de
/// compilación: en builds normales (sin el define) las llamadas a
/// `useAuthEmulator`/`useFirestoreEmulator`/`useFunctionsEmulator` no
/// existen en el binario y el SDK apunta al proyecto real `p-gri-b5b40`.
Future<void> bootstrap() async {
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Emuladores: SOLO en builds de desarrollo con el flag explícito.
  // `const` garantiza que el árbol se pode sin el define.
  const useEmulators =
      bool.fromEnvironment('USE_EMULATORS', defaultValue: false);
  if (useEmulators) {
    // Auth es async (espera el handshake); Firestore programa el host.
    // Los tres SDK aplican `automaticHostMapping`: en el emulador de Android
    // 127.0.0.1 se reescribe solo a 10.0.2.2, así que el host es el mismo
    // literal en web, escritorio y móvil.
    await FirebaseAuth.instance.useAuthEmulator('127.0.0.1', 9099);
    FirebaseFirestore.instance.useFirestoreEmulator('127.0.0.1', 8080);
    // Functions: MISMA región que el provider y que el `onCall` del codebase
    // functions/ — un desajuste da un 404 opaco (CORS aparente en web).
    // Puerto 5001 = `emulators.functions.port` de firebase.json (11-01).
    FirebaseFunctions.instanceFor(region: 'us-central1')
        .useFunctionsEmulator('127.0.0.1', 5001);
  }
}
