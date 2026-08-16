import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/format.dart';
import '../../core/theme.dart';
import '../../models/producto.dart';
import '../restaurantes/restaurantes_provider.dart';
import '../sesion_qr/sesion_provider.dart';
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
              const Text('🍽️', style: TextStyle(fontSize: 40)),
              const SizedBox(height: 8),
              const Text('No tienes una sesión activa'),
              const SizedBox(height: 16),
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
      body: detalleAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('📋', style: TextStyle(fontSize: 40)),
              const SizedBox(height: 8),
              const Text('Error al cargar el menú'),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () => ref.invalidate(
                    restauranteDetalleProvider(sesion.restauranteId)),
                icon: const Icon(Icons.refresh),
                label: const Text('Reintentar'),
              ),
            ],
          ),
        ),
        data: (detalle) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            for (final categoria in detalle.categorias)
              ExpansionTile(
                initiallyExpanded: detalle.categorias.first == categoria,
                title: Text(
                  categoria.nombre,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: GriColors.text,
                  ),
                ),
                subtitle: Text(
                  '${categoria.productos.length} ítems',
                  style:
                      const TextStyle(color: GriColors.gray, fontSize: 12),
                ),
                children: [
                  for (final producto in categoria.productos)
                    _ProductoRow(producto: producto),
                ],
              ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
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
                disabledForegroundColor: GriColors.gray,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              icon: const Icon(Icons.shopping_cart_outlined),
              label: Text(
                cart.isEmpty
                    ? 'Tu carrito está vacío'
                    // Total informativo — el real lo responde el server.
                    : 'Carrito (${cart.itemCount}) · ${formatCOP(cart.total)}',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Fila de producto del menú: precio COP + controles del carrito.
/// Agotado (`disponible=false`) → fila deshabilitada, sin botones.
class _ProductoRow extends ConsumerWidget {
  const _ProductoRow({required this.producto});

  final Producto producto;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final linea = ref.watch(carritoProvider)[producto.id];

    if (!producto.disponible) {
      return ListTile(
        enabled: false,
        title: Text(
          producto.nombre,
          style: const TextStyle(color: GriColors.gray),
        ),
        subtitle: const Text(
          'Agotado',
          style: TextStyle(
            color: GriColors.gray,
            fontWeight: FontWeight.bold,
          ),
        ),
        trailing: Text(
          formatCOP(producto.precio),
          style: const TextStyle(color: GriColors.gray),
        ),
      );
    }

    return ListTile(
      title: Text(producto.nombre),
      subtitle: producto.descripcion != null
          ? Text(
              producto.descripcion!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            )
          : null,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            formatCOP(producto.precio),
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: GriColors.primary,
            ),
          ),
          const SizedBox(width: 8),
          if (linea == null)
            IconButton(
              icon: const Icon(Icons.add_circle_outline),
              color: GriColors.primary,
              tooltip: 'Agregar ${producto.nombre}',
              onPressed: () =>
                  ref.read(carritoProvider.notifier).agregar(producto),
            )
          else ...[
            IconButton(
              icon: const Icon(Icons.remove_circle_outline),
              onPressed: () => ref
                  .read(carritoProvider.notifier)
                  .decrementar(producto.id),
            ),
            Text(
              '${linea.cantidad}',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 15,
              ),
            ),
            IconButton(
              icon: const Icon(Icons.add_circle_outline),
              color: GriColors.primary,
              onPressed: () => ref
                  .read(carritoProvider.notifier)
                  .incrementar(producto.id),
            ),
          ],
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
              const Text(
                'Tu pedido',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: GriColors.text,
                ),
              ),
              const SizedBox(height: 12),
              for (final l in cart.values)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
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
                  const Text('Total', style: TextStyle(color: GriColors.gray)),
                  const Spacer(),
                  Text(
                    formatCOP(cart.total),
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: GriColors.primary,
                    ),
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
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
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
      debugPrint('enviar pedido falló: $e');
      if (!mounted) return;
      setState(() => _sending = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Error de conexión. Intenta de nuevo.'),
          backgroundColor: GriColors.chipCanceladaFg,
        ),
      );
    }
  }
}
