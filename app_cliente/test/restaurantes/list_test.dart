import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gri_cliente/features/restaurantes/restaurantes_list_screen.dart';
import 'package:gri_cliente/features/restaurantes/restaurantes_provider.dart';
import 'package:gri_cliente/models/restaurante.dart';

/// Tests de la lista de restaurantes (REST-01 UI): render con mock, loading
/// y error + Reintentar. Override del provider — sin tocar red.

final _fixture = <Restaurante>[
  const Restaurante(
    id: 1,
    nombre: 'Restaurante Demo GRI',
    tipoCocina: 'Comida colombiana',
    descripcion: null,
    direccion: 'Calle 100',
    calificacion: null, // Phase 5: siempre null → UI muestra "—"
  ),
  const Restaurante(
    id: 2,
    nombre: 'Sushi Kai',
    tipoCocina: 'Japonesa',
    descripcion: null,
    direccion: 'Cra 15',
    calificacion: null,
  ),
];

Widget _wrap(AsyncValue<List<Restaurante>> value) {
  return ProviderScope(
    overrides: [restaurantesListProvider.overrideWithValue(value)],
    child: const MaterialApp(home: RestaurantesListScreen()),
  );
}

void main() {
  testWidgets(
      'renderiza tarjetas con nombre + tipo_cocina + calificación "—"',
      (tester) async {
    await tester.pumpWidget(_wrap(AsyncData(_fixture)));
    await tester.pumpAndSettle();

    expect(find.text('Restaurante Demo GRI'), findsOneWidget);
    expect(find.text('Sushi Kai'), findsOneWidget);
    expect(find.text('Comida colombiana'), findsOneWidget);
    expect(find.text('Japonesa'), findsOneWidget);
    // calificacion null → "—" (una por card).
    expect(find.text('—'), findsNWidgets(2));
  });

  testWidgets('estado loading muestra spinner', (tester) async {
    await tester.pumpWidget(_wrap(const AsyncLoading()));
    // Sin pumpAndSettle: AsyncLoading infinito nunca se settle.
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsWidgets);
  });

  testWidgets('estado error muestra mensaje + Reintentar', (tester) async {
    await tester.pumpWidget(
      _wrap(AsyncError('boom', StackTrace.current)),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('Error'), findsOneWidget);
    expect(find.text('Reintentar'), findsOneWidget);
  });
}
