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

/// Doc ID = código QR (ej. `GRI-MESA-demo-001`).
 String get id;/// Tenant de la mesa — TODA query del panel filtra por el rid de claims.
 String get restauranteId; int get numero; int get capacidad;@JsonKey(fromJson: estadoMesaFromJson) EstadoMesa get estado; DateTime? get updatedAt;
/// Create a copy of Mesa
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$MesaCopyWith<Mesa> get copyWith => _$MesaCopyWithImpl<Mesa>(this as Mesa, _$identity);

  /// Serializes this Mesa to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Mesa&&(identical(other.id, id) || other.id == id)&&(identical(other.restauranteId, restauranteId) || other.restauranteId == restauranteId)&&(identical(other.numero, numero) || other.numero == numero)&&(identical(other.capacidad, capacidad) || other.capacidad == capacidad)&&(identical(other.estado, estado) || other.estado == estado)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,restauranteId,numero,capacidad,estado,updatedAt);

@override
String toString() {
  return 'Mesa(id: $id, restauranteId: $restauranteId, numero: $numero, capacidad: $capacidad, estado: $estado, updatedAt: $updatedAt)';
}


}

/// @nodoc
abstract mixin class $MesaCopyWith<$Res>  {
  factory $MesaCopyWith(Mesa value, $Res Function(Mesa) _then) = _$MesaCopyWithImpl;
@useResult
$Res call({
 String id, String restauranteId, int numero, int capacidad,@JsonKey(fromJson: estadoMesaFromJson) EstadoMesa estado, DateTime? updatedAt
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
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? restauranteId = null,Object? numero = null,Object? capacidad = null,Object? estado = null,Object? updatedAt = freezed,}) {
  return _then(Mesa(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,restauranteId: null == restauranteId ? _self.restauranteId : restauranteId // ignore: cast_nullable_to_non_nullable
as String,numero: null == numero ? _self.numero : numero // ignore: cast_nullable_to_non_nullable
as int,capacidad: null == capacidad ? _self.capacidad : capacidad // ignore: cast_nullable_to_non_nullable
as int,estado: null == estado ? _self.estado : estado // ignore: cast_nullable_to_non_nullable
as EstadoMesa,updatedAt: freezed == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String restauranteId,  int numero,  int capacidad, @JsonKey(fromJson: estadoMesaFromJson)  EstadoMesa estado,  DateTime? updatedAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Mesa() when $default != null:
return $default(_that.id,_that.restauranteId,_that.numero,_that.capacidad,_that.estado,_that.updatedAt);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String restauranteId,  int numero,  int capacidad, @JsonKey(fromJson: estadoMesaFromJson)  EstadoMesa estado,  DateTime? updatedAt)  $default,) {final _that = this;
switch (_that) {
case _Mesa():
return $default(_that.id,_that.restauranteId,_that.numero,_that.capacidad,_that.estado,_that.updatedAt);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String restauranteId,  int numero,  int capacidad, @JsonKey(fromJson: estadoMesaFromJson)  EstadoMesa estado,  DateTime? updatedAt)?  $default,) {final _that = this;
switch (_that) {
case _Mesa() when $default != null:
return $default(_that.id,_that.restauranteId,_that.numero,_that.capacidad,_that.estado,_that.updatedAt);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _Mesa extends Mesa {
  const _Mesa({required this.id, this.restauranteId = '', required this.numero, required this.capacidad, @JsonKey(fromJson: estadoMesaFromJson) required this.estado, this.updatedAt}): super._();
  factory _Mesa.fromJson(Map<String, dynamic> json) => _$MesaFromJson(json);

/// Doc ID = código QR (ej. `GRI-MESA-demo-001`).
@override final  String id;
/// Tenant de la mesa — TODA query del panel filtra por el rid de claims.
@override@JsonKey() final  String restauranteId;
@override final  int numero;
@override final  int capacidad;
@override@JsonKey(fromJson: estadoMesaFromJson) final  EstadoMesa estado;
@override final  DateTime? updatedAt;

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
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _Mesa&&(identical(other.id, id) || other.id == id)&&(identical(other.restauranteId, restauranteId) || other.restauranteId == restauranteId)&&(identical(other.numero, numero) || other.numero == numero)&&(identical(other.capacidad, capacidad) || other.capacidad == capacidad)&&(identical(other.estado, estado) || other.estado == estado)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,restauranteId,numero,capacidad,estado,updatedAt);

@override
String toString() {
  return 'Mesa(id: $id, restauranteId: $restauranteId, numero: $numero, capacidad: $capacidad, estado: $estado, updatedAt: $updatedAt)';
}


}

/// @nodoc
abstract mixin class _$MesaCopyWith<$Res> implements $MesaCopyWith<$Res> {
  factory _$MesaCopyWith(_Mesa value, $Res Function(_Mesa) _then) = __$MesaCopyWithImpl;
@override @useResult
$Res call({
 String id, String restauranteId, int numero, int capacidad,@JsonKey(fromJson: estadoMesaFromJson) EstadoMesa estado, DateTime? updatedAt
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
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? restauranteId = null,Object? numero = null,Object? capacidad = null,Object? estado = null,Object? updatedAt = freezed,}) {
  return _then(_Mesa(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,restauranteId: null == restauranteId ? _self.restauranteId : restauranteId // ignore: cast_nullable_to_non_nullable
as String,numero: null == numero ? _self.numero : numero // ignore: cast_nullable_to_non_nullable
as int,capacidad: null == capacidad ? _self.capacidad : capacidad // ignore: cast_nullable_to_non_nullable
as int,estado: null == estado ? _self.estado : estado // ignore: cast_nullable_to_non_nullable
as EstadoMesa,updatedAt: freezed == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}


}

// dart format on
