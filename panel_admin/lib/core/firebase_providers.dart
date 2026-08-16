// core/firebase_providers.dart — providers de instancias Firebase (Phase 10).
//
// Override point de tests (patrón verificado app_cliente 10-02): los tests
// inyectan MockFirebaseAuth / FakeFirebaseFirestore vía
// `firebaseAuthProvider.overrideWithValue(...)` /
// `firestoreProvider.overrideWithValue(...)` — las features NUNCA tocan
// `FirebaseX.instance` directo (salvo este archivo y el bootstrap).
//
// Para claims/routing NO se mockea el token: se overridea directo el
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
/// persistido al arrancar (persistencia nativa del SDK). Lo consume el
/// redirect del GoRouter (`authStateChangesProvider`).
@Riverpod(keepAlive: true)
Stream<User?> authStateChanges(Ref ref) =>
    ref.watch(firebaseAuthProvider).authStateChanges();

/// Claims `{role, rid}` del idToken — SOLO para enrutado/gating de UI; la
/// autorización real vive en las Security Rules (threat model del plan).
///
/// * `rid` es el restauranteId del tenant para staff; `super_admin` no
///   lleva rid (elige restaurante en el selector).
/// * `forceRefresh: true` al leer: tras un login los claims frescos deben
///   estar ya en el token (evita la carrera del token cacheado).
/// * Sin sesión → `('invitado', null)`. Ausencia de role == cliente
///   (regla `isCliente()` de firestore.rules) — el panel rechaza ambos.
@Riverpod(keepAlive: true)
Future<({String role, String? rid})> claims(Ref ref) async {
  // Rebuild en cada cambio de sesión (login/logout).
  ref.watch(authStateChangesProvider);
  final user = ref.watch(firebaseAuthProvider).currentUser;
  if (user == null) return (role: 'invitado', rid: null);

  final token = await user.getIdTokenResult(true);
  final c = token.claims ?? const <String, dynamic>{};
  return (
    role: c['role'] as String? ?? 'cliente',
    rid: c['rid'] as String?,
  );
}
