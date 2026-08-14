// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'reserva.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$Reserva {

 int get id;@JsonKey(name: 'restaurante_id') int get restauranteId;@JsonKey(name: 'restaurante_nombre') String get restauranteNombre;@JsonKey(name: 'mesa_id') int get mesaId;@JsonKey(name: 'mesa_numero') int get mesaNumero; String get fecha;@JsonKey(name: 'hora_inicio') String get horaInicio;@JsonKey(name: 'num_personas') int get numPersonas; String get estado;@JsonKey(name: 'created_at') String get createdAt;
/// Create a copy of Reserva
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ReservaCopyWith<Reserva> get copyWith => _$ReservaCopyWithImpl<Reserva>(this as Reserva, _$identity);

  /// Serializes this Reserva to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Reserva&&(identical(other.id, id) || other.id == id)&&(identical(other.restauranteId, restauranteId) || other.restauranteId == restauranteId)&&(identical(other.restauranteNombre, restauranteNombre) || other.restauranteNombre == restauranteNombre)&&(identical(other.mesaId, mesaId) || other.mesaId == mesaId)&&(identical(other.mesaNumero, mesaNumero) || other.mesaNumero == mesaNumero)&&(identical(other.fecha, fecha) || other.fecha == fecha)&&(identical(other.horaInicio, horaInicio) || other.horaInicio == horaInicio)&&(identical(other.numPersonas, numPersonas) || other.numPersonas == numPersonas)&&(identical(other.estado, estado) || other.estado == estado)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,restauranteId,restauranteNombre,mesaId,mesaNumero,fecha,horaInicio,numPersonas,estado,createdAt);

@override
String toString() {
  return 'Reserva(id: $id, restauranteId: $restauranteId, restauranteNombre: $restauranteNombre, mesaId: $mesaId, mesaNumero: $mesaNumero, fecha: $fecha, horaInicio: $horaInicio, numPersonas: $numPersonas, estado: $estado, createdAt: $createdAt)';
}


}

/// @nodoc
abstract mixin class $ReservaCopyWith<$Res>  {
  factory $ReservaCopyWith(Reserva value, $Res Function(Reserva) _then) = _$ReservaCopyWithImpl;
@useResult
$Res call({
 int id,@JsonKey(name: 'restaurante_id') int restauranteId,@JsonKey(name: 'restaurante_nombre') String restauranteNombre,@JsonKey(name: 'mesa_id') int mesaId,@JsonKey(name: 'mesa_numero') int mesaNumero, String fecha,@JsonKey(name: 'hora_inicio') String horaInicio,@JsonKey(name: 'num_personas') int numPersonas, String estado,@JsonKey(name: 'created_at') String createdAt
});




}
/// @nodoc
class _$ReservaCopyWithImpl<$Res>
    implements $ReservaCopyWith<$Res> {
  _$ReservaCopyWithImpl(this._self, this._then);

  final Reserva _self;
  final $Res Function(Reserva) _then;

/// Create a copy of Reserva
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? restauranteId = null,Object? restauranteNombre = null,Object? mesaId = null,Object? mesaNumero = null,Object? fecha = null,Object? horaInicio = null,Object? numPersonas = null,Object? estado = null,Object? createdAt = null,}) {
  return _then(Reserva(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,restauranteId: null == restauranteId ? _self.restauranteId : restauranteId // ignore: cast_nullable_to_non_nullable
as int,restauranteNombre: null == restauranteNombre ? _self.restauranteNombre : restauranteNombre // ignore: cast_nullable_to_non_nullable
as String,mesaId: null == mesaId ? _self.mesaId : mesaId // ignore: cast_nullable_to_non_nullable
as int,mesaNumero: null == mesaNumero ? _self.mesaNumero : mesaNumero // ignore: cast_nullable_to_non_nullable
as int,fecha: null == fecha ? _self.fecha : fecha // ignore: cast_nullable_to_non_nullable
as String,horaInicio: null == horaInicio ? _self.horaInicio : horaInicio // ignore: cast_nullable_to_non_nullable
as String,numPersonas: null == numPersonas ? _self.numPersonas : numPersonas // ignore: cast_nullable_to_non_nullable
as int,estado: null == estado ? _self.estado : estado // ignore: cast_nullable_to_non_nullable
as String,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [Reserva].
extension ReservaPatterns on Reserva {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _Reserva value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _Reserva() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _Reserva value)  $default,){
final _that = this;
switch (_that) {
case _Reserva():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _Reserva value)?  $default,){
final _that = this;
switch (_that) {
case _Reserva() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int id, @JsonKey(name: 'restaurante_id')  int restauranteId, @JsonKey(name: 'restaurante_nombre')  String restauranteNombre, @JsonKey(name: 'mesa_id')  int mesaId, @JsonKey(name: 'mesa_numero')  int mesaNumero,  String fecha, @JsonKey(name: 'hora_inicio')  String horaInicio, @JsonKey(name: 'num_personas')  int numPersonas,  String estado, @JsonKey(name: 'created_at')  String createdAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Reserva() when $default != null:
return $default(_that.id,_that.restauranteId,_that.restauranteNombre,_that.mesaId,_that.mesaNumero,_that.fecha,_that.horaInicio,_that.numPersonas,_that.estado,_that.createdAt);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int id, @JsonKey(name: 'restaurante_id')  int restauranteId, @JsonKey(name: 'restaurante_nombre')  String restauranteNombre, @JsonKey(name: 'mesa_id')  int mesaId, @JsonKey(name: 'mesa_numero')  int mesaNumero,  String fecha, @JsonKey(name: 'hora_inicio')  String horaInicio, @JsonKey(name: 'num_personas')  int numPersonas,  String estado, @JsonKey(name: 'created_at')  String createdAt)  $default,) {final _that = this;
switch (_that) {
case _Reserva():
return $default(_that.id,_that.restauranteId,_that.restauranteNombre,_that.mesaId,_that.mesaNumero,_that.fecha,_that.horaInicio,_that.numPersonas,_that.estado,_that.createdAt);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int id, @JsonKey(name: 'restaurante_id')  int restauranteId, @JsonKey(name: 'restaurante_nombre')  String restauranteNombre, @JsonKey(name: 'mesa_id')  int mesaId, @JsonKey(name: 'mesa_numero')  int mesaNumero,  String fecha, @JsonKey(name: 'hora_inicio')  String horaInicio, @JsonKey(name: 'num_personas')  int numPersonas,  String estado, @JsonKey(name: 'created_at')  String createdAt)?  $default,) {final _that = this;
switch (_that) {
case _Reserva() when $default != null:
return $default(_that.id,_that.restauranteId,_that.restauranteNombre,_that.mesaId,_that.mesaNumero,_that.fecha,_that.horaInicio,_that.numPersonas,_that.estado,_that.createdAt);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _Reserva extends Reserva {
  const _Reserva({required this.id, @JsonKey(name: 'restaurante_id') required this.restauranteId, @JsonKey(name: 'restaurante_nombre') required this.restauranteNombre, @JsonKey(name: 'mesa_id') required this.mesaId, @JsonKey(name: 'mesa_numero') required this.mesaNumero, required this.fecha, @JsonKey(name: 'hora_inicio') required this.horaInicio, @JsonKey(name: 'num_personas') required this.numPersonas, required this.estado, @JsonKey(name: 'created_at') required this.createdAt}): super._();
  factory _Reserva.fromJson(Map<String, dynamic> json) => _$ReservaFromJson(json);

@override final  int id;
@override@JsonKey(name: 'restaurante_id') final  int restauranteId;
@override@JsonKey(name: 'restaurante_nombre') final  String restauranteNombre;
@override@JsonKey(name: 'mesa_id') final  int mesaId;
@override@JsonKey(name: 'mesa_numero') final  int mesaNumero;
@override final  String fecha;
@override@JsonKey(name: 'hora_inicio') final  String horaInicio;
@override@JsonKey(name: 'num_personas') final  int numPersonas;
@override final  String estado;
@override@JsonKey(name: 'created_at') final  String createdAt;

/// Create a copy of Reserva
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ReservaCopyWith<_Reserva> get copyWith => __$ReservaCopyWithImpl<_Reserva>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ReservaToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _Reserva&&(identical(other.id, id) || other.id == id)&&(identical(other.restauranteId, restauranteId) || other.restauranteId == restauranteId)&&(identical(other.restauranteNombre, restauranteNombre) || other.restauranteNombre == restauranteNombre)&&(identical(other.mesaId, mesaId) || other.mesaId == mesaId)&&(identical(other.mesaNumero, mesaNumero) || other.mesaNumero == mesaNumero)&&(identical(other.fecha, fecha) || other.fecha == fecha)&&(identical(other.horaInicio, horaInicio) || other.horaInicio == horaInicio)&&(identical(other.numPersonas, numPersonas) || other.numPersonas == numPersonas)&&(identical(other.estado, estado) || other.estado == estado)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,restauranteId,restauranteNombre,mesaId,mesaNumero,fecha,horaInicio,numPersonas,estado,createdAt);

@override
String toString() {
  return 'Reserva(id: $id, restauranteId: $restauranteId, restauranteNombre: $restauranteNombre, mesaId: $mesaId, mesaNumero: $mesaNumero, fecha: $fecha, horaInicio: $horaInicio, numPersonas: $numPersonas, estado: $estado, createdAt: $createdAt)';
}


}

/// @nodoc
abstract mixin class _$ReservaCopyWith<$Res> implements $ReservaCopyWith<$Res> {
  factory _$ReservaCopyWith(_Reserva value, $Res Function(_Reserva) _then) = __$ReservaCopyWithImpl;
@override @useResult
$Res call({
 int id,@JsonKey(name: 'restaurante_id') int restauranteId,@JsonKey(name: 'restaurante_nombre') String restauranteNombre,@JsonKey(name: 'mesa_id') int mesaId,@JsonKey(name: 'mesa_numero') int mesaNumero, String fecha,@JsonKey(name: 'hora_inicio') String horaInicio,@JsonKey(name: 'num_personas') int numPersonas, String estado,@JsonKey(name: 'created_at') String createdAt
});




}
/// @nodoc
class __$ReservaCopyWithImpl<$Res>
    implements _$ReservaCopyWith<$Res> {
  __$ReservaCopyWithImpl(this._self, this._then);

  final _Reserva _self;
  final $Res Function(_Reserva) _then;

/// Create a copy of Reserva
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? restauranteId = null,Object? restauranteNombre = null,Object? mesaId = null,Object? mesaNumero = null,Object? fecha = null,Object? horaInicio = null,Object? numPersonas = null,Object? estado = null,Object? createdAt = null,}) {
  return _then(_Reserva(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,restauranteId: null == restauranteId ? _self.restauranteId : restauranteId // ignore: cast_nullable_to_non_nullable
as int,restauranteNombre: null == restauranteNombre ? _self.restauranteNombre : restauranteNombre // ignore: cast_nullable_to_non_nullable
as String,mesaId: null == mesaId ? _self.mesaId : mesaId // ignore: cast_nullable_to_non_nullable
as int,mesaNumero: null == mesaNumero ? _self.mesaNumero : mesaNumero // ignore: cast_nullable_to_non_nullable
as int,fecha: null == fecha ? _self.fecha : fecha // ignore: cast_nullable_to_non_nullable
as String,horaInicio: null == horaInicio ? _self.horaInicio : horaInicio // ignore: cast_nullable_to_non_nullable
as String,numPersonas: null == numPersonas ? _self.numPersonas : numPersonas // ignore: cast_nullable_to_non_nullable
as int,estado: null == estado ? _self.estado : estado // ignore: cast_nullable_to_non_nullable
as String,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

// dart format on
