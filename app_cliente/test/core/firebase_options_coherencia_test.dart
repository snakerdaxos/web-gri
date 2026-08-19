// test/core/firebase_options_coherencia_test.dart — gate de coherencia entre
// el registro de Firebase declarado en Dart y el APK que se compila (11-17).
//
// POR QUÉ EXISTE. El proyecto p-gri-b5b40 tiene DOS apps Android registradas:
//
//   com.gri.gri_cliente → 1:703827387403:android:1f0746d200e4e12ce6d30e  (la buena)
//   gri.app            → 1:703827387403:android:b55b9ee758dc5108e6d30e  (registro viejo)
//
// `lib/firebase_options.dart` declaraba el VIEJO desde la Fase 10, y sobrevivió
// diez fases sin que ningún linter ni ninguna prueba lo detectara: para
// Firestore y para Auth con email/contraseña la discrepancia es invisible
// (projectId y messagingSenderId sí eran correctos, que es lo que usan esos
// servicios). Google Sign-In en Android NO la tolera.
//
// Este test es puro `dart:io`: lee los DOS archivos y afirma que el
// `applicationId` de Gradle y el `appId` de Dart pertenecen al MISMO registro.
// Es un gate barato contra una clase de deriva que ya se coló una vez.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Tabla de registros del proyecto, declarada aquí a propósito: si alguien
/// cambia el `applicationId` de Gradle tiene que venir a este archivo y
/// declarar conscientemente contra qué registro de la consola corresponde.
const Map<String, String> registrosAndroid = {
  'com.gri.gri_cliente': '1:703827387403:android:1f0746d200e4e12ce6d30e',
};

/// Registros que NO deben aparecer, con el motivo.
const Map<String, String> registrosProhibidos = {
  '1:703827387403:android:b55b9ee758dc5108e6d30e':
      'es el registro viejo de `gri.app`, cuyo packageName NO coincide con el '
          'APK. Con él, Google Sign-In en Android falla con DEVELOPER_ERROR '
          '(código 10) aunque la huella SHA-1 esté bien registrada.',
};

String _leer(String ruta) {
  final f = File(ruta);
  expect(f.existsSync(), isTrue, reason: 'no se encontró $ruta');
  return f.readAsStringSync();
}

void main() {
  late String gradle;
  late String opciones;

  setUpAll(() {
    gradle = _leer('android/app/build.gradle.kts');
    opciones = _leer('lib/firebase_options.dart');
  });

  test('el applicationId de Gradle está en la tabla de registros', () {
    final m = RegExp(r'''applicationId\s*=\s*["']([^"']+)["']''').firstMatch(gradle);
    expect(m, isNotNull, reason: 'no se pudo extraer applicationId de Gradle');
    final applicationId = m!.group(1)!;

    expect(
      registrosAndroid.containsKey(applicationId),
      isTrue,
      reason: 'El applicationId "$applicationId" no está declarado en '
          '`registrosAndroid`. Si cambiaste el paquete de la app, registrá la '
          'app nueva en Firebase y añadí aquí su appId — si no, la app '
          'apuntará a un registro que no le corresponde.',
    );
  });

  test('el appId de Android de firebase_options CORRESPONDE al applicationId',
      () {
    final applicationId = RegExp(r'''applicationId\s*=\s*["']([^"']+)["']''')
        .firstMatch(gradle)!
        .group(1)!;
    final esperado = registrosAndroid[applicationId]!;

    // Bloque `static const FirebaseOptions android = FirebaseOptions( ... );`
    final bloque = RegExp(
      r'FirebaseOptions\s+android\s*=\s*FirebaseOptions\(([\s\S]*?)\);',
    ).firstMatch(opciones);
    expect(bloque, isNotNull,
        reason: 'no se encontró el bloque `android` en firebase_options.dart');

    final appId = RegExp(r'''appId:\s*["']([^"']+)["']''')
        .firstMatch(bloque!.group(1)!)
        ?.group(1);
    expect(appId, isNotNull,
        reason: 'no se pudo extraer el appId del bloque android');

    expect(
      appId,
      esperado,
      reason: 'INCOHERENCIA DE CONFIGURACIÓN.\n'
          '  applicationId del APK : $applicationId\n'
          '  appId declarado       : $appId\n'
          '  appId que le toca     : $esperado\n'
          'La huella SHA-1 se registra contra la app de la consola cuyo '
          'packageName coincide con el APK. Con el appId equivocado, Google '
          'Sign-In falla en Android con DEVELOPER_ERROR (código 10) — un error '
          'opaco que no dice qué falta — aunque la huella esté bien puesta.',
    );
  });

  test('el registro viejo de gri.app NO aparece en firebase_options', () {
    for (final entrada in registrosProhibidos.entries) {
      expect(
        opciones.contains(entrada.key),
        isFalse,
        reason: 'firebase_options.dart menciona ${entrada.key}, que '
            '${entrada.value}',
      );
    }
  });

  test('el comentario del bloque android no nombra el registro viejo', () {
    // El comentario de la Fase 10 decía literalmente "App Android gri.app" y
    // es lo que documentaba (y perpetuaba) el error. Si vuelve, este caso cae.
    expect(
      RegExp(r'gri\.app').hasMatch(opciones),
      isFalse,
      reason: 'firebase_options.dart todavía nombra `gri.app`: ese es el '
          'registro viejo y el comentario es lo que perpetuó el error.',
    );
  });

  group('la corrección NO altera el resto de la configuración', () {
    // La regeneración de este archivo no debe cambiar nada más por sorpresa.
    // Valores verificados contra `firebase apps:sdkconfig` del proyecto real.
    const invariantes = {
      'projectId': 'p-gri-b5b40',
      'messagingSenderId': '703827387403',
      'storageBucket': 'p-gri-b5b40.firebasestorage.app',
    };

    for (final inv in invariantes.entries) {
      test('android.${inv.key} sigue siendo ${inv.value}', () {
        final bloque = RegExp(
          r'FirebaseOptions\s+android\s*=\s*FirebaseOptions\(([\s\S]*?)\);',
        ).firstMatch(opciones)!.group(1)!;
        final valor = RegExp('${inv.key}' r''':\s*["']([^"']+)["']''')
            .firstMatch(bloque)
            ?.group(1);
        expect(valor, inv.value);
      });
    }

    test('el bloque web queda intacto (lo comparte el panel admin)', () {
      final bloque = RegExp(
        r'FirebaseOptions\s+web\s*=\s*FirebaseOptions\(([\s\S]*?)\);',
      ).firstMatch(opciones)!.group(1)!;
      expect(
        RegExp(r'''appId:\s*["']([^"']+)["']''').firstMatch(bloque)?.group(1),
        '1:703827387403:web:08ae995e35ce9516e6d30e',
      );
    });
  });

  test('el panel admin declara el MISMO registro web que la app cliente', () {
    // El proyecto tiene UNA sola app Web (`gri.web`), verificado con
    // `firebase apps:list`. Las dos apps la comparten A PROPÓSITO — ver el
    // razonamiento en el SUMMARY de 11-17. Este caso lo deja afirmado: si
    // alguien registra una app web propia para el panel, tiene que venir aquí
    // y decidirlo conscientemente.
    final panel = File('../panel_admin/lib/firebase_options.dart');
    expect(panel.existsSync(), isTrue,
        reason: 'no se encontró panel_admin/lib/firebase_options.dart');
    expect(
      panel.readAsStringSync().contains('1:703827387403:web:08ae995e35ce9516e6d30e'),
      isTrue,
    );
  });
}
