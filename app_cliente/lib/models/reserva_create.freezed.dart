// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'reserva_create.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$ReservaCreate {

 String get restauranteId; String get fecha; int get hora; int get numPersonas;
/// Create a copy of ReservaCreate
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ReservaCreateCopyWith<ReservaCreate> get copyWith => _$ReservaCreateCopyWithImpl<ReservaCreate>(this as ReservaCreate, _$identity);

  /// Serializes this ReservaCreate to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ReservaCreate&&(identical(other.restauranteId, restauranteId) || other.restauranteId == restauranteId)&&(identical(other.fecha, fecha) || other.fecha == fecha)&&(identical(other.hora, hora) || other.hora == hora)&&(identical(other.numPersonas, numPersonas) || other.numPersonas == numPersonas));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,restauranteId,fecha,hora,numPersonas);

@override
String toString() {
  return 'ReservaCreate(restauranteId: $restauranteId, fecha: $fecha, hora: $hora, numPersonas: $numPersonas)';
}


}

/// @nodoc
abstract mixin class $ReservaCreateCopyWith<$Res>  {
  factory $ReservaCreateCopyWith(ReservaCreate value, $Res Function(ReservaCreate) _then) = _$ReservaCreateCopyWithImpl;
@useResult
$Res call({
 String restauranteId, String fecha, int hora, int numPersonas
});




}
/// @nodoc
class _$ReservaCreateCopyWithImpl<$Res>
    implements $ReservaCreateCopyWith<$Res> {
  _$ReservaCreateCopyWithImpl(this._self, this._then);

  final ReservaCreate _self;
  final $Res Function(ReservaCreate) _then;

/// Create a copy of ReservaCreate
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? restauranteId = null,Object? fecha = null,Object? hora = null,Object? numPersonas = null,}) {
  return _then(ReservaCreate(
restauranteId: null == restauranteId ? _self.restauranteId : restauranteId // ignore: cast_nullable_to_non_nullable
as String,fecha: null == fecha ? _self.fecha : fecha // ignore: cast_nullable_to_non_nullable
as String,hora: null == hora ? _self.hora : hora // ignore: cast_nullable_to_non_nullable
as int,numPersonas: null == numPersonas ? _self.numPersonas : numPersonas // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}


/// Adds pattern-matching-related methods to [ReservaCreate].
extension ReservaCreatePatterns on ReservaCreate {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ReservaCreate value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ReservaCreate() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ReservaCreate value)  $default,){
final _that = this;
switch (_that) {
case _ReservaCreate():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ReservaCreate value)?  $default,){
final _that = this;
switch (_that) {
case _ReservaCreate() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String restauranteId,  String fecha,  int hora,  int numPersonas)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ReservaCreate() when $default != null:
return $default(_that.restauranteId,_that.fecha,_that.hora,_that.numPersonas);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String restauranteId,  String fecha,  int hora,  int numPersonas)  $default,) {final _that = this;
switch (_that) {
case _ReservaCreate():
return $default(_that.restauranteId,_that.fecha,_that.hora,_that.numPersonas);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String restauranteId,  String fecha,  int hora,  int numPersonas)?  $default,) {final _that = this;
switch (_that) {
case _ReservaCreate() when $default != null:
return $default(_that.restauranteId,_that.fecha,_that.hora,_that.numPersonas);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _ReservaCreate implements ReservaCreate {
  const _ReservaCreate({required this.restauranteId, required this.fecha, required this.hora, required this.numPersonas});
  factory _ReservaCreate.fromJson(Map<String, dynamic> json) => _$ReservaCreateFromJson(json);

@override final  String restauranteId;
@override final  String fecha;
@override final  int hora;
@override final  int numPersonas;

/// Create a copy of ReservaCreate
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ReservaCreateCopyWith<_ReservaCreate> get copyWith => __$ReservaCreateCopyWithImpl<_ReservaCreate>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ReservaCreateToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ReservaCreate&&(identical(other.restauranteId, restauranteId) || other.restauranteId == restauranteId)&&(identical(other.fecha, fecha) || other.fecha == fecha)&&(identical(other.hora, hora) || other.hora == hora)&&(identical(other.numPersonas, numPersonas) || other.numPersonas == numPersonas));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,restauranteId,fecha,hora,numPersonas);

@override
String toString() {
  return 'ReservaCreate(restauranteId: $restauranteId, fecha: $fecha, hora: $hora, numPersonas: $numPersonas)';
}


}

/// @nodoc
abstract mixin class _$ReservaCreateCopyWith<$Res> implements $ReservaCreateCopyWith<$Res> {
  factory _$ReservaCreateCopyWith(_ReservaCreate value, $Res Function(_ReservaCreate) _then) = __$ReservaCreateCopyWithImpl;
@override @useResult
$Res call({
 String restauranteId, String fecha, int hora, int numPersonas
});




}
/// @nodoc
class __$ReservaCreateCopyWithImpl<$Res>
    implements _$ReservaCreateCopyWith<$Res> {
  __$ReservaCreateCopyWithImpl(this._self, this._then);

  final _ReservaCreate _self;
  final $Res Function(_ReservaCreate) _then;

/// Create a copy of ReservaCreate
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? restauranteId = null,Object? fecha = null,Object? hora = null,Object? numPersonas = null,}) {
  return _then(_ReservaCreate(
restauranteId: null == restauranteId ? _self.restauranteId : restauranteId // ignore: cast_nullable_to_non_nullable
as String,fecha: null == fecha ? _self.fecha : fecha // ignore: cast_nullable_to_non_nullable
as String,hora: null == hora ? _self.hora : hora // ignore: cast_nullable_to_non_nullable
as int,numPersonas: null == numPersonas ? _self.numPersonas : numPersonas // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

// dart format on
