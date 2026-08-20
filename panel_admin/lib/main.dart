import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'core/async_fallo.dart';
import 'core/firebase_bootstrap.dart';
import 'core/reloj.dart';

/// Cierres de limpieza de los relojes de la app.
///
/// El `ProviderScope` raíz vive lo que vive el proceso, así que estos
/// temporizadores no se apagan nunca — que es exactamente lo que se quiere en
/// producción. La lista existe para que [relojQueLate] tenga dónde registrar
/// su limpieza sin inventarse un `ref` que aquí no hay, y para que quede a la
/// vista que la decisión de no apagarlos es deliberada y no un olvido.
final List<void Function()> _temporizadoresDeLaApp = <void Function()>[];

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Firebase ANTES de runApp: emuladores (si USE_EMULATORS) deben cablearse
  // antes de que cualquier provider resuelva las instancias (Pitfall 2).
  await bootstrap();
  // `retry: reintentoGri` (11-33). El default de Riverpod 3 reintenta
  // CUALQUIER excepción 10 veces con backoff hasta 6,4 s —≈38 s— y durante
  // todo ese rato el provider es `AsyncLoading`, no `AsyncError`. Ver
  // core/async_fallo.dart.
  runApp(ProviderScope(
    retry: reintentoGri,
    overrides: [
      // EL RELOJ QUE LATE, solo en la app de verdad (11-34).
      //
      // El defecto de `fabricaDeRelojProvider` es el reloj QUIETO: da la hora
      // correcta pero no vuelve a mirarla. Aquí se sustituye por el que late
      // cada 30 s, que es lo que hace que una mesa se libere sola al pasar
      // los 30 minutos de cortesía de su reserva SIN que cambie ningún
      // documento — ningún onSnapshot va a avisar de que se hizo tarde.
      //
      // El defecto es el quieto y no el que late porque un temporizador vivo
      // dentro de un test de widget enrojece el harness («A Timer is still
      // pending…»): 80 casos medidos. Ver core/reloj.dart.
      fabricaDeRelojProvider.overrideWithValue(
        () => relojQueLate(_temporizadoresDeLaApp.add),
      ),
    ],
    child: const GriApp(),
  ));
}
