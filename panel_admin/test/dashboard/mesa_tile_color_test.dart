import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gri_panel_admin/core/firebase_providers.dart';
import 'package:gri_panel_admin/core/theme.dart';
import 'package:gri_panel_admin/features/dashboard/mesas_provider.dart';
import 'package:gri_panel_admin/features/dashboard/widgets/mesa_tile.dart';
import 'package:gri_panel_admin/models/mesa.dart';

import '../helpers/firebase_fakes.dart';

/// Tests del MesaTile (ADMN-02 + MIGRA-05): cada uno de los 4 estados
/// aplica el par (bg, fg) EXACTO del mockup, y el mapa se actualiza EN
/// VIVO cuando cambia el estado de una mesa en Firestore (onSnapshot) SIN
/// rebuild manual del widget.

Mesa _m(EstadoMesa e) => Mesa(
      id: 'GRI-MESA-demo-001',
      numero: 1,
      capacidad: 4,
      estado: e,
    );

/// Extrae el Container que pinta el MesaTile (vía su ValueKey) y retorna su
/// [BoxDecoration].color.
Color _tileBg(WidgetTester tester) {
  final container = tester.widget<Container>(
    find.byKey(const ValueKey('mesa-tile-1')),
  );
  final decoration = container.decoration as BoxDecoration;
  return decoration.color!;
}

void main() {
  testWidgets('disponible tile uses green palette', (tester) async {
    await tester.pumpWidget(
      MaterialApp(home: Scaffold(body: MesaTile(mesa: _m(EstadoMesa.disponible)))),
    );
    expect(_tileBg(tester), GriColors.mesaDisponibleBg);
    expect(
      tester.widget<Text>(find.text('Mesa 1')).style?.color,
      GriColors.mesaDisponibleFg,
    );
  });

  testWidgets('ocupada tile uses red palette', (tester) async {
    await tester.pumpWidget(
      MaterialApp(home: Scaffold(body: MesaTile(mesa: _m(EstadoMesa.ocupada)))),
    );
    expect(_tileBg(tester), GriColors.mesaOcupadaBg);
    expect(
      tester.widget<Text>(find.text('Mesa 1')).style?.color,
      GriColors.mesaOcupadaFg,
    );
  });

  testWidgets('reservada tile uses yellow palette', (tester) async {
    await tester.pumpWidget(
      MaterialApp(home: Scaffold(body: MesaTile(mesa: _m(EstadoMesa.reservada)))),
    );
    expect(_tileBg(tester), GriColors.mesaReservadaBg);
    expect(
      tester.widget<Text>(find.text('Mesa 1')).style?.color,
      GriColors.mesaReservadaFg,
    );
  });

  testWidgets('limpieza tile uses blue palette', (tester) async {
    await tester.pumpWidget(
      MaterialApp(home: Scaffold(body: MesaTile(mesa: _m(EstadoMesa.limpieza)))),
    );
    expect(_tileBg(tester), GriColors.mesaLimpiezaBg);
    expect(
      tester.widget<Text>(find.text('Mesa 1')).style?.color,
      GriColors.mesaLimpiezaFg,
    );
  });

  // ── MIGRA-05: mapa EN VIVO (onSnapshot) ─────────────────────────────────

  testWidgets(
      'mapa en vivo: escribir el estado de una mesa en Firestore cambia el color del tile SIN rebuild manual',
      (tester) async {
    final db = await buildFakeFirestoreConSeed();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          firestoreProvider.overrideWithValue(db),
          claimsProvider.overrideWith(
            (ref) async => (role: 'admin_restaurante', rid: 'demo'),
          ),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: Consumer(
              builder: (_, ref, _) {
                final mesasAsync = ref.watch(mesasProvider);
                return mesasAsync.when(
                  loading: () => const Center(
                    child: CircularProgressIndicator(),
                  ),
                  error: (e, _) => Text('$e'),
                  data: (mesas) => GridView.count(
                    crossAxisCount: 3,
                    children: [
                      for (final m in mesas) MesaTile(mesa: m),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Inicial: las 3 mesas del seed están disponibles (verde).
    expect(_tileBg(tester), GriColors.mesaDisponibleBg);
    expect(find.text('Mesa 1'), findsOneWidget);
    expect(find.text('Mesa 3'), findsOneWidget);

    // La mutación llega por Firestore — NADIE toca el widget.
    await db.doc('mesas/GRI-MESA-demo-001').update({
      'estado': 'ocupada',
      'updatedAt': FieldValue.serverTimestamp(),
    });
    await tester.pumpAndSettle();

    // El tile refleja el nuevo color (rojo) por el onSnapshot.
    expect(_tileBg(tester), GriColors.mesaOcupadaBg);
    expect(
      tester.widget<Text>(find.text('Mesa 1')).style?.color,
      GriColors.mesaOcupadaFg,
    );
  });

  testWidgets(
      'mapa en vivo filtra por tenant: una mesa de OTRO restaurante no aparece',
      (tester) async {
    final db = await buildFakeFirestoreConSeed();
    // Mesa del restaurante norte (otro tenant).
    await db.doc('mesas/GRI-MESA-norte-001').set({
      'restauranteId': 'norte',
      'numero': 1,
      'capacidad': 2,
      'estado': 'disponible',
      'updatedAt': FieldValue.serverTimestamp(),
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          firestoreProvider.overrideWithValue(db),
          claimsProvider.overrideWith(
            (ref) async => (role: 'admin_restaurante', rid: 'demo'),
          ),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: Consumer(
              builder: (_, ref, _) => ref.watch(mesasProvider).when(
                    loading: () => const SizedBox.shrink(),
                    error: (e, _) => Text('$e'),
                    data: (mesas) => Column(
                      children: [
                        for (final m in mesas) Text('Mesa ${m.numero}'),
                      ],
                    ),
                  ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Solo las 3 del seed (demo) — la del norte NO (Pitfall 4: TODA query
    // lleva where restauranteId == rid). Este test renderiza Text (no
    // MesaTile): contar las filas "Mesa N" prueba el aislamiento igual.
    expect(find.text('Mesa 1'), findsOneWidget);
    expect(find.text('Mesa 2'), findsOneWidget);
    expect(find.text('Mesa 3'), findsOneWidget);
    expect(
      find.textContaining(RegExp(r'^Mesa \d+$')),
      findsNWidgets(3),
      reason: 'la Mesa 1 del norte NO debe duplicar la fila',
    );
  });
}
