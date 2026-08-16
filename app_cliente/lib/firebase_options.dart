// firebase_options.dart — config del proyecto Firebase p-gri-b5b40.
//
// FALLBACK MANUAL (10-02 Task 1): el archivo estándar lo genera
// `flutterfire configure`, pero ese comando requiere `firebase login`
// interactivo. Valores transcritos de:
//   * documentos/google-services.json  (app Android `gri.app`)
//   * documentos/firebase-config-web.js (app Web `grip.web`)
// Shape idéntica al archivo generado (docs/FIREBASE_SETUP.md §7): con options
// vía Dart NO se requiere el plugin Gradle de google-services.
//
// Plataformas soportadas: android + web (las apps registradas del proyecto).
// ignore_for_file: type=lint

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Default [FirebaseOptions] para inicializar Firebase en esta app.
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
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        throw UnsupportedError(
          'DefaultFirebaseOptions no está configurado para iOS — '
          'agregá la app en la consola de Firebase y regenerá este archivo.',
        );
      case TargetPlatform.macOS:
        throw UnsupportedError(
          'DefaultFirebaseOptions no está configurado para macOS.',
        );
      case TargetPlatform.windows:
        throw UnsupportedError(
          'DefaultFirebaseOptions no está configurado para Windows.',
        );
      case TargetPlatform.linux:
        throw UnsupportedError(
          'DefaultFirebaseOptions no está configurado para Linux.',
        );
      case TargetPlatform.fuchsia:
        throw UnsupportedError(
          'DefaultFirebaseOptions no está configurado para Fuchsia.',
        );
    }
  }

  /// App Web `grip.web` (firebase-config-web.js).
  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyAXPPuBMkMUgt_piyLg6uvWiEY0ff4kiC4',
    appId: '1:703827387403:web:08ae995e35ce9516e6d30e',
    authDomain: 'p-gri-b5b40.firebaseapp.com',
    messagingSenderId: '703827387403',
    projectId: 'p-gri-b5b40',
    storageBucket: 'p-gri-b5b40.firebasestorage.app',
    measurementId: 'G-8H4SQ9ZHV5',
  );

  /// App Android `gri.app` (google-services.json, client 0).
  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyBZe8QtDCsv3RTZc9ykoQ9wBJskboyOzwk',
    appId: '1:703827387403:android:b55b9ee758dc5108e6d30e',
    messagingSenderId: '703827387403',
    projectId: 'p-gri-b5b40',
    storageBucket: 'p-gri-b5b40.firebasestorage.app',
  );
}
