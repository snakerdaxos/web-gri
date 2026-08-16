// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'cliente_resumen.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$ClienteResumen {

/// UID de Firebase del cliente.
 String get usuarioId;/// Nombre denormalizado del ÚLTIMO pedido (snapshot).
 String get clienteNombre; int get nPedidos;/// Σ totals int COP.
 int get totalConsumo;/// createdAt del pedido más reciente.
 DateTime? get ultimoPedido;
/// Create a copy of ClienteResumen
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ClienteResumenCopyWith<ClienteResumen> get copyWith => _$ClienteResumenCopyWithImpl<ClienteResumen>(this as ClienteResumen, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ClienteResumen&&(identical(other.usuarioId, usuarioId) || other.usuarioId == usuarioId)&&(identical(other.clienteNombre, clienteNombre) || other.clienteNombre == clienteNombre)&&(identical(other.nPedidos, nPedidos) || other.nPedidos == nPedidos)&&(identical(other.totalConsumo, totalConsumo) || other.totalConsumo == totalConsumo)&&(identical(other.ultimoPedido, ultimoPedido) || other.ultimoPedido == ultimoPedido));
}


@override
int get hashCode => Object.hash(runtimeType,usuarioId,clienteNombre,nPedidos,totalConsumo,ultimoPedido);

@override
String toString() {
  return 'ClienteResumen(usuarioId: $usuarioId, clienteNombre: $clienteNombre, nPedidos: $nPedidos, totalConsumo: $totalConsumo, ultimoPedido: $ultimoPedido)';
}


}

/// @nodoc
abstract mixin class $ClienteResumenCopyWith<$Res>  {
  factory $ClienteResumenCopyWith(ClienteResumen value, $Res Function(ClienteResumen) _then) = _$ClienteResumenCopyWithImpl;
@useResult
$Res call({
 String usuarioId, String clienteNombre, int nPedidos, int totalConsumo, DateTime? ultimoPedido
});




}
/// @nodoc
class _$ClienteResumenCopyWithImpl<$Res>
    implements $ClienteResumenCopyWith<$Res> {
  _$ClienteResumenCopyWithImpl(this._self, this._then);

  final ClienteResumen _self;
  final $Res Function(ClienteResumen) _then;

/// Create a copy of ClienteResumen
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? usuarioId = null,Object? clienteNombre = null,Object? nPedidos = null,Object? totalConsumo = null,Object? ultimoPedido = freezed,}) {
  return _then(ClienteResumen(
usuarioId: null == usuarioId ? _self.usuarioId : usuarioId // ignore: cast_nullable_to_non_nullable
as String,clienteNombre: null == clienteNombre ? _self.clienteNombre : clienteNombre // ignore: cast_nullable_to_non_nullable
as String,nPedidos: null == nPedidos ? _self.nPedidos : nPedidos // ignore: cast_nullable_to_non_nullable
as int,totalConsumo: null == totalConsumo ? _self.totalConsumo : totalConsumo // ignore: cast_nullable_to_non_nullable
as int,ultimoPedido: freezed == ultimoPedido ? _self.ultimoPedido : ultimoPedido // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}

}


/// Adds pattern-matching-related methods to [ClienteResumen].
extension ClienteResumenPatterns on ClienteResumen {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ClienteResumen value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ClienteResumen() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ClienteResumen value)  $default,){
final _that = this;
switch (_that) {
case _ClienteResumen():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ClienteResumen value)?  $default,){
final _that = this;
switch (_that) {
case _ClienteResumen() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String usuarioId,  String clienteNombre,  int nPedidos,  int totalConsumo,  DateTime? ultimoPedido)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ClienteResumen() when $default != null:
return $default(_that.usuarioId,_that.clienteNombre,_that.nPedidos,_that.totalConsumo,_that.ultimoPedido);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String usuarioId,  String clienteNombre,  int nPedidos,  int totalConsumo,  DateTime? ultimoPedido)  $default,) {final _that = this;
switch (_that) {
case _ClienteResumen():
return $default(_that.usuarioId,_that.clienteNombre,_that.nPedidos,_that.totalConsumo,_that.ultimoPedido);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String usuarioId,  String clienteNombre,  int nPedidos,  int totalConsumo,  DateTime? ultimoPedido)?  $default,) {final _that = this;
switch (_that) {
case _ClienteResumen() when $default != null:
return $default(_that.usuarioId,_that.clienteNombre,_that.nPedidos,_that.totalConsumo,_that.ultimoPedido);case _:
  return null;

}
}

}

/// @nodoc


class _ClienteResumen implements ClienteResumen {
  const _ClienteResumen({required this.usuarioId, required this.clienteNombre, required this.nPedidos, required this.totalConsumo, this.ultimoPedido});
  

/// UID de Firebase del cliente.
@override final  String usuarioId;
/// Nombre denormalizado del ÚLTIMO pedido (snapshot).
@override final  String clienteNombre;
@override final  int nPedidos;
/// Σ totals int COP.
@override final  int totalConsumo;
/// createdAt del pedido más reciente.
@override final  DateTime? ultimoPedido;

/// Create a copy of ClienteResumen
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ClienteResumenCopyWith<_ClienteResumen> get copyWith => __$ClienteResumenCopyWithImpl<_ClienteResumen>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ClienteResumen&&(identical(other.usuarioId, usuarioId) || other.usuarioId == usuarioId)&&(identical(other.clienteNombre, clienteNombre) || other.clienteNombre == clienteNombre)&&(identical(other.nPedidos, nPedidos) || other.nPedidos == nPedidos)&&(identical(other.totalConsumo, totalConsumo) || other.totalConsumo == totalConsumo)&&(identical(other.ultimoPedido, ultimoPedido) || other.ultimoPedido == ultimoPedido));
}


@override
int get hashCode => Object.hash(runtimeType,usuarioId,clienteNombre,nPedidos,totalConsumo,ultimoPedido);

@override
String toString() {
  return 'ClienteResumen(usuarioId: $usuarioId, clienteNombre: $clienteNombre, nPedidos: $nPedidos, totalConsumo: $totalConsumo, ultimoPedido: $ultimoPedido)';
}


}

/// @nodoc
abstract mixin class _$ClienteResumenCopyWith<$Res> implements $ClienteResumenCopyWith<$Res> {
  factory _$ClienteResumenCopyWith(_ClienteResumen value, $Res Function(_ClienteResumen) _then) = __$ClienteResumenCopyWithImpl;
@override @useResult
$Res call({
 String usuarioId, String clienteNombre, int nPedidos, int totalConsumo, DateTime? ultimoPedido
});




}
/// @nodoc
class __$ClienteResumenCopyWithImpl<$Res>
    implements _$ClienteResumenCopyWith<$Res> {
  __$ClienteResumenCopyWithImpl(this._self, this._then);

  final _ClienteResumen _self;
  final $Res Function(_ClienteResumen) _then;

/// Create a copy of ClienteResumen
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? usuarioId = null,Object? clienteNombre = null,Object? nPedidos = null,Object? totalConsumo = null,Object? ultimoPedido = freezed,}) {
  return _then(_ClienteResumen(
usuarioId: null == usuarioId ? _self.usuarioId : usuarioId // ignore: cast_nullable_to_non_nullable
as String,clienteNombre: null == clienteNombre ? _self.clienteNombre : clienteNombre // ignore: cast_nullable_to_non_nullable
as String,nPedidos: null == nPedidos ? _self.nPedidos : nPedidos // ignore: cast_nullable_to_non_nullable
as int,totalConsumo: null == totalConsumo ? _self.totalConsumo : totalConsumo // ignore: cast_nullable_to_non_nullable
as int,ultimoPedido: freezed == ultimoPedido ? _self.ultimoPedido : ultimoPedido // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}


}

// dart format on
