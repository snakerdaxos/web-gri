import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'core/theme.dart';
import 'core/token_provider.dart';
import 'features/auth/login_screen.dart';
import 'features/clientes/clientes_screen.dart';
import 'features/cocina/cocina_screen.dart';
import 'features/configuracion/configuracion_screen.dart';
import 'features/dashboard/dashboard_screen.dart';
import 'features/mesas/mesas_screen.dart';
import 'features/reportes/reportes_screen.dart';
import 'features/reservas/reservas_screen.dart';
import 'features/shared/app_shell.dart';

/// GoRouter con auth guard (T-04-08) + ShellRoute (sidebar persistente).
///
/// `refreshListenable`: ValueNotifier que se incrementa en cada cambio del
/// authState (login/logout/session-expired) → el redirect se re-evalúa.
final goRouterProvider = Provider<GoRouter>((ref) {
  final routerNotifier = ValueNotifier<int>(0);
  ref.listen(authStateProvider, (_, _) => routerNotifier.value++);
  ref.onDispose(routerNotifier.dispose);

  return GoRouter(
    initialLocation: '/',
    refreshListenable: routerNotifier,
    redirect: (context, state) {
      // Solo AsyncData con User no-null está "logueado" — isLoading y
      // AsyncError se tratan como no logueado (T-04-08).
      final loggedIn = ref.read(authStateProvider).value != null;
      final onLogin = state.matchedLocation == '/login';

      if (!loggedIn) return onLogin ? null : '/login';
      if (onLogin) return '/';
      return null;
    },
    routes: [
      GoRoute(path: '/login', builder: (_, _) => const LoginScreen()),
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
