import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'core/async_fallo.dart';
import 'core/firebase_bootstrap.dart';

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
    child: const GriApp(),
  ));
}
