// firebase_options.dart — config del proyecto Firebase p-gri-b5b40 (panel).
//
// FALLBACK MANUAL (10-05 Task 1, patrón 10-02 app_cliente): el archivo
// estándar lo genera `flutterfire configure`, pero ese comando requiere
// `firebase login` interactivo. Valores transcritos de
// documentos/firebase-config-web.js (app Web `grip.web`). Shape idéntica
// al archivo generado (docs/FIREBASE_SETUP.md §7): con options vía Dart
// NO se requiere el plugin Gradle de google-services.
//
// El panel es WEB-ONLY: única plataforma soportada.
// ignore_for_file: type=lint

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart' show kIsWeb;

/// Default [FirebaseOptions] para inicializar Firebase en el panel.
///
/// ```dart
/// await Firebase.initializeApp(
///   options: DefaultFirebaseOptions.currentPlatform,
/// );
/// ```
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    throw UnsupportedError(
      'El panel GRI es web-only — no hay configuración Firebase para '
      'plataformas nativas.',
    );
  }

  /// App Web `gri.web` (firebase-config-web.js).
  ///
  /// VERIFICADO EN 11-17 con `firebase apps:list --project p-gri-b5b40`: el
  /// proyecto tiene UNA sola app Web, y `app_cliente` declara este MISMO
  /// `appId` para su build web. Es COMPARTIDA A PROPÓSITO, no un descuido:
  /// el registro web de Firebase no aporta aislamiento (la autorización vive
  /// en claims + firestore.rules, que son del proyecto, no de la app), y un
  /// segundo registro solo separaría métricas de Analytics. Si algún día se
  /// quieren métricas separadas, hay que registrar una app web propia para el
  /// panel y actualizar el caso correspondiente de
  /// `app_cliente/test/core/firebase_options_coherencia_test.dart`.
  ///
  /// El panel es web-only: no tiene carpeta `android/`, así que la corrección
  /// de appId de Android de 11-17 NO le aplica.
  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyAXPPuBMkMUgt_piyLg6uvWiEY0ff4kiC4',
    appId: '1:703827387403:web:08ae995e35ce9516e6d30e',
    authDomain: 'p-gri-b5b40.firebaseapp.com',
    messagingSenderId: '703827387403',
    projectId: 'p-gri-b5b40',
    storageBucket: 'p-gri-b5b40.firebasestorage.app',
    measurementId: 'G-8H4SQ9ZHV5',
  );
}
