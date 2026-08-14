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

@JsonKey(name: 'usuario_id') int get usuarioId; String get nombre; String get email;@JsonKey(name: 'num_pedidos') int get numPedidos;@JsonKey(name: 'total_gastado') double get totalGastado;@JsonKey(name: 'ultimo_pedido_at') DateTime? get ultimoPedidoAt;
/// Create a copy of ClienteResumen
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ClienteResumenCopyWith<ClienteResumen> get copyWith => _$ClienteResumenCopyWithImpl<ClienteResumen>(this as ClienteResumen, _$identity);

  /// Serializes this ClienteResumen to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ClienteResumen&&(identical(other.usuarioId, usuarioId) || other.usuarioId == usuarioId)&&(identical(other.nombre, nombre) || other.nombre == nombre)&&(identical(other.email, email) || other.email == email)&&(identical(other.numPedidos, numPedidos) || other.numPedidos == numPedidos)&&(identical(other.totalGastado, totalGastado) || other.totalGastado == totalGastado)&&(identical(other.ultimoPedidoAt, ultimoPedidoAt) || other.ultimoPedidoAt == ultimoPedidoAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,usuarioId,nombre,email,numPedidos,totalGastado,ultimoPedidoAt);

@override
String toString() {
  return 'ClienteResumen(usuarioId: $usuarioId, nombre: $nombre, email: $email, numPedidos: $numPedidos, totalGastado: $totalGastado, ultimoPedidoAt: $ultimoPedidoAt)';
}


}

/// @nodoc
abstract mixin class $ClienteResumenCopyWith<$Res>  {
  factory $ClienteResumenCopyWith(ClienteResumen value, $Res Function(ClienteResumen) _then) = _$ClienteResumenCopyWithImpl;
@useResult
$Res call({
@JsonKey(name: 'usuario_id') int usuarioId, String nombre, String email,@JsonKey(name: 'num_pedidos') int numPedidos,@JsonKey(name: 'total_gastado') double totalGastado,@JsonKey(name: 'ultimo_pedido_at') DateTime? ultimoPedidoAt
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
@pragma('vm:prefer-inline') @override $Res call({Object? usuarioId = null,Object? nombre = null,Object? email = null,Object? numPedidos = null,Object? totalGastado = null,Object? ultimoPedidoAt = freezed,}) {
  return _then(ClienteResumen(
usuarioId: null == usuarioId ? _self.usuarioId : usuarioId // ignore: cast_nullable_to_non_nullable
as int,nombre: null == nombre ? _self.nombre : nombre // ignore: cast_nullable_to_non_nullable
as String,email: null == email ? _self.email : email // ignore: cast_nullable_to_non_nullable
as String,numPedidos: null == numPedidos ? _self.numPedidos : numPedidos // ignore: cast_nullable_to_non_nullable
as int,totalGastado: null == totalGastado ? _self.totalGastado : totalGastado // ignore: cast_nullable_to_non_nullable
as double,ultimoPedidoAt: freezed == ultimoPedidoAt ? _self.ultimoPedidoAt : ultimoPedidoAt // ignore: cast_nullable_to_non_nullable
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function(@JsonKey(name: 'usuario_id')  int usuarioId,  String nombre,  String email, @JsonKey(name: 'num_pedidos')  int numPedidos, @JsonKey(name: 'total_gastado')  double totalGastado, @JsonKey(name: 'ultimo_pedido_at')  DateTime? ultimoPedidoAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ClienteResumen() when $default != null:
return $default(_that.usuarioId,_that.nombre,_that.email,_that.numPedidos,_that.totalGastado,_that.ultimoPedidoAt);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function(@JsonKey(name: 'usuario_id')  int usuarioId,  String nombre,  String email, @JsonKey(name: 'num_pedidos')  int numPedidos, @JsonKey(name: 'total_gastado')  double totalGastado, @JsonKey(name: 'ultimo_pedido_at')  DateTime? ultimoPedidoAt)  $default,) {final _that = this;
switch (_that) {
case _ClienteResumen():
return $default(_that.usuarioId,_that.nombre,_that.email,_that.numPedidos,_that.totalGastado,_that.ultimoPedidoAt);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function(@JsonKey(name: 'usuario_id')  int usuarioId,  String nombre,  String email, @JsonKey(name: 'num_pedidos')  int numPedidos, @JsonKey(name: 'total_gastado')  double totalGastado, @JsonKey(name: 'ultimo_pedido_at')  DateTime? ultimoPedidoAt)?  $default,) {final _that = this;
switch (_that) {
case _ClienteResumen() when $default != null:
return $default(_that.usuarioId,_that.nombre,_that.email,_that.numPedidos,_that.totalGastado,_that.ultimoPedidoAt);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _ClienteResumen implements ClienteResumen {
  const _ClienteResumen({@JsonKey(name: 'usuario_id') required this.usuarioId, required this.nombre, required this.email, @JsonKey(name: 'num_pedidos') required this.numPedidos, @JsonKey(name: 'total_gastado') required this.totalGastado, @JsonKey(name: 'ultimo_pedido_at') required this.ultimoPedidoAt});
  factory _ClienteResumen.fromJson(Map<String, dynamic> json) => _$ClienteResumenFromJson(json);

@override@JsonKey(name: 'usuario_id') final  int usuarioId;
@override final  String nombre;
@override final  String email;
@override@JsonKey(name: 'num_pedidos') final  int numPedidos;
@override@JsonKey(name: 'total_gastado') final  double totalGastado;
@override@JsonKey(name: 'ultimo_pedido_at') final  DateTime? ultimoPedidoAt;

/// Create a copy of ClienteResumen
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ClienteResumenCopyWith<_ClienteResumen> get copyWith => __$ClienteResumenCopyWithImpl<_ClienteResumen>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ClienteResumenToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ClienteResumen&&(identical(other.usuarioId, usuarioId) || other.usuarioId == usuarioId)&&(identical(other.nombre, nombre) || other.nombre == nombre)&&(identical(other.email, email) || other.email == email)&&(identical(other.numPedidos, numPedidos) || other.numPedidos == numPedidos)&&(identical(other.totalGastado, totalGastado) || other.totalGastado == totalGastado)&&(identical(other.ultimoPedidoAt, ultimoPedidoAt) || other.ultimoPedidoAt == ultimoPedidoAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,usuarioId,nombre,email,numPedidos,totalGastado,ultimoPedidoAt);

@override
String toString() {
  return 'ClienteResumen(usuarioId: $usuarioId, nombre: $nombre, email: $email, numPedidos: $numPedidos, totalGastado: $totalGastado, ultimoPedidoAt: $ultimoPedidoAt)';
}


}

/// @nodoc
abstract mixin class _$ClienteResumenCopyWith<$Res> implements $ClienteResumenCopyWith<$Res> {
  factory _$ClienteResumenCopyWith(_ClienteResumen value, $Res Function(_ClienteResumen) _then) = __$ClienteResumenCopyWithImpl;
@override @useResult
$Res call({
@JsonKey(name: 'usuario_id') int usuarioId, String nombre, String email,@JsonKey(name: 'num_pedidos') int numPedidos,@JsonKey(name: 'total_gastado') double totalGastado,@JsonKey(name: 'ultimo_pedido_at') DateTime? ultimoPedidoAt
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
@override @pragma('vm:prefer-inline') $Res call({Object? usuarioId = null,Object? nombre = null,Object? email = null,Object? numPedidos = null,Object? totalGastado = null,Object? ultimoPedidoAt = freezed,}) {
  return _then(_ClienteResumen(
usuarioId: null == usuarioId ? _self.usuarioId : usuarioId // ignore: cast_nullable_to_non_nullable
as int,nombre: null == nombre ? _self.nombre : nombre // ignore: cast_nullable_to_non_nullable
as String,email: null == email ? _self.email : email // ignore: cast_nullable_to_non_nullable
as String,numPedidos: null == numPedidos ? _self.numPedidos : numPedidos // ignore: cast_nullable_to_non_nullable
as int,totalGastado: null == totalGastado ? _self.totalGastado : totalGastado // ignore: cast_nullable_to_non_nullable
as double,ultimoPedidoAt: freezed == ultimoPedidoAt ? _self.ultimoPedidoAt : ultimoPedidoAt // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}


}

// dart format on
