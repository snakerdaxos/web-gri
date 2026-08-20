// core/firebase_error_mapper.dart — el MISMO clasificador de fallos que
// app_cliente, del lado del panel (11-33).
//
// ── POR QUÉ ESTÁ DUPLICADO ─────────────────────────────────────────────────
// Las dos apps no comparten paquete. Es la convención del repo desde la fase
// 10: los modelos y las máquinas de estado ya están duplicados, y 11-32 hizo
// lo mismo con la regla de la cuenta (`cuenta.dart` / `cuenta_mesa.dart`).
// Para que las dos copias no deriven en silencio, **las dos suites prueban el
// MISMO vector de códigos**: si una copia reclasifica un código, su test cae.
// Ver `test/core/firebase_error_mapper_test.dart` en las dos apps.
//
// ── QUÉ SE COPIA Y QUÉ NO ──────────────────────────────────────────────────
// Se copian LAS CAUSAS y los CRITERIOS, que son la parte que no puede
// divergir. NO se copian los textos: el que lee el panel es un mesero, un
// cocinero o un administrador, no un comensal, y «entra con una cuenta de
// cliente» no significaría nada para él.
//
// LOS CRITERIOS, literales de 11-23:
//   1. Un `permission-denied` NUNCA produce un mensaje que culpe a la red ni
//      al dato que se buscaba. Es un problema de QUIÉN ERES.
//   2. `desconocido` no afirma ninguna causa concreta. Preferimos admitir que
//      no sabemos qué pasó antes que inventársela.
//   3. El mensaje describe la CONDICIÓN de la cuenta, jamás la regla concreta
//      que denegó ni el rol que haría falta (mitigación T-11-23-01).
//
// ── POR QUÉ EL TEXTO ES UNA PLANTILLA Y NO 72 CADENAS ──────────────────────
// En el cliente hay 10 contextos y cada uno tiene su redacción a mano, porque
// son pantallas de producto con matices distintos. En el panel hay una docena
// de listados que hacen todos LO MISMO: traer una colección y pintarla. La
// causa aporta la forma de la frase y el contexto solo aporta el sustantivo.
// Escribir 72 cadenas a mano habría multiplicado por doce las ocasiones de
// que una se saltara el criterio 1 sin que nadie lo notara; con la plantilla,
// el criterio se comprueba UNA vez por causa y vale para todas.
import 'dart:async';

import 'package:firebase_core/firebase_core.dart';

/// Causa de dominio de un fallo. Las MISMAS seis de 11-23, en el mismo orden.
enum CausaFallo {
  /// El dato no tiene la forma esperada.
  formatoInvalido,

  /// El documento o la colección no existen.
  noEncontrado,

  /// Existe, pero su estado no admite la operación.
  noDisponible,

  /// Las reglas de seguridad denegaron la operación a ESTA cuenta.
  permisoDenegado,

  /// No se pudo hablar con el backend.
  sinConexion,

  /// No lo sabemos. NUNCA se redacta como si lo supiéramos.
  desconocido,
}

/// Qué estaba cargando la pantalla cuando falló.
///
/// El valor de cada entrada es el sustantivo que entra en la frase, así que
/// tiene que encajar detrás de «no pudimos cargar …» y de «tu cuenta no puede
/// ver …». Se revisan de un vistazo, que es justamente lo que se pierde
/// cuando los textos están repartidos por doce pantallas.
enum Contexto {
  pedidosCocina('los pedidos de la cocina'),
  avisosCuenta('los avisos de cuenta'),
  cuentaMesa('la cuenta de la mesa'),
  mesas('las mesas'),
  menu('el menú'),
  reservas('las reservas'),
  clientes('los clientes'),
  historialCliente('el historial de este cliente'),
  equipo('el equipo'),
  reportes('los reportes'),
  estadisticas('las estadísticas'),
  restaurantes('los restaurantes'),
  sesion('los datos de tu sesión');

  const Contexto(this.loQueSeCarga);

  /// Sustantivo que entra en la plantilla del mensaje.
  final String loQueSeCarga;
}

/// Clasifica un fallo crudo en su [CausaFallo].
///
/// Tabla IDÉNTICA a la de `app_cliente/lib/core/firebase_error_mapper.dart`.
/// `aborted` y `failed-precondition` caen a [CausaFallo.desconocido] A
/// PROPÓSITO (decisión de 11-23): no son de red ni de permisos, y meterlos en
/// un saco concreto reproduciría el bug que este archivo repara con otro
/// texto.
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

/// Reconoce las excepciones de red de `dart:io` SIN importar `dart:io`: el
/// panel se compila a WEB, donde ese import no existe. Se compara contra el
/// prefijo de `toString()`, que es un literal de cada clase y sobrevive a la
/// minificación de dart2js (el nombre de `runtimeType` no).
bool _esFalloDeRedDeIo(Object error) {
  const prefijos = <String>[
    'SocketException',
    'HttpException',
    'HandshakeException',
    'ClientException',
  ];
  final texto = error.toString();
  for (final prefijo in prefijos) {
    if (texto.startsWith(prefijo)) return true;
  }
  return false;
}

/// Texto que lee el miembro del staff para una [causa] en un [contexto].
String mensajeDe(CausaFallo causa, {required Contexto contexto}) {
  final que = contexto.loQueSeCarga;
  switch (causa) {
    case CausaFallo.formatoInvalido:
      return 'Los datos de $que no tienen el formato esperado. Avisa a quien '
          'administre la plataforma.';

    case CausaFallo.noEncontrado:
      // NO dice «no existe» a secas: el incidente de 11-24 fue exactamente
      // eso — el panel afirmó «el restaurante no existe» cuando lo que
      // faltaba era una function sin desplegar.
      return 'No encontramos $que. Puede que se haya eliminado o que aún no '
          'esté configurado.';

    case CausaFallo.noDisponible:
      return 'No podemos mostrar $que en este momento. Vuelve a intentarlo en '
          'unos segundos.';

    case CausaFallo.permisoDenegado:
      // CRITERIO 1. Ni una palabra sobre la red ni sobre el dato: señala la
      // CUENTA. Y no nombra la regla ni el rol que haría falta (T-11-23-01):
      // decir «necesitas ser admin_restaurante» le da a quien sondee el mapa
      // de la autorización.
      return 'Tu cuenta no puede ver $que. Pide a un administrador que revise '
          'los permisos de tu usuario.';

    case CausaFallo.sinConexion:
      return 'No pudimos conectar con el servidor para cargar $que. Revisa tu '
          'conexión e inténtalo de nuevo.';

    case CausaFallo.desconocido:
      // CRITERIO 2. Ni «conexión» ni «cuenta» ni «permiso»: si supiéramos
      // cuál de las tres es, no estaríamos aquí. Aquí cae, entre otros,
      // `failed-precondition`, que es el índice compuesto ausente.
      return 'No pudimos cargar $que. Vuelve a intentarlo; si sigue igual, '
          'avisa a quien administre la plataforma.';
  }
}

/// Clasificar y redactar en una línea. Existe para que ninguna rama de error
/// tenga excusa para quedarse con el texto a ciegas.
String mensajeDeFallo(Object error, {required Contexto contexto}) =>
    mensajeDe(clasificarFallo(error), contexto: contexto);
