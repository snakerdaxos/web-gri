// core/state_machines.dart — port 1:1 de
// backend/app/core/state_machines.py (ARCHITECTURE.md Pattern 5).
//
// Módulo PURO: no importa Firestore/Auth — solo las tablas de transiciones.
// Las features importan `validarTransicion()` en sus controllers/mutaciones;
// los tests unitarios corren en milisegundos.
//
// Cada tabla mapea `estado_origen -> {estados_destino}` (strings idénticos
// a los enums de Python — Firestore guarda los mismos valores). Un `Set`
// vacío marca un estado TERMINAL (no admite más transiciones).
//
// Diferencia intencional vs Python: los estados son `String` (no Enum)
// porque llegan de/entran a Firestore como strings.

/// Transición de estado no permitida por la máquina de estados del dominio.
///
/// Atributos (port de `TransicionInvalidaError`):
/// * [maquina] — nombre de la máquina ("mesa", "pedido", ...).
/// * [actual] — estado origen.
/// * [nueva] — estado destino rechazado.
class TransicionInvalidaException implements Exception {
  const TransicionInvalidaException(this.maquina, this.actual, this.nueva);

  final String maquina;
  final String actual;
  final String nueva;

  @override
  String toString() =>
      "[$maquina] transición '$actual' → '$nueva' no permitida";
}

// ---- Tablas (diff 1:1 contra state_machines.py, mismo orden/valores) ----

/// Set vacío = terminal (port de MESA_TRANSITIONS).
const Map<String, Set<String>> mesaTransitions = {
  'disponible': {'reservada', 'ocupada'},
  'reservada': {'ocupada', 'disponible'},
  'ocupada': {'limpieza'},
  'limpieza': {'disponible'},
};

/// Port de PEDIDO_TRANSITIONS (rechazado y pagado terminales).
const Map<String, Set<String>> pedidoTransitions = {
  'borrador': {'enviado'},
  'enviado': {'aceptado', 'rechazado'},
  'aceptado': {'en_preparacion'},
  'en_preparacion': {'servido'},
  'servido': {'pagado'},
  'rechazado': <String>{}, // terminal
  'pagado': <String>{}, // terminal
};

/// Port de RESERVA_TRANSITIONS (cancelada terminal).
const Map<String, Set<String>> reservaTransitions = {
  'pendiente': {'confirmada', 'cancelada'},
  'confirmada': {'cancelada'},
  'cancelada': <String>{}, // terminal
};

/// Port de PAGO_TRANSITIONS (aprobado y rechazado terminales).
const Map<String, Set<String>> pagoTransitions = {
  'pendiente': {'aprobado', 'rechazado'},
  'aprobado': <String>{}, // terminal
  'rechazado': <String>{}, // terminal
};

/// Port de SESION_TRANSITIONS (cerrada y expirada terminales).
const Map<String, Set<String>> sesionTransitions = {
  'activa': {'cerrada', 'expirada'},
  'cerrada': <String>{}, // terminal
  'expirada': <String>{}, // terminal
};

/// Registro de las 5 máquinas (port de `_ALL`; clave `sesion_mesa`).
const Map<String, Map<String, Set<String>>> _all = {
  'mesa': mesaTransitions,
  'pedido': pedidoTransitions,
  'reserva': reservaTransitions,
  'pago': pagoTransitions,
  'sesion_mesa': sesionTransitions,
};

/// Tabla de transiciones de una máquina (port del acceso a `_ALL` en los
/// tests Python — permite verificar cobertura sin exponer el registro).
Map<String, Set<String>> transicionesDe(String maquina) {
  final transitions = _all[maquina];
  if (transitions == null) {
    // Python levanta KeyError — aquí ArgumentError (error de programador).
    throw ArgumentError.value(maquina, 'maquina', 'máquina desconocida');
  }
  return transitions;
}

/// Lanza [TransicionInvalidaException] si `actual` → `nueva` no está
/// declarada en la máquina indicada (port de `validar_transicion`).
///
/// Estados sin entrada en la tabla (o terminales) rechazan todo.
void validarTransicion(String maquina, String actual, String nueva) {
  final permitidas = transicionesDe(maquina)[actual] ?? const <String>{};
  if (!permitidas.contains(nueva)) {
    throw TransicionInvalidaException(maquina, actual, nueva);
  }
}

/// Versión booleana de [validarTransicion] (port de `puede_transicionar`).
bool puedeTransicionar(String maquina, String actual, String nueva) {
  return transicionesDe(maquina)[actual]?.contains(nueva) ?? false;
}
