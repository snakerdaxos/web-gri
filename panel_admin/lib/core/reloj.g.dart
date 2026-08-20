// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'reloj.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// La hora actual como `AsyncValue`, para los widgets.

@ProviderFor(relojDeSala)
final relojDeSalaProvider = RelojDeSalaProvider._();

/// La hora actual como `AsyncValue`, para los widgets.

final class RelojDeSalaProvider
    extends
        $FunctionalProvider<AsyncValue<DateTime>, DateTime, Stream<DateTime>>
    with $FutureModifier<DateTime>, $StreamProvider<DateTime> {
  /// La hora actual como `AsyncValue`, para los widgets.
  RelojDeSalaProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'relojDeSalaProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$relojDeSalaHash();

  @$internal
  @override
  $StreamProviderElement<DateTime> $createElement($ProviderPointer pointer) =>
      $StreamProviderElement(pointer);

  @override
  Stream<DateTime> create(Ref ref) {
    return relojDeSala(ref);
  }
}

String _$relojDeSalaHash() => r'c497c47a17813ca697fccd94a50a8c38629c745e';
