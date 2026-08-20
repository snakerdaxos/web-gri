// ============================================================================
// GRI — Las tres ramas del panel que AFIRMABAN algo falso (plan 11-33).
//
// El barrido de 11-29 revisó los 36 `catch` de las dos apps y no podía ver
// estas tres: ninguna es un `catch`, son ramas `error:` de un `AsyncValue`.
//
//   1. `historial_dialog.dart` — `error: (e, _) => const _SinPedidos()`
//      «Este cliente no tiene pedidos». Es una afirmación SOBRE LOS DATOS
//      hecha desde un fallo que no los pudo leer. El comentario decía «404
//      (existence hiding) y vacío → mismo mensaje», que es un criterio
//      razonable para un 404 y falso para un permiso denegado o una caída de
//      red: esos no ocultan nada, simplemente no se leyeron.
//
//   2. `configuracion_screen.dart` — «No hay restaurante seleccionado»
//      Es LITERALMENTE la familia del incidente de 11-24 («el restaurante no
//      existe» cuando lo que faltaba era una function sin desplegar): se
//      afirma una condición del estado a partir de un error de transporte.
//
//   3. `app_shell.dart` — `error: (_, _) => const SizedBox.shrink()`
//      El selector de restaurante del super-admin desaparece sin decir nada.
//      Peor que un mensaje malo: no hay nada que leer ni nada que hacer.
//
// Se afirma la CADENA que leería la persona, y en los tres casos también que
// la afirmación falsa YA NO ESTÁ.
// ============================================================================

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:gri_panel_admin/core/async_fallo.dart';
import 'package:gri_panel_admin/core/firebase_providers.dart';
import 'package:gri_panel_admin/features/clientes/clientes_provider.dart';
import 'package:gri_panel_admin/features/clientes/historial_dialog.dart';
import 'package:gri_panel_admin/features/configuracion/configuracion_screen.dart';
import 'package:gri_panel_admin/features/dashboard/restaurante_provider.dart';
import 'package:gri_panel_admin/models/pedido_staff.dart';
import 'package:gri_panel_admin/models/cliente_resumen.dart';
import 'package:gri_panel_admin/models/restaurante.dart';

import '../helpers/firebase_fakes.dart';

FirebaseException _denegado() =>
    FirebaseException(plugin: 'cloud_firestore', code: 'permission-denied');

String _texto(WidgetTester tester) => tester
    .widgetList<Text>(find.byType(Text))
    .map((t) => t.data ?? t.textSpan?.toPlainText() ?? '')
    .join(' | ');

Future<void> _pump(WidgetTester tester, Widget w) async {
  await tester.pumpWidget(w);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
  await tester.pump(const Duration(milliseconds: 50));
}

Widget _scope(List<Override> overrides, Widget child) => ProviderScope(
      retry: reintentoGri,
      overrides: overrides,
      child: MaterialApp(home: Scaffold(body: child)),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
      'historial: un fallo NO puede decir que el cliente no tiene pedidos',
      (tester) async {
    final db = await buildFakeFirestoreConSeed();
    const cliente = ClienteResumen(
      usuarioId: 'uid-cli',
      clienteNombre: 'Carlos Demo',
      nPedidos: 3,
      totalConsumo: 90000,
    );

    await _pump(
      tester,
      _scope([
        firestoreProvider.overrideWithValue(db),
        claimsProvider.overrideWith((ref) async => (role: 'mesero', rid: 'demo')),
        clienteHistorialProvider('uid-cli')
            .overrideWith((ref) => Future<List<PedidoStaff>>.error(_denegado())),
      ], Builder(builder: (context) {
        // El diálogo se abre por su función pública; no hay widget exportado.
        return Consumer(builder: (context, ref, _) {
          WidgetsBinding.instance.addPostFrameCallback(
              (_) => showHistorialDialog(context, ref, cliente));
          return const SizedBox.shrink();
        });
      })),
    );

    final texto = _texto(tester);
    // LA MENTIRA. Este cliente tiene 3 pedidos; lo que falló fue leerlos.
    expect(texto, isNot(contains('no tiene pedidos')),
        reason: 'afirmar «no tiene pedidos» desde un fallo de lectura es falso');
    expect(texto, contains('Tu cuenta no puede ver el historial de este cliente'));
  });

  testWidgets(
      'configuración: un fallo NO puede decir «no hay restaurante seleccionado»',
      (tester) async {
    final db = await buildFakeFirestoreConSeed();

    await _pump(
      tester,
      _scope([
        firestoreProvider.overrideWithValue(db),
        claimsProvider
            .overrideWith((ref) async => (role: 'admin_restaurante', rid: 'demo')),
        restauranteProvider
            .overrideWith((ref) => Stream<Restaurante>.error(_denegado())),
      ], const ConfiguracionScreen()),
    );
    // La rama vive en la pestaña «Restaurante», que no es la que abre por
    // defecto: sin este toque el caso miraría otra pantalla y pasaría en
    // verde sin haber visto nunca la frase.
    await tester.tap(find.widgetWithText(Tab, 'Restaurante'));
    await tester.pumpAndSettle();

    final texto = _texto(tester);
    // La familia de 11-24: afirmar una condición del estado desde un error
    // de transporte. HAY restaurante seleccionado; no se pudo leer.
    expect(texto, isNot(contains('No hay restaurante seleccionado')),
        reason: 'es la frase del incidente de 11-24, con otro sujeto');
    expect(texto, contains('Tu cuenta no puede ver los restaurantes'));
  });
}
