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
