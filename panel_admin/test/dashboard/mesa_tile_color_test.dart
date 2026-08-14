import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gri_panel_admin/core/theme.dart';
import 'package:gri_panel_admin/features/dashboard/widgets/mesa_tile.dart';
import 'package:gri_panel_admin/models/mesa.dart';

/// Tests del MesaTile (ADMN-02): verifica que cada uno de los 4 estados aplica
/// el par (bg, fg) EXACTO del mockup.

Mesa _m(EstadoMesa e) => Mesa(
      id: 1,
      numero: 1,
      capacidad: 4,
      codigoQr: 'GRI-MESA-001',
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
}
