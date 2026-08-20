// ============================================================================
// GRI — La cuenta de la mesa, lado STAFF (plan 11-32).
//
// EL HUECO QUE CIERRA
// ---------------------------------------------------------------------------
// El aviso «la mesa 3 pidió la cuenta» llegaba sin cifra. El mesero pulsaba
// «Entregar cuenta», la sesión se cerraba, la mesa se iba a limpieza… y él
// cobraba sin saber cuánto. Para averiguarlo había que abrir Firestore y
// sumar los pedidos a mano.
//
// ── LA REGLA (decisión del usuario, 2026-08-20) ────────────────────────────
// Solo se cobra lo SERVIDO. Y como una sesión pertenece a UN usuario (quien
// escanea el QR pide por toda la mesa), la cuenta del comensal y la de la
// mesa son EL MISMO importe: los dos deben ver el mismo número o uno de los
// dos está mintiendo.
//
// ── ESTE ARCHIVO ES EL ESPEJO DE `app_cliente/lib/features/pedidos/cuenta.dart`
// Las dos apps no comparten paquete —los modelos y las máquinas de estado
// llevan duplicados desde la fase 10—, así que la regla de negocio vive dos
// veces. Para que no deriven en silencio, las dos suites prueban EL MISMO
// vector de cifras (32.000 + 18.000 servidos, 25.000 en curso, 40.000
// rechazado → total 50.000, pendiente 25.000). Si una copia cambia la regla,
// su test cae.
//
// ── DE DÓNDE SALEN LAS DOS LISTAS ──────────────────────────────────────────
// * `servidos`: de `pedidosServidosMesaProvider` — consulta propia, acotada a
//   la ventana de la sesión (ver `pedidos_staff_provider.dart`).
// * `enCurso`: de la cola de cocina que YA está en vivo en la pantalla
//   (`pedidosStaffProvider`, estados enviado|aceptado|en_preparacion). No se
//   consulta nada nuevo para saber qué falta por servir.
// ============================================================================

import '../../models/pedido_staff.dart';

/// Estados que aún pueden acabar cobrándose: están en curso y NO entran en el
/// importe todavía. `rechazado` NO está aquí: no se cobra ni se anuncia.
const Set<EstadoPedido> estadosEnCurso = {
  EstadoPedido.enviado,
  EstadoPedido.aceptado,
  EstadoPedido.enPreparacion,
};

/// La cuenta de una mesa tal y como la ve el staff.
class CuentaMesa {
  const CuentaMesa({required this.cobrados, required this.pendientes});

  /// Pedidos `servido` de esta sesión — lo que se cobra.
  final List<PedidoStaff> cobrados;

  /// Pedidos en curso de esta mesa — lo que NO se cobra si se cierra ahora.
  final List<PedidoStaff> pendientes;

  int get total => cobrados.fold<int>(0, (suma, p) => suma + p.total);

  int get totalPendiente =>
      pendientes.fold<int>(0, (suma, p) => suma + p.total);

  bool get hayPendientes => pendientes.isNotEmpty;

  /// No hay nada de esta mesa: ni servido ni en curso.
  bool get vacia => cobrados.isEmpty && pendientes.isEmpty;
}

/// Arma la cuenta de [mesaId] a partir de las dos listas.
///
/// Las dos se re-filtran por `sesionId == mesaId` aunque el provider ya lo
/// haga: `enCurso` llega de la cola del RESTAURANTE ENTERO (todas las mesas),
/// así que sin este filtro la mesa 3 anunciaría los platos de la mesa 5 como
/// suyos. Filtrar dos veces no cuesta nada y deja la regla probada aquí, en
/// una función pura, en vez de escondida en un `map` de un stream.
CuentaMesa cuentaDeMesa({
  required String mesaId,
  required List<PedidoStaff> servidos,
  required List<PedidoStaff> enCurso,
}) {
  return CuentaMesa(
    cobrados: [
      for (final p in servidos)
        if (p.sesionId == mesaId && p.estado == EstadoPedido.servido) p,
    ],
    pendientes: [
      for (final p in enCurso)
        if (p.sesionId == mesaId && estadosEnCurso.contains(p.estado)) p,
    ],
  );
}
