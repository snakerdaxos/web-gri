// test/restaurantes/iconos_test.dart — la iconografía de la home después de
// sustituir los emojis (11-13).
//
// Los emojis eran `Text` y por tanto NINGÚN test podía localizarlos por lo que
// significaban: `find.text('📷')` casa con un glifo, no con "escanear QR".
// Con `Icon` + `GriIcons` sí, y eso es lo que se afirma aquí.
//
// LO QUE ESTO NO PRUEBA: que los iconos SE VEAN bien. Un widget test compara
// `IconData` y mide cajas; el aspecto sigue siendo verificación humana.
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gri_cliente/core/firebase_providers.dart';
import 'package:gri_cliente/core/gri_icons.dart';
import 'package:gri_cliente/features/restaurantes/home_screen.dart';

import '../helpers/firebase_fakes.dart';

Widget _wrap(FakeFirebaseFirestore db) => ProviderScope(
      overrides: [
        firestoreProvider.overrideWithValue(db),
        firebaseAuthProvider.overrideWithValue(mockAuth(displayName: 'Ana')),
      ],
      child: const MaterialApp(home: HomeScreen()),
    );

void main() {
  testWidgets('el botón de escanear muestra el icono de QR, no una cámara',
      (tester) async {
    final db = await buildFakeFirestoreConSeed();
    await tester.pumpWidget(_wrap(db));
    await tester.pumpAndSettle();

    // Aparece DOS veces a propósito: el botón del encabezado y la tarjeta
    // "Escanear mesa" del grid de acciones. Antes eran dos `📷` distintos.
    expect(find.byIcon(GriIcons.escanearQr), findsNWidgets(2));
    expect(find.byIcon(Icons.camera_alt), findsNothing,
        reason: '`escanearQr` describe lo que el botón HACE; una cámara '
            'sugeriría hacer una foto');
  });

  testWidgets('el botón de QR conserva sus 45x45 (el mínimo táctil es de 11-14)',
      (tester) async {
    final db = await buildFakeFirestoreConSeed();
    await tester.pumpWidget(_wrap(db));
    await tester.pumpAndSettle();

    // El del encabezado es el primero del árbol.
    final caja = tester.getSize(find.ancestor(
      of: find.byIcon(GriIcons.escanearQr).first,
      matching: find.byType(SizedBox),
    ).first);
    expect(caja, const Size(45, 45),
        reason: 'sustituir el emoji NO puede encoger el objetivo táctil. '
            'Que 45 < 48 (mínimo de Material) es deuda CONOCIDA y le toca a '
            '11-14: aquí solo se congela para que no empeore');

    expect(tester.widget<Icon>(find.byIcon(GriIcons.escanearQr).first).size,
        22.0,
        reason: 'el fontSize que tenía el Text del emoji era 22');
  });

  testWidgets('la calificación usa un Icon de estrella con su color de marca',
      (tester) async {
    final db = await buildFakeFirestoreConSeed();
    await db.doc('restaurantes/demo').update({
      'califProm': 4.8,
      'califCount': 245,
    });
    await tester.pumpWidget(_wrap(db));
    await tester.pumpAndSettle();

    final estrella = tester.widget<Icon>(find.byIcon(GriIcons.calificacion));
    expect(estrella.size, 14.0);
    expect(estrella.color, const Color(0xFFF5A623),
        reason: 'el ámbar de la calificación es el que ya tenía el Text del '
            '⭐; el icono no puede estrenar color');
    expect(find.text('4.8 (245)'), findsOneWidget);
  });

  testWidgets('el logo de la cabecera es un Icon con etiqueta accesible',
      (tester) async {
    final db = await buildFakeFirestoreConSeed();
    await tester.pumpWidget(_wrap(db));
    await tester.pumpAndSettle();

    final logo = tester.widget<Icon>(find.byIcon(GriIcons.menu).first);
    expect(logo.size, 22.0);
    expect(logo.semanticLabel, 'GRI',
        reason: 'un icono SIN texto al lado necesita etiqueta: el emoji no '
            'tenía ninguna y el lector de pantalla leía el nombre Unicode '
            'del glifo');
  });
}
