// core/firebase_bootstrap.dart — bootstrap secuencial de Firebase (Phase 10).
//
// Módulo PURO de arranque: `main()` hace `WidgetsFlutterBinding
// .ensureInitialized()` y luego `await bootstrap()` ANTES de `runApp`.
//
// ORDEN crítico (Pitfall 2 del research 10): initApp → useAuthEmulator →
// useFirestoreEmulator. Si `FirebaseAuth.instance` resuelve antes del
// `useAuthEmulator`, la app toca el proyecto REAL — por eso el gate se
// evalúa aquí, antes de que cualquier provider esté vivo.
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

import '../firebase_options.dart';

/// Inicializa Firebase y (solo con `--dart-define=USE_EMULATORS=true`)
/// conecta Auth + Firestore a los emuladores locales.
///
/// El gate es `const bool.fromEnvironment` → constante en tiempo de
/// compilación: en builds normales (sin el define) las llamadas a
/// `useAuthEmulator`/`useFirestoreEmulator` no existen en el binario y el
/// SDK apunta al proyecto real `p-gri-b5b40`.
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
    // En Android el SDK mapea 127.0.0.1 → 10.0.2.2 automáticamente.
    await FirebaseAuth.instance.useAuthEmulator('127.0.0.1', 9099);
    FirebaseFirestore.instance.useFirestoreEmulator('127.0.0.1', 8080);
  }
}
