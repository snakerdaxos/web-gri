// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'perfil_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Edición del perfil del cliente (AUTH-05): PATCH /cliente/perfil con
/// nombre (siempre) y password (solo si el user la escribió — el email es
/// immutable server-side y jamás se envía).

@ProviderFor(PerfilController)
final perfilControllerProvider = PerfilControllerProvider._();

/// Edición del perfil del cliente (AUTH-05): PATCH /cliente/perfil con
/// nombre (siempre) y password (solo si el user la escribió — el email es
/// immutable server-side y jamás se envía).
final class PerfilControllerProvider
    extends $AsyncNotifierProvider<PerfilController, void> {
  /// Edición del perfil del cliente (AUTH-05): PATCH /cliente/perfil con
  /// nombre (siempre) y password (solo si el user la escribió — el email es
  /// immutable server-side y jamás se envía).
  PerfilControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'perfilControllerProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$perfilControllerHash();

  @$internal
  @override
  PerfilController create() => PerfilController();
}

String _$perfilControllerHash() => r'871a648d286d19a9a1ff9866c183f1ba09e7cc28';

/// Edición del perfil del cliente (AUTH-05): PATCH /cliente/perfil con
/// nombre (siempre) y password (solo si el user la escribió — el email es
/// immutable server-side y jamás se envía).

abstract class _$PerfilController extends $AsyncNotifier<void> {
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
