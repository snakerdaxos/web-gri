// ============================================================================
// GRI — LA VENTANA DE BLOQUEO DE LA MESA POR RESERVA (plan 11-34).
//
// Decisión del usuario (2026-08-20): la mesa solo está bloqueada por una
// reserva entre 30 min ANTES y 30 min DESPUÉS de su hora. Fuera de esa
// ventana está libre. Si el cliente no aparece, se libera sola.
//
// ── POR QUÉ ESTA SUITE USA INSTANTES LITERALES ───────────────────────────
// Toda la lógica de aquí es una comparación con la hora. Calcular la
// expectativa con la MISMA expresión que el código (`reserva.fecha.subtract(
// margenAntesDeLaReserva)`) probaría que la expresión es igual a sí misma y
// nada más. Cada caso escribe el instante a mano — 20:29, 20:30, 21:30,
// 21:31 — y el plan 11-31 es la razón: encontró cinco archivos que dependían
// en silencio del reloj de la máquina y se habrían puesto rojos a partir de
// las 19:01.
//
// ── LOS BORDES SE PRUEBAN EXACTOS ────────────────────────────────────────
// Un `>=` escrito como `>` es el error más probable de este código y no lo
// detecta ninguna prueba «a media ventana». Los cuatro bordes tienen su caso.
// ============================================================================

import 'package:flutter_test/flutter_test.dart';
import 'package:gri_panel_admin/features/dashboard/bloqueo_reserva.dart';
import 'package:gri_panel_admin/models/mesa.dart';
import 'package:gri_panel_admin/models/reserva.dart';

/// La reserva de referencia de toda la suite: HOY a las 21:00.
final _reservaA21 = DateTime(2026, 8, 20, 21, 0);

Reserva _reserva({
  String mesaId = 'GRI-MESA-demo-001',
  DateTime? fecha,
  String estado = 'confirmada',
  int personas = 4,
}) =>
    Reserva(
      id: 'r-1',
      restauranteId: 'demo',
      mesaId: mesaId,
      mesaNumero: 1,
      fecha: fecha ?? _reservaA21,
      numPersonas: personas,
      estado: estado,
      usuarioId: 'uid-cliente',
    );

Mesa _mesa({
  String id = 'GRI-MESA-demo-001',
  int numero = 1,
  EstadoMesa estado = EstadoMesa.disponible,
}) =>
    Mesa(
      id: id,
      restauranteId: 'demo',
      numero: numero,
      capacidad: 4,
      estado: estado,
    );

void main() {
  group('reservaBloqueaLaMesa — los cuatro bordes de la ventana', () {
    test('20:29 (un minuto antes de abrirse): NO bloquea', () {
      expect(
        reservaBloqueaLaMesa(_reserva(), DateTime(2026, 8, 20, 20, 29)),
        isFalse,
      );
    });

    test('20:30 EXACTAS (−30 min): SÍ bloquea', () {
      expect(
        reservaBloqueaLaMesa(_reserva(), DateTime(2026, 8, 20, 20, 30)),
        isTrue,
      );
    });

    test('21:30 EXACTAS (+30 min, último minuto de cortesía): SÍ bloquea', () {
      expect(
        reservaBloqueaLaMesa(_reserva(), DateTime(2026, 8, 20, 21, 30)),
        isTrue,
      );
    });

    test('21:31: ya NO bloquea — la mesa se liberó SOLA', () {
      // Esta es la liberación automática entera: no hay proceso, no hay
      // escritura, no hay Cloud Function. Pasa el minuto y deja de teñir.
      expect(
        reservaBloqueaLaMesa(_reserva(), DateTime(2026, 8, 20, 21, 31)),
        isFalse,
      );
    });
  });

  group('reservaBloqueaLaMesa — lo que queda fuera', () {
    test('cuatro horas antes NO bloquea (el caso que motivó el cambio)', () {
      // Con el margen mínimo de 4 h de 11-31, una reserva de hoy nace SIEMPRE
      // a cuatro horas vista. El comportamiento anterior marcaba la mesa
      // justo aquí y la retiraba de circulación media tarde.
      expect(
        reservaBloqueaLaMesa(_reserva(), DateTime(2026, 8, 20, 17, 0)),
        isFalse,
      );
    });

    test('una reserva CANCELADA no bloquea, ni dentro de la ventana', () {
      // Es la palanca de liberación MANUAL del administrador: cancelar la
      // reserva libera la mesa en el acto.
      expect(
        reservaBloqueaLaMesa(
          _reserva(estado: 'cancelada'),
          DateTime(2026, 8, 20, 21, 0),
        ),
        isFalse,
      );
    });

    test('una reserva PENDIENTE sí bloquea (aún puede presentarse)', () {
      expect(
        reservaBloqueaLaMesa(
          _reserva(estado: 'pendiente'),
          DateTime(2026, 8, 20, 21, 0),
        ),
        isTrue,
      );
    });
  });

  group('estadoVisualMesa — la precedencia', () {
    test('OCUPADA gana sobre el bloqueo: el cliente llegó y está comiendo',
        () {
      expect(
        estadoVisualMesa(
            estadoGuardado: EstadoMesa.ocupada, bloqueadaPorReserva: true),
        EstadoMesa.ocupada,
      );
    });

    test('LIMPIEZA gana sobre el bloqueo', () {
      expect(
        estadoVisualMesa(
            estadoGuardado: EstadoMesa.limpieza, bloqueadaPorReserva: true),
        EstadoMesa.limpieza,
      );
    });

    test('DISPONIBLE + dentro de la ventana → se pinta RESERVADA', () {
      expect(
        estadoVisualMesa(
            estadoGuardado: EstadoMesa.disponible, bloqueadaPorReserva: true),
        EstadoMesa.reservada,
      );
    });

    test(
        'RESERVADA guardada + FUERA de la ventana → se pinta DISPONIBLE '
        '(las mesas marcadas por el código viejo se liberan solas)', () {
      // Cierra la migración sin script: los documentos que el `crearReserva`
      // anterior a 11-34 dejó en `reservada` no bloquean a nadie.
      expect(
        estadoVisualMesa(
            estadoGuardado: EstadoMesa.reservada, bloqueadaPorReserva: false),
        EstadoMesa.disponible,
      );
    });
  });

  group('componerMapaDeMesas', () {
    final mesas = [
      _mesa(id: 'GRI-MESA-demo-001', numero: 1),
      _mesa(id: 'GRI-MESA-demo-002', numero: 2),
      _mesa(
          id: 'GRI-MESA-demo-003',
          numero: 3,
          estado: EstadoMesa.ocupada),
    ];

    test('dentro de la ventana solo se tiñe la mesa reservada', () {
      final mapa = componerMapaDeMesas(
        mesas: mesas,
        reservasDelDia: [_reserva(mesaId: 'GRI-MESA-demo-002')],
        ahora: DateTime(2026, 8, 20, 20, 45),
      );

      expect(mapa[0].estadoVisual, EstadoMesa.disponible);
      expect(mapa[1].estadoVisual, EstadoMesa.reservada);
      expect(mapa[2].estadoVisual, EstadoMesa.ocupada);
    });

    test('la reserva viaja con la mesa que tiñe, y SOLO con esa', () {
      // El color sin causa visible era la queja literal del operador: el
      // amarillo aparecía «a veces» y no se podía deducir de dónde venía.
      final mapa = componerMapaDeMesas(
        mesas: mesas,
        reservasDelDia: [_reserva(mesaId: 'GRI-MESA-demo-002', personas: 6)],
        ahora: DateTime(2026, 8, 20, 20, 45),
      );

      expect(mapa[0].reserva, isNull);
      expect(mapa[1].reserva?.numPersonas, 6);
      expect(mapa[2].reserva, isNull);
    });

    test(
        'una mesa OCUPADA con reserva en ventana no lleva reserva adjunta: '
        'el amarillo no se pinta y hablar de él sería contradecir el color',
        () {
      final mapa = componerMapaDeMesas(
        mesas: mesas,
        reservasDelDia: [_reserva(mesaId: 'GRI-MESA-demo-003')],
        ahora: DateTime(2026, 8, 20, 21, 0),
      );

      expect(mapa[2].estadoVisual, EstadoMesa.ocupada);
      expect(mapa[2].reserva, isNull);
    });

    test('a las 17:00 no hay NINGUNA mesa teñida por la reserva de las 21:00',
        () {
      final mapa = componerMapaDeMesas(
        mesas: mesas,
        reservasDelDia: [_reserva(mesaId: 'GRI-MESA-demo-002')],
        ahora: DateTime(2026, 8, 20, 17, 0),
      );

      expect(mapa.where((m) => m.estadoVisual == EstadoMesa.reservada),
          isEmpty);
    });

    test('con dos reservas de la misma mesa en ventana, gana la más temprana',
        () {
      final mapa = componerMapaDeMesas(
        mesas: mesas,
        reservasDelDia: [
          _reserva(mesaId: 'GRI-MESA-demo-002', personas: 8)
              .copyWith(id: 'tarde', fecha: DateTime(2026, 8, 20, 21, 15)),
          _reserva(mesaId: 'GRI-MESA-demo-002', personas: 2)
              .copyWith(id: 'temprana', fecha: DateTime(2026, 8, 20, 20, 55)),
        ],
        ahora: DateTime(2026, 8, 20, 20, 50),
      );

      expect(mapa[1].reserva?.id, 'temprana',
          reason: 'el mesero está esperando a la de las 20:55');
    });
  });

  group('contarPorEstadoVisual — los contadores del dashboard', () {
    test(
        'una mesa con reserva a 4 horas SIGUE contando como disponible '
        '(el contador tenía el mismo defecto que el mapa)', () {
      final mapa = componerMapaDeMesas(
        mesas: [_mesa(id: 'GRI-MESA-demo-001')],
        reservasDelDia: [_reserva()],
        ahora: DateTime(2026, 8, 20, 17, 0),
      );

      final c = contarPorEstadoVisual(mapa);
      expect(c.disponibles, 1);
      expect(c.reservadas, 0);
    });

    test('dentro de la ventana el contador la mueve a reservadas', () {
      final mapa = componerMapaDeMesas(
        mesas: [_mesa(id: 'GRI-MESA-demo-001')],
        reservasDelDia: [_reserva()],
        ahora: DateTime(2026, 8, 20, 21, 0),
      );

      final c = contarPorEstadoVisual(mapa);
      expect(c.disponibles, 0);
      expect(c.reservadas, 1);
    });

    test('los cuatro estados suman el total de mesas', () {
      final mapa = componerMapaDeMesas(
        mesas: [
          _mesa(id: 'm1', numero: 1),
          _mesa(id: 'm2', numero: 2, estado: EstadoMesa.ocupada),
          _mesa(id: 'm3', numero: 3, estado: EstadoMesa.limpieza),
          _mesa(id: 'm4', numero: 4),
        ],
        reservasDelDia: [_reserva(mesaId: 'm4')],
        ahora: DateTime(2026, 8, 20, 21, 0),
      );

      final c = contarPorEstadoVisual(mapa);
      expect(c.disponibles + c.ocupadas + c.reservadas + c.limpieza, 4);
      expect(
        (c.disponibles, c.ocupadas, c.reservadas, c.limpieza),
        (1, 1, 1, 1),
      );
    });
  });
}
