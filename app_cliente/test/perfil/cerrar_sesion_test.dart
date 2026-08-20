// ============================================================================
// GRI — CERRAR SESIÓN desde el perfil del comensal (plan 11-34).
//
// ── POR QUÉ EXISTE ESTE ARCHIVO ──────────────────────────────────────────
// 11-34 le puso al PANEL el botón de cerrar sesión que le faltaba, y al
// llamar por primera vez a su `logout()` saltó un defecto de fontanería de
// Riverpod 3: `ref.read(...notifier).logout()` no crea listener, el notifier
// autoDispose se dispone mientras el `await signOut()` está en vuelo, y el
// `ref.invalidate(claimsProvider)` posterior lanza «Cannot use "ref" after the
// provider was disposed». Efecto silencioso: los claims del usuario que sale
// se quedan cacheados.
//
// La app cliente SÍ tenía el botón (`perfil_screen.dart`), pero su
// `LogoutController.logout()` es código idéntico y se invoca igual. El test
// de unidad que ya existía —`login_register_test.dart`, «logout cierra la
// sesión»— NO puede ver este fallo: llama al notifier desde un
// `ProviderContainer` que el propio test retiene. Hace falta el recorrido por
// la PANTALLA, que es donde el provider queda sin listener. Eso es lo que
// hace este archivo.
// ============================================================================

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gri_cliente/core/firebase_providers.dart';
import 'package:gri_cliente/features/perfil/perfil_screen.dart';

import '../helpers/firebase_fakes.dart';

const _uid = 'test-uid';

Future<FakeFirebaseFirestore> _db() async {
  final db = FakeFirebaseFirestore();
  await db.collection('usuarios').doc(_uid).set({
    'nombre': 'Carlos Pérez',
    'email': 'carlos@demo.gri.dev',
    'role': 'cliente',
    'restauranteId': null,
    'createdAt': FieldValue.serverTimestamp(),
  });
  return db;
}

void main() {
  testWidgets('el botón "Cerrar sesión" está en el perfil', (tester) async {
    final auth = mockAuth(email: 'carlos@demo.gri.dev');
    await tester.pumpWidget(ProviderScope(
      overrides: [
        firebaseAuthProvider.overrideWithValue(auth),
        firestoreProvider.overrideWithValue(await _db()),
      ],
      child: const MaterialApp(home: Scaffold(body: PerfilScreen())),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Cerrar sesión'), findsOneWidget);
  });

  testWidgets(
      'pulsarlo cierra la sesión de verdad y SIN excepciones de Riverpod',
      (tester) async {
    // El caso que reproduce el defecto: el `logout()` se invoca desde la
    // PANTALLA, sin ningún listener que retenga al notifier durante el await.
    final excepciones = <String>[];
    final anterior = FlutterError.onError;
    FlutterError.onError = (d) => excepciones.add(d.exceptionAsString());

    final auth = mockAuth(email: 'carlos@demo.gri.dev');
    try {
      await tester.pumpWidget(ProviderScope(
        overrides: [
          firebaseAuthProvider.overrideWithValue(auth),
          firestoreProvider.overrideWithValue(await _db()),
        ],
        child: const MaterialApp(home: Scaffold(body: PerfilScreen())),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Cerrar sesión'));
      await tester.pumpAndSettle();
    } finally {
      // Se restaura ANTES de cualquier expect: si un expect falla con el hook
      // puesto, el harness aborta con «a foundation debug variable was
      // changed» y el motivo real se pierde (misma lección que 11-23).
      FlutterError.onError = anterior;
    }

    expect(auth.currentUser, isNull, reason: 'la sesión tiene que cerrarse');
    expect(
      excepciones.where((e) => e.contains('after the provider was disposed')),
      isEmpty,
      reason: 'el logout no puede reventar por disposición del notifier:\n'
          '${excepciones.join("\n")}',
    );
  });
}
