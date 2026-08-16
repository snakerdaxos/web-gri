import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/producto.dart';

/// Línea del carrito: producto del menú + cantidad.
class CarritoLine {
  const CarritoLine({required this.producto, required this.cantidad});

  final Producto producto;
  final int cantidad;

  /// int COP (Phase 10: precios Firestore son enteros).
  int get subtotal => producto.precio * cantidad;
}

/// Helpers de lectura sobre el mapa del carrito (id → línea).
extension CarritoX on Map<String, CarritoLine> {
  /// Σ precio×cantidad — informativo ANTES de enviar; el total real lo
  /// responde el server (snapshot server-side).
  int get total => values.fold(0, (s, l) => s + l.subtotal);

  /// Σ cantidades (badge del botón carrito).
  int get itemCount => values.fold(0, (s, l) => s + l.cantidad);
}

/// Carrito del menú de la mesa — Notifier puro (sin red): agregar /
/// incrementar / decrementar (cantidad 1 → remueve la línea) / limpiar.
///
/// Vive mientras la app viva: [carritoProvider] es keepAlive para que el
/// carrito sobreviva abrir/cerrar el bottom sheet del carrito y navegar
/// entre menú y estado del pedido. Se limpia tras enviar o al abrir otra
/// sesión.
class CarritoNotifier extends Notifier<Map<String, CarritoLine>> {
  @override
  Map<String, CarritoLine> build() => {};

  void agregar(Producto producto) {
    state = {
      ...state,
      producto.id: CarritoLine(
        producto: producto,
        cantidad: (state[producto.id]?.cantidad ?? 0) + 1,
      ),
    };
  }

  void incrementar(String productoId) {
    final linea = state[productoId];
    if (linea == null) return;
    state = {
      ...state,
      productoId:
          CarritoLine(producto: linea.producto, cantidad: linea.cantidad + 1),
    };
  }

  /// Cantidad 1 → remueve la línea completa.
  void decrementar(String productoId) {
    final linea = state[productoId];
    if (linea == null) return;
    if (linea.cantidad <= 1) {
      remover(productoId);
      return;
    }
    state = {
      ...state,
      productoId:
          CarritoLine(producto: linea.producto, cantidad: linea.cantidad - 1),
    };
  }

  void remover(String productoId) {
    state = {...state}..remove(productoId);
  }

  void limpiar() => state = {};
}

final carritoProvider =
    NotifierProvider<CarritoNotifier, Map<String, CarritoLine>>(
  CarritoNotifier.new,
);
