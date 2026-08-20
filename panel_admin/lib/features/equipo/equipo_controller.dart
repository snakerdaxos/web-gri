import 'package:cloud_functions/cloud_functions.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/firebase_providers.dart';

part 'equipo_controller.g.dart';

/// Lo que devuelve la callable `crearUsuarioStaff` (11-08).
/// `creado == false` significa que el correo ya existía y el alta fue una
/// REPARACIÓN idempotente, no un usuario nuevo — la pantalla lo dice.
typedef ResultadoAlta = ({
  String uid,
  bool creado,
  String rol,
  String restauranteId,
});

/// Alta de una persona del equipo. Es una COSTURA inyectable: el diálogo la
/// lee del provider, así que los widget tests la sustituyen por un doble y no
/// necesitan Firebase (misma costura que `bootstrapAccionProvider`, 11-07).
typedef CrearStaffAccion = Future<ResultadoAlta> Function({
  required String nombre,
  required String email,
  required String password,
  required String rol,
  String? restauranteId,
});

/// Costura de la callable sola. Existe porque `FirebaseFunctions` no se puede
/// instanciar en `flutter test` (exige una app Firebase inicializada): sin
/// ella, la acción REAL sería inejecutable en tests y la forma del payload
/// —incluida la ausencia deliberada de `restauranteId`— quedaría afirmada en
/// vez de verificada.
typedef CrearStaffCallable = Future<Map<String, dynamic>> Function(
  Map<String, dynamic> payload,
);

/// Error de alta con el mensaje YA redactado para el operador
/// (patrón `RestauranteException` / `BootstrapException`).
class EquipoException implements Exception {
  const EquipoException(this.message);

  final String message;

  @override
  String toString() => message;
}

const _msgGenerico = 'No se pudo crear el usuario. Intenta de nuevo.';

/// Texto ÚNICO de la indisponibilidad de la gestión de personal (11-26).
///
/// Lo usan LAS DOS traducciones de error Y el aviso permanente de
/// `equipo_screen.dart`. Es una sola constante a propósito: si el aviso previo
/// y el mensaje del fallo se escribieran por separado acabarían diciendo cosas
/// distintas, y el operador no sabría a cuál creer.
///
/// Criterio de redacción heredado del plan 11-23 (mensajes del escaneo):
/// **verdad + causa + siguiente paso**. No culpa al operador, no le pide
/// reintentar algo que hoy no puede funcionar, y no suena a avería — porque no
/// lo es: es una decisión de producto registrada en `11-CONTEXT.md`
/// («Blaze — REVERTIDO»).
const mensajeGestionPersonalNoDisponible =
    'El alta y la baja de personal todavía no se hacen desde el panel: las '
    'funciones que las ejecutan no están desplegadas en este proyecto. '
    'Mientras tanto se hacen por script, desde el equipo del propietario — '
    'ver docs/GESTION-PERSONAL.md.';

/// ¿El fallo es «la callable no está desplegada», o algo que la función decidió?
///
/// **Por qué existe.** El usuario decidió no activar Blaze, así que
/// `crearUsuarioStaff` y `cambiarEstadoStaff` viven en `functions/src/` con sus
/// ~200 pruebas pero **sin desplegar**. `httpsCallable(...).call()` contra un
/// proyecto que no tiene esa función devuelve `not-found`; cuando falla la
/// resolución antes del 404 limpio, `unavailable` o `internal`.
///
/// **Cómo se distingue del `not-found` de DOMINIO.** Las dos callables lanzan
/// su `not-found` SIEMPRE acompañado de un mensaje redactado —
/// `El restaurante ${rid} no existe.` (`crear-usuario-staff.js:152`) y
/// `Ese usuario ya no existe.` (`cambiar-estado-staff.js:118`)—, así que un
/// `not-found` **sin** mensaje del servidor es el caso de «no desplegada». Se
/// reconoce además el marcador crudo del transporte (`NOT FOUND`, `404`) por si
/// la plataforma rellena `message` con él en vez de dejarlo vacío: sin esa
/// comprobación la regla volvería a soltar «El restaurante no existe», que es
/// justo la mentira que este plan cierra.
///
/// ⚠️ **EL DÍA DEL DESPLIEGUE.** `not-found` deja de llegar sin mensaje por sí
/// solo y esta rama se apaga sin tocar nada. `unavailable` e `internal`, en
/// cambio, pasarían a significar «la función existe y se cayó»: hay que
/// sacarlos de este grupo. Anotado en `docs/ESTADO-DESPLIEGUE.md` §5.
bool _callableNoDesplegada(String code, String? mensajeServidor) {
  if (code == 'unavailable' || code == 'internal') return true;
  if (code != 'not-found') return false;
  final normalizado =
      (mensajeServidor ?? '').toLowerCase().replaceAll(RegExp('[^a-z0-9]'), '');
  return normalizado.isEmpty ||
      normalizado == 'notfound' ||
      normalizado == '404';
}

/// Traducción de los códigos de `crearUsuarioStaff` a texto para el operador.
///
/// REGLA: nunca se muestra el texto crudo del servidor (T-11-10-04) SALVO en
/// `invalid-argument`, que es el único código que la función reserva para
/// fallos de FORMA del payload y cuyos mensajes están redactados para leerse
/// ("La contraseña debe tener al menos 8 caracteres.").
///
/// ⚠️ `already-exists` cubre DOS ramas distintas del anti-secuestro de la
/// callable —correo de otro tenant y correo de un cliente— así que el texto
/// no puede afirmar cuál de las dos es sin mentir en la otra. Ver el
/// comentario de `equipo_controller` en el SUMMARY de 11-10.
String mensajeAltaStaff(String code, [String? mensajeServidor]) {
  // Va ANTES del switch: `not-found` significa dos cosas distintas y este es el
  // único sitio que las separa (ver [_callableNoDesplegada]).
  if (_callableNoDesplegada(code, mensajeServidor)) {
    return mensajeGestionPersonalNoDisponible;
  }
  switch (code) {
    case 'permission-denied':
      return 'No tienes permiso para crear ese usuario.';
    case 'invalid-argument':
      final m = mensajeServidor?.trim() ?? '';
      return m.isEmpty ? _msgGenerico : m;
    case 'already-exists':
      return 'Ese correo ya está en uso por otra cuenta (de otro restaurante '
          'o de un cliente). Usa un correo distinto para su cuenta de trabajo.';
    case 'not-found':
      return 'El restaurante no existe.';
    case 'unauthenticated':
      return 'Tu sesión expiró. Vuelve a iniciar sesión.';
    case 'failed-precondition':
      // Reintentar NO puede arreglarlo: la cuenta del llamador está mal
      // aprovisionada (claim `role` sin `rid`). Decirle "intenta de nuevo"
      // lo mandaría a un bucle.
      return 'Tu cuenta no tiene restaurante asignado. Pide al super admin '
          'que la revise.';
    default:
      return _msgGenerico;
  }
}

/// Invocación real de `crearUsuarioStaff`. La región la fija
/// `firebaseFunctionsProvider` (`us-central1`, declarada en los dos lados).
@Riverpod(keepAlive: true)
CrearStaffCallable crearStaffCallable(Ref ref) {
  return (payload) async {
    final res = await ref
        .read(firebaseFunctionsProvider)
        .httpsCallable('crearUsuarioStaff')
        .call<Object?>(payload);
    return _comoMapa(res.data);
  };
}

/// Implementación real de [CrearStaffAccion].
///
/// `keepAlive` a propósito: el diálogo la obtiene con `ref.read` en el submit,
/// sin observarla; con autoDispose podría descartarse con la llamada en vuelo.
@Riverpod(keepAlive: true)
CrearStaffAccion crearStaffAccion(Ref ref) {
  return ({
    required String nombre,
    required String email,
    required String password,
    required String rol,
    String? restauranteId,
  }) async {
    final payload = <String, dynamic>{
      'nombre': nombre.trim(),
      // La función normaliza igual; hacerlo aquí evita que dos altas del mismo
      // correo con distinta caja parezcan personas distintas en la UI.
      'email': email.trim().toLowerCase(),
      'password': password,
      'rol': rol,
      // Un `admin_restaurante` NO manda `restauranteId`: la callable DERIVA el
      // rid de su claim (prohibición 2 de la matriz). El campo solo viaja
      // cuando lo elige un `super_admin` en el selector del formulario.
      // (`?valor` omite la clave entera cuando es null — null-aware element.)
      'restauranteId': ?restauranteId,
    };

    final Map<String, dynamic> datos;
    try {
      datos = await ref.read(crearStaffCallableProvider)(payload);
    } on FirebaseFunctionsException catch (e) {
      throw EquipoException(mensajeAltaStaff(e.code, e.message));
    } catch (_) {
      throw const EquipoException(_msgGenerico);
    }

    return (
      uid: datos['uid'] as String? ?? '',
      creado: datos['creado'] as bool? ?? true,
      rol: datos['rol'] as String? ?? rol,
      restauranteId: datos['restauranteId'] as String? ?? (restauranteId ?? ''),
    );
  };
}

// ===========================================================================
// BAJA REVERSIBLE DE PERSONAL (11-24)
// ===========================================================================

/// Lo que devuelve la callable `cambiarEstadoStaff` (11-24).
typedef ResultadoCambioEstado = ({
  String uid,
  bool activo,
  String rol,
  String restauranteId,
});

/// Desactivar / reactivar a alguien del equipo. Misma COSTURA inyectable que
/// el alta: la pantalla la lee del provider y los widget tests la sustituyen.
typedef CambiarEstadoAccion = Future<ResultadoCambioEstado> Function({
  required String uid,
  required bool activo,
});

/// Costura de la callable sola (ver [CrearStaffCallable] para el porqué).
typedef CambiarEstadoCallable = Future<Map<String, dynamic>> Function(
  Map<String, dynamic> payload,
);

const _msgGenericoEstado =
    'No se pudo cambiar el estado del usuario. Intenta de nuevo.';

/// Traducción de los códigos de `cambiarEstadoStaff` a texto para el operador.
///
/// ⚠️ `permission-denied` cubre CINCO controles distintos del servidor (rol del
/// llamador, objetivo `super_admin`, auto-baja, cruce de restaurante y objetivo
/// que no es personal). El texto no puede afirmar cuál fue sin mentir en los
/// otros cuatro, así que dice lo único cierto para todos. La UI ya oculta las
/// acciones que sabe que el servidor va a rechazar; llegar aquí significa que
/// algo no cuadra y el operador tiene que enterarse.
///
/// `failed-precondition` SÍ muestra el mensaje del servidor: es el único código
/// que la función reserva para un estado que el operador puede arreglar ("falta
/// el rol en su ficha; vuelve a darlo de alta con el mismo correo"), y
/// resumirlo lo dejaría sin saber qué hacer.
String mensajeCambioEstadoStaff(String code, [String? mensajeServidor]) {
  // Misma separación que en el alta, y por el mismo motivo: hoy el `not-found`
  // que se recibe de verdad NO es «ese usuario ya no existe».
  if (_callableNoDesplegada(code, mensajeServidor)) {
    return mensajeGestionPersonalNoDisponible;
  }
  switch (code) {
    case 'permission-denied':
      return 'No tienes permiso para cambiar el estado de ese usuario.';
    case 'not-found':
      return 'Ese usuario ya no existe.';
    case 'failed-precondition':
      final m = mensajeServidor?.trim() ?? '';
      return m.isEmpty ? _msgGenericoEstado : m;
    case 'unauthenticated':
      return 'Tu sesión expiró. Vuelve a iniciar sesión.';
    default:
      return _msgGenericoEstado;
  }
}

/// Invocación real de `cambiarEstadoStaff`.
@Riverpod(keepAlive: true)
CambiarEstadoCallable cambiarEstadoCallable(Ref ref) {
  return (payload) async {
    final res = await ref
        .read(firebaseFunctionsProvider)
        .httpsCallable('cambiarEstadoStaff')
        .call<Object?>(payload);
    return _comoMapa(res.data);
  };
}

/// Implementación real de [CambiarEstadoAccion].
///
/// El payload lleva SOLO `uid` y `activo`: ni rol ni restaurante. Los dos los
/// DERIVA el servidor del objetivo (de sus claims o, si ya está de baja, de su
/// doc espejo). Mandarlos desde aquí sería darle al cliente una palanca sobre
/// una decisión que no le corresponde, exactamente como el `restauranteId` del
/// alta.
@Riverpod(keepAlive: true)
CambiarEstadoAccion cambiarEstadoAccion(Ref ref) {
  return ({required String uid, required bool activo}) async {
    final Map<String, dynamic> datos;
    try {
      datos = await ref.read(cambiarEstadoCallableProvider)(
        <String, dynamic>{'uid': uid, 'activo': activo},
      );
    } on FirebaseFunctionsException catch (e) {
      throw EquipoException(mensajeCambioEstadoStaff(e.code, e.message));
    } catch (_) {
      throw const EquipoException(_msgGenericoEstado);
    }

    return (
      uid: datos['uid'] as String? ?? uid,
      activo: datos['activo'] as bool? ?? activo,
      rol: datos['rol'] as String? ?? '',
      restauranteId: datos['restauranteId'] as String? ?? '',
    );
  };
}

/// `httpsCallable().call()` devuelve `Map<Object?, Object?>` en algunas
/// plataformas y `Map<String, dynamic>` en otras: normalizar aquí evita un
/// `type cast` que solo reventaría en producción y no en los tests.
Map<String, dynamic> _comoMapa(Object? data) {
  if (data is Map) {
    return <String, dynamic>{
      for (final e in data.entries) '${e.key}': e.value,
    };
  }
  return const <String, dynamic>{};
}
