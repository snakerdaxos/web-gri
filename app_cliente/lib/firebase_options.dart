// firebase_options.dart — config del proyecto Firebase p-gri-b5b40.
//
// FALLBACK MANUAL (10-02 Task 1): el archivo estándar lo genera
// `flutterfire configure`, pero ese comando requiere `firebase login`
// interactivo. Valores transcritos de:
//   * documentos/google-services.json  (app Android del registro VIEJO — ver
//     el bloque `android` más abajo: ese archivo NO debe usarse ni copiarse a
//     android/app/, y el `appId` fue corregido en 11-17)
//   * documentos/firebase-config-web.js (app Web `gri.web`)
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

  /// App Web `gri.web` (firebase-config-web.js) — es la UNICA app web del
  /// proyecto y la comparten app_cliente y panel_admin a proposito.
  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyAXPPuBMkMUgt_piyLg6uvWiEY0ff4kiC4',
    appId: '1:703827387403:web:08ae995e35ce9516e6d30e',
    authDomain: 'p-gri-b5b40.firebaseapp.com',
    messagingSenderId: '703827387403',
    projectId: 'p-gri-b5b40',
    storageBucket: 'p-gri-b5b40.firebasestorage.app',
    measurementId: 'G-8H4SQ9ZHV5',
  );

  /// App Android `gri_cliente (android)` — packageName `com.gri.gri_cliente`,
  /// el MISMO `applicationId` que declara `android/app/build.gradle.kts`.
  ///
  /// CORREGIDO EN 11-17. Hasta aquí este bloque declaraba el appId de un
  /// registro VIEJO con OTRO packageName, heredado de
  /// `documentos/google-services.json` (cuál es, y por qué ese archivo no debe
  /// copiarse a android/app/: docs/FIREBASE_SETUP.md §9.5).
  /// El appId viejo NO se transcribe aquí a propósito: el gate de coherencia
  /// prohíbe su presencia en este archivo, precisamente para que no pueda
  /// volver por un copiar-pegar desde un comentario.
  /// Para Firestore y para Auth con email/contraseña la discrepancia es
  /// invisible —`projectId` y `messagingSenderId` sí eran correctos, y es lo
  /// que usan esos servicios—, por eso sobrevivió diez fases. Google Sign-In
  /// en Android NO la tolera: la huella SHA-1 se registra contra la app cuyo
  /// packageName coincide con el APK, así que con el registro viejo el
  /// ingreso falla con DEVELOPER_ERROR (código 10) aunque la huella esté bien.
  ///
  /// Valores verificados contra el proyecto real con
  /// `firebase apps:sdkconfig ANDROID 1:703827387403:android:1f0746d200e4e12ce6d30e`.
  /// El `apiKey` es el MISMO en los dos registros (ambos usan la clave Android
  /// del proyecto), así que la corrección se reduce al `appId`.
  ///
  /// El gate `test/core/firebase_options_coherencia_test.dart` impide que la
  /// deriva vuelva a pasar inadvertida.
  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyBZe8QtDCsv3RTZc9ykoQ9wBJskboyOzwk',
    appId: '1:703827387403:android:1f0746d200e4e12ce6d30e',
    messagingSenderId: '703827387403',
    projectId: 'p-gri-b5b40',
    storageBucket: 'p-gri-b5b40.firebasestorage.app',
  );
}
