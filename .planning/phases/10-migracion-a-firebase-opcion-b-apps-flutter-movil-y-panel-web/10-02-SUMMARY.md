---
phase: 10-migracion-a-firebase-opcion-b-apps-flutter-movil-y-panel-web
plan: "02"
subsystem: app_cliente
tags: [firebase, auth, state-machines, flutter, migracion]
requires:
  - "10-01 (rules/indexes/firebase.json — agente paralelo en raíz)"
provides:
  - "firebase_bootstrap + firebase_options (proyecto p-gri-b5b40, android+web)"
  - "firebaseAuthProvider/firestoreProvider (override point de tests para 10-03/10-04)"
  - "core/state_machines.dart port 1:1 verificado (5 máquinas)"
  - "authStateProvider StreamProvider<User?> + claimsProvider (role,rid)"
  - "test/helpers/firebase_fakes.dart (seed demo + mockAuth, reutilizable)"
affects:
  - "app_cliente auth (login/registro/logout), perfil, router guard"
tech-stack:
  added:
    - "firebase_core 4.13.0"
    - "firebase_auth 6.5.7"
    - "cloud_firestore 6.8.0"
    - "fake_cloud_firestore 4.2.0 (dev)"
    - "firebase_auth_mocks 0.15.2 (dev)"
    - "mock_exceptions ^0.8.2 (dev, directo)"
  patterns:
    - "Bootstrap secuencial initApp→useAuthEmulator→useFirestoreEmulator antes de runApp, gate const bool.fromEnvironment(USE_EMULATORS)"
    - "Providers inyectables de instancias Firebase como único punto de override en tests"
    - "Controllers riverpod class-based con submit()→Future<bool> + StateError.message como contrato de mensajes de UI (contracto de la era dio conservado)"
key-files:
  created:
    - app_cliente/lib/firebase_options.dart
    - app_cliente/lib/core/firebase_bootstrap.dart
    - app_cliente/lib/core/firebase_providers.dart
    - app_cliente/lib/core/state_machines.dart
    - app_cliente/test/state_machines_test.dart
    - app_cliente/test/helpers/firebase_fakes.dart
  modified:
    - app_cliente/pubspec.yaml
    - app_cliente/lib/main.dart
    - app_cliente/lib/app.dart
    - app_cliente/lib/features/auth/auth_controller.dart
    - app_cliente/lib/features/perfil/perfil_controller.dart
    - app_cliente/lib/features/perfil/perfil_screen.dart
    - app_cliente/test/auth/login_register_test.dart
    - app_cliente/test/perfil/perfil_edit_test.dart
decisions:
  - "firebase_options.dart escrito a mano (fallback documentado): flutterfire CLI no instalado y configure requiere firebase login interactivo"
  - "authStateProvider deriva de firebaseAuthProvider (no watch del StreamProvider — watch devuelve AsyncValue); claimsProvider lee currentUser + getIdTokenResult(true)"
  - "Tests que registran throws de mock_exceptions usan uids distintos: el registry global clavea por == y MockUser (EquatableMixin) es == por valor"
metrics:
  duration: "25m"
  completed: "2026-08-16"
  tests: "73 pass (43 legacy intactos + 30 nuevos: 13 state_machines + 11 auth + 6 perfil)"
  analyze: "0 issues"
---

# Phase 10 Plan 02: app_cliente — bootstrap Firebase + state machines + auth/perfil Summary

**One-liner:** app_cliente arranca sobre Firebase (p-gri-b5b40, emuladores solo con flag), con las 5 state machines porteadas 1:1 de Python (13 tests) y auth/registro/logout/perfil 100% sobre FirebaseAuth + doc espejo usuarios/{uid}, con helpers de fakes reutilizables para 10-03/10-04.

## What Was Built

### Task 1 — Bootstrap + providers (458f6ca)
- Deps con pins exactos: firebase_core 4.13.0 / firebase_auth 6.5.7 / cloud_firestore 6.8.0 + fakes de dev. `flutter pub deps` confirma las 5 versiones.
- `firebase_options.dart` con `DefaultFirebaseOptions.currentPlatform` (android `gri.app` + web `grip.web`, projectId p-gri-b5b40) — **fallback manual** del plan (valores inline de google-services.json / firebase-config-web.js; con options vía Dart no se requiere el plugin Gradle).
- `firebase_bootstrap.dart`: `Firebase.initializeApp` → si `const bool.fromEnvironment('USE_EMULATORS', defaultValue: false)` → `useAuthEmulator('127.0.0.1', 9099)` + `useFirestoreEmulator('127.0.0.1', 8080)`, en ese orden y **antes de runApp** (Pitfall 2: sin el flag las llamadas no existen en el binario — gate `const`).
- `firebase_providers.dart`: `firebaseAuthProvider` / `firestoreProvider` (keepAlive, override point de tests) + `authStateChangesProvider`.
- `main.dart`: `dotenv.load` legacy se mantiene (env.dart vive hasta 10-04).

### Task 2 — Port 1:1 state machines (a4d2458 RED → cc48628 GREEN)
- `core/state_machines.dart`: 5 tablas `Map<String, Set<String>>` (mesa/pedido/reserva/pago/sesion_mesa) idénticas línea a línea a `state_machines.py` (diff documentado en el commit); `TransicionInvalidaException` con toString `[maquina] transición 'actual' → 'nueva' no permitida`; `validarTransicion` / `puedeTransicionar` / `transicionesDe` (accessor para el test de cobertura). Módulo PURO (cero imports Firestore/Auth).
- 13 tests: port completo de `backend/tests/test_state_machines.py` (ciclo mesa, cadena pedido, terminales-rechazan-todo en las 5 máquinas, cobertura de tablas, mensaje de excepción) + matriz FULL de consistencia validar↔puede (5×N² casos).

### Task 3 — Fakes + auth/perfil migrados (3f7b427, 5dbd3d8)
- `test/helpers/firebase_fakes.dart`: `buildFakeFirestoreConSeed()` (restaurantes/demo, mesas GRI-MESA-demo-001..003, 2 categorías, 4 productos int COP) + `mockAuth()` firmado. Patrón de override documentado: providers se overridean por valor; claims se overridean directo (no se mockea el token); errores via `whenCalling(Invocation.method(#simbolo, null))`.
- `auth_controller.dart` reescrito (misma forma de consumo: `submit()` → `Future<bool>`, StateError.message para la UI):
  - login → `signInWithEmailAndPassword` con mapeo `invalid-credential`→'Credenciales inválidas', `network-request-failed`→sin conexión, email-already-in-use, too-many-requests, etc.
  - registro → `createUserWithEmailAndPassword` (auto-login nativo) + `updateDisplayName` + `set(usuarios/{uid}, {role: 'cliente', restauranteId: null, createdAt: serverTimestamp})` — **nunca otro role**.
  - logout → `signOut`; `authStateProvider` (StreamProvider<User?>) reemplaza a token_provider en el router; `claimsProvider` lee `(role, rid)` del idTokenResult con forceRefresh — solo gating de UI (authz vive en rules).
- `perfil_controller.dart`: `perfilProvider` (currentUser + doc usuarios/{uid} con fallback a displayName/email de Auth); `actualizarNombre` → update que toca **solo 'nombre'**; `cambiarPassword` → `reauthenticateWithCredential(EmailAuthProvider...)` + `updatePassword`, `wrong-password` → 'Contraseña actual incorrecta'.
- `app.dart`: guard y refreshListenable al nuevo `authStateProvider` (misma lógica redirect: no logueado→/login; logueado en /login|/register→/inicio). Ruta `/mesa/pago` e import conservados hasta 10-04.
- Tests: registro asserta `usuarios/{uid}.role == 'cliente'`, `restauranteId == null` y keys exactas del doc; perfil asserta single-field update (keys intactas) y mapeo de password incorrecta; widget parity de validación pre-red intacta.

## Verification Results

| Check | Resultado |
|---|---|
| `flutter pub get` con 5 pins exactos | ✅ resueltos tal cual |
| `firebase_options` projectId p-gri-b5b40 + android + web | ✅ |
| Gate emuladores `const bool.fromEnvironment`, antes de runApp | ✅ (sin el define las llamadas se podan del binario) |
| `flutter analyze` | ✅ 0 issues |
| Suite completa | ✅ **73/73** (43 legacy sin regresiones + 30 nuevos) |
| `state_machines_test.dart` | ✅ 13/13 (incluye matriz full de consistencia) |
| Registro escribe espejo con role cliente | ✅ assertado en test |
| App escribe claims | ✅ NINGUNA escritura (solo lectura idTokenResult) |
| Features no migradas (restaurantes/reservas/pedidos/pagos/ws) | ✅ intactas — compilan y sus tests siguen verdes |

## Deviations from Plan

### Desvíos Rule 3 (auto-aplicados)

**1. [Rule 3 - Blocking] firebase_options.dart manual en vez de flutterfire CLI**
- **Found during:** Task 1
- **Issue:** `flutterfire` CLI no instalado y `flutterfire configure` requiere `firebase login` interactivo (imposible en ejecución no interactiva).
- **Fix:** Fallback manual EXACTO que el propio plan documenta: archivo escrito a mano con los valores inline del bloque interfaces. Nota del plan: "con options vía Dart NO se requiere el plugin Gradle de google-services".
- **Files:** app_cliente/lib/firebase_options.dart
- **Commit:** 458f6ca

**2. [Rule 3 - Blocking] perfil_screen.dart rewireado (no estaba en files_modified)**
- **Found during:** Task 3
- **Issue:** la screen consumía el controller viejo (`updatePerfil(nombre, password)` + `authStateProvider` de token_provider) — imposible migrar perfil sin tocarla.
- **Fix:** rewiring mínimo: watch de `perfilProvider`, `_guardar` → `actualizarNombre` + `cambiarPassword` condicional, logout vía `LogoutController`; se agregó campo "Contraseña actual" (necesario para el re-auth del cambio de password).
- **Files:** app_cliente/lib/features/perfil/perfil_screen.dart
- **Commit:** 3f7b427

**3. [Rule 3 - Blocking] mock_exceptions ^0.8.2 como dev dep directa**
- **Found during:** Task 3
- **Issue:** simular `FirebaseAuthException` (credenciales inválidas, wrong-password) requiere `whenCalling` de mock_exceptions; importarla como transitiva dispara el lint `depend_on_referenced_packages` (analyze-0 es AC).
- **Fix:** dev dep directa (misma versión ya resuelta 0.8.2). No altera los pins locked.
- **Files:** app_cliente/pubspec.yaml, app_cliente/pubspec.lock
- **Commit:** 3f7b427, 5dbd3d8

### Decisiones técnicas menores (documentadas en código)

- **`authStateProvider` deriva de `firebaseAuthProvider` directo** (no `ref.watch` del StreamProvider hermano — watch devuelve `AsyncValue`, no el stream). Semántica idéntica y override-safe.
- **`claimsProvider` sin sesión retorna `('invitado', null)`** — el plan no especificaba el caso; string dedicado para que el gating de UI no confunda 'cliente'.
- **`transicionesDe()` público** en state_machines — necesario para portear `test_cobertura_declarada` (los tests Python acceden a las tablas; el accessor evita exponer el registro completo).
- **Gotcha mock_exceptions:** su registry es global y clavea por `==`; `MockUser` usa EquatableMixin (== por valor) → un throw registrado en un test matchea users "value-iguales" de tests siguientes. Mitigación: uids distintos (`uid-wrong-pass`) en los tests que registran throws. Documentado en los propios tests.

## Auth Gates

Ninguno. Los emuladores NO se usaron (todo contra fakes — por diseño del plan para CI).

## Notes for Continuation (10-03 / 10-04)

- `test/helpers/firebase_fakes.dart` está listo para reutilizar (seed demo completo).
- Features no migradas siguen con providers viejos (dio/api_client/token_provider/ws_client): NO tocar hasta sus planes. El greeting de home_screen y el ws_client leen el `authStateProvider` VIEJO (null tras migración) — esperado; se corrige en 10-03/10-04.
- 10-04 purga: borrar auth_storage/token_provider/api_client/env/ws_client + tests ws + `dotenv.load` de main.dart.
- El pubspec NO quitó ninguna dep legacy (Pitfall 10).

## Self-Check: PASSED

- Archivos clave en disco: firebase_options.dart ✅ / firebase_bootstrap.dart ✅ / firebase_providers.dart ✅ / state_machines.dart ✅ / firebase_fakes.dart ✅
- Commits verificados en git log: 458f6ca ✅ / a4d2458 ✅ / cc48628 ✅ / 3f7b427 ✅ / 5dbd3d8 ✅
- flutter analyze 0 issues + flutter test 73/73 ✅ (última corrida post-último-commit de código)
