import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'core/theme.dart';
import 'features/auth/auth_controller.dart';
import 'features/auth/login_screen.dart';
import 'features/auth/register_screen.dart';
import 'features/pedidos/menu_mesa_screen.dart';
import 'features/pedidos/pedido_estado_screen.dart';
import 'features/pagos/pago_screen.dart';
import 'features/perfil/perfil_screen.dart';
import 'features/restaurantes/home_screen.dart';
import 'features/restaurantes/restaurante_detalle_screen.dart';
import 'features/restaurantes/restaurantes_list_screen.dart';
import 'features/reservas/mis_reservas_screen.dart';
import 'features/reservas/reserva_wizard_screen.dart';
import 'features/sesion_qr/scan_screen.dart';
import 'features/shared/app_shell.dart';

/// GoRouter con auth guard + navegación inferior de 4 tabs.
///
/// * `refreshListenable`: ValueNotifier que se incrementa en cada cambio del
///   authState (stream de FirebaseAuth — login/logout/restauración de
///   sesión persistida) → el redirect se re-evalúa.
/// * [StatefulShellRoute.indexedStack]: 4 branches hermanas (Inicio /
///   Restaurantes / Reservas / Perfil) — cada tab preserva su propio estado
///   (scroll, datos cargados) al switchear. Es la solución oficial de
///   go_router 17 para bottom nav (Pattern 1 del research 05); el
///   `ShellRoute` del panel NO sirve aquí (una sola branch activa).
/// * `/restaurantes/:id` (detalle) y `/reservas/wizard` viven FUERA del
///   shell: se abren push sobre pantalla completa (ocultan el bottom nav).
final goRouterProvider = Provider<GoRouter>((ref) {
  final routerNotifier = ValueNotifier<int>(0);
  ref.listen(authStateProvider, (_, _) => routerNotifier.value++);
  ref.onDispose(routerNotifier.dispose);

  return GoRouter(
    initialLocation: '/inicio',
    refreshListenable: routerNotifier,
    redirect: (context, state) {
      // Solo AsyncData con User no-null está "logueado" — isLoading (sesión
      // persistida restaurándose) y AsyncError se tratan como no logueado
      // (misma defensa que el panel).
      final loggedIn = ref.read(authStateProvider).value != null;
      final onAuth = state.matchedLocation.startsWith('/login') ||
          state.matchedLocation.startsWith('/register');

      if (!loggedIn && !onAuth) return '/login';
      if (loggedIn && onAuth) return '/inicio';
      return null;
    },
    routes: [
      GoRoute(path: '/login', builder: (_, _) => const LoginScreen()),
      GoRoute(path: '/register', builder: (_, _) => const RegisterScreen()),

      // Push fullscreen (sin bottom nav).
      GoRoute(path: '/sesion/scan', builder: (_, _) => const ScanScreen()),
      GoRoute(path: '/mesa', builder: (_, _) => const MenuMesaScreen()),
      GoRoute(
        path: '/mesa/pedidos',
        builder: (_, _) => const PedidoEstadoScreen(),
      ),
      GoRoute(
        path: '/mesa/pago',
        builder: (_, _) => const PagoScreen(),
      ),
      GoRoute(
        path: '/restaurantes/:id',
        builder: (_, state) => RestauranteDetalleScreen(
          restauranteId: int.parse(state.pathParameters['id']!),
        ),
      ),
      GoRoute(
        path: '/reservas/wizard',
        builder: (_, state) => ReservaWizardScreen(
          restauranteId: int.tryParse(
                state.uri.queryParameters['restauranteId'] ?? '',
              ) ??
              0,
          restauranteNombre:
              state.uri.queryParameters['restauranteNombre'] ?? '',
        ),
      ),

      // 4 tabs del bottom nav — cada branch preserva su estado.
      StatefulShellRoute.indexedStack(
        builder: (_, _, navigationShell) =>
            AppShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/inicio',
                builder: (_, _) => const HomeScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/restaurantes',
                builder: (_, _) => const RestaurantesListScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/reservas',
                builder: (_, _) => const MisReservasScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/perfil',
                builder: (_, _) => const PerfilScreen(),
              ),
            ],
          ),
        ],
      ),
    ],
  );
});

class GriClienteApp extends ConsumerWidget {
  const GriClienteApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(goRouterProvider);
    return MaterialApp.router(
      title: 'GRI Cliente',
      debugShowCheckedModeBanner: false,
      theme: griTheme,
      routerConfig: router,
    );
  }
}
