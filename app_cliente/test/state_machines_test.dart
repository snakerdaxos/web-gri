// Unitarios puros de las state machines de dominio — port 1:1 de
// backend/tests/test_state_machines.py (Phase 10, MIGRA-01).
//
// NO tocan Firestore/Auth ni levantan bindings — corren en milisegundos.
// Validan que las tablas Dart sean EXACTAMENTE las de
// backend/app/core/state_machines.py: mismas transiciones declaradas,
// mismos estados terminales, misma semántica de validar/puedeTransicionar.
import 'package:flutter_test/flutter_test.dart';
import 'package:gri_cliente/core/state_machines.dart';

/// Estados de cada máquina (port de los Enums de Python — la coincidencia
/// exacta con las claves de las tablas la verifica el test de cobertura).
const estadosMesa = ['disponible', 'reservada', 'ocupada', 'limpieza'];
const estadosPedido = [
  'borrador',
  'enviado',
  'aceptado',
  'en_preparacion',
  'servido',
  'rechazado',
  'pagado',
];
const estadosReserva = ['pendiente', 'confirmada', 'cancelada'];
const estadosPago = ['pendiente', 'aprobado', 'rechazado'];
const estadosSesion = ['activa', 'cerrada', 'expirada'];

void main() {
  // --- MESA --------------------------------------------------------------

  group('mesa', () {
    test('transiciones válidas: ciclo completo + reservas', () {
      // Python: test_mesas_transiciones_validas.
      expect(
          () => validarTransicion('mesa', 'disponible', 'ocupada'),
          returnsNormally);
      expect(
          () => validarTransicion('mesa', 'ocupada', 'limpieza'),
          returnsNormally);
      expect(
          () => validarTransicion('mesa', 'limpieza', 'disponible'),
          returnsNormally);
      expect(
          () => validarTransicion('mesa', 'disponible', 'reservada'),
          returnsNormally);
      expect(
          () => validarTransicion('mesa', 'reservada', 'ocupada'),
          returnsNormally);
      expect(
          () => validarTransicion('mesa', 'reservada', 'disponible'),
          returnsNormally);
    });

    test('saltos no declarados rechazados con atributos correctos',
        () {
      // Python: test_mesa_transiciones_invalidas_rechazadas.
      const casos = [
        ('limpieza', 'ocupada'),
        ('disponible', 'limpieza'),
        ('ocupada', 'disponible'),
      ];
      for (final (actual, nueva) in casos) {
        expect(
          () => validarTransicion('mesa', actual, nueva),
          throwsA(isA<TransicionInvalidaException>()
              .having((e) => e.maquina, 'maquina', 'mesa')
              .having((e) => e.actual, 'actual', actual)
              .having((e) => e.nueva, 'nueva', nueva)),
          reason: 'mesa $actual → $nueva no está declarada',
        );
      }
    });
  });

  // --- PEDIDO ------------------------------------------------------------

  group('pedido', () {
    test('cadena completa borrador→…→pagado es válida', () {
      // Python: test_pedido_cadena_completa_valida.
      expect(
          () => validarTransicion('pedido', 'borrador', 'enviado'),
          returnsNormally);
      expect(
          () => validarTransicion('pedido', 'enviado', 'aceptado'),
          returnsNormally);
      expect(
          () => validarTransicion('pedido', 'aceptado', 'en_preparacion'),
          returnsNormally);
      expect(
          () => validarTransicion('pedido', 'en_preparacion', 'servido'),
          returnsNormally);
      expect(
          () => validarTransicion('pedido', 'servido', 'pagado'),
          returnsNormally);
    });

    test('enviado puede rechazarse', () {
      // Python: test_pedido_enviado_puede_rechazarse.
      expect(
          () => validarTransicion('pedido', 'enviado', 'rechazado'),
          returnsNormally);
    });

    test('rechazado y pagado son terminales: TODO destino lanza', () {
      // Python: test_pedido_rechazado_y_pagado_son_terminales.
      for (final terminal in ['rechazado', 'pagado']) {
        for (final nuevo in estadosPedido) {
          if (nuevo == terminal) continue;
          expect(
            () => validarTransicion('pedido', terminal, nuevo),
            throwsA(isA<TransicionInvalidaException>()),
            reason: 'pedido terminal $terminal → $nuevo debe rechazarse',
          );
        }
      }
    });

    test('saltos de cadena rechazados (borrador→pagado, borrador→aceptado)',
        () {
      // Python: test_pedido_salto_invalido_rechazado.
      expect(() => validarTransicion('pedido', 'borrador', 'pagado'),
          throwsA(isA<TransicionInvalidaException>()));
      expect(() => validarTransicion('pedido', 'borrador', 'aceptado'),
          throwsA(isA<TransicionInvalidaException>()));
    });
  });

  // --- RESERVA / PAGO / SESION (terminales rechazan todo) ----------------

  test('reserva: válidas declaradas; cancelada es terminal', () {
    expect(() => validarTransicion('reserva', 'pendiente', 'confirmada'),
        returnsNormally);
    expect(() => validarTransicion('reserva', 'pendiente', 'cancelada'),
        returnsNormally);
    expect(() => validarTransicion('reserva', 'confirmada', 'cancelada'),
        returnsNormally);

    for (final nuevo in estadosReserva) {
      if (nuevo == 'cancelada') continue;
      expect(
        () => validarTransicion('reserva', 'cancelada', nuevo),
        throwsA(isA<TransicionInvalidaException>()),
        reason: 'reserva terminal cancelada → $nuevo debe rechazarse',
      );
    }
  });

  test('pago: válidas declaradas; aprobado y rechazado son terminales', () {
    expect(() => validarTransicion('pago', 'pendiente', 'aprobado'),
        returnsNormally);
    expect(() => validarTransicion('pago', 'pendiente', 'rechazado'),
        returnsNormally);

    for (final terminal in ['aprobado', 'rechazado']) {
      for (final nuevo in estadosPago) {
        if (nuevo == terminal) continue;
        expect(
          () => validarTransicion('pago', terminal, nuevo),
          throwsA(isA<TransicionInvalidaException>()),
          reason: 'pago terminal $terminal → $nuevo debe rechazarse',
        );
      }
    }
  });

  test('sesion_mesa: válidas declaradas; cerrada y expirada son terminales',
      () {
    expect(() => validarTransicion('sesion_mesa', 'activa', 'cerrada'),
        returnsNormally);
    expect(() => validarTransicion('sesion_mesa', 'activa', 'expirada'),
        returnsNormally);

    for (final terminal in ['cerrada', 'expirada']) {
      for (final nuevo in estadosSesion) {
        if (nuevo == terminal) continue;
        expect(
          () => validarTransicion('sesion_mesa', terminal, nuevo),
          throwsA(isA<TransicionInvalidaException>()),
          reason: 'sesion_mesa terminal $terminal → $nuevo debe rechazarse',
        );
      }
    }
  });

  // --- COBERTURA: tablas vs estados (port de test_cobertura_declarada) ---

  test('cobertura declarada: todo estado tiene entrada en su tabla', () {
    expect(transicionesDe('mesa').keys, unorderedEquals(estadosMesa));
    expect(transicionesDe('pedido').keys, unorderedEquals(estadosPedido));
    expect(transicionesDe('reserva').keys, unorderedEquals(estadosReserva));
    expect(transicionesDe('pago').keys, unorderedEquals(estadosPago));
    expect(
        transicionesDe('sesion_mesa').keys, unorderedEquals(estadosSesion));
  });

  // --- puedeTransicionar (versión booleana) ------------------------------

  test('puedeTransicionar retorna bool sin lanzar', () {
    // Python: test_puede_transicionar_retorna_bool_false_sin_levantar.
    expect(puedeTransicionar('mesa', 'limpieza', 'ocupada'), isFalse);
    expect(puedeTransicionar('mesa', 'disponible', 'ocupada'), isTrue);
    // Terminal: nunca puede transicionar.
    expect(puedeTransicionar('pedido', 'pagado', 'borrador'), isFalse);
  });

  test('puedeTransicionar es consistente con validarTransicion (matriz FULL)',
      () {
    // Behavior del plan: versión booleana consistente — se verifica la
    // matriz completa de las 5 máquinas.
    const maquinas = {
      'mesa': estadosMesa,
      'pedido': estadosPedido,
      'reserva': estadosReserva,
      'pago': estadosPago,
      'sesion_mesa': estadosSesion,
    };
    maquinas.forEach((maquina, estados) {
      for (final actual in estados) {
        for (final nueva in estados) {
          final bool esperado =
              transicionesDe(maquina)[actual]?.contains(nueva) ?? false;
          expect(
            puedeTransicionar(maquina, actual, nueva),
            esperado,
            reason: '$maquina $actual → $nueva inconsistente',
          );
          if (esperado) {
            expect(() => validarTransicion(maquina, actual, nueva),
                returnsNormally);
          } else {
            expect(() => validarTransicion(maquina, actual, nueva),
                throwsA(isA<TransicionInvalidaException>()));
          }
        }
      }
    });
  });

  // --- Mensaje de la excepción -------------------------------------------

  test('el mensaje de la excepción contiene [maquina] y los estados', () {
    // Behavior del plan: "lanza TransicionInvalidaException con mensaje que
    // contiene [maquina]".
    final e = TransicionInvalidaException('mesa', 'disponible', 'limpieza');
    expect(e.toString(), contains('[mesa]'));
    expect(e.toString(), contains('disponible'));
    expect(e.toString(), contains('limpieza'));
    expect(e.toString(), contains('no permitida'));
  });
}
