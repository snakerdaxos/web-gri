import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/firebase_providers.dart';
import '../../core/theme.dart';
import '../mesas/mesa_actions_sheet.dart';
import 'mesas_provider.dart';
import 'restaurante_provider.dart';
import 'restaurantes_list_provider.dart';
import 'stats_provider.dart';
import 'widgets/mesa_legend.dart';
import 'widgets/mesa_tile.dart';
import 'widgets/stat_card.dart';

/// Dashboard (ADMN-01 + ADMN-02) — 4 stat cards + mapa de mesas coloreado.
///
/// Consume [statsProvider] y [mesasProvider] (ambos Stream con polling 10s).
/// Renderiza estados AsyncLoading / AsyncError / AsyncData idiomáticamente.
///
/// Phase 7 (WS) retira el Timer: el contrato de INPUT cambia (Stream de mesas
/// alimentado por WS en vez de polling), pero el body del screen (este
/// archivo) no se toca — solo los providers.
class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(statsProvider);
    final mesasAsync = ref.watch(mesasProvider);

    // ── Plataforma sin restaurante activo (11-02) ────────────────────────
    //
    // `ridActivoProvider` devuelve null para un super_admin sin selección y
    // `_maybeInitDefaultRid` del AppShell hace `return` sin seleccionar nada
    // cuando la lista viene vacía: el super aterrizaba en un tablero de ceros
    // con un selector vacío y sin ninguna pista de qué hacer (el "selector
    // muerto" de CONCERNS.md). Aquí se sustituyen esas tarjetas en cero por
    // una guía del siguiente paso.
    //
    // Solo aplica al super_admin: el staff siempre trae `rid` por claims.
    // Ambos `.value` son deliberados — mientras claims/rid cargan no se
    // afirma nada y el dashboard sigue su camino normal.
    final esSuperAdmin =
        ref.watch(claimsProvider).value?.role == 'super_admin';
    final ridAsync = ref.watch(ridActivoProvider);
    final sinRestauranteActivo =
        esSuperAdmin && ridAsync.hasValue && ridAsync.value == null;

    // Material ancestor: en producción lo provee el Scaffold del AppShell,
    // pero la pantalla debe ser fiel también standalone (tests/pumps
    // directos) — el InkWell de los MesaTile (08-03) lo exige.
    return Material(
      color: GriColors.background,
      child: LayoutBuilder(
        builder: (context, constraints) {
        // Responsive crossAxisCount del grid de stat cards (4/2/1).
        final statCrossAxis = constraints.maxWidth >= 1100
            ? 4
            : (constraints.maxWidth >= 750 ? 2 : 1);
        // Responsive crossAxisCount del grid de mesas (4/3/2).
        final mesaCrossAxis = constraints.maxWidth >= 1100
            ? 4
            : (constraints.maxWidth >= 750 ? 3 : 2);

        return SingleChildScrollView(
          padding: const EdgeInsets.all(30),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Stat cards (o guía de arranque) ──────────────────────────
              if (sinRestauranteActivo)
                const _GuiaSinRestaurante()
              else
                statsAsync.when(
                loading: () => const SizedBox(
                  height: 130,
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (e, _) => _ErrorBox(
                  message: 'Error cargando estadísticas',
                  onRetry: () => ref.invalidate(statsProvider),
                ),
                data: (s) => GridView.count(
                  crossAxisCount: statCrossAxis,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 20,
                  crossAxisSpacing: 20,
                  // StatCard altura ~99px (padding 22*2 + contenido ~55); el
                  // childAspectRatio 2.6 da una card de aspect ancho en lg.
                  childAspectRatio: 2.6,
                  children: [
                    StatCard(
                      label: 'Mesas disponibles',
                      value: s.mesasDisponibles,
                      iconBg: GriColors.statIconDisponibleBg,
                      iconFg: GriColors.mesaDisponibleDot,
                      emoji: '🪑',
                    ),
                    StatCard(
                      label: 'Mesas ocupadas',
                      value: s.mesasOcupadas,
                      iconBg: GriColors.statIconOcupadaBg,
                      iconFg: GriColors.primary,
                      emoji: '👥',
                    ),
                    StatCard(
                      label: 'Reservas hoy',
                      value: s.reservasHoy,
                      iconBg: GriColors.statIconReservasBg,
                      iconFg: GriColors.mesaReservadaDot,
                      emoji: '📅',
                    ),
                    StatCard(
                      label: 'Pedidos activos',
                      value: s.pedidosActivos,
                      iconBg: GriColors.statIconPedidosBg,
                      iconFg: GriColors.mesaLimpiezaDot,
                      emoji: '📋',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 30),

              // ── Mapa de mesas ─────────────────────────────────────────────
              Container(
                padding: const EdgeInsets.all(25),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(15),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x0D000000),
                      blurRadius: 12,
                      offset: Offset(0, 3),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Estado de las mesas',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: GriColors.text,
                          ),
                        ),
                        // El alta vive en la pantalla de gestión (08-03):
                        // desde el mapa solo se navega a /mesas.
                        ElevatedButton.icon(
                          onPressed: () => context.go('/mesas'),
                          icon: const Text('+'),
                          label: const Text('Nueva mesa'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: GriColors.primary,
                            foregroundColor: Colors.white,
                            disabledBackgroundColor:
                                GriColors.primary.withValues(alpha: 0.4),
                            disabledForegroundColor: Colors.white70,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 25),
                    const MesaLegend(),
                    const SizedBox(height: 25),
                    mesasAsync.when(
                      loading: () => const SizedBox(
                        height: 200,
                        child:
                            Center(child: CircularProgressIndicator()),
                      ),
                      error: (e, _) => _ErrorBox(
                        message: 'Error cargando mesas',
                        onRetry: () => ref.invalidate(mesasProvider),
                      ),
                      data: (mesas) {
                        if (mesas.isEmpty) {
                          return const Padding(
                            padding: EdgeInsets.symmetric(vertical: 40),
                            child: Center(
                              child: Text(
                                'Sin mesas configuradas',
                                style: TextStyle(color: GriColors.gray),
                              ),
                            ),
                          );
                        }
                        return GridView.count(
                          crossAxisCount: mesaCrossAxis,
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          mainAxisSpacing: 20,
                          crossAxisSpacing: 20,
                          // MesaTile minHeight 130 + padding interno.
                          childAspectRatio: 1.1,
                          children: [
                            // Mapa operacional (ADMN-04): tap → sheet con
                            // SOLO transiciones válidas + Ver QR (la
                            // edición vive en /mesas → showEdit false).
                            for (final m in mesas)
                              MesaTile(
                                mesa: m,
                                onTap: () => showMesaActionsSheet(
                                  context,
                                  ref,
                                  m,
                                  showEdit: false,
                                ),
                              ),
                          ],
                        );
                      },
                    ),
                  ],
                ),
              ),
            ],
          ), // Column (mapa de mesas)
        ); // SingleChildScrollView
      }, // builder
      ), // LayoutBuilder (child: de Material)
    ); // Material
  }
}

class _ErrorBox extends StatelessWidget {
  const _ErrorBox({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              message,
              style: const TextStyle(color: GriColors.gray, fontSize: 16),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: onRetry,
              style: ElevatedButton.styleFrom(
                backgroundColor: GriColors.primary,
                foregroundColor: Colors.white,
              ),
              child: const Text('Reintentar'),
            ),
          ],
        ),
      ),
    );
  }
}


/// Guía de arranque para el `super_admin` sin restaurante activo (11-02).
///
/// Sustituye a las 4 tarjetas de estadísticas en cero, que no comunicaban
/// nada: distingue los DOS motivos por los que no hay restaurante activo y
/// dice el siguiente paso concreto de cada uno.
///
/// Se apoya en [restaurantesListProvider], que el topbar del AppShell YA
/// observa para el super_admin (`app_shell.dart:324`) — no abre ninguna
/// consulta adicional. Ese provider lista solo los ACTIVOS: si la plataforma
/// tuviera restaurantes pero todos desactivados, se muestra la guía de
/// creación, y `Configuración → Restaurantes` es igualmente el lugar correcto
/// (es donde se reactivan).
///
/// Estilo: mismo patrón de estado vacío ya vigente en esta pantalla
/// ("Sin mesas configuradas") sobre la tarjeta blanca del mapa de mesas —
/// la identidad visual actual se conserva (decisión bloqueada de la fase).
class _GuiaSinRestaurante extends ConsumerWidget {
  const _GuiaSinRestaurante();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final listaAsync = ref.watch(restaurantesListProvider);

    // Mientras la lista carga no se afirma cuál de los dos casos es. Si falla,
    // se cae al mensaje del selector: decir "no hay restaurantes" sin haber
    // podido leerlos sería mentir al operador.
    if (listaAsync.isLoading) {
      return const SizedBox(
        height: 130,
        child: Center(child: CircularProgressIndicator()),
      );
    }

    final plataformaVacia = listaAsync.value?.isEmpty ?? false;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 40),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0D000000),
            blurRadius: 12,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            plataformaVacia ? '🏪' : '👇',
            style: const TextStyle(fontSize: 34),
          ),
          const SizedBox(height: 12),
          Text(
            plataformaVacia
                ? 'Aún no hay restaurantes en la plataforma'
                : 'Selecciona un restaurante',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: GriColors.text,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            plataformaVacia
                ? 'Ve a Configuración → Restaurantes para crear el primero.'
                : 'Usa el selector de la barra superior para elegir con qué '
                    'restaurante quieres trabajar.',
            textAlign: TextAlign.center,
            style: const TextStyle(color: GriColors.gray),
          ),
          if (plataformaVacia) ...[
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () => context.go('/configuracion'),
              style: ElevatedButton.styleFrom(
                backgroundColor: GriColors.primary,
                foregroundColor: Colors.white,
              ),
              child: const Text('Ir a Configuración'),
            ),
          ],
        ],
      ),
    );
  }
}
