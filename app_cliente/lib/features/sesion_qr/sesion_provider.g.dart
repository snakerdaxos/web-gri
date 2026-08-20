// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'sesion_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Stream del doc `sesiones/{mesaId}` (banner vivo): refleja
/// `cuentaSolicitada`, cambios de estado del staff y el cierre de sesión
/// — detección de cierre → la UI trata estado != 'activa' como fin de la
/// sesión (mismo rol que el evento `sesion.cerrada` del WS de Phase 7).

@ProviderFor(sesion)
final sesionProvider = SesionFamily._();

/// Stream del doc `sesiones/{mesaId}` (banner vivo): refleja
/// `cuentaSolicitada`, cambios de estado del staff y el cierre de sesión
/// — detección de cierre → la UI trata estado != 'activa' como fin de la
/// sesión (mismo rol que el evento `sesion.cerrada` del WS de Phase 7).

final class SesionProvider
    extends
        $FunctionalProvider<
          AsyncValue<SesionMesa>,
          SesionMesa,
          Stream<SesionMesa>
        >
    with $FutureModifier<SesionMesa>, $StreamProvider<SesionMesa> {
  /// Stream del doc `sesiones/{mesaId}` (banner vivo): refleja
  /// `cuentaSolicitada`, cambios de estado del staff y el cierre de sesión
  /// — detección de cierre → la UI trata estado != 'activa' como fin de la
  /// sesión (mismo rol que el evento `sesion.cerrada` del WS de Phase 7).
  SesionProvider._({
    required SesionFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'sesionProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$sesionHash();

  @override
  String toString() {
    return r'sesionProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $StreamProviderElement<SesionMesa> $createElement($ProviderPointer pointer) =>
      $StreamProviderElement(pointer);

  @override
  Stream<SesionMesa> create(Ref ref) {
    final argument = this.argument as String;
    return sesion(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is SesionProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$sesionHash() => r'5b407ad9049d5270a586b03a28b62edfee22d3c0';

/// Stream del doc `sesiones/{mesaId}` (banner vivo): refleja
/// `cuentaSolicitada`, cambios de estado del staff y el cierre de sesión
/// — detección de cierre → la UI trata estado != 'activa' como fin de la
/// sesión (mismo rol que el evento `sesion.cerrada` del WS de Phase 7).

final class SesionFamily extends $Family
    with $FunctionalFamilyOverride<Stream<SesionMesa>, String> {
  SesionFamily._()
    : super(
        retry: null,
        name: r'sesionProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Stream del doc `sesiones/{mesaId}` (banner vivo): refleja
  /// `cuentaSolicitada`, cambios de estado del staff y el cierre de sesión
  /// — detección de cierre → la UI trata estado != 'activa' como fin de la
  /// sesión (mismo rol que el evento `sesion.cerrada` del WS de Phase 7).

  SesionProvider call(String mesaId) =>
      SesionProvider._(argument: mesaId, from: this);

  @override
  String toString() => r'sesionProvider';
}

/// Sesión más reciente del usuario autenticado (o null) — query realtime
/// `sesiones where usuarioId == uid`. NO filtra por estado: tras el cierre
/// la sigue emitiendo (estado 'cerrada') para que el cliente pueda calificar
/// sus pedidos servidos (locked: calificación tras cierre) y el banner se
/// despida al detectar el cierre (la UI discrimina por `estado`).
/// keepAlive: el banner de home / menú / pedidos la observan a través de
/// la navegación. Sin usuario → emite null (banner fuera).

@ProviderFor(sesionActual)
final sesionActualProvider = SesionActualProvider._();

/// Sesión más reciente del usuario autenticado (o null) — query realtime
/// `sesiones where usuarioId == uid`. NO filtra por estado: tras el cierre
/// la sigue emitiendo (estado 'cerrada') para que el cliente pueda calificar
/// sus pedidos servidos (locked: calificación tras cierre) y el banner se
/// despida al detectar el cierre (la UI discrimina por `estado`).
/// keepAlive: el banner de home / menú / pedidos la observan a través de
/// la navegación. Sin usuario → emite null (banner fuera).

final class SesionActualProvider
    extends
        $FunctionalProvider<
          AsyncValue<SesionMesa?>,
          SesionMesa?,
          Stream<SesionMesa?>
        >
    with $FutureModifier<SesionMesa?>, $StreamProvider<SesionMesa?> {
  /// Sesión más reciente del usuario autenticado (o null) — query realtime
  /// `sesiones where usuarioId == uid`. NO filtra por estado: tras el cierre
  /// la sigue emitiendo (estado 'cerrada') para que el cliente pueda calificar
  /// sus pedidos servidos (locked: calificación tras cierre) y el banner se
  /// despida al detectar el cierre (la UI discrimina por `estado`).
  /// keepAlive: el banner de home / menú / pedidos la observan a través de
  /// la navegación. Sin usuario → emite null (banner fuera).
  SesionActualProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'sesionActualProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$sesionActualHash();

  @$internal
  @override
  $StreamProviderElement<SesionMesa?> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<SesionMesa?> create(Ref ref) {
    return sesionActual(ref);
  }
}

String _$sesionActualHash() => r'7cb2b7446c6b0829613457891c63878da686fea5';

/// Mutaciones de la sesión: [abrir] por código QR (cámara o input manual).
///
/// TODO fallo sale como [SesionException] con un mensaje que dice la VERDAD
/// sobre su causa (11-23). Cinco causas, cinco mensajes:
/// formato del código, mesa inexistente, mesa no disponible, permiso denegado
/// y backend inalcanzable. Los tres primeros los produce el dominio; los dos
/// últimos salen de `clasificarFallo`/`mensajeDe`
/// (`core/firebase_error_mapper.dart`). Nunca un stack trace al usuario, y
/// nunca —esto es lo que arregla 11-23— un mensaje que culpe al código
/// cuando el problema es la cuenta o la red.

@ProviderFor(SesionController)
final sesionControllerProvider = SesionControllerProvider._();

/// Mutaciones de la sesión: [abrir] por código QR (cámara o input manual).
///
/// TODO fallo sale como [SesionException] con un mensaje que dice la VERDAD
/// sobre su causa (11-23). Cinco causas, cinco mensajes:
/// formato del código, mesa inexistente, mesa no disponible, permiso denegado
/// y backend inalcanzable. Los tres primeros los produce el dominio; los dos
/// últimos salen de `clasificarFallo`/`mensajeDe`
/// (`core/firebase_error_mapper.dart`). Nunca un stack trace al usuario, y
/// nunca —esto es lo que arregla 11-23— un mensaje que culpe al código
/// cuando el problema es la cuenta o la red.
final class SesionControllerProvider
    extends $AsyncNotifierProvider<SesionController, void> {
  /// Mutaciones de la sesión: [abrir] por código QR (cámara o input manual).
  ///
  /// TODO fallo sale como [SesionException] con un mensaje que dice la VERDAD
  /// sobre su causa (11-23). Cinco causas, cinco mensajes:
  /// formato del código, mesa inexistente, mesa no disponible, permiso denegado
  /// y backend inalcanzable. Los tres primeros los produce el dominio; los dos
  /// últimos salen de `clasificarFallo`/`mensajeDe`
  /// (`core/firebase_error_mapper.dart`). Nunca un stack trace al usuario, y
  /// nunca —esto es lo que arregla 11-23— un mensaje que culpe al código
  /// cuando el problema es la cuenta o la red.
  SesionControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'sesionControllerProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$sesionControllerHash();

  @$internal
  @override
  SesionController create() => SesionController();
}

String _$sesionControllerHash() => r'46c7293daf5d1a2648502630985f0feab40c014b';

/// Mutaciones de la sesión: [abrir] por código QR (cámara o input manual).
///
/// TODO fallo sale como [SesionException] con un mensaje que dice la VERDAD
/// sobre su causa (11-23). Cinco causas, cinco mensajes:
/// formato del código, mesa inexistente, mesa no disponible, permiso denegado
/// y backend inalcanzable. Los tres primeros los produce el dominio; los dos
/// últimos salen de `clasificarFallo`/`mensajeDe`
/// (`core/firebase_error_mapper.dart`). Nunca un stack trace al usuario, y
/// nunca —esto es lo que arregla 11-23— un mensaje que culpe al código
/// cuando el problema es la cuenta o la red.

abstract class _$SesionController extends $AsyncNotifier<void> {
  FutureOr<void> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<AsyncValue<void>, void>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<void>, void>,
              AsyncValue<void>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
