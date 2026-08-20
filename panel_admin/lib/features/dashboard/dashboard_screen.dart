import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/firebase_providers.dart';
import '../../core/async_fallo.dart';
import '../../core/firebase_error_mapper.dart';
import '../../core/theme.dart';
import 'mesas_provider.dart';
import 'restaurante_provider.dart';
import 'restaurantes_list_provider.dart';
import 'stats_provider.dart';
import 'widgets/mapa_de_mesas.dart';
import 'widgets/mesa_legend.dart';
import 'widgets/stat_card.dart';
import '../../core/design_tokens.dart';
import '../shared/error_box.dart';
import '../shared/responsive_page.dart';
import '../../core/gri_icons.dart';

/// Dashboard (ADMN-01 + ADMN-02) — 4 stat cards + mapa de mesas coloreado.
///
/// Consume [statsProvider] y [mesasProvider] (ambos Stream con polling 10s).
/// Renderiza estados AsyncLoading / AsyncError / AsyncData idiomáticamente.
///
/// Phase 7 (WS) retira el Timer: el contrato de INPUT cambia (Stream de mesas
/// alimentado por WS en vez de polling), pero el body del screen (este
/// archivo) no se toca — solo los providers.
/// Alto fijo de cada [StatCard] en el grid de estadísticas.
///
/// Público a propósito: `test/shared/responsive_test.dart` mide el alto
/// NATURAL de una [StatCard] y comprueba que este número sigue siendo
/// suficiente. Si alguien cambia la tipografía de la card y deja de caber, el
/// test se pone rojo en vez de recortarse en silencio.
const double alturaStatCard = 130;

/// Delegate del grid de mesas, compartido por el mapa del dashboard y
/// `/mesas` para que los dos no puedan divergir.
///
/// `maxCrossAxisExtent` en vez de `crossAxisCount`: el grid deja de tener un
/// tope de 4 escrito a mano y el tile deja de poder crecer sin límite.
///
/// 325 NO es un número redondo: es el que hace que los saltos de columna caigan
/// donde ya caían con la regla anterior (`ancho >= 1100 ? 4 : ancho >= 750 ? 3
/// : 2`), teniendo en cuenta el padding de 30 de la pantalla y el
/// `crossAxisSpacing` de 20 — 2·(325+20) = 690 = 750−60 y 3·(325+20) = 1035 ≈
/// 1100−60. `responsive_test.dart` compara columna a columna contra la regla
/// histórica a 700, 800, 1030 (ventana 1280), 1190 (ventana 1440) y 1200.
///
/// LÍMITE CONOCIDO: por debajo de ~500px de contenido la regla nueva da 1
/// columna donde la vieja daba 2. Es un ancho al que un panel de escritorio no
/// se usa, y una ficha de mesa de 170px no era legible de todas formas.
const SliverGridDelegateWithMaxCrossAxisExtent mesaGridDelegate =
    SliverGridDelegateWithMaxCrossAxisExtent(
  maxCrossAxisExtent: 325,
  mainAxisSpacing: 20,
  crossAxisSpacing: 20,
  // MesaTile minHeight 130 + padding interno.
  childAspectRatio: 1.1,
);

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
      child: ResponsivePage(
        builder: (context, ancho) {
        // Responsive crossAxisCount del grid de stat cards (4/2/1).
        // Los umbrales son los MISMOS de siempre (GriBreakpoints 750/1100):
        // moverlos sería un cambio visual prohibido por la fase.
        final statCrossAxis = ancho >= GriBreakpoints.expanded
            ? 4
            : (ancho >= GriBreakpoints.compact ? 2 : 1);

        return SingleChildScrollView(
          padding: const EdgeInsets.all(30),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Stat cards (o guía de arranque) ──────────────────────────
              if (sinRestauranteActivo)
                const _GuiaSinRestaurante()
              else
                statsAsync.cuandoConFallo(
                cargando: () => const SizedBox(
                  height: 130,
                  child: Center(child: CircularProgressIndicator()),
                ),
                fallo: (e) => ErrorBox(
                  message: mensajeDeFallo(e, contexto: Contexto.estadisticas),
                  onRetry: () => ref.invalidate(statsProvider),
                ),
                datos: (s) => GridView(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  // ALTO FIJO, no childAspectRatio (11-21).
                  //
                  // Con `childAspectRatio: 2.6` el alto de la card salía del
                  // ANCHO, y el ancho depende del viewport: a 1280px de
                  // ventana la card quedaba de 87px de alto para un contenido
                  // que pide 115 → los 31px de desborde que 11-02 anotó. El
                  // mismo ratio daba 188px de alto a 1 columna y 149 a 1920:
                  // el alto nunca fue una decisión de diseño, era un efecto
                  // colateral del ancho.
                  //
                  // 130 = por encima del alto natural medido de [StatCard]
                  // (115px con una etiqueta de una línea) con margen para
                  // métricas de fuente distintas, y es además el alto que la
                  // card ya tenía en el tramo de 2 columnas (129px), que es
                  // el más parecido al mockup. `responsive_test.dart` afirma
                  // que este número sigue siendo >= el alto natural medido.
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: statCrossAxis,
                    mainAxisSpacing: 20,
                    crossAxisSpacing: 20,
                    mainAxisExtent: alturaStatCard,
                  ),
                  children: [
                    StatCard(
                      label: 'Mesas disponibles',
                      value: s.mesasDisponibles,
                      iconBg: GriColors.statIconDisponibleBg,
                      iconFg: GriColors.mesaDisponibleDot,
                      icono: GriIcons.mesas,
                    ),
                    StatCard(
                      label: 'Mesas ocupadas',
                      value: s.mesasOcupadas,
                      iconBg: GriColors.statIconOcupadaBg,
                      iconFg: GriColors.primary,
                      icono: GriIcons.clientes,
                    ),
                    StatCard(
                      label: 'Reservas hoy',
                      value: s.reservasHoy,
                      iconBg: GriColors.statIconReservasBg,
                      iconFg: GriColors.mesaReservadaDot,
                      icono: GriIcons.reservas,
                    ),
                    StatCard(
                      label: 'Pedidos activos',
                      value: s.pedidosActivos,
                      iconBg: GriColors.statIconPedidosBg,
                      iconFg: GriColors.mesaLimpiezaDot,
                      icono: GriIcons.pedidos,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 30),

              // ── Mapa de mesas ─────────────────────────────────────────────
              Container(
                padding: const EdgeInsets.all(25),
                decoration: griCardDecoration,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Expanded + ellipsis: el título a 20 bold y el botón
                        // compartían un Row sin acotar → 148px de desborde a
                        // 800px de ventana. Con Expanded el reparto es el
                        // mismo cuando hay sitio (título a la izquierda,
                        // botón a la derecha) y deja de romperse cuando no.
                        const Expanded(
                          child: Text(
                            'Estado de las mesas',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: GriColors.text,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        // El alta vive en la pantalla de gestión (08-03):
                        // desde el mapa solo se navega a /mesas.
                        ElevatedButton.icon(
                          onPressed: () => context.go('/mesas'),
                          icon: const Text('+'),
                          label: const Text('Nueva mesa'),
                          style: griBotonPrimario,
                        ),
                      ],
                    ),
                    const SizedBox(height: 25),
                    const MesaLegend(),
                    const SizedBox(height: 25),
                    mesasAsync.cuandoConFallo(
                      cargando: () => const SizedBox(
                        height: 200,
                        child:
                            Center(child: CircularProgressIndicator()),
                      ),
                      fallo: (e) => ErrorBox(
                        message: mensajeDeFallo(e, contexto: Contexto.mesas),
                        onRetry: () => ref.invalidate(mesasProvider),
                      ),
                      datos: (mesas) {
                        if (mesas.isEmpty) {
                          return const Padding(
                            padding: EdgeInsets.symmetric(vertical: 40),
                            child: Center(
                              child: Text(
                                'Sin mesas configuradas',
                                style: TextStyle(color: GriColors.textoSecundarioAccesible),
                              ),
                            ),
                          );
                        }
                        // Mapa operacional (ADMN-04): tap → sheet con SOLO
                        // transiciones válidas + Ver QR (la edición vive en
                        // /mesas → showEdit false).
                        //
                        // 11-34: la rejilla y su color viven en
                        // [MapaDeMesas], compartido con /mesas — el color ya
                        // no sale del campo `estado` sino de la ventana de
                        // reserva, y las dos pantallas no pueden divergir.
                        return MapaDeMesas(mesas: mesas, showEdit: false);
                      },
                    ),
                  ],
                ),
              ),
            ],
          ), // Column (mapa de mesas)
        ); // SingleChildScrollView
      }, // builder
      ), // ResponsivePage (child: de Material)
    ); // Material
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
      decoration: griCardDecoration,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // size 34 = el fontSize del emoji que sustituye.
          //
          // El '👇' apuntaba HACIA ABAJO a un control que está ARRIBA (el
          // selector vive en el topbar): la sustitución corrige además el
          // significado, no solo la fuente.
          Icon(
            plataformaVacia ? GriIcons.restaurante : GriIcons.selectorArriba,
            size: 34,
            color: GriColors.gray,
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
            style: const TextStyle(color: GriColors.textoSecundarioAccesible),
          ),
          if (plataformaVacia) ...[
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () => context.go('/configuracion'),
              child: const Text('Ir a Configuración'),
            ),
          ],
        ],
      ),
    );
  }
}
