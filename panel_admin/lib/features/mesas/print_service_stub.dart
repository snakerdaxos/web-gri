/// window.print() — stub para plataformas sin JS interop (VM de tests).
///
/// Ver [printCurrentView] en `print_service.dart` (export condicional).
void printCurrentView() {
  // Jamás debe llamarse en la VM: los tests NO tapean el botón Imprimir.
  throw UnsupportedError('printCurrentView solo existe en web');
}
