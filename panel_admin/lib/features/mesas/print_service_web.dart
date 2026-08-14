import 'package:web/web.dart' as web;

/// window.print() en el target web (package:web — sin dart:html deprecado).
void printCurrentView() => web.window.print();
