import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/async_fallo.dart';
import '../../core/firebase_error_mapper.dart';
import '../../core/firebase_providers.dart';
import '../../core/format.dart';
import '../../core/state_machines.dart';
import '../../core/theme.dart';
import '../../models/pedido_staff.dart';
import 'cuenta_mesa.dart';
import 'pedidos_staff_provider.dart';
import 'widgets/pedido_card.dart';
import '../shared/error_box.dart';
import '../shared/responsive_page.dart';
import '../../core/gri_icons.dart';

/// Vista cocina (ADMN-05) — cola de pedidos activos EN VIVO (Phase 10:
/// onSnapshot nativo — WS y polling retirados de esta vista, MIGRA-05).
///
/// Vive DENTRO del ShellRoute del panel (sin Scaffold propio de AppShell):
/// el body es un header + [ListView] de [PedidoCard]. `onAvanzar` escribe
/// el nuevo estado a Firestore vía [avanzarPedidoStaff] (transición +
/// matriz rol validadas ANTES del update; las rules re-fuerzan) y la cola
/// se refresca sola por el snapshot — sin invalidate manual.
class CocinaScreen extends ConsumerWidget {
  const CocinaScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pedidosAsync = ref.watch(pedidosStaffProvider);
    // Rol de claims (gating de UI; la matriz la re-valida avanzarPedidoStaff
    // y las rules son la autoridad final).
    final rol = ref.watch(claimsProvider).value?.role ?? '';
    // 11-33: era `.value ?? const []`. Un listener denegado daba lista vacía
    // y el badge decía «ninguna mesa pidió la cuenta»: una mesa esperando
    // para pagar quedaba INVISIBLE, sin que nada indicara que el dato no se
    // había podido leer. Ahora el fallo se conserva y se pinta.
    final avisosAsync = ref.watch(avisoCuentaProvider);
    final avisos = avisosAsync.value ?? const <AvisoCuenta>[];

    // Material ancestor: en producción lo provee el Scaffold del AppShell,
    // pero la pantalla debe ser fiel también standalone (tests/usuarios que
    // la bombean directa) — sin esto Flutter inyecta el fallback style
    // (48px) a los Text sin fontSize explícito.
    return Material(
      color: GriColors.background,
      child: ResponsivePage(
        padding: const EdgeInsets.all(30),
        builder: (context, ancho) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Expanded + ellipsis: el subtítulo pedía su ancho intrínseco
                // dentro de un Row sin acotar. Medido en 11-21 con el shell
                // real: 150px de desborde a 450 de ventana, 100 a 500, 50 a
                // 550 y 0.25 a 600 — una recta, no un caso raro.
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Pedidos · Cocina',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: GriColors.text,
                        ),
                      ),
                      SizedBox(height: 5),
                      Text(
                        'Cola de pedidos activos (en vivo)',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: GriColors.textoSecundarioAccesible),
                      ),
                    ],
                  ),
                ),
                // Aviso de cuenta EN VIVO (PAGO-01): sesiones activas con
                // cuentaSolicitada — sustituye el badge del WS. Flexible:
                // en pantallas angostas el badge se acota y su texto
                // ellipsiza (sin RenderFlex overflow). Tap → sheet de
                // entrega (cierra sesión + mesa a limpieza, PAGO-04).
                // 11-33: si el listener de avisos FALLA, aquí no puede no
                // haber nada. «Sin badge» significa «ninguna mesa pidió la
                // cuenta», y eso es una afirmación sobre los datos que no
                // podemos hacer cuando justamente no hemos podido leerlos.
                // El aviso ocupa el sitio del badge, que es donde mira.
                if (avisosAsync.hasError)
                  Flexible(
                    child: Text(
                      mensajeDeFallo(avisosAsync.error!,
                          contexto: Contexto.avisosCuenta),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: GriColors.mesaReservadaFg,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  )
                else if (avisos.isNotEmpty)
                  Flexible(
                    child: _CuentaAvisosBadge(
                      cantidad: avisos.length,
                      onTap: () => _abrirAvisosCuenta(context, ref, avisos),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 20),
            Expanded(
              child: pedidosAsync.cuandoConFallo(
                cargando: () =>
                    const Center(child: CircularProgressIndicator()),
                fallo: (e) => ErrorBox(
                  padding: EdgeInsets.zero,
                  // Antes: 'Error cargando pedidos' — el mismo texto para un
                  // permiso denegado que para una caída de red (11-33).
                  message:
                      mensajeDeFallo(e, contexto: Contexto.pedidosCocina),
                  onRetry: () => ref.invalidate(pedidosStaffProvider),
                ),
                datos: (pedidos) {
                  if (pedidos.isEmpty) {
                    return const Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // El emoji de fiesta iba dentro de la frase. Pasa a
                          // icono encima, del mismo tamano que el texto que
                          // acompanaba (18), en el mismo gris.
                          Icon(
                            GriIcons.todoAlDia,
                            size: 18,
                            color: GriColors.gray,
                          ),
                          SizedBox(height: 6),
                          Text(
                            'No hay pedidos activos',
                            style: TextStyle(
                              fontSize: 18,
                              color: GriColors.textoSecundarioAccesible,
                            ),
                          ),
                          SizedBox(height: 6),
                          Text(
                            'Los pedidos enviados desde la app aparecerán aquí',
                            style: TextStyle(
                              color: GriColors.textoSecundarioAccesible,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    );
                  }
                  return ListView.separated(
                    itemCount: pedidos.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 16),
                    itemBuilder: (_, i) => PedidoCard(
                      pedido: pedidos[i],
                      rol: rol,
                      onAvanzar: (pedido, destino) =>
                          _avanzar(context, ref, pedido, destino),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Sheet de avisos de cuenta: una fila por mesa que pidió la cuenta con
  /// la acción "Entregar cuenta" ([entregarCuenta] — cierra la sesión y
  /// pasa la mesa a limpieza). El badge del header desaparece SOLO al
  /// commitear la tx (el stream `avisoCuenta` re-emite — sin invalidate).
  Future<void> _abrirAvisosCuenta(
    BuildContext context,
    WidgetRef ref,
    List<AvisoCuenta> avisos,
  ) {
    return showModalBottomSheet<void>(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 18, 20, 6),
              child: Row(
                children: [
                  Text(
                    'Mesas que pidieron la cuenta',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            for (final a in avisos)
              _FilaAvisoCuenta(
                aviso: a,
                onEntregar: () => _entregar(context, ref, a),
              ),
          ],
        ),
      ),
    );
  }

  /// Entrega + feedback. Capturas síncronas ANTES del await (patrón
  /// _avanzar). El sheet se cierra primero; el aviso desaparece del header
  /// por el onSnapshot (JAMÁS se muta estado local).
  Future<void> _entregar(
    BuildContext context,
    WidgetRef ref,
    AvisoCuenta aviso,
  ) async {
    final messenger = ScaffoldMessenger.maybeOf(context);
    final db = ref.read(firestoreProvider);

    // El importe se lee ANTES de la tx: al cerrar la sesión el aviso
    // desaparece y con él la fila que lo mostraba. Si se leyera después, la
    // confirmación saldría en blanco justo cuando más se necesita.
    final cobrado = _importeMesa(ref, aviso.mesaId);

    Navigator.of(context).pop();

    try {
      await entregarCuenta(db, mesaId: aviso.mesaId);
      messenger?.showSnackBar(
        SnackBar(
          content: Text('Mesa ${aviso.mesaNumero} — cuenta entregada por '
              '${formatCOP(cobrado)} (sesión cerrada)'),
          duration: const Duration(seconds: 3),
        ),
      );
    } on StateError catch (e) {
      messenger?.showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    } catch (_) {
      messenger?.showSnackBar(
        const SnackBar(
          content: Text('No se pudo entregar la cuenta'),
          duration: Duration(seconds: 3),
        ),
      );
    }
  }

  /// Avance + feedback accionable. El [ScaffoldMessenger] se captura ANTES
  /// del await (sin context a través del gap async).
  ///
  /// SIN invalidate post-escritura: el onSnapshot de la cola emite el doc
  /// actualizado por sí solo (server es la fuente de verdad).
  Future<void> _avanzar(
    BuildContext context,
    WidgetRef ref,
    PedidoStaff pedido,
    EstadoPedido destino,
  ) async {
    final messenger = ScaffoldMessenger.maybeOf(context);
    final db = ref.read(firestoreProvider);
    final rol = ref.read(claimsProvider).value?.role ?? '';

    try {
      await avanzarPedidoStaff(db, rol: rol, pedido: pedido, destino: destino);
    } on TransicionInvalidaException {
      // La carrera la ganó otro staff: la cola ya se refrescó sola.
      messenger?.showSnackBar(
        const SnackBar(
          content: Text('Alguien ya movió este pedido — refrescando'),
          duration: Duration(seconds: 3),
        ),
      );
    } on StateError catch (e) {
      messenger?.showSnackBar(
        SnackBar(
          content: Text(e.message),
          duration: const Duration(seconds: 3),
        ),
      );
    } catch (_) {
      messenger?.showSnackBar(
        const SnackBar(
          content: Text('No se pudo actualizar el pedido'),
          duration: Duration(seconds: 3),
        ),
      );
    }
  }
}

/// El importe ya servido de [mesaId], leído SIN suscribirse (`read`): se usa
/// en el instante del cobro, no en un `build`.
int _importeMesa(WidgetRef ref, String mesaId) {
  final servidos =
      ref.read(pedidosServidosMesaProvider(mesaId)).value ?? const [];
  final enCurso = ref.read(pedidosStaffProvider).value ?? const [];
  return cuentaDeMesa(mesaId: mesaId, servidos: servidos, enCurso: enCurso)
      .total;
}

/// Una mesa que pidió la cuenta, CON SU IMPORTE (plan 11-32).
///
/// ── LO QUE ESTA FILA ARREGLA ──────────────────────────────────────────────
/// Antes decía solo «Mesa 3» y, al tocarla, cerraba la sesión. El mesero
/// cobraba a ojo. Ahora la cifra está a la vista ANTES del toque, que es el
/// único momento en que sirve.
///
/// Y avisa de lo que se queda fuera: si la mesa tiene platos en curso,
/// entregar la cuenta cierra la sesión y esos platos NO se cobran nunca
/// (solo se cobra lo servido — decisión del usuario). Es información que el
/// mesero necesita para decidir si cobra ya o espera a que salga la cocina.
///
/// El flujo NO cambia: un toque sigue siendo entregar la cuenta.
class _FilaAvisoCuenta extends ConsumerWidget {
  const _FilaAvisoCuenta({required this.aviso, required this.onEntregar});

  final AvisoCuenta aviso;
  final VoidCallback onEntregar;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final servidosAsync = ref.watch(pedidosServidosMesaProvider(aviso.mesaId));
    final enCurso = ref.watch(pedidosStaffProvider).value ?? const [];
    final cuenta = cuentaDeMesa(
      mesaId: aviso.mesaId,
      servidos: servidosAsync.value ?? const [],
      enCurso: enCurso,
    );
    final n = cuenta.pendientes.length;
    // Si la consulta del importe falló, el guion del `trailing` solo dice que
    // no hay cifra; hace falta decir POR QUÉ y qué hacer. Sin esto el mesero
    // ve un guion permanente sin saber si es que carga o que no puede leerlo.
    final falloImporte = servidosAsync.error;

    return ListTile(
      leading: const Icon(GriIcons.marca, size: 20),
      title: Text('Mesa ${aviso.mesaNumero}'),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (falloImporte != null)
            Text(
              mensajeDeFallo(falloImporte, contexto: Contexto.cuentaMesa),
              style: const TextStyle(
                color: GriColors.mesaReservadaFg,
                fontWeight: FontWeight.bold,
              ),
            ),
          if (cuenta.hayPendientes)
            Text(
              '$n ${n == 1 ? 'pedido' : 'pedidos'} sin servir por '
              '${formatCOP(cuenta.totalPendiente)}: al cerrar la sesión no se '
              '${n == 1 ? 'cobra' : 'cobran'}.',
              style: const TextStyle(
                color: GriColors.mesaReservadaFg,
                fontWeight: FontWeight.bold,
              ),
            ),
          const Text(
            'Entregar cuenta cierra la sesión y pasa la mesa a limpieza',
          ),
        ],
      ),
      // El importe es lo primero que el ojo busca: va grande y a la derecha.
      // Mientras la consulta carga se muestra un guion, NUNCA un cero: un
      // cero es una cifra y se leería como "esta mesa no debe nada".
      // Ni cargando ni fallando se enseña una cifra (11-33). 11-32 ya evitaba
      // el CERO durante la carga —un cero es una cifra y se lee como «esta
      // mesa no debe nada»—, pero la rama de ERROR caía en
      // `.value ?? const []` y enseñaba ese mismo cero como si fuera el
      // importe real. Un mesero que lo creyera cerraría la sesión sin cobrar.
      trailing: servidosAsync.hasError || servidosAsync.isLoading
          ? const Text('—', style: TextStyle(fontSize: 18))
          : Text(
              formatCOP(cuenta.total),
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: GriColors.text,
              ),
            ),
      isThreeLine: cuenta.hayPendientes || falloImporte != null,
      onTap: onEntregar,
    );
  }
}

/// Badge "pidieron la cuenta" para el header de cocina (amarillo del
/// mockup, visible a distancia). Tap → sheet de entrega de cuentas.
class _CuentaAvisosBadge extends StatelessWidget {
  const _CuentaAvisosBadge({required this.cantidad, this.onTap});

  final int cantidad;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: GriColors.mesaReservadaBg,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              GriIcons.marca,
              size: 14,
              color: GriColors.mesaReservadaFg,
            ),
            const SizedBox(width: 6),
            // Flexible: el texto se acota al ancho que el header le deje
            // (pantallas angostas) en vez de desbordar el Row del badge.
            Flexible(
              child: Text(
                cantidad == 1
                    ? '1 mesa pidió la cuenta'
                    : '$cantidad mesas pidieron la cuenta',
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: GriColors.mesaReservadaFg,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

