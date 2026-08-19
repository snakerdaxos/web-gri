import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gri_panel_admin/core/gri_icons.dart';
import 'package:gri_panel_admin/features/mesas/qr_dialog.dart';
import 'package:gri_panel_admin/models/mesa.dart';
import 'package:qr_flutter/qr_flutter.dart';

/// Tests del QR dialog (MESA-03, 10-06): el QR se genera EN EL PANEL con
/// qr_flutter a partir del doc ID determinista (`GRI-MESA-{rid}-{num}`) —
/// YA NO existe endpoint /m/{codigo}: el contenido del QR ES el código.
///
/// Nota: qr_flutter 4.1.0 no expone getter público de `data` (se guarda en
/// `_data` privado) — la igualdad EXACTA del código se asierta vía el
/// SelectableText, y el pintado real del QR vía su QrPainter montado.
///
/// El botón Imprimir NO se tapea: `web.window.print()` solo existe en
/// el browser (package:web) — en la VM del runner lanzaría.

const _mesa = Mesa(
  id: 'GRI-MESA-demo-009',
  restauranteId: 'demo',
  numero: 9,
  capacidad: 4,
  estado: EstadoMesa.disponible,
);

void main() {
  testWidgets(
    'renderiza QrImageView con data == código del doc (GRI-MESA-demo-009) — sin endpoint',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => Center(
                child: ElevatedButton(
                  onPressed: () => showQrDialog(context, _mesa),
                  child: const Text('abrir'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('abrir'));
      await tester.pumpAndSettle();

      // Título con el número de la mesa.
      expect(find.text('Mesa 9 — Código QR'), findsOneWidget);

      // El QR pinta EXACTAMENTE el código del doc (data es privado en
      // qr_flutter 4.1.0 → se verifica el painter real montado + igualdad
      // textual abajo).
      expect(find.byType(QrImageView), findsOneWidget);
      final qrPainter = find.byWidgetPredicate(
        (w) => w is CustomPaint && w.painter is QrPainter,
      );
      expect(qrPainter, findsOneWidget);

      // Fallback textual seleccionable (el staff puede tipearlo/copearlo) —
      // igualdad EXACTA con el código determinista del doc.
      expect(find.byType(SelectableText), findsOneWidget);
      expect(
        tester.widget<SelectableText>(find.byType(SelectableText)).data,
        'GRI-MESA-demo-009',
      );

      // El botón Imprimir existe (NO se tapea — web-only).
      // 11-21: el emoji de impresora es ahora un Icon dentro de un
      // TextButton.icon; el finder cambia, la aserción NO.
      expect(find.text('Imprimir'), findsOneWidget);
      expect(find.byIcon(GriIcons.imprimir), findsOneWidget);
    },
  );

  testWidgets('botón Cerrar hace pop del dialog', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => Center(
              child: ElevatedButton(
                onPressed: () => showQrDialog(context, _mesa),
                child: const Text('abrir'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();
    expect(find.byType(QrImageView), findsOneWidget);

    await tester.tap(find.text('Cerrar'));
    await tester.pumpAndSettle();
    expect(find.byType(QrImageView), findsNothing);
  });
}
