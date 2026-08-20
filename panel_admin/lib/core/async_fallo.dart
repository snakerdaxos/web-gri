// core/async_fallo.dart — que un stream ROTO no se pinte como un stream que
// CARGA (11-33). COPIA de app_cliente/lib/core/async_fallo.dart: las dos apps
// no comparten paquete (convención del repo desde la fase 10) y la causa raíz
// —el reintento automático de Riverpod 3— es idéntica en las dos. Las dos
// suites prueban el MISMO vector para que las copias no deriven en silencio.
//
// ── LA CAUSA RAÍZ, QUE NO ESTABA EN NUESTRO CÓDIGO ─────────────────────────
// El usuario abrió «ver pedido» y la pantalla se quedó girando. La rama
// `error:` existía desde 11-09 y el clasificador honesto desde 11-23; aun así
// no se veía ninguna de las dos cosas. El motivo está en Riverpod 3:
//
//   ProviderContainer.defaultRetry(retryCount, error) — riverpod 3.4.2
//     if (retryCount >= 10) return null;
//     if (error is ProviderException || error is Error) return null;
//     delay = 200ms * 2^retryCount, tope 6400ms
//
// Cuando un provider falla con algo que NO es un `Error` de Dart —y una
// `FirebaseException` es una `Exception`, no un `Error`— Riverpod **reintenta
// diez veces** y, mientras tanto, el estado NO es `AsyncError`: es
//
//   AsyncLoading(error: …, retrying: true)      (element.dart:790)
//
// `AsyncValue.when` despacha por `isLoading` ANTES que por el error, así que
// pinta la rama `loading:`. Sumando la escalera 200+400+800+1600+3200+6400×5
// son **≈38 segundos de spinner** antes de que aparezca el primer mensaje. Y
// para un `permission-denied` esos 38 segundos son puro humo: la regla va a
// denegar las diez veces, y cada reintento vuelve a suscribir el listener
// contra Firestore.
//
// Un spinner que no termina no le dice NADA al usuario y no le da NADA que
// hacer. Es el mismo defecto de familia que el escáner culpando al QR
// (11-23), el panel diciendo «el restaurante no existe» (11-24) y el
// asistente de reservas culpando al horario (11-29): la pantalla afirma algo
// que no es lo que pasó. Aquí ni siquiera afirma: calla.
//
// ── LAS DOS PIEZAS ─────────────────────────────────────────────────────────
// 1. [reintentoGri] — política de reintento cableada en el `ProviderScope`
//    raíz. Solo se reintenta lo que puede arreglarse SOLO con esperar.
// 2. [AsyncFalloX.cuandoConFallo] — sustituto de `when` que pinta el error en
//    cuanto lo hay, aunque Riverpod siga reintentando por debajo.
//
// Las dos son necesarias: la primera evita reintentar en balde, la segunda
// evita el silencio DURANTE el reintento legítimo.
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'firebase_error_mapper.dart';

/// Cuántas veces se reintenta un fallo que puede mejorar solo.
///
/// Tres, no diez. Con la escalera de abajo son 1,4 s en total: suficiente para
/// absorber un bache de red al cambiar de wifi a datos, y lo bastante corto
/// para que nadie interprete la espera como un cuelgue.
const int maxReintentos = 3;

/// Política de reintento de TODA la app (se cablea en el `ProviderScope` raíz
/// de `main.dart`).
///
/// La decisión de reintentar se toma sobre la [CausaFallo] del clasificador de
/// 11-23, no sobre el código crudo: es el mismo vocabulario que usan los
/// mensajes, así que no pueden divergir.
///
/// **Solo [CausaFallo.sinConexion] se reintenta.** Las demás son
/// deterministas y volver a intentarlas no cambia el resultado:
///
/// * [CausaFallo.permisoDenegado] — las rules van a denegar igual. El usuario
///   tiene que entrar con otra cuenta; nadie lo va a arreglar esperando.
/// * [CausaFallo.noEncontrado] — el documento no está. Seguirá sin estar.
/// * [CausaFallo.formatoInvalido] / [CausaFallo.noDisponible] — son de
///   dominio, no de transporte.
/// * [CausaFallo.desconocido] — aquí cae `failed-precondition`, que es el
///   índice compuesto ausente (tres incidentes de este proyecto). Un índice no
///   aparece por reintentar: hay que desplegarlo. Reintentar solo retrasaría
///   38 segundos el diagnóstico.
///
/// Devolver `null` significa «no reintentes»: Riverpod pasa el provider a
/// `AsyncError` inmediatamente y la pantalla puede hablar.
Duration? reintentoGri(int retryCount, Object error) {
  // Un `Error` de Dart es un bug de programación, jamás algo transitorio.
  // Riverpod lo excluye en su default y aquí se mantiene explícito.
  if (error is Error) return null;
  if (clasificarFallo(error) != CausaFallo.sinConexion) return null;
  if (retryCount >= maxReintentos) return null;
  // 200 ms, 400 ms, 800 ms.
  return Duration(milliseconds: 200 * (1 << retryCount));
}

extension AsyncFalloX<T> on AsyncValue<T> {
  /// `when` que NO se traga el error.
  ///
  /// `AsyncValue.when` mira `isLoading` primero, y un provider en pleno
  /// reintento es `AsyncLoading` **con el error dentro**. Este método invierte
  /// esa prioridad: si hay un error adjunto, se pinta el error.
  ///
  /// Consecuencia buscada: durante el reintento de un fallo de red el usuario
  /// lee «No pudimos conectar con el servidor…» en vez de mirar un spinner.
  /// Si el reintento acaba funcionando, el `data` sustituye al mensaje solo.
  R cuandoConFallo<R>({
    required R Function() cargando,
    required R Function(Object error) fallo,
    required R Function(T valor) datos,
  }) {
    final e = error;
    if (e != null) return fallo(e);
    if (isLoading) return cargando();
    return datos(requireValue);
  }
}
