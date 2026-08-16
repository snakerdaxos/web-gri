// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'firebase_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Instancia única de [FirebaseAuth] (keepAlive — vive toda la app).

@ProviderFor(firebaseAuth)
final firebaseAuthProvider = FirebaseAuthProvider._();

/// Instancia única de [FirebaseAuth] (keepAlive — vive toda la app).

final class FirebaseAuthProvider
    extends $FunctionalProvider<FirebaseAuth, FirebaseAuth, FirebaseAuth>
    with $Provider<FirebaseAuth> {
  /// Instancia única de [FirebaseAuth] (keepAlive — vive toda la app).
  FirebaseAuthProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'firebaseAuthProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$firebaseAuthHash();

  @$internal
  @override
  $ProviderElement<FirebaseAuth> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  FirebaseAuth create(Ref ref) {
    return firebaseAuth(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(FirebaseAuth value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<FirebaseAuth>(value),
    );
  }
}

String _$firebaseAuthHash() => r'8c3e9d11b27110ca96130356b5ef4d5d34a5ffc2';

/// Instancia única de [FirebaseFirestore] (keepAlive — vive toda la app).

@ProviderFor(firestore)
final firestoreProvider = FirestoreProvider._();

/// Instancia única de [FirebaseFirestore] (keepAlive — vive toda la app).

final class FirestoreProvider
    extends
        $FunctionalProvider<
          FirebaseFirestore,
          FirebaseFirestore,
          FirebaseFirestore
        >
    with $Provider<FirebaseFirestore> {
  /// Instancia única de [FirebaseFirestore] (keepAlive — vive toda la app).
  FirestoreProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'firestoreProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$firestoreHash();

  @$internal
  @override
  $ProviderElement<FirebaseFirestore> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  FirebaseFirestore create(Ref ref) {
    return firestore(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(FirebaseFirestore value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<FirebaseFirestore>(value),
    );
  }
}

String _$firestoreHash() => r'864285def6284159b44f9598dcde96347e0c1dce';

/// Stream de sesión: emite `User?` en cada login/logout + el usuario
/// persistido al arrancar (persistencia nativa del SDK). Lo consume el
/// redirect del GoRouter (`authStateChangesProvider`).

@ProviderFor(authStateChanges)
final authStateChangesProvider = AuthStateChangesProvider._();

/// Stream de sesión: emite `User?` en cada login/logout + el usuario
/// persistido al arrancar (persistencia nativa del SDK). Lo consume el
/// redirect del GoRouter (`authStateChangesProvider`).

final class AuthStateChangesProvider
    extends $FunctionalProvider<AsyncValue<User?>, User?, Stream<User?>>
    with $FutureModifier<User?>, $StreamProvider<User?> {
  /// Stream de sesión: emite `User?` en cada login/logout + el usuario
  /// persistido al arrancar (persistencia nativa del SDK). Lo consume el
  /// redirect del GoRouter (`authStateChangesProvider`).
  AuthStateChangesProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'authStateChangesProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$authStateChangesHash();

  @$internal
  @override
  $StreamProviderElement<User?> $createElement($ProviderPointer pointer) =>
      $StreamProviderElement(pointer);

  @override
  Stream<User?> create(Ref ref) {
    return authStateChanges(ref);
  }
}

String _$authStateChangesHash() => r'fbc1119daa6ac470aeac4f186072c2b179f82dc5';

/// Claims `{role, rid}` del idToken — SOLO para enrutado/gating de UI; la
/// autorización real vive en las Security Rules (threat model del plan).
///
/// * `rid` es el restauranteId del tenant para staff; `super_admin` no
///   lleva rid (elige restaurante en el selector).
/// * `forceRefresh: true` al leer: tras un login los claims frescos deben
///   estar ya en el token (evita la carrera del token cacheado).
/// * Sin sesión → `('invitado', null)`. Ausencia de role == cliente
///   (regla `isCliente()` de firestore.rules) — el panel rechaza ambos.

@ProviderFor(claims)
final claimsProvider = ClaimsProvider._();

/// Claims `{role, rid}` del idToken — SOLO para enrutado/gating de UI; la
/// autorización real vive en las Security Rules (threat model del plan).
///
/// * `rid` es el restauranteId del tenant para staff; `super_admin` no
///   lleva rid (elige restaurante en el selector).
/// * `forceRefresh: true` al leer: tras un login los claims frescos deben
///   estar ya en el token (evita la carrera del token cacheado).
/// * Sin sesión → `('invitado', null)`. Ausencia de role == cliente
///   (regla `isCliente()` de firestore.rules) — el panel rechaza ambos.

final class ClaimsProvider
    extends
        $FunctionalProvider<
          AsyncValue<({String? rid, String role})>,
          ({String? rid, String role}),
          FutureOr<({String? rid, String role})>
        >
    with
        $FutureModifier<({String? rid, String role})>,
        $FutureProvider<({String? rid, String role})> {
  /// Claims `{role, rid}` del idToken — SOLO para enrutado/gating de UI; la
  /// autorización real vive en las Security Rules (threat model del plan).
  ///
  /// * `rid` es el restauranteId del tenant para staff; `super_admin` no
  ///   lleva rid (elige restaurante en el selector).
  /// * `forceRefresh: true` al leer: tras un login los claims frescos deben
  ///   estar ya en el token (evita la carrera del token cacheado).
  /// * Sin sesión → `('invitado', null)`. Ausencia de role == cliente
  ///   (regla `isCliente()` de firestore.rules) — el panel rechaza ambos.
  ClaimsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'claimsProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$claimsHash();

  @$internal
  @override
  $FutureProviderElement<({String? rid, String role})> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<({String? rid, String role})> create(Ref ref) {
    return claims(ref);
  }
}

String _$claimsHash() => r'511a065a415b0d008ac104e06acd41485f5d3f0e';
