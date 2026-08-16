// test/helpers/firebase_fakes.dart — fakes de Firebase para tests del
// panel (Phase 10). Copia adaptada del helper homónimo de app_cliente
// (10-02, patrón verificado): los emuladores NO funcionan en `flutter
// test` (sin platform channels de red) — por eso fakes in-memory.
//
// ── Patrón de override (usar en TODOS los tests de features) ──────────────
//
//     final db = await buildFakeFirestoreConSeed();
//     final auth = mockAuth(email: 'admin@demo.gri.dev');
//     final container = ProviderContainer(overrides: [
//       firebaseAuthProvider.overrideWithValue(auth),
//       firestoreProvider.overrideWithValue(db),
//     ]);
//
// * Las features NUNCA tocan `FirebaseX.instance` — siempre leen
//   `firebaseAuthProvider`/`firestoreProvider` (core/firebase_providers),
//   así los overrides de arriba cortan toda la app del mundo real.
// * Para claims/routing NO se mockea el token: se overridea directo el
//   provider de claims con valores:
//
//     claimsProvider.overrideWith((ref) async => (role: 'mesero', rid: 'demo'))
//
// * Errores de Auth simulados con `whenCalling` de mock_exceptions:
//
//     whenCalling(any).on(auth).thenThrow(
//       FirebaseAuthException(code: 'invalid-credential'),
//     );
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';

/// FakeFirestore con el seed mínimo del restaurante demo — el MISMO shape
/// que scripts/seed_firebase.mjs (research 10) + 2 restaurantes extra para
/// el selector del super_admin (uno inactivo para verificar el filtro
/// `activo == true`): restaurantes/{demo, norte, sur}, mesas
/// GRI-MESA-demo-001..003 (doc ID = código QR), 2 categorías y 4
/// productos con precios int COP.
Future<FakeFirebaseFirestore> buildFakeFirestoreConSeed() async {
  final db = FakeFirebaseFirestore();

  Future<void> restaurante(
    String id,
    String nombre,
    String direccion,
    bool activo,
  ) =>
      db.doc('restaurantes/$id').set({
        'nombre': nombre,
        'descripcion': 'Cocina colombiana de autor en el corazón de Bogotá',
        'tipoCocina': 'Colombiana',
        'direccion': direccion,
        'activo': activo,
        'califProm': 0.0,
        'califCount': 0,
        'createdAt': FieldValue.serverTimestamp(),
      });

  await restaurante('demo', 'Restaurante Demo GRI',
      'Cra. 7 #63-44, Bogotá', true);
  await restaurante(
      'norte', 'GRI Norte', 'Calle 100 #15-30, Bogotá', true);
  await restaurante(
      'sur', 'GRI Sur (inactivo)', 'Cra. 27 #10-20, Bogotá', false);

  // Mesas: doc ID determinista = código QR (research: "QR→mesa es un get()
  // directo por doc ID (O(1)); UNIQUE QR garantizado por construcción").
  const capacidades = [2, 4, 6];
  for (var i = 1; i <= capacidades.length; i++) {
    await db.doc('mesas/GRI-MESA-demo-00$i').set({
      'restauranteId': 'demo',
      'numero': i,
      'capacidad': capacidades[i - 1],
      'estado': 'disponible',
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  // 2 categorías + 4 productos (snapshot de menú mínimo — paridad con el
  // seed de app_cliente; el panel lo consume desde 10-06).
  final platos = await db.collection('categorias').add({
    'restauranteId': 'demo',
    'nombre': 'Platos fuertes',
    'orden': 1,
    'activo': true,
  });
  final bebidas = await db.collection('categorias').add({
    'restauranteId': 'demo',
    'nombre': 'Bebidas',
    'orden': 2,
    'activo': true,
  });

  Future<void> producto(String categoriaId, String nombre,
          String descripcion, int precio) =>
      db.collection('productos').add({
        'restauranteId': 'demo',
        'categoriaId': categoriaId,
        'nombre': nombre,
        'descripcion': descripcion,
        'precio': precio, // int COP — sin floats (research anti-pattern)
        'imagenUrl': '',
        'disponible': true,
        'activo': true,
      });

  await producto(platos.id, 'Bandeja paisa', 'La clásica de siempre', 28000);
  await producto(platos.id, 'Ajiaco santafereño', 'Con pollo y mazorca', 25000);
  await producto(bebidas.id, 'Limonada de coco', 'Fresca de la casa', 8000);
  await producto(bebidas.id, 'Café con leche', 'Tinto campesino', 4500);

  return db;
}

/// MockFirebaseAuth firmado con un usuario de test (uid estable
/// 'test-uid' por defecto para que los docs usuarios/{uid} sean
/// predecibles en los tests).
MockFirebaseAuth mockAuth({
  String? email,
  String uid = 'test-uid',
  String? displayName,
  bool signedIn = true,
}) {
  return MockFirebaseAuth(
    signedIn: signedIn,
    mockUser: MockUser(uid: uid, email: email, displayName: displayName),
  );
}
