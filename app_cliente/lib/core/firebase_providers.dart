// core/firebase_providers.dart — providers de instancias Firebase (Phase 10).
//
// Override point de tests: los tests inyectan MockFirebaseAuth /
// FakeFirebaseFirestore vía `firebaseAuthProvider.overrideWithValue(...)` /
// `firestoreProvider.overrideWithValue(...)` — las features NUNCA tocan
// `FirebaseX.instance` directo (salvo este archivo y el bootstrap).
//
// Para claims/routing: NO se mockea el token — se overridea directo el
// provider de claims (`claimsProvider`) con valores.
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'firebase_providers.g.dart';

/// Instancia única de [FirebaseAuth] (keepAlive — vive toda la app).
@Riverpod(keepAlive: true)
FirebaseAuth firebaseAuth(Ref ref) => FirebaseAuth.instance;

/// Instancia única de [FirebaseFirestore] (keepAlive — vive toda la app).
@Riverpod(keepAlive: true)
FirebaseFirestore firestore(Ref ref) => FirebaseFirestore.instance;

/// Stream de sesión: emite `User?` en cada login/logout + el usuario
/// persistido al arrancar (persistencia nativa del SDK — sustituyó a la
/// capa REST de tokens de la era anterior).
@Riverpod(keepAlive: true)
Stream<User?> authStateChanges(Ref ref) =>
    ref.watch(firebaseAuthProvider).authStateChanges();
