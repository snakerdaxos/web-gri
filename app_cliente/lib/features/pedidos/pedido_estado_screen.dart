import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/firebase_providers.dart';
import '../../core/format.dart';
import '../../core/gri_icons.dart';
import '../../core/firebase_error_mapper.dart';
import '../../core/theme.dart';
import '../../models/pedido.dart';
import '../../models/sesion_mesa.dart';
import '../pagos/calificacion_sheet.dart';
import '../sesion_qr/sesion_provider.dart';
import '../../core/design_tokens.dart';
import 'cuenta.dart';
import 'pedidos_provider.dart';

/// Estado de los pedidos de la sesión (PEDI-04 UI) — cards con chips de
/// estado coloreados que se actualizan SOLOS (stream snapshots, MIGRA-05)
/// + botón "Pedir la cuenta" (PAGO-01; el checkout en línea quedó
/// DIFERIDO en Phase 10) + calificación de pedidos servidos tras el
/// cierre de la sesión.
class PedidoEstadoScreen extends ConsumerStatefulWidget {
  const PedidoEstadoScreen({super.key});

  @override
  ConsumerState<PedidoEstadoScreen> createState() =>
      _PedidoEstadoScreenState();
}

class _PedidoEstadoScreenState extends ConsumerState<PedidoEstadoScreen> {
  bool _pidiendoCuenta = false;

  /// Mirror local tras pedir la cuenta exitosamente — la visibilidad no
  /// depende solo del stream (robusto en cualquier flujo).
  bool _cuentaYaPedida = false;

  Future<void> _pedirCuenta() async {
    if (_pidiendoCuenta) return;
    final sesion = ref.read(sesionActualProvider).value;
    final uid = ref.read(firebaseAuthProvider).currentUser?.uid;
    if (sesion == null || uid == null) return;
    setState(() => _pidiendoCuenta = true);
    try {
      await solicitarCuenta(
        ref.read(firestoreProvider),
        uid: uid,
        mesaId: sesion.mesaId,
      );
      if (!mounted) return;
      setState(() => _cuentaYaPedida = true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cuenta solicitada — el mesero viene en camino'),
          backgroundColor: GriColors.green,
        ),
      );
    } on PedidoException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.message),
          backgroundColor: GriColors.chipCanceladaFg,
        ),
      );
    } catch (e) {
      // 11-23: mismo caso que el envío del pedido — el texto afirmaba la red
      // como causa sin saber nada. La traza se conserva (T-11-23-04).
      debugPrint('pedir cuenta falló [${clasificarFallo(e)}]: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(mensajeDeFallo(e, contexto: Contexto.solicitarCuenta)),
          backgroundColor: GriColors.chipCanceladaFg,
        ),
      );
    } finally {
      if (mounted) setState(() => _pidiendoCuenta = false);
    }
  }

  void _abrirCalificacion(String pedidoId) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => CalificacionSheet(pedidoId: pedidoId),
    );
  }

  @override
  Widget build(BuildContext context) {
    final sesion = ref.watch(sesionActualProvider).value;
    final pedidosAsync = ref.watch(pedidosSessionProvider);

    final sesionCerrada = sesion != null && sesion.estado != 'activa';

    // La cuenta se calcula UNA vez y la usan las dos zonas: la lista (para
    // saber que se cobra en cada tarjeta) y la barra inferior (el importe).
    // `desde` es el inicioAt de la sesion: sin el, los pedidos de una visita
    // anterior a la MISMA mesa se colarian en la cuenta (ver cuenta.dart).
    final cuenta = calcularCuenta(
      pedidosAsync.value ?? const [],
      desde: sesion?.inicioAt,
    );

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: GriColors.text,
        elevation: 0,
        title: Text(
          sesion == null
              ? 'Mis pedidos'
              : 'Mis pedidos · Mesa ${sesion.mesaNumero}',
        ),
      ),
      body: pedidosAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(GriIcons.enVivo, size: 40, color: GriColors.gray),
              const SizedBox(height: GriSpacing.sm),
              const Text('Error al cargar tus pedidos'),
              const SizedBox(height: GriSpacing.md),
              ElevatedButton.icon(
                onPressed: () => ref.invalidate(pedidosSessionProvider),
                icon: const Icon(Icons.refresh),
                label: const Text('Reintentar'),
              ),
            ],
          ),
        ),
        data: (_) {
          // NO se pinta la lista cruda del stream: se pinta la de la SESION
          // ACTUAL (cuenta.enLaSesion). Si se listaran los pedidos de una
          // visita anterior, el comensal veria platos que no estan en su
          // total y la cuenta parecería mal sumada.
          final pedidos = cuenta.enLaSesion;
          if (pedidos.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(GriIcons.cocinando,
                      size: 40, color: GriColors.gray),
                  const SizedBox(height: GriSpacing.sm),
                  const Text('Aún no hay pedidos en esta sesión'),
                  const SizedBox(height: GriSpacing.md),
                  ElevatedButton(
                    onPressed: () => context.push('/mesa'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: GriColors.primary,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Ver el menú'),
                  ),
                ],
              ),
            );
          }
          return ListView(
            padding: const EdgeInsets.all(GriSpacing.md),
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Center(
                  child: Text(
                    'Se actualiza automáticamente',
                    style: GriText.auxiliar.copyWith(color: GriColors.textoSecundarioAccesible),
                  ),
                ),
              ),
              for (final pedido in pedidos)
                _PedidoCard(
                  pedido: pedido,
                  etiquetaCobro: etiquetaCobro(pedido.estado),
                  // Calificación: pedido servido + sesión cerrada (locked).
                  onCalificar: sesionCerrada && pedido.estado == 'servido'
                      ? () => _abrirCalificacion(pedido.id)
                      : null,
                ),
            ],
          );
        },
      ),
      bottomNavigationBar: sesion == null
          ? null
          : _cuentaSection(sesion, sesionCerrada, cuenta),
    );
  }

  /// Barra inferior: EL IMPORTE primero, la accion despues.
  ///
  /// Hasta 11-32 aqui solo vivia el boton "Pedir la cuenta": el comensal
  /// pedia la cuenta y no veia jamas una cifra. Ahora el resumen va SIEMPRE
  /// que haya algo en la sesion -- antes de pedir, despues de pedir y tras el
  /// cierre --, porque saber cuanto se debe no puede depender de haber
  /// pulsado un boton.
  Widget _cuentaSection(
    SesionMesa sesion,
    bool sesionCerrada,
    CuentaSesion cuenta,
  ) {
    final yaPedida =
        !sesionCerrada && (sesion.cuentaSolicitada || _cuentaYaPedida);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
            GriSpacing.md, GriSpacing.sm, GriSpacing.md, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!cuenta.vacia) ...[
              _ResumenCuenta(cuenta: cuenta, sesionCerrada: sesionCerrada),
              const SizedBox(height: GriSpacing.sm),
            ],
            if (sesionCerrada)
              const Center(
                child: Text(
                  // ignore: lines_longer_than_80_chars
                  'Sesión cerrada — ¡gracias por tu visita! 🙌', // EMOJI-OK: despedida
                  style: TextStyle(color: GriColors.textoSecundarioAccesible),
                ),
              )
            else if (yaPedida)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: GriColors.chipConfirmadaBg,
                  borderRadius: BorderRadius.circular(12),
                ),
                // El check era un glifo dentro del texto: pasa a Icon en un
                // Row con el MISMO tamano (15 = el fontSize del Text) y el
                // mismo color, para que el lector de pantalla no lea "marca
                // de verificacion" detras de la frase.
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Cuenta solicitada',
                      style: GriText.boton
                          .copyWith(color: GriColors.chipConfirmadaFg),
                    ),
                    const SizedBox(width: GriSpacing.xs),
                    const Icon(GriIcons.confirmado,
                        size: 15, color: GriColors.chipConfirmadaFg),
                  ],
                ),
              )
            else
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _pidiendoCuenta ? null : _pedirCuenta,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: GriColors.primary,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: GriColors.primaryTint,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  icon: _pidiendoCuenta
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(GriIcons.resumenPedido),
                  label: const Text(
                    'Pedir la cuenta',
                    style: GriText.botonGrande,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// El resumen de la cuenta: la cifra que se cobra AHORA y, si falta algo por
/// servir, cuanto es y cuando entrara.
///
/// -- POR QUE NO ES UN TOTAL A SECAS ----------------------------------------
/// La regla del usuario es "solo se cobra lo servido", y eso hace que el
/// importe SUBA solo mientras la cocina trabaje. Si aqui hubiera unicamente
/// un numero, el comensal leeria 50.000, llegaria su ultimo plato y de
/// pronto veria 75.000 sin explicacion -- y con razon pensaria que le estan
/// cobrando de mas. Por eso el bloque pendiente es OBLIGATORIO cuando hay
/// pedidos en curso: dice el importe que falta, cuantos pedidos son, y que
/// entraran cuando lleguen a la mesa.
class _ResumenCuenta extends StatelessWidget {
  const _ResumenCuenta({required this.cuenta, required this.sesionCerrada});

  final CuentaSesion cuenta;
  final bool sesionCerrada;

  @override
  Widget build(BuildContext context) {
    final n = cuenta.pendientes.length;
    final plural = n != 1;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(GriSpacing.sm + GriSpacing.xs),
      decoration: BoxDecoration(
        color: GriColors.primaryTint,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: GriColors.primaryTintBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                // Tras el cierre el mesero ya cobro: la etiqueta deja de ser
                // una peticion y pasa a ser el recibo.
                sesionCerrada ? 'Total pagado' : 'Total a pagar',
                style: GriText.boton.copyWith(color: GriColors.text),
              ),
              const Spacer(),
              Text(
                formatCOP(cuenta.total),
                style:
                    GriText.tituloSeccion.copyWith(color: GriColors.primary),
              ),
            ],
          ),
          if (cuenta.cobrados.isEmpty) ...[
            const SizedBox(height: GriSpacing.xs),
            Text(
              'Todavía no te han servido nada, por eso el total va en cero.',
              style: GriText.auxiliar
                  .copyWith(color: GriColors.textoSecundarioAccesible),
            ),
          ],
          if (cuenta.hayPendientes) ...[
            const SizedBox(height: GriSpacing.sm),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(GriIcons.cocinando,
                    size: 14, color: GriColors.textoSecundarioAccesible),
                const SizedBox(width: GriSpacing.xs),
                Expanded(
                  child: Text(
                    'Aún en cocina: $n ${plural ? 'pedidos' : 'pedido'} por '
                    '${formatCOP(cuenta.totalPendiente)}, se '
                    '${plural ? 'sumarán' : 'sumará'} a tu cuenta cuando te '
                    '${plural ? 'los' : 'lo'} sirvan.',
                    style: GriText.auxiliar
                        .copyWith(color: GriColors.textoSecundarioAccesible),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// Lo que se le dice al comensal sobre SU pedido concreto: la etiqueta que
/// aparece junto al importe de cada tarjeta.
///
/// Sin esto, tres tarjetas con tres importes y un total que no es su suma
/// parecen un error de calculo. Con esto, cada linea explica por que entra o
/// no entra en la cuenta.
String etiquetaCobro(String estado) {
  if (estado == estadoCobrable) return 'Se cobra';
  if (estadosPendientes.contains(estado)) return 'Aún no se cobra';
  return 'No se cobra';
}

/// Card de un pedido: chip de estado coloreado + items + total (+ CTA
/// calificar cuando la sesión cerró y el pedido está servido).
class _PedidoCard extends StatelessWidget {
  const _PedidoCard({
    required this.pedido,
    required this.etiquetaCobro,
    this.onCalificar,
  });

  final Pedido pedido;

  /// 'Se cobra' | 'Aun no se cobra' | 'No se cobra' -- 11-32. Va PEGADA al
  /// importe de la tarjeta porque es ahi donde el comensal compara: sin ella,
  /// un total que no es la suma de las tarjetas parece un error.
  final String etiquetaCobro;

  final VoidCallback? onCalificar;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(GriSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Pedido #${pedido.codigoCorto}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: GriColors.text,
                    ),
                  ),
                ),
                _EstadoChip(pedido: pedido),
              ],
            ),
            const SizedBox(height: 10),
            for (final item in pedido.items)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Text('${item.nombre} ×${item.cantidad}'),
              ),
            const SizedBox(height: 10),
            Row(
              children: [
                Text(
                  etiquetaCobro,
                  style: GriText.auxiliar
                      .copyWith(color: GriColors.textoSecundarioAccesible),
                ),
                const Spacer(),
                Text(
                  formatCOP(pedido.total),
                  style: GriText.botonGrande.copyWith(color: GriColors.primary),
                ),
              ],
            ),
            if (onCalificar != null) ...[
              const SizedBox(height: GriSpacing.sm),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: onCalificar,
                  icon: const Icon(Icons.star_border, color: GriColors.calificacionEstrella),
                  label: const Text(
                    'Calificar',
                    style: TextStyle(
                        color: GriColors.calificacionEstrella,
                        fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Chip coloreado según el estado (5 estados, paleta PedidoEstadoX).
class _EstadoChip extends StatelessWidget {
  const _EstadoChip({required this.pedido});

  final Pedido pedido;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: GriSpacing.xs),
      decoration: BoxDecoration(
        color: pedido.estadoBg(context),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        pedido.estadoLabel,
        style: GriText.chip.copyWith(color: pedido.estadoColor(context)),
      ),
    );
  }
}
