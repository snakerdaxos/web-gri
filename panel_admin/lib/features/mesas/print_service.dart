/// Indirección web-only para `window.print()` (MESA-03).
///
/// `package:web` importa `dart:js_interop`, que NO existe en la VM del
/// test runner — un import directo en `qr_dialog.dart` rompería la
/// compilación de cualquier test que lo alcance transitivamente. Este
/// export condicional resuelve stub (VM) vs web (browser) en compile-time.
library;

export 'print_service_stub.dart'
    if (dart.library.js_interop) 'print_service_web.dart';
