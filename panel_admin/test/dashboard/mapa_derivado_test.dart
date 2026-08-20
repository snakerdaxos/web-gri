// ============================================================================
// GRI — El mapa de mesas PINTADO desde la ventana de reserva (plan 11-34).
//
// `ventana_reserva_test.dart` cubre la lógica pura. Este archivo cubre lo
// otro, que es donde vivía el bug: que la PANTALLA use esa lógica y no el
// campo `estado`. Un mapa que llame a `componerMapaDeMesas` y luego pinte
// `mesa.estado` pasaría la suite pura entera.
//
// ── EL RELOJ VA FIJO ─────────────────────────────────────────────────────
// `fabricaDeRelojProvider` se sobreescribe con un instante literal. Es EL
// punto por el que entra la hora a la aplicación, así que fijarlo ahí fija a
// la vez el mapa y los contadores del dashboard: los dos no pueden afirmar
// sobre horas distintas. Sin esto la suite se pondría roja sola según la hora
// a la que se ejecutara — el defecto que 11-31 encontró en cinco archivos.
// ============================================================================

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gri_panel_admin/core/firebase_providers.dart';
import 'package:gri_panel_admin/core/reloj.dart';
import 'package:gri_panel_admin/core/theme.dart';
import 'package:gri_panel_admin/features/dashboard/widgets/mapa_de_mesas.dart';
import 'package:gri_panel_admin/features/dashboard/widgets/mesa_tile.dart';
import 'package:gri_panel_admin/features/reservas/reservas_provider.dart';
import 'package:gri_panel_admin/models/mesa.dart';
import 'package:gri_panel_admin/models/reserva.dart';

/// HOY, en la fecha de referencia de la suite.
final _hoy = DateTime(2026, 8, 20);
final _reservaA21 = DateTime(2026, 8, 20, 21, 0);

const _m1 = 'GRI-MESA-demo-001';
const _m2 = 'GRI-MESA-demo-002';

Mesa _mesa(String id, int numero, {EstadoMesa estado = EstadoMesa.disponible}) =>
    Mesa(
      id: id,
      restauranteId: 'demo',
      numero: numero,
      capacidad: 4,
      estado: estado,
    );

Reserva _reserva(String mesaId, {String estado = 'confirmada'}) => Reserva(
      id: '${mesaId}_20260820_21',
      restauranteId: 'demo',
      mesaId: mesaId,
      mesaNumero: 2,
      fecha: _reservaA21,
      numPersonas: 4,
      estado: estado,
      usuarioId: 'uid-cliente',
    );

/// El color de fondo del tile de una mesa, leído del `Container` pintado.
Color _fondoDelTile(WidgetTester tester, int numero) {
  final contenedor = tester.widget<Container>(
    find.byKey(ValueKey('mesa-tile-$numero')),
  );
  return (contenedor.decoration! as BoxDecoration).color!;
}

Future<void> _montar(
  WidgetTester tester, {
  required List<Mesa> mesas,
  required List<Reserva> reservas,
  required DateTime ahora,
  AsyncValue<List<Reserva>>? reservasRotas,
}) async {
  tester.view.physicalSize = const Size(1400, 1000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(ProviderScope(
    overrides: [
      firestoreProvider.overrideWithValue(FakeFirebaseFirestore()),
      fabricaDeRelojProvider.overrideWithValue(() => Stream.value(ahora)),
      if (reservasRotas != null)
        reservasHoyProvider.overrideWith(
          (ref) => Stream<List<Reserva>>.error(
            reservasRotas.error!,
            reservasRotas.stackTrace,
          ),
        )
      else
        reservasHoyProvider.overrideWith((ref) => Stream.value(reservas)),
    ],
    child: MaterialApp(
      home: Scaffold(
        backgroundColor: GriColors.background,
        body: SingleChildScrollView(
          child: MapaDeMesas(mesas: mesas, showEdit: false),
        ),
      ),
    ),
  ));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
      'a las 21:00 la mesa reservada se pinta AMARILLA y la otra no',
      (tester) async {
    await _montar(
      tester,
      mesas: [_mesa(_m1, 1), _mesa(_m2, 2)],
      reservas: [_reserva(_m2)],
      ahora: DateTime(2026, 8, 20, 21, 0),
    );

    expect(_fondoDelTile(tester, 2), GriColors.mesaReservadaBg);
    expect(_fondoDelTile(tester, 1), GriColors.mesaDisponibleBg);
  });

  testWidgets(
      'a las 17:00 la MISMA mesa con la MISMA reserva se pinta DISPONIBLE',
      (tester) async {
    // El par de casos que demuestra que el color depende de la HORA y no del
    // documento: nada cambia entre este caso y el anterior salvo el reloj.
    await _montar(
      tester,
      mesas: [_mesa(_m1, 1), _mesa(_m2, 2)],
      reservas: [_reserva(_m2)],
      ahora: DateTime(2026, 8, 20, 17, 0),
    );

    expect(_fondoDelTile(tester, 2), GriColors.mesaDisponibleBg);
  });

  testWidgets(
      'a las 21:31 se liberó SOLA: pasada la cortesía vuelve a disponible',
      (tester) async {
    await _montar(
      tester,
      mesas: [_mesa(_m2, 2)],
      reservas: [_reserva(_m2)],
      ahora: DateTime(2026, 8, 20, 21, 31),
    );

    expect(_fondoDelTile(tester, 2), GriColors.mesaDisponibleBg);
  });

  testWidgets(
      'una mesa guardada como RESERVADA por el código viejo, sin reserva en '
      'ventana, se pinta DISPONIBLE', (tester) async {
    // Migración sin script: los documentos que dejó marcados el
    // `crearReserva` anterior a 11-34 no bloquean a nadie.
    await _montar(
      tester,
      mesas: [_mesa(_m1, 1, estado: EstadoMesa.reservada)],
      reservas: const [],
      ahora: DateTime(2026, 8, 20, 17, 0),
    );

    expect(_fondoDelTile(tester, 1), GriColors.mesaDisponibleBg);
  });

  testWidgets('cancelar la reserva libera la mesa en el acto', (tester) async {
    // La palanca manual del administrador. Misma hora que el primer caso,
    // misma mesa; lo único distinto es el estado de la reserva.
    await _montar(
      tester,
      mesas: [_mesa(_m2, 2)],
      reservas: [_reserva(_m2, estado: 'cancelada')],
      ahora: DateTime(2026, 8, 20, 21, 0),
    );

    expect(_fondoDelTile(tester, 2), GriColors.mesaDisponibleBg);
  });

  testWidgets('el tile DICE por qué está amarillo (hora y personas)',
      (tester) async {
    await _montar(
      tester,
      mesas: [_mesa(_m2, 2)],
      reservas: [_reserva(_m2)],
      ahora: DateTime(2026, 8, 20, 21, 0),
    );

    expect(find.text('21:00 · 4 personas'), findsOneWidget,
        reason: 'un color sin causa visible es una pregunta, no un dato');
  });

  testWidgets(
      'si NO se pueden leer las reservas: el mapa se pinta igual Y se avisa',
      (tester) async {
    await _montar(
      tester,
      mesas: [_mesa(_m1, 1), _mesa(_m2, 2)],
      reservas: const [],
      ahora: DateTime(2026, 8, 20, 21, 0),
      reservasRotas: AsyncValue.error(
        Exception('permission-denied'),
        StackTrace.current,
      ),
    );

    // El mapa NO desaparece: es la herramienta que el mesero usa todo el día.
    expect(find.byType(MesaTile), findsNWidgets(2));
    // Pero no se calla: sin las reservas, el amarillo no es fiable.
    expect(find.textContaining('No pudimos leer las reservas'), findsOneWidget);
  });

  testWidgets('sin fallo NO aparece el aviso (el aviso puede fallar)',
      (tester) async {
    // Canario del caso anterior: si el aviso se pintara siempre, aquel test
    // pasaría igual sin que el aviso significara nada.
    await _montar(
      tester,
      mesas: [_mesa(_m1, 1)],
      reservas: const [],
      ahora: DateTime(2026, 8, 20, 21, 0),
    );

    expect(find.textContaining('No pudimos leer las reservas'), findsNothing);
  });

  testWidgets('la fecha de referencia de la suite es la del reloj fijado',
      (tester) async {
    // Ancla: si alguien cambia `_hoy` sin tocar los instantes de los casos,
    // la suite dejaría de probar lo que dice probar.
    expect(_reservaA21.year, _hoy.year);
    expect(_reservaA21.month, _hoy.month);
    expect(_reservaA21.day, _hoy.day);
  });
}
