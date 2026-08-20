// ============================================================================
// GRI — GATE: `main.dart` instala el reloj que LATE (plan 11-34).
//
// ── POR QUÉ HACE FALTA UN GATE PARA ESTO ─────────────────────────────────
// El defecto de `fabricaDeRelojProvider` es el reloj QUIETO, para que ningún
// test de widget arrastre un `Timer.periodic` (80 casos rojos medidos con el
// latido por defecto). El que late se instala EXCLUSIVAMENTE en el
// `ProviderScope` raíz de `main.dart`.
//
// Eso deja un agujero muy concreto: si alguien borra ese override, o crea un
// entrypoint nuevo sin él, el mapa de mesas deja de refrescarse solo en
// producción —una mesa se queda amarilla hasta que alguien recargue— y NO se
// pone roja ni una sola prueba. Sería un fallo invisible.
//
// Este archivo lo hace visible. Es una comprobación ESTÁTICA sobre el fuente
// de `main.dart`: es lo que se puede afirmar sin ejecutar `main()`, que
// arranca Firebase.
//
// Mismo patrón que `password_policy_gate_test.dart`: cuando el cableado vive
// en un sitio que ningún test monta, se vigila el fuente.
// ============================================================================

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('main.dart sustituye el reloj por relojQueLate en el scope raíz', () {
    final fuente = File('lib/main.dart').readAsStringSync();

    expect(fuente, contains('fabricaDeRelojProvider.overrideWithValue'),
        reason: 'sin el override, el mapa de mesas no se refresca solo en '
            'producción y ninguna otra prueba lo nota');
    expect(fuente, contains('relojQueLate'),
        reason: 'tiene que ser el que LATE, no el quieto');
  });

  test('el override va DENTRO del ProviderScope raíz, no en otro sitio', () {
    final fuente = File('lib/main.dart').readAsStringSync();

    final scope = fuente.indexOf('runApp(ProviderScope(');
    final override = fuente.indexOf('fabricaDeRelojProvider.overrideWithValue');
    expect(scope, greaterThanOrEqualTo(0), reason: 'ancla: el scope raíz');
    expect(override, greaterThan(scope),
        reason: 'un override fuera del scope raíz no llega a los providers');
  });

  test('CANARIO: el gate detecta la ausencia del override', () {
    // Sin este caso, los dos anteriores pasarían igual con un `contains` que
    // buscara una cadena que siempre está.
    const sinOverride = '''
      runApp(ProviderScope(
        retry: reintentoGri,
        child: const GriApp(),
      ));
    ''';
    expect(sinOverride.contains('fabricaDeRelojProvider.overrideWithValue'),
        isFalse);
  });
}
