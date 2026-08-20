// core/firebase_error_mapper.dart — traducción ÚNICA de un fallo crudo a una
// causa de dominio y a un mensaje honesto (11-23).
//
// ── EL BUG QUE ESTE ARCHIVO CIERRA ─────────────────────────────────────────
// El usuario escaneó el QR de una mesa y la app le dijo:
//     «No pudimos abrir la mesa. Verifica el código e intenta de nuevo.»
// Estuvo revisando el QR. El QR era correcto. Las causas reales fueron dos, y
// ninguna tenía que ver con el código:
//   1. `FirebaseException(code: 'permission-denied')` — su cuenta llevaba rol
//      `super_admin` y la regla de `create` sobre `sesiones` exige
//      `isCliente()` (firestore.rules). Es correcto por diseño: un miembro de
//      plataforma no se sienta a pedir. Pero hay que DECÍRSELO.
//   2. `FirebaseException(code: 'unavailable')` — la app estaba compilada con
//      `--dart-define=USE_EMULATORS=true` y los emuladores no corrían.
// Las dos caían en el mismo `catch (_)` y salían por el mismo texto.
//
// REGLA DE ORO: un `permission-denied` JAMÁS produce un mensaje que hable del
// código, del QR o de «verificar». Es un problema de QUIÉN ERES, no de QUÉ
// ESCANEASTE. Lo custodia `test/core/firebase_error_mapper_test.dart`.
//
// ── DISCIPLINA DEL MÓDULO ──────────────────────────────────────────────────
// Lógica PURA: NO importa pantallas, providers, ni `dart:io`. Mismo papel que
// `functions/src/auth-matrix.js` en el backend — la decisión se aísla para
// poder probar la combinatoria entera sin montar nada.
//
// ── POR QUÉ NO SE IMPORTA `dart:io` ────────────────────────────────────────
// `SocketException` vive en `dart:io`, que NO existe en Flutter Web, y esta
// app se compila también a web. Importarlo aquí rompería el build web. Los
// fallos de red del lado `io` se reconocen por el PREFIJO de su `toString()`,
// que es un literal del propio `toString()` de esas clases y por tanto
// sobrevive a la minificación de dart2js (a diferencia de
// `runtimeType.toString()`, que sí se minifica en release).
import 'dart:async';

import 'package:firebase_core/firebase_core.dart';

/// ¿Se compiló apuntando a los emuladores locales?
///
/// `const bool.fromEnvironment` es una constante de TIEMPO DE COMPILACIÓN: en
/// un build de producción vale `false` y el compilador PODA la rama que añade
/// [pistaEmuladores], así que ese texto ni siquiera existe en el binario que
/// llega al usuario final (mitigación T-11-23-03).
///
/// Mismo define que usa `core/firebase_bootstrap.dart` para cablear los
/// emuladores: si allí se conecta a `127.0.0.1`, aquí se sabe.
const bool usandoEmuladores =
    bool.fromEnvironment('USE_EMULATORS', defaultValue: false);

/// Pista de desarrollo que se añade a los fallos de red cuando el build apunta
/// a los emuladores. Es literalmente el segundo tropiezo del incidente real:
/// un `unavailable` con este define activo casi siempre significa que los
/// emuladores están apagados, no que no haya internet.
const String pistaEmuladores = ' ¿Están corriendo los emuladores?';

/// Causa de dominio de un fallo, ya separada de la excepción que la produjo.
///
/// Son las CINCO que el usuario enumeró tras el incidente, más el cajón de
/// sastre. El cajón es explícito a propósito: preferimos admitir que no
/// sabemos qué pasó antes que inventarle una causa al usuario.
enum CausaFallo {
  /// El texto escaneado no tiene forma de código de mesa GRI.
  formatoInvalido,

  /// El código está bien formado pero no corresponde a ninguna mesa.
  noEncontrado,

  /// La mesa existe pero su estado no admite la operación (ocupada, limpieza).
  noDisponible,

  /// Las reglas de seguridad denegaron la operación a ESTA cuenta.
  permisoDenegado,

  /// No se pudo hablar con el backend (red caída, emuladores apagados,
  /// timeout).
  sinConexion,

  /// No lo sabemos. NUNCA se redacta como si lo supiéramos.
  desconocido,
}

/// Operación durante la que ocurrió el fallo. Permite afinar la REDACCIÓN sin
/// duplicar la CLASIFICACIÓN: la causa es la misma, lo que cambia es qué le
/// decimos a quien está delante de la pantalla.
enum Contexto {
  /// Abrir la mesa escaneando (o escribiendo) su código QR.
  abrirMesa,

  /// Enviar el pedido del carrito.
  crearPedido,

  /// Pedir la cuenta al mesero.
  solicitarCuenta,

  /// Calificar un pedido ya servido.
  calificar,

  /// Crear una reserva (asignación automática de mesa). AÑADIDO EN 11-29: el
  /// `catch` de `ReservaController.create` aplastaba capacidad, slot tomado y
  /// estado de mesa en «Ese horario acaba de ser reservado, elige otro»,
  /// que además era FALSO para dos de las tres.
  crearReserva,

  /// Cancelar una reserva propia (11-29).
  cancelarReserva,

  // ── CONTEXTOS DE LECTURA (11-33) ─────────────────────────────────────────
  // Los seis de arriba son MUTACIONES: alguien pulsó un botón y la operación
  // falló. Estos cuatro son LISTENERS: nadie pulsó nada, la pantalla
  // simplemente no puede mostrar lo que fue a buscar. La causa se clasifica
  // igual —es el mismo backend y los mismos códigos—, pero la redacción tiene
  // que hablar de VER, no de hacer. Sin ellos, la rama `error:` de un
  // `AsyncValue` no tenía ningún texto honesto que usar y se quedaba con un
  // «Error al cargar X» que no dice ni la causa ni qué hacer.

  /// Escuchar los pedidos de la sesión de mesa (pantalla «Mis pedidos»).
  verPedidos,

  /// Cargar la carta de un restaurante (menú de mesa y detalle).
  verMenu,

  /// Listar las reservas propias.
  verReservas,

  /// Listar los restaurantes disponibles.
  verRestaurantes,
}

/// Clasifica un fallo crudo en su [CausaFallo].
///
/// El mapeo por `code` de [FirebaseException] es el corazón del arreglo. Los
/// códigos son los de gRPC que usa Firestore
/// (https://firebase.google.com/docs/reference/js/firestore_.md#firestoreerrorcode):
///
/// * `permission-denied` — las rules dijeron que no. Es la denegación de
///   `isCliente()` del incidente real.
/// * `unauthenticated` — no hay credencial válida. Se agrupa con la anterior
///   porque para el usuario el problema es el MISMO: su cuenta. Nunca es el
///   código escaneado.
/// * `unavailable` — el backend no responde (o los emuladores están
///   apagados).
/// * `deadline-exceeded` — la operación agotó su plazo: red lenta o caída.
/// * `cancelled` — el canal se cortó a media operación.
/// * `internal` — el servidor devolvió un error propio; desde el cliente es
///   indistinguible de «el backend no está sano», y la acción del usuario es
///   la misma: reintentar.
/// * `not-found` — el documento no existe.
///
/// Todo lo demás cae en [CausaFallo.desconocido] DELIBERADAMENTE. Códigos como
/// `aborted` (contención de la transacción) o `failed-precondition` (índice
/// compuesto ausente) no son fallos de red ni de permisos, y meterlos en un
/// saco concreto reproduciría el bug que este archivo repara, solo que con
/// otro texto.
CausaFallo clasificarFallo(Object error) {
  if (error is FirebaseException) {
    switch (error.code) {
      case 'permission-denied':
      case 'unauthenticated':
        return CausaFallo.permisoDenegado;
      case 'unavailable':
      case 'deadline-exceeded':
      case 'cancelled':
      case 'internal':
        return CausaFallo.sinConexion;
      case 'not-found':
        return CausaFallo.noEncontrado;
      default:
        return CausaFallo.desconocido;
    }
  }
  if (error is TimeoutException) return CausaFallo.sinConexion;
  if (_esFalloDeRedDeIo(error)) return CausaFallo.sinConexion;
  return CausaFallo.desconocido;
}

/// Reconoce las excepciones de red de `dart:io` SIN importar `dart:io`
/// (ver cabecera: rompería el build web).
///
/// Se compara contra el prefijo de `toString()` porque ese texto es un literal
/// dentro del `toString()` de cada clase y sobrevive a la minificación; el
/// nombre de `runtimeType` no.
bool _esFalloDeRedDeIo(Object error) {
  const prefijos = <String>[
    'SocketException', // no hay ruta al host / conexión rechazada
    'HttpException', // respuesta HTTP malformada o cortada
    'HandshakeException', // TLS no negoció
    'ClientException', // package:http, si algún día entra por aquí
  ];
  final texto = error.toString();
  for (final prefijo in prefijos) {
    if (texto.startsWith(prefijo)) return true;
  }
  return false;
}

/// Texto que se le muestra al usuario para una [causa] ocurrida en un
/// [contexto].
///
/// Los textos de [Contexto.abrirMesa] son los que el usuario acordó tras el
/// incidente. Tres invariantes, todas con test propio:
///
/// 1. [CausaFallo.permisoDenegado] nunca menciona el código, el QR ni
///    «verifica»: señala la CUENTA.
/// 2. [CausaFallo.desconocido] no afirma ninguna causa concreta — ni siquiera
///    la red.
/// 3. El texto describe la CONDICIÓN de la cuenta, jamás la regla concreta que
///    denegó, el rol que hace falta ni la forma de los datos: útil sin ser un
///    oráculo para quien sondee (mitigación T-11-23-01).
String mensajeDe(CausaFallo causa, {required Contexto contexto}) {
  switch (causa) {
    case CausaFallo.formatoInvalido:
      switch (contexto) {
        case Contexto.abrirMesa:
          return 'Ese código no parece el de una mesa GRI. Revisa que estés '
              'escaneando el QR de la mesa.';
        case Contexto.crearPedido:
          return 'Los datos del pedido no tienen el formato esperado. Vuelve a '
              'armar tu pedido.';
        case Contexto.solicitarCuenta:
          return 'Los datos de la mesa no tienen el formato esperado. Vuelve a '
              'escanear el QR de la mesa.';
        case Contexto.calificar:
          return 'Los datos de la calificación no tienen el formato esperado.';
        case Contexto.crearReserva:
          return 'Los datos de la reserva no tienen el formato esperado. '
              'Vuelve a elegir fecha, hora y número de personas.';
        case Contexto.cancelarReserva:
          return 'Los datos de esa reserva no tienen el formato esperado.';
        case Contexto.verPedidos:
          return 'Los datos de tus pedidos no tienen el formato esperado. '
              'Vuelve a escanear el QR de la mesa.';
        case Contexto.verMenu:
          return 'Los datos del menú no tienen el formato esperado.';
        case Contexto.verReservas:
          return 'Los datos de tus reservas no tienen el formato esperado.';
        case Contexto.verRestaurantes:
          return 'Los datos de los restaurantes no tienen el formato '
              'esperado.';
      }

    case CausaFallo.noEncontrado:
      switch (contexto) {
        case Contexto.abrirMesa:
          return 'Esa mesa no existe. Puede que el QR sea de otro restaurante '
              'o que la mesa se haya eliminado.';
        case Contexto.crearPedido:
          return 'Tu sesión en la mesa ya no existe. Vuelve a escanear el QR '
              'de la mesa.';
        case Contexto.solicitarCuenta:
          return 'Tu sesión en la mesa ya no existe. Vuelve a escanear el QR '
              'de la mesa.';
        case Contexto.calificar:
          return 'Ese pedido ya no existe.';
        case Contexto.crearReserva:
          return 'Ese restaurante ya no admite reservas. Puede que lo hayan '
              'dado de baja.';
        case Contexto.cancelarReserva:
          return 'Esa reserva ya no existe.';
        case Contexto.verPedidos:
          return 'Tu sesión en la mesa ya no existe. Vuelve a escanear el QR '
              'de la mesa.';
        case Contexto.verMenu:
          return 'Ese restaurante ya no está publicado. Puede que lo hayan '
              'dado de baja.';
        case Contexto.verReservas:
          return 'No encontramos tus reservas.';
        case Contexto.verRestaurantes:
          return 'No encontramos ningún restaurante publicado.';
      }

    case CausaFallo.noDisponible:
      switch (contexto) {
        case Contexto.abrirMesa:
          // TEXTO CONGELADO: es el mensaje que ya era correcto antes del plan
          // y que `scan_test.dart` afirma literal. No tocar sin actualizar los
          // dos tests que lo fijan.
          return 'La mesa no está disponible en este momento';
        case Contexto.crearPedido:
          return 'La mesa no está disponible para pedir en este momento.';
        case Contexto.solicitarCuenta:
          return 'La mesa no está disponible para pedir la cuenta en este '
              'momento.';
        case Contexto.calificar:
          return 'Ese pedido todavía no se puede calificar.';
        case Contexto.crearReserva:
          // La mesa se movió MIENTRAS reservábamos (otro staff la ocupó entre
          // la lectura y la escritura). No es «el horario está tomado».
          return 'La mesa cambió de estado mientras hacíamos la reserva. '
              'Vuelve a intentarlo.';
        case Contexto.cancelarReserva:
          return 'Esa reserva ya estaba cancelada.';
        case Contexto.verPedidos:
          return 'Esta mesa ya no está activa. Vuelve a escanear el QR para '
              'abrirla de nuevo.';
        case Contexto.verMenu:
          return 'El menú de este restaurante no está disponible en este '
              'momento.';
        case Contexto.verReservas:
          return 'Tus reservas no están disponibles en este momento.';
        case Contexto.verRestaurantes:
          return 'La lista de restaurantes no está disponible en este '
              'momento.';
      }

    case CausaFallo.permisoDenegado:
      // NINGUNO de estos cuatro textos puede mencionar el código, el QR ni
      // «verifica». Es la invariante que da nombre a este plan.
      switch (contexto) {
        case Contexto.abrirMesa:
          return 'Tu cuenta no puede abrir mesas. Entra con una cuenta de '
              'cliente para pedir desde la mesa.';
        case Contexto.crearPedido:
          return 'Tu cuenta no puede enviar pedidos desde esta mesa. Entra con '
              'la cuenta de cliente con la que se abrió la mesa.';
        case Contexto.solicitarCuenta:
          return 'Tu cuenta no puede pedir la cuenta de esta mesa. Entra con '
              'la cuenta de cliente con la que se abrió la mesa.';
        case Contexto.calificar:
          return 'Tu cuenta no puede calificar este pedido. Solo lo califica '
              'la cuenta de cliente que lo pidió.';
        case Contexto.crearReserva:
          return 'Tu cuenta no puede reservar mesas. Entra con una cuenta de '
              'cliente para reservar.';
        case Contexto.cancelarReserva:
          return 'Tu cuenta no puede cancelar esta reserva. Entra con la '
              'cuenta de cliente con la que se hizo.';
        case Contexto.verPedidos:
          return 'Tu cuenta no puede ver los pedidos de esta mesa. Entra con '
              'la cuenta de cliente con la que se abrió la mesa.';
        case Contexto.verMenu:
          return 'Tu cuenta no puede ver esta carta. Entra con una cuenta de '
              'cliente para ver el menú.';
        case Contexto.verReservas:
          return 'Tu cuenta no puede ver estas reservas. Entra con la cuenta '
              'de cliente con la que las hiciste.';
        case Contexto.verRestaurantes:
          return 'Tu cuenta no puede ver los restaurantes. Vuelve a entrar '
              'con tu cuenta de cliente.';
      }

    case CausaFallo.sinConexion:
      final String base;
      switch (contexto) {
        case Contexto.abrirMesa:
          base = 'No pudimos conectar con el servidor. Revisa tu conexión e '
              'inténtalo de nuevo.';
        case Contexto.crearPedido:
          base = 'No pudimos conectar con el servidor para enviar tu pedido. '
              'Revisa tu conexión e inténtalo de nuevo.';
        case Contexto.solicitarCuenta:
          base = 'No pudimos conectar con el servidor para solicitar la '
              'cuenta. Revisa tu conexión e inténtalo de nuevo.';
        case Contexto.calificar:
          base = 'No pudimos conectar con el servidor para enviar tu '
              'calificación. Revisa tu conexión e inténtalo de nuevo.';
        case Contexto.crearReserva:
          base = 'No pudimos conectar con el servidor para crear tu reserva. '
              'Revisa tu conexión e inténtalo de nuevo.';
        case Contexto.cancelarReserva:
          base = 'No pudimos conectar con el servidor para cancelar tu '
              'reserva. Revisa tu conexión e inténtalo de nuevo.';
        case Contexto.verPedidos:
          base = 'No pudimos conectar con el servidor para ver tus pedidos. '
              'Revisa tu conexión e inténtalo de nuevo.';
        case Contexto.verMenu:
          base = 'No pudimos conectar con el servidor para cargar el menú. '
              'Revisa tu conexión e inténtalo de nuevo.';
        case Contexto.verReservas:
          base = 'No pudimos conectar con el servidor para cargar tus '
              'reservas. Revisa tu conexión e inténtalo de nuevo.';
        case Contexto.verRestaurantes:
          base = 'No pudimos conectar con el servidor para cargar los '
              'restaurantes. Revisa tu conexión e inténtalo de nuevo.';
      }
      // Rama podada en producción: `usandoEmuladores` es una constante de
      // compilación (ver su doc).
      return usandoEmuladores ? '$base$pistaEmuladores' : base;

    case CausaFallo.desconocido:
      // No sabemos qué pasó, así que NO lo afirmamos. Ni «verifica el código»
      // (culparía al usuario) ni «error de conexión» (culparía a la red).
      switch (contexto) {
        case Contexto.abrirMesa:
          return 'No pudimos abrir la mesa. Vuelve a intentarlo; si sigue '
              'igual, avisa al mesero.';
        case Contexto.crearPedido:
          return 'No pudimos enviar tu pedido. Vuelve a intentarlo; si sigue '
              'igual, avisa al mesero.';
        case Contexto.solicitarCuenta:
          return 'No pudimos solicitar la cuenta. Vuelve a intentarlo; si '
              'sigue igual, avisa al mesero.';
        case Contexto.calificar:
          return 'No pudimos enviar tu calificación. Vuelve a intentarlo más '
              'tarde.';
        case Contexto.crearReserva:
          return 'No pudimos crear la reserva. Vuelve a intentarlo; si sigue '
              'igual, llama al restaurante.';
        case Contexto.cancelarReserva:
          return 'No pudimos cancelar la reserva. Vuelve a intentarlo; si '
              'sigue igual, llama al restaurante.';
        // Los cuatro de lectura NO nombran red, cuenta ni permiso: si
        // supiéramos cuál de las tres es, no estaríamos en `desconocido`.
        // Aquí caen, entre otros, `failed-precondition` (índice compuesto
        // ausente) y `aborted`, por la decisión explícita de 11-23.
        case Contexto.verPedidos:
          return 'No pudimos cargar tus pedidos. Vuelve a intentarlo; si '
              'sigue igual, avisa al mesero.';
        case Contexto.verMenu:
          return 'No pudimos cargar el menú. Vuelve a intentarlo; si sigue '
              'igual, avisa al mesero.';
        case Contexto.verReservas:
          return 'No pudimos cargar tus reservas. Vuelve a intentarlo; si '
              'sigue igual, llama al restaurante.';
        case Contexto.verRestaurantes:
          return 'No pudimos cargar los restaurantes. Vuelve a intentarlo '
              'más tarde.';
      }
  }
}

/// Atajo de los dos pasos que casi siempre van juntos: clasificar el fallo y
/// redactar su mensaje.
///
/// Existe para que ningún `catch` tenga excusa para quedarse con el texto a
/// ciegas: es UNA línea.
String mensajeDeFallo(Object error, {required Contexto contexto}) =>
    mensajeDe(clasificarFallo(error), contexto: contexto);
