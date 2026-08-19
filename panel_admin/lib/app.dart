import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'core/firebase_providers.dart';
import 'core/theme.dart';
import 'features/auth/login_screen.dart';
import 'features/bootstrap/bootstrap_screen.dart';
import 'features/clientes/clientes_screen.dart';
import 'features/cocina/cocina_screen.dart';
import 'features/configuracion/configuracion_screen.dart';
import 'features/dashboard/dashboard_screen.dart';
import 'features/equipo/equipo_provider.dart' show rolesQueGestionanEquipo;
import 'features/equipo/equipo_screen.dart';
import 'features/mesas/mesas_screen.dart';
import 'features/reportes/reportes_screen.dart';
import 'features/reservas/reservas_screen.dart';
import 'features/shared/app_shell.dart';
import 'features/shared/not_found_screen.dart';

/// GoRouter con auth guard + ShellRoute (sidebar persistente).
///
/// Phase 10: `refreshListenable` se dispara en cada cambio del
/// authStateChanges de FirebaseAuth (login/logout/persistencia del SDK —
/// sustituyó al authState de la era REST/tokens).
final goRouterProvider = Provider<GoRouter>((ref) {
  final routerNotifier = ValueNotifier<int>(0);
  ref.listen(authStateChangesProvider, (_, _) => routerNotifier.value++);
  // También los CLAIMS: el gating de `/equipo` depende del rol, y los claims
  // se resuelven DESPUÉS del evento de sesión. Sin este listener, un
  // `admin_restaurante` que abriera /equipo por URL sería evaluado con los
  // claims todavía en `AsyncLoading` y el redirect no se volvería a ejecutar
  // al llegar el rol.
  ref.listen(claimsProvider, (_, _) => routerNotifier.value++);
  ref.onDispose(routerNotifier.dispose);

  return GoRouter(
    initialLocation: '/',
    refreshListenable: routerNotifier,
    // 404 propio en vez de la pantalla roja de Flutter. EL ORDEN IMPORTA: el
    // `redirect` de abajo se evalúa ANTES que este `errorBuilder`, así que sin
    // sesión una ruta desconocida sigue yendo a /login — el 404 no sirve para
    // sondear qué rutas internas existen (T-11-09-03). Cubierto por
    // test/router_404_test.dart, con su caso negativo.
    errorBuilder: (context, state) => NotFoundScreen(uri: state.uri),
    redirect: (context, state) {
      // Solo AsyncData con User no-null está "logueado" — isLoading y
      // AsyncError se tratan como no logueado (misma defensa T-04-08).
      // El RECHAZO de rol cliente vive en LoginController (defense UX):
      // un cliente nunca queda con sesión abierta en el panel.
      final loggedIn = ref.read(authStateChangesProvider).value != null;

      // `/bootstrap` es EXENTA EN AMBOS SENTIDOS y el `return null` es
      // incondicional a propósito. NO "limpiar" esto:
      // `createUserWithEmailAndPassword` emite un evento de authStateChanges,
      // el `refreshListenable` de arriba re-evalúa este redirect, y sin la
      // exención el usuario sería expulsado de /bootstrap hacia '/' CON LA
      // CALLABLE TODAVÍA EN VUELO — dejando la reversión de la cuenta sin
      // pantalla donde ejecutarse. La navegación de salida la hace la propia
      // pantalla con `context.go('/')` cuando termina.
      // Cubierto por test/bootstrap/bootstrap_router_test.dart.
      if (state.matchedLocation == '/bootstrap') return null;

      const rutasPublicas = {'/login', '/bootstrap'};
      final esPublica = rutasPublicas.contains(state.matchedLocation);

      if (!loggedIn) return esPublica ? null : '/login';
      if (state.matchedLocation == '/login') return '/';

      // Gating de `/equipo` por rol. ESTO NO ES SEGURIDAD: es lo que impide
      // llegar por URL en web (el ítem del sidebar ya está oculto). La
      // autorización real son `firestore.rules` (listado del equipo acotado al
      // rid) y la callable `crearUsuarioStaff` (alta), las dos con suite propia
      // contra emuladores.
      //
      // Mientras los claims cargan NO se decide: `.value` es null y expulsar
      // ahí echaría a un admin legítimo. El `ref.listen(claimsProvider)` de
      // arriba re-evalúa este redirect en cuanto el rol llega.
      if (state.matchedLocation == '/equipo') {
        final rol = ref.read(claimsProvider).value?.role;
        if (rol != null && !rolesQueGestionanEquipo.contains(rol)) return '/';
      }
      return null;
    },
    routes: [
      GoRoute(path: '/login', builder: (_, _) => const LoginScreen()),
      // FUERA del ShellRoute: el bootstrap no tiene sidebar (no hay
      // restaurante ni sesión de staff todavía).
      GoRoute(path: '/bootstrap', builder: (_, _) => const BootstrapScreen()),
      ShellRoute(
        // state.uri.path → AppShell deriva el ítem activo del sidebar.
        builder: (_, state, child) =>
            AppShell(location: state.uri.path, child: child),
        routes: [
          GoRoute(path: '/', builder: (_, _) => const DashboardScreen()),
          GoRoute(path: '/mesas', builder: (_, _) => const MesasScreen()),
          GoRoute(path: '/cocina', builder: (_, _) => const CocinaScreen()),
          GoRoute(
            path: '/clientes',
            builder: (_, _) => const ClientesScreen(),
          ),
          GoRoute(
            path: '/reservas',
            builder: (_, _) => const ReservasScreen(),
          ),
          GoRoute(
            path: '/reportes',
            builder: (_, _) => const ReportesScreen(),
          ),
          GoRoute(
            path: '/equipo',
            builder: (_, _) => const EquipoScreen(),
          ),
          GoRoute(
            path: '/configuracion',
            builder: (_, _) => const ConfiguracionScreen(),
          ),
        ],
      ),
    ],
  );
});

class GriApp extends ConsumerWidget {
  const GriApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(goRouterProvider);
    return MaterialApp.router(
      title: 'GRI Panel',
      debugShowCheckedModeBanner: false,
      theme: griTheme,
      routerConfig: router,
    );
  }
}
