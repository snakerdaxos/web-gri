// ============================================================================
// GRI — El CÁLCULO de la cuenta (plan 11-32). Lógica pura, sin Firestore.
//
// POR QUÉ ESTE ARCHIVO EXISTE APARTE DE `cuenta_test.dart`
// ---------------------------------------------------------------------------
// `cuenta_test.dart` prueba la SOLICITUD de la cuenta (el flag
// `cuentaSolicitada`) y la pantalla. Hasta 11-32 nadie sumaba nada: el importe
// no existía en ninguna de las dos apps. Este archivo prueba la única cosa que
// el cliente lee para decidir cuánto paga.
//
// ── DISCIPLINA DE UN TEST DE DINERO ────────────────────────────────────────
// Las cifras esperadas son LITERALES escritos a mano (50000, 25000). Nunca
// `pedidos.fold(...)` ni ninguna expresión que reproduzca la del código: un
// test que calcula lo esperado con la misma fórmula que la implementación
// pasa en verde aunque la fórmula sea la equivocada, porque compara un error
// consigo mismo. Aquí, si `calcularCuenta` cambia la regla de negocio, los
// números literales no la siguen y el test se pone rojo.
//
// ── LA REGLA DE NEGOCIO QUE CUSTODIA (decisión del usuario, 2026-08-20) ────
// Solo se cobra lo SERVIDO. Un pedido rechazado por cocina no se paga; uno en
// preparación tampoco — todavía. El importe SUBE cuando ese plato se sirve, y
// por eso la cuenta distingue tres montones y no da un total a secas.
// ============================================================================

import 'package:flutter_test/flutter_test.dart';
import 'package:gri_cliente/core/format.dart';
import 'package:gri_cliente/features/pedidos/cuenta.dart';
import 'package:gri_cliente/models/pedido.dart';
import 'package:gri_cliente/models/pedido_item.dart';

/// Un pedido de la mesa 001 con importe y estado explícitos. El `total` NO se
/// deriva de los items a propósito: el doc de Firestore lo trae congelado y la
/// cuenta debe sumar ESE campo, no recalcular con precios de hoy.
Pedido _pedido({
  required String id,
  required String estado,
  required int total,
  DateTime? createdAt,
}) =>
    Pedido(
      id: id,
      restauranteId: 'demo',
      mesaId: 'GRI-MESA-demo-001',
      sesionId: 'GRI-MESA-demo-001',
      usuarioId: 'test-uid',
      estado: estado,
      total: total,
      items: const [
        PedidoItem(
          productoId: 'p1',
          nombre: 'Bandeja paisa',
          precio: 32000,
          cantidad: 1,
        ),
      ],
      createdAt: createdAt,
    );

void main() {
  // ── El caso central: servido sí, en curso no, rechazado nunca ───────────

  group('calcularCuenta — qué entra en el total', () {
    // 32.000 + 18.000 servidos = 50.000. En preparación 25.000 (fuera del
    // total, pero VISIBLE). Rechazado 40.000 (fuera y no se cobra jamás).
    final pedidos = [
      _pedido(id: 'a', estado: 'servido', total: 32000),
      _pedido(id: 'b', estado: 'servido', total: 18000),
      _pedido(id: 'c', estado: 'en_preparacion', total: 25000),
      _pedido(id: 'd', estado: 'rechazado', total: 40000),
    ];

    test('el total son SOLO los servidos: 32.000 + 18.000 = 50.000', () {
      expect(calcularCuenta(pedidos).total, 50000);
    });

    test('el total formateado es exactamente "\$ 50.000"', () {
      expect(formatCOP(calcularCuenta(pedidos).total), '\$ 50.000');
    });

    test('lo pendiente de servir se reporta APARTE: 25.000, 1 pedido', () {
      final cuenta = calcularCuenta(pedidos);
      expect(cuenta.totalPendiente, 25000);
      expect(cuenta.pendientes.length, 1);
      expect(cuenta.pendientes.single.id, 'c');
      expect(cuenta.hayPendientes, isTrue);
    });

    test('el rechazado no está ni en el total ni en lo pendiente', () {
      final cuenta = calcularCuenta(pedidos);
      expect(cuenta.cobrados.map((p) => p.id), isNot(contains('d')));
      expect(cuenta.pendientes.map((p) => p.id), isNot(contains('d')));
      expect(cuenta.rechazados.map((p) => p.id), ['d']);
      // El importe del rechazado (40.000) no se cuela por ninguna vía.
      expect(cuenta.total, 50000);
      expect(cuenta.totalPendiente, 25000);
    });

    test('los tres estados en curso cuentan como pendientes', () {
      final cuenta = calcularCuenta([
        _pedido(id: 'a', estado: 'enviado', total: 1000),
        _pedido(id: 'b', estado: 'aceptado', total: 2000),
        _pedido(id: 'c', estado: 'en_preparacion', total: 3000),
      ]);
      expect(cuenta.total, 0);
      expect(cuenta.totalPendiente, 6000);
      expect(cuenta.pendientes.length, 3);
    });
  });

  // ── El total SUBE al servirse: es el punto delicado del diseño ──────────

  test('al pasar de en_preparacion a servido el total sube de 50.000 a 75.000',
      () {
    final antes = [
      _pedido(id: 'a', estado: 'servido', total: 50000),
      _pedido(id: 'b', estado: 'en_preparacion', total: 25000),
    ];
    final despues = [
      _pedido(id: 'a', estado: 'servido', total: 50000),
      _pedido(id: 'b', estado: 'servido', total: 25000),
    ];
    expect(calcularCuenta(antes).total, 50000);
    expect(calcularCuenta(antes).totalPendiente, 25000);
    expect(calcularCuenta(despues).total, 75000);
    expect(calcularCuenta(despues).totalPendiente, 0);
    expect(calcularCuenta(despues).hayPendientes, isFalse);
  });

  // ── La cuenta suma el `total` CONGELADO, no re-deriva de los items ──────

  test('suma el total del doc aunque no cuadre con los items (congelado)', () {
    // El item dice 32.000; el doc dice 12.000 (precio del día del pedido).
    // Se cobra lo que dice el doc: los precios de hoy no reescriben la
    // historia. Si alguien recalculara desde `items`, saldría 32.000.
    final cuenta = calcularCuenta([
      _pedido(id: 'a', estado: 'servido', total: 12000),
    ]);
    expect(cuenta.total, 12000);
  });

  // ── Sesión REUTILIZADA: `sesiones/{mesaId}` se sobrescribe (abrirSesion
  //    hace tx.set sobre el MISMO id). Los pedidos de la visita anterior
  //    conservan el mismo `sesionId` Y el mismo `usuarioId`, así que la query
  //    del cliente los sigue devolviendo. Cobrarlos sería cobrar dos veces.

  group('ventana de la sesión (desde = inicioAt)', () {
    final inicio = DateTime(2026, 8, 20, 20, 0);

    test('un pedido ANTERIOR a inicioAt no se cobra (visita pasada)', () {
      final cuenta = calcularCuenta(
        [
          _pedido(
            id: 'viejo',
            estado: 'servido',
            total: 99000,
            createdAt: DateTime(2026, 8, 13, 21, 0),
          ),
          _pedido(
            id: 'hoy',
            estado: 'servido',
            total: 30000,
            createdAt: DateTime(2026, 8, 20, 20, 5),
          ),
        ],
        desde: inicio,
      );
      expect(cuenta.total, 30000, reason: 'los 99.000 son de la visita pasada');
      expect(cuenta.cobrados.single.id, 'hoy');
      expect(cuenta.fueraDeLaSesion.single.id, 'viejo');
    });

    test('sin `desde` no se filtra nada (no sabemos la ventana)', () {
      final cuenta = calcularCuenta([
        _pedido(
          id: 'viejo',
          estado: 'servido',
          total: 99000,
          createdAt: DateTime(2026, 8, 13, 21, 0),
        ),
      ]);
      expect(cuenta.total, 99000);
    });

    test('createdAt null (serverTimestamp pendiente) SÍ entra', () {
      // Un pedido recién escrito llega a la caché local con createdAt null
      // hasta que el server resuelve el sentinel. Excluirlo haría que el
      // total parpadeara hacia abajo justo después de pedir.
      final cuenta = calcularCuenta(
        [_pedido(id: 'recien', estado: 'servido', total: 7000)],
        desde: inicio,
      );
      expect(cuenta.total, 7000);
    });

    test('un pedido EXACTAMENTE en inicioAt entra (borde inclusivo)', () {
      final cuenta = calcularCuenta(
        [
          _pedido(
            id: 'borde',
            estado: 'servido',
            total: 5000,
            createdAt: inicio,
          ),
        ],
        desde: inicio,
      );
      expect(cuenta.total, 5000);
    });
  });

  // ── Bordes ──────────────────────────────────────────────────────────────

  test('sin pedidos: total 0, vacía, sin pendientes', () {
    final cuenta = calcularCuenta(const []);
    expect(cuenta.total, 0);
    expect(cuenta.totalPendiente, 0);
    expect(cuenta.vacia, isTrue);
    expect(cuenta.hayPendientes, isFalse);
    expect(formatCOP(cuenta.total), '\$ 0');
  });

  test('solo pendientes: total 0 pero la cuenta NO está vacía', () {
    final cuenta = calcularCuenta([
      _pedido(id: 'a', estado: 'enviado', total: 20000),
    ]);
    expect(cuenta.total, 0);
    expect(cuenta.vacia, isFalse);
  });

  test('estado "pagado" no suma al total a cobrar (no se cobra dos veces)',
      () {
    // 'pagado' es inalcanzable en v1 (ni la matriz del panel ni las rules lo
    // permiten), pero si algún día llega NO debe volver a cobrarse.
    final cuenta = calcularCuenta([
      _pedido(id: 'a', estado: 'servido', total: 10000),
      _pedido(id: 'b', estado: 'pagado', total: 90000),
    ]);
    expect(cuenta.total, 10000);
    expect(cuenta.totalPendiente, 0);
  });
}
