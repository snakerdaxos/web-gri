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
