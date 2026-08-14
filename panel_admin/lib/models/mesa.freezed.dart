// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'mesa.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$Mesa {

 int get id; int get numero; int get capacidad;@JsonKey(name: 'codigo_qr') String get codigoQr;@JsonKey(fromJson: estadoMesaFromJson) EstadoMesa get estado;
/// Create a copy of Mesa
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$MesaCopyWith<Mesa> get copyWith => _$MesaCopyWithImpl<Mesa>(this as Mesa, _$identity);

  /// Serializes this Mesa to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Mesa&&(identical(other.id, id) || other.id == id)&&(identical(other.numero, numero) || other.numero == numero)&&(identical(other.capacidad, capacidad) || other.capacidad == capacidad)&&(identical(other.codigoQr, codigoQr) || other.codigoQr == codigoQr)&&(identical(other.estado, estado) || other.estado == estado));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,numero,capacidad,codigoQr,estado);

@override
String toString() {
  return 'Mesa(id: $id, numero: $numero, capacidad: $capacidad, codigoQr: $codigoQr, estado: $estado)';
}


}

/// @nodoc
abstract mixin class $MesaCopyWith<$Res>  {
  factory $MesaCopyWith(Mesa value, $Res Function(Mesa) _then) = _$MesaCopyWithImpl;
@useResult
$Res call({
 int id, int numero, int capacidad,@JsonKey(name: 'codigo_qr') String codigoQr,@JsonKey(fromJson: estadoMesaFromJson) EstadoMesa estado
});




}
/// @nodoc
class _$MesaCopyWithImpl<$Res>
    implements $MesaCopyWith<$Res> {
  _$MesaCopyWithImpl(this._self, this._then);

  final Mesa _self;
  final $Res Function(Mesa) _then;

/// Create a copy of Mesa
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? numero = null,Object? capacidad = null,Object? codigoQr = null,Object? estado = null,}) {
  return _then(Mesa(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,numero: null == numero ? _self.numero : numero // ignore: cast_nullable_to_non_nullable
as int,capacidad: null == capacidad ? _self.capacidad : capacidad // ignore: cast_nullable_to_non_nullable
as int,codigoQr: null == codigoQr ? _self.codigoQr : codigoQr // ignore: cast_nullable_to_non_nullable
as String,estado: null == estado ? _self.estado : estado // ignore: cast_nullable_to_non_nullable
as EstadoMesa,
  ));
}

}


/// Adds pattern-matching-related methods to [Mesa].
extension MesaPatterns on Mesa {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _Mesa value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _Mesa() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _Mesa value)  $default,){
final _that = this;
switch (_that) {
case _Mesa():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _Mesa value)?  $default,){
final _that = this;
switch (_that) {
case _Mesa() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int id,  int numero,  int capacidad, @JsonKey(name: 'codigo_qr')  String codigoQr, @JsonKey(fromJson: estadoMesaFromJson)  EstadoMesa estado)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Mesa() when $default != null:
return $default(_that.id,_that.numero,_that.capacidad,_that.codigoQr,_that.estado);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int id,  int numero,  int capacidad, @JsonKey(name: 'codigo_qr')  String codigoQr, @JsonKey(fromJson: estadoMesaFromJson)  EstadoMesa estado)  $default,) {final _that = this;
switch (_that) {
case _Mesa():
return $default(_that.id,_that.numero,_that.capacidad,_that.codigoQr,_that.estado);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int id,  int numero,  int capacidad, @JsonKey(name: 'codigo_qr')  String codigoQr, @JsonKey(fromJson: estadoMesaFromJson)  EstadoMesa estado)?  $default,) {final _that = this;
switch (_that) {
case _Mesa() when $default != null:
return $default(_that.id,_that.numero,_that.capacidad,_that.codigoQr,_that.estado);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _Mesa implements Mesa {
  const _Mesa({required this.id, required this.numero, required this.capacidad, @JsonKey(name: 'codigo_qr') required this.codigoQr, @JsonKey(fromJson: estadoMesaFromJson) required this.estado});
  factory _Mesa.fromJson(Map<String, dynamic> json) => _$MesaFromJson(json);

@override final  int id;
@override final  int numero;
@override final  int capacidad;
@override@JsonKey(name: 'codigo_qr') final  String codigoQr;
@override@JsonKey(fromJson: estadoMesaFromJson) final  EstadoMesa estado;

/// Create a copy of Mesa
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$MesaCopyWith<_Mesa> get copyWith => __$MesaCopyWithImpl<_Mesa>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$MesaToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _Mesa&&(identical(other.id, id) || other.id == id)&&(identical(other.numero, numero) || other.numero == numero)&&(identical(other.capacidad, capacidad) || other.capacidad == capacidad)&&(identical(other.codigoQr, codigoQr) || other.codigoQr == codigoQr)&&(identical(other.estado, estado) || other.estado == estado));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,numero,capacidad,codigoQr,estado);

@override
String toString() {
  return 'Mesa(id: $id, numero: $numero, capacidad: $capacidad, codigoQr: $codigoQr, estado: $estado)';
}


}

/// @nodoc
abstract mixin class _$MesaCopyWith<$Res> implements $MesaCopyWith<$Res> {
  factory _$MesaCopyWith(_Mesa value, $Res Function(_Mesa) _then) = __$MesaCopyWithImpl;
@override @useResult
$Res call({
 int id, int numero, int capacidad,@JsonKey(name: 'codigo_qr') String codigoQr,@JsonKey(fromJson: estadoMesaFromJson) EstadoMesa estado
});




}
/// @nodoc
class __$MesaCopyWithImpl<$Res>
    implements _$MesaCopyWith<$Res> {
  __$MesaCopyWithImpl(this._self, this._then);

  final _Mesa _self;
  final $Res Function(_Mesa) _then;

/// Create a copy of Mesa
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? numero = null,Object? capacidad = null,Object? codigoQr = null,Object? estado = null,}) {
  return _then(_Mesa(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,numero: null == numero ? _self.numero : numero // ignore: cast_nullable_to_non_nullable
as int,capacidad: null == capacidad ? _self.capacidad : capacidad // ignore: cast_nullable_to_non_nullable
as int,codigoQr: null == codigoQr ? _self.codigoQr : codigoQr // ignore: cast_nullable_to_non_nullable
as String,estado: null == estado ? _self.estado : estado // ignore: cast_nullable_to_non_nullable
as EstadoMesa,
  ));
}


}

// dart format on
