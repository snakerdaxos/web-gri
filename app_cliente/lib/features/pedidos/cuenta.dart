// ============================================================================
// GRI — La cuenta de la mesa, lado cliente (plan 11-32).
//
// EL HUECO QUE CIERRA
// ---------------------------------------------------------------------------
// Hasta 11-32 la única suma de toda la app era la del carrito
// (`carrito_controller.dart`), y ocurría ANTES de enviar el pedido. Después de
// eso nadie sumaba nada: el cliente pulsaba «Pedir la cuenta», se prendía un
// flag, y ni él ni el mesero veían jamás un importe. Cobrar exigía abrir la
// base de datos y sumar a mano.
//
// ── LA REGLA DE NEGOCIO (decisión del usuario, 2026-08-20) ─────────────────
// SOLO SE COBRA LO SERVIDO. «Si no se sirvió, no se paga». Un pedido rechazado
// por cocina no se cobra nunca; uno en preparación no se cobra TODAVÍA.
//
// La consecuencia incómoda es que EL IMPORTE CAMBIA SOLO mientras haya
// pedidos en curso: el cliente pide la cuenta con un plato en el fuego, ve
// 50.000, se lo sirven y ve 75.000. Por eso este módulo NO devuelve un total:
// devuelve tres montones separados (cobrado / pendiente / rechazado) para que
// la pantalla pueda decir cuál es cuál. Un total a secas sería una cifra que
// se mueve sin explicación.
//
// ── POR QUÉ ES LÓGICA PURA ─────────────────────────────────────────────────
// Sin Firestore, sin widgets, sin providers: es dinero y tiene que poder
// probarse con cifras a mano (`test/pedidos/cuenta_calculo_test.dart`). Mismo
// criterio que `core/firebase_error_mapper.dart`.
//
// ── EL ESPEJO DEL PANEL ────────────────────────────────────────────────────
// `panel_admin/lib/features/cocina/cuenta_mesa.dart` hace lo MISMO sobre
// `PedidoStaff`. Las dos apps no comparten paquete (convención del repo: los
// modelos y las máquinas de estado están duplicados desde la fase 10), así que
// la regla vive dos veces. Las dos copias se prueban con los MISMOS vectores
// de cifras — si una deriva, su suite se pone roja.
// ============================================================================

import '../../models/pedido.dart';

/// Estados de un pedido que aún puede acabar en la cuenta: está en curso y no
/// se cobra todavía, pero el cliente tiene que verlo o pagará una cifra y
/// leerá otra cuando llegue el plato.
const Set<String> estadosPendientes = {'enviado', 'aceptado', 'en_preparacion'};

/// El único estado que se cobra (decisión del usuario, locked).
const String estadoCobrable = 'servido';

/// La cuenta de una sesión de mesa, ya separada en montones.
///
/// [total] es lo que el cliente paga AHORA. [totalPendiente] es lo que se
/// sumará si esos platos llegan a servirse — informativo, NUNCA se cobra.
class CuentaSesion {
  const CuentaSesion({
    required this.cobrados,
    required this.pendientes,
    required this.rechazados,
    required this.fueraDeLaSesion,
  });

  /// Pedidos en estado `servido` dentro de la ventana de la sesión.
  final List<Pedido> cobrados;

  /// Pedidos en curso (`enviado` | `aceptado` | `en_preparacion`).
  final List<Pedido> pendientes;

  /// Pedidos `rechazado` por cocina: se muestran para que el cliente sepa por
  /// qué NO están en el total, pero no suman.
  final List<Pedido> rechazados;

  /// Pedidos descartados por ser de una VISITA ANTERIOR a la misma mesa (ver
  /// [calcularCuenta]). No se muestran: no son de esta cuenta.
  final List<Pedido> fueraDeLaSesion;

  /// Lo que se cobra ahora mismo, en COP enteros.
  int get total => cobrados.fold<int>(0, (suma, p) => suma + p.total);

  /// Lo que aún no se cobra porque no ha llegado a la mesa.
  int get totalPendiente =>
      pendientes.fold<int>(0, (suma, p) => suma + p.total);

  bool get hayPendientes => pendientes.isNotEmpty;

  /// No hay NADA que enseñar de esta sesión (ni cobrado, ni en curso, ni
  /// rechazado). Distinto de `total == 0`, que también pasa cuando todo está
  /// aún en la cocina.
  bool get vacia =>
      cobrados.isEmpty && pendientes.isEmpty && rechazados.isEmpty;

  /// Todos los pedidos de ESTA sesión, cobrados y no cobrados, en el orden en
  /// que llegaron en la lista de entrada. Lo que la pantalla debe listar.
  List<Pedido> get deLaSesion => [...cobrados, ...pendientes, ...rechazados];
}

/// Reparte [pedidos] en los montones de [CuentaSesion].
///
/// [desde] es el `inicioAt` de la sesión ACTUAL. Filtra los pedidos anteriores
/// y esto NO es una precaución teórica:
///
///   `sesiones/{mesaId}` tiene doc ID DETERMINISTA y `abrirSesion()` hace
///   `tx.set()` sobre el MISMO documento cuando la sesión anterior está
///   cerrada (sesion_provider.dart, paso 4). Los pedidos de la visita pasada
///   conservan `sesionId == mesaId` y `usuarioId == uid`, exactamente los dos
///   filtros de `pedidosSessionProvider`. Sin esta ventana, un cliente que
///   vuelve a la MISMA mesa se encuentra la cena de la semana pasada sumada a
///   su cuenta.
///
/// Un pedido con `createdAt == null` SIEMPRE entra: es un `serverTimestamp()`
/// que el servidor todavía no ha resuelto (escritura recién hecha, visible en
/// la caché local). Excluirlo haría que el total bajara un instante justo
/// después de pedir.
///
/// Cuando [desde] es null no se filtra: no sabemos dónde empieza la ventana y
/// esconder pedidos por sospecha sería peor que mostrarlos.
CuentaSesion calcularCuenta(List<Pedido> pedidos, {DateTime? desde}) {
  final cobrados = <Pedido>[];
  final pendientes = <Pedido>[];
  final rechazados = <Pedido>[];
  final fuera = <Pedido>[];

  for (final pedido in pedidos) {
    final creado = pedido.createdAt;
    if (desde != null && creado != null && creado.isBefore(desde)) {
      fuera.add(pedido);
      continue;
    }
    if (pedido.estado == estadoCobrable) {
      cobrados.add(pedido);
    } else if (estadosPendientes.contains(pedido.estado)) {
      pendientes.add(pedido);
    } else {
      // Hoy solo 'rechazado' (y el inalcanzable 'pagado', que se queda aquí a
      // propósito: si algún día llega, NO se vuelve a cobrar).
      rechazados.add(pedido);
    }
  }

  return CuentaSesion(
    cobrados: cobrados,
    pendientes: pendientes,
    rechazados: rechazados,
    fueraDeLaSesion: fuera,
  );
}
