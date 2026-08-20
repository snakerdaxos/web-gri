import '../../models/mesa.dart';
import '../../models/reserva.dart';

/// ============================================================================
/// LA VENTANA DE BLOQUEO DE LA MESA POR RESERVA (plan 11-34)
///
/// Decisión del usuario, 2026-08-20:
///
///   «Lo que bloquee la mesa solo será media hora antes de la reserva y media
///    hora después, para el tiempo de espera. Si el usuario que reservó no
///    hace pedido, se libera. O el admin podría liberar la mesa.»
///
/// ── EL PROBLEMA QUE RESUELVE ───────────────────────────────────────────────
/// El mapa del panel pintaba el campo `estado` de la mesa, y ese campo lo
/// escribía `crearReserva` en el cliente. De ahí salían tres comportamientos
/// incoherentes que el operador no podía explicarse:
///
///   · Reserva creada HOY para hoy   → la mesa se ponía `reservada` al crearla,
///                                     horas antes de que llegara nadie.
///   · Reserva creada AYER para hoy  → la mesa NO se ponía `reservada` y el
///                                     mesero perdía el aviso.
///   · El cliente no aparece         → NADA liberaba la mesa. Quedaba
///                                     inutilizable el resto del turno.
///
/// Con el margen mínimo de 4 h de 11-31, lo primero es todavía peor: una
/// reserva de hoy nace SIEMPRE a 4 horas vista, así que marcar la mesa al
/// crearla la retira de circulación media tarde por un cliente que quizá no
/// venga.
///
/// ── POR QUÉ EL COLOR TIENE QUE DERIVARSE, Y POR QUÉ ESO SIMPLIFICA ────────
/// La regla no se puede implementar guardando el bloqueo en `estado`, porque
/// ese campo no sabe qué hora es: alguien tendría que escribirlo al entrar en
/// la ventana y borrarlo al salir, y no hay quien lo haga — sin plan Blaze no
/// hay Cloud Functions desplegadas.
///
/// Derivando el color de las reservas del día, la liberación automática es
/// IMPLÍCITA: pasados los 30 minutos de cortesía la reserva simplemente deja
/// de teñir la mesa. No hay nada que escribir, nada que programar y nada que
/// pueda quedarse a medias. El `estado` vuelve a significar solo lo que pasa
/// ahora mismo (ocupada, en limpieza) y las tres incoherencias de arriba
/// desaparecen a la vez.
///
/// ── LAS TRES SALIDAS DE LA VENTANA ────────────────────────────────────────
///  1. El cliente llega y pide  → la mesa pasa a `ocupada` por la vía normal
///     (abrir sesión). `ocupada` gana sobre el bloqueo: ver [estadoVisualMesa].
///  2. El cliente no aparece    → a los +30 min la reserva sale de la ventana
///     y la mesa se libera sola. Sin escribir nada.
///  3. El administrador la libera a mano → cancela la reserva
///     (`cancelarReservaNoShow`); una reserva cancelada no bloquea nunca.
///
/// ── FUERA DE ALCANCE (declarado en la especificación) ─────────────────────
/// Avisar al cliente de que su reserva expiró; reasignar la mesa a otra
/// reserva; marcar la reserva como `no_show` para los informes (se deja
/// `confirmada`: nadie la ha cancelado, simplemente pasó su hora).
/// ============================================================================

/// Cuánto ANTES de la hora reservada se bloquea la mesa.
const Duration margenAntesDeLaReserva = Duration(minutes: 30);

/// Cuánto DESPUÉS de la hora reservada se sigue esperando al cliente. Pasado
/// este tiempo de cortesía la mesa se libera sola.
const Duration cortesiaTrasLaReserva = Duration(minutes: 30);

/// Estados de reserva que pueden bloquear una mesa.
///
/// `cancelada` NO está, y eso es lo que convierte «cancelar la reserva» en la
/// palanca de liberación manual del administrador.
const Set<String> estadosDeReservaQueBloquean = {'confirmada', 'pendiente'};

/// ¿Esta reserva bloquea su mesa en el instante [ahora]?
///
/// La ventana es CERRADA en los dos extremos: exactamente a −30 min ya
/// bloquea y exactamente a +30 min todavía bloquea. Los bordes se eligen así
/// para que no exista ningún instante ambiguo, y los dos están cubiertos con
/// instantes literales en `test/dashboard/ventana_reserva_test.dart`.
bool reservaBloqueaLaMesa(Reserva reserva, DateTime ahora) {
  if (!estadosDeReservaQueBloquean.contains(reserva.estado)) return false;
  final desde = reserva.fecha.subtract(margenAntesDeLaReserva);
  final hasta = reserva.fecha.add(cortesiaTrasLaReserva);
  return !ahora.isBefore(desde) && !ahora.isAfter(hasta);
}

/// Los `mesaId` bloqueados por alguna reserva en el instante [ahora].
Set<String> mesasBloqueadasPorReserva(
  Iterable<Reserva> reservas,
  DateTime ahora,
) {
  return {
    for (final r in reservas)
      if (reservaBloqueaLaMesa(r, ahora)) r.mesaId,
  };
}

/// El estado que el mapa PINTA, que ya no es el que el documento guarda.
///
/// ── LA PRECEDENCIA, Y POR QUÉ ES ESTA ─────────────────────────────────────
/// `ocupada` y `limpieza` describen algo que está pasando FÍSICAMENTE en la
/// mesa ahora mismo y ganan siempre: si el cliente de la reserva llegó y
/// abrió sesión, la mesa está ocupada — la reserva se cumplió y ya no pinta
/// nada. Si hay gente comiendo en una mesa que además tenía reserva a las
/// 21:00, lo urgente para el mesero es que está ocupada.
///
/// `disponible` y `reservada` son los dos estados «vacíos», y entre ellos
/// decide la ventana. Que `reservada` guardado en el documento se trate igual
/// que `disponible` NO es un descuido: es lo que hace que el mapa deje de
/// depender de un campo que nadie mantiene, y lo que permite que las mesas
/// marcadas `reservada` por el código anterior a 11-34 se liberen solas en
/// cuanto su reserva sale de la ventana.
EstadoMesa estadoVisualMesa({
  required EstadoMesa estadoGuardado,
  required bool bloqueadaPorReserva,
}) {
  switch (estadoGuardado) {
    case EstadoMesa.ocupada:
    case EstadoMesa.limpieza:
      return estadoGuardado;
    case EstadoMesa.disponible:
    case EstadoMesa.reservada:
      return bloqueadaPorReserva
          ? EstadoMesa.reservada
          : EstadoMesa.disponible;
  }
}

/// Una mesa lista para pintar: el documento, el color que le toca AHORA y la
/// reserva que lo justifica (si la hay).
///
/// [reserva] no es decorativa: es lo que permite al tile decir «reservada a
/// las 21:00 para 4» en vez de un amarillo sin explicación, que era
/// literalmente la queja del operador — el color aparecía «a veces» y no se
/// podía deducir de dónde venía.
typedef MesaEnMapa = ({
  Mesa mesa,
  EstadoMesa estadoVisual,
  Reserva? reserva,
});

/// Compone el mapa: cada mesa con el color que le corresponde en [ahora].
///
/// Función PURA y con el instante inyectado. Los tests le pasan instantes
/// literales; nadie recalcula la expectativa con la misma expresión que el
/// código, que es como 11-31 descubrió cinco archivos que dependían en
/// silencio del reloj de la máquina.
List<MesaEnMapa> componerMapaDeMesas({
  required List<Mesa> mesas,
  required List<Reserva> reservasDelDia,
  required DateTime ahora,
}) {
  // La reserva que se muestra es la que BLOQUEA. Si dos reservas de la misma
  // mesa cayeran en la ventana a la vez (no debería: el doc ID es
  // {mesa}_{fecha}_{hora}, uno por franja), gana la más temprana, que es la
  // que el mesero está esperando.
  final bloqueantes = <String, Reserva>{};
  for (final r in reservasDelDia) {
    if (!reservaBloqueaLaMesa(r, ahora)) continue;
    final previa = bloqueantes[r.mesaId];
    if (previa == null || r.fecha.isBefore(previa.fecha)) {
      bloqueantes[r.mesaId] = r;
    }
  }

  return [
    for (final mesa in mesas)
      (
        mesa: mesa,
        estadoVisual: estadoVisualMesa(
          estadoGuardado: mesa.estado,
          bloqueadaPorReserva: bloqueantes.containsKey(mesa.id),
        ),
        // La reserva solo se adjunta cuando de verdad tiñe la mesa: si la
        // mesa está ocupada, el amarillo no se pinta y hablar de la reserva
        // en el tile sería contradecir el color.
        reserva: estadoVisualMesa(
                  estadoGuardado: mesa.estado,
                  bloqueadaPorReserva: bloqueantes.containsKey(mesa.id),
                ) ==
                EstadoMesa.reservada
            ? bloqueantes[mesa.id]
            : null,
      ),
  ];
}

/// Recuento por estado VISUAL, para las tarjetas del dashboard.
///
/// Existe porque el contador «Mesas disponibles» tenía exactamente el mismo
/// defecto que el mapa: contaba el campo `estado`, así que una mesa marcada
/// `reservada` por una reserva de dentro de cinco horas no se contaba como
/// disponible aunque lo estuviera.
({int disponibles, int ocupadas, int reservadas, int limpieza}) contarPorEstadoVisual(
  List<MesaEnMapa> mapa,
) {
  var disponibles = 0;
  var ocupadas = 0;
  var reservadas = 0;
  var limpieza = 0;
  for (final m in mapa) {
    switch (m.estadoVisual) {
      case EstadoMesa.disponible:
        disponibles++;
      case EstadoMesa.ocupada:
        ocupadas++;
      case EstadoMesa.reservada:
        reservadas++;
      case EstadoMesa.limpieza:
        limpieza++;
    }
  }
  return (
    disponibles: disponibles,
    ocupadas: ocupadas,
    reservadas: reservadas,
    limpieza: limpieza,
  );
}
