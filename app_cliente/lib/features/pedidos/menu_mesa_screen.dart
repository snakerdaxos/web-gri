import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/format.dart';
import '../../core/async_fallo.dart';
import '../shared/fallo_de_stream.dart';
import '../../core/gri_icons.dart';
import '../../core/firebase_error_mapper.dart';
import '../../core/theme.dart';
import '../../models/producto.dart';
import '../restaurantes/restaurantes_provider.dart';
import '../sesion_qr/sesion_provider.dart';
import '../shared/empty_state.dart';
import '../shared/producto_card.dart';
import '../../core/design_tokens.dart';
import 'carrito_controller.dart';
import 'pedidos_provider.dart';

/// Menú de la mesa con carrito (PEDI-01/02 UI).
///
/// * La sesión viene de [sesionActualProvider] (stream Firestore); el menú
///   se REUSA de `restauranteDetalleProvider` (Firestore — el menú NO se
///   re-implementa).
/// * Productos agotados deshabilitados desde el render inicial (Pitfall 7:
///   el rechazo de cocina es red de seguridad, no UX).
/// * El bottom bar abre el carrito (total informativo + envío por tx).
class MenuMesaScreen extends ConsumerWidget {
  const MenuMesaScreen({super.key});

  void _abrirCarrito(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => _CarritoSheet(
        onEnviado: () {
          Navigator.of(context).pop(); // cierra el sheet (ruta tope)
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('¡Pedido enviado!'),
              backgroundColor: GriColors.green,
            ),
          );
          context.pushReplacement('/mesa/pedidos');
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sesionAsync = ref.watch(sesionActualProvider);
    final sesion = sesionAsync.value;

    if (sesionAsync.isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    // Sin sesión — o sesión CERRADA/expirada (el stream la sigue emitiendo
    // para la calificación): el menú exige una sesión activa.
    if (sesion == null || sesion.estado != 'activa') {
      return Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.white,
          foregroundColor: GriColors.text,
          elevation: 0,
          title: const Text('Mi mesa'),
        ),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(GriIcons.menu, size: 40, color: GriColors.gray),
              const SizedBox(height: GriSpacing.sm),
              const Text('No tienes una sesión activa'),
              const SizedBox(height: GriSpacing.md),
              ElevatedButton(
                onPressed: () => context.push('/sesion/scan'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: GriColors.primary,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Escanear QR de la mesa'),
              ),
            ],
          ),
        ),
      );
    }

    final detalleAsync =
        ref.watch(restauranteDetalleProvider(sesion.restauranteId));
    final cart = ref.watch(carritoProvider);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: GriColors.text,
        elevation: 0,
        title: Text('Mesa ${sesion.mesaNumero} · ${sesion.restauranteNombre}'),
      ),
      // `cuandoConFallo` y no `when` (11-33): durante los reintentos de
      // Riverpod el estado es AsyncLoading CON el error dentro y `when`
      // elegía la rama de carga — spinner mudo en vez de mensaje.
      body: detalleAsync.cuandoConFallo(
        cargando: () => const Center(child: CircularProgressIndicator()),
        fallo: (e) => FalloDeStream(
          icono: GriIcons.resumenPedido,
          // Antes: 'Error al cargar el menú' — el mismo texto para un permiso
          // denegado que para una caída de red.
          mensaje: mensajeDeFallo(e, contexto: Contexto.verMenu),
          onReintentar: () => ref.invalidate(
              restauranteDetalleProvider(sesion.restauranteId)),
        ),
        datos: (detalle) {
          // EL AGUJERO QUE ESTO CIERRA (11-09). Sin este guard el `children`
          // del ListView salía entero de `for (cat in detalle.categorias)`:
          // con 0 categorías el cuerpo quedaba COMPLETAMENTE EN BLANCO. Y
          // esta es la pantalla a la que se llega JUSTO DESPUÉS de escanear
          // el QR de la mesa — el peor momento posible para parecer rota.
          // Su hermana `restaurante_detalle_screen.dart` ya trataba bien el
          // mismo caso, señal de que era un olvido y no una decisión.
          //
          // Ocupa solo el `body`: el AppBar con el número de mesa y la barra
          // del carrito siguen ahí (cubierto por menu_vacio_test.dart).
          if (detalle.categorias.isEmpty) {
            return const EmptyState(
              icono: GriIcons.resumenPedido,
              titulo: 'Este restaurante aún no publicó su menú',
              guia: 'Avísale al mesero para que tome tu pedido en la mesa.',
            );
          }
          return ListView(
            padding: const EdgeInsets.all(GriSpacing.md),
            children: [
              for (final categoria in detalle.categorias)
                ExpansionTile(
                  initiallyExpanded: detalle.categorias.first == categoria,
                  title: Text(
                    categoria.nombre,
                    // 11-30: era el peso por defecto del `ListTile` (16). El
                    // nombre de la sección de una carta —"Entradas", "Platos
                    // fuertes"— manda sobre los platos que la siguen; con el
                    // mismo tamaño que el nombre de un plato, no mandaba.
                    style: GriText.tituloSeccion.copyWith(
                      color: GriColors.text,
                    ),
                  ),
                  subtitle: Text(
                    '${categoria.productos.length} ítems',
                    style:
                        GriText.auxiliar.copyWith(color: GriColors.textoSecundarioAccesible),
                  ),
                  // El aire de la carta lo reparte `ListaProductos`; el
                  // `ExpansionTile` solo separa la última tarjeta de la
                  // categoría siguiente.
                  childrenPadding:
                      const EdgeInsets.only(bottom: GriSpacing.md),
                  children: [
                    ListaProductos(
                      productos: categoria.productos,
                      tarjeta: (producto) =>
                          _ProductoDeLaMesa(producto: producto),
                    ),
                  ],
                ),
            ],
          );
        },
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(GriSpacing.md, GriSpacing.sm, GriSpacing.md, 12),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              // Carrito vacío → deshabilitado (no abre el sheet).
              onPressed:
                  cart.isEmpty ? null : () => _abrirCarrito(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: GriColors.primary,
                foregroundColor: Colors.white,
                disabledBackgroundColor: GriColors.primaryTint,
                disabledForegroundColor: GriColors.textoSecundarioAccesible,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              icon: const Icon(Icons.shopping_cart_outlined),
              label: Text(
                cart.isEmpty
                    ? 'Tu carrito está vacío'
                    // Total informativo — el real lo responde el server.
                    : 'Carrito (${cart.itemCount}) · ${formatCOP(cart.total)}',
                style: GriText.botonGrande,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Un plato de la carta de la mesa: la tarjeta compartida
/// ([ProductoCard]) + los controles del carrito (11-30).
///
/// ANTES era una `ListTile` con el precio de `trailing` — la "lista" que el
/// usuario dijo que no parecía una carta, y sin la foto que el producto ya
/// tenía guardada. Lo que NO cambia es la interacción: los mismos botones,
/// los mismos `tooltip` (que son lo que lee el lector de pantalla, 11-14) y
/// el mismo `carritoProvider`.
///
/// Agotado (`disponible == false`): la tarjeta se encarga (chip, foto en gris
/// y precio apagado) y aquí no se pasa ninguna acción.
class _ProductoDeLaMesa extends ConsumerWidget {
  const _ProductoDeLaMesa({required this.producto});

  final Producto producto;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final linea = ref.watch(carritoProvider)[producto.id];
    final carrito = ref.read(carritoProvider.notifier);

    if (!producto.disponible) {
      return ProductoCard(producto: producto);
    }

    return ProductoCard(
      producto: producto,
      // Pulsar el plato entero lo agrega — en una carta se señala el plato,
      // no un botoncito. La etiqueta es la que anuncia el lector de pantalla.
      etiquetaAccion: 'Agregar ${producto.nombre} al pedido',
      onTap: () => linea == null
          ? carrito.agregar(producto)
          : carrito.incrementar(producto.id),
      accion: linea == null
          ? IconButton(
              icon: const Icon(Icons.add_circle_outline),
              color: GriColors.primary,
              tooltip: 'Agregar ${producto.nombre}',
              onPressed: () => carrito.agregar(producto),
            )
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.remove_circle_outline),
                  // Sin tooltip el lector de pantalla anunciaba solo "botón":
                  // el icono no lleva texto al lado (11-14).
                  tooltip: 'Quitar una unidad',
                  onPressed: () => carrito.decrementar(producto.id),
                ),
                Text('${linea.cantidad}', style: GriText.boton),
                IconButton(
                  icon: const Icon(Icons.add_circle_outline),
                  color: GriColors.primary,
                  tooltip: 'Agregar una unidad',
                  onPressed: () => carrito.incrementar(producto.id),
                ),
              ],
            ),
    );
  }
}

/// Bottom sheet del carrito: líneas con snapshot, total informativo y
/// envío (Pitfall 4: botón disabled mientras vuela). Sin campo de notas —
/// el doc shape de pedidos de Phase 10 no las incluye.
class _CarritoSheet extends ConsumerStatefulWidget {
  const _CarritoSheet({required this.onEnviado});

  /// Lo cablea MenuMesaScreen: cierra el sheet, SnackBar verde y navega
  /// al estado del pedido (usa el context de la SCREEN — el del sheet
  /// muere con el pop).
  final VoidCallback onEnviado;

  @override
  ConsumerState<_CarritoSheet> createState() => _CarritoSheetState();
}

class _CarritoSheetState extends ConsumerState<_CarritoSheet> {
  bool _sending = false;

  @override
  Widget build(BuildContext context) {
    // Mantiene vivo el (autoDispose) PedidosController mientras el sheet
    // existe — sin un listener, Riverpod 3 lo dispone tras el ref.read y
    // el `state =` post-await del controller explota.
    ref.watch(pedidosControllerProvider);

    final cart = ref.watch(carritoProvider);

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Tu pedido',
                style: GriText.tituloSeccion.copyWith(color: GriColors.text),
              ),
              const SizedBox(height: 12),
              for (final l in cart.values)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: GriSpacing.xs),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text('${l.producto.nombre} ×${l.cantidad}'),
                      ),
                      Text(
                        formatCOP(l.subtotal),
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              const Divider(height: 24),
              Row(
                children: [
                  const Text('Total', style: TextStyle(color: GriColors.textoSecundarioAccesible)),
                  const Spacer(),
                  Text(
                    formatCOP(cart.total),
                    style: GriText.tituloSeccion.copyWith(color: GriColors.primary),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                // Pitfall 4: disabled mientras vuela — doble envío = 2 pedidos.
                onPressed: (_sending || cart.isEmpty) ? null : _enviar,
                style: ElevatedButton.styleFrom(
                  backgroundColor: GriColors.primary,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: GriColors.primaryTint,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: _sending
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text(
                        'Enviar pedido',
                        style: GriText.botonGrande,
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _enviar() async {
    final cart = ref.read(carritoProvider);
    if (cart.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      // La tx exige sesión activa propia; los items viajan con snapshot.
      await ref.read(pedidosControllerProvider.notifier).enviar();
      widget.onEnviado();
    } on PedidoException catch (e) {
      if (!mounted) return;
      setState(() => _sending = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.message),
          backgroundColor: GriColors.chipCanceladaFg,
        ),
      );
    } catch (e) {
      // 11-23: decía «Error de conexión» ante CUALQUIER excepción. Un
      // `permission-denied` mandaba al usuario a revisar su wifi. Ahora se
      // clasifica; la traza se conserva (T-11-23-04).
      debugPrint('enviar pedido falló [${clasificarFallo(e)}]: $e');
      if (!mounted) return;
      setState(() => _sending = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(mensajeDeFallo(e, contexto: Contexto.crearPedido)),
          backgroundColor: GriColors.chipCanceladaFg,
        ),
      );
    }
  }
}
