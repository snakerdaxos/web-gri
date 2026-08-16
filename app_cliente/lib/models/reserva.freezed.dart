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

 String get id; String get restauranteId; String get restauranteNombre; String get mesaId; int get mesaNumero; String get usuarioId; DateTime get fecha; String get fechaStr; int get hora; int get numPersonas; String get estado; DateTime? get createdAt;
/// Create a copy of Reserva
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ReservaCopyWith<Reserva> get copyWith => _$ReservaCopyWithImpl<Reserva>(this as Reserva, _$identity);

  /// Serializes this Reserva to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Reserva&&(identical(other.id, id) || other.id == id)&&(identical(other.restauranteId, restauranteId) || other.restauranteId == restauranteId)&&(identical(other.restauranteNombre, restauranteNombre) || other.restauranteNombre == restauranteNombre)&&(identical(other.mesaId, mesaId) || other.mesaId == mesaId)&&(identical(other.mesaNumero, mesaNumero) || other.mesaNumero == mesaNumero)&&(identical(other.usuarioId, usuarioId) || other.usuarioId == usuarioId)&&(identical(other.fecha, fecha) || other.fecha == fecha)&&(identical(other.fechaStr, fechaStr) || other.fechaStr == fechaStr)&&(identical(other.hora, hora) || other.hora == hora)&&(identical(other.numPersonas, numPersonas) || other.numPersonas == numPersonas)&&(identical(other.estado, estado) || other.estado == estado)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,restauranteId,restauranteNombre,mesaId,mesaNumero,usuarioId,fecha,fechaStr,hora,numPersonas,estado,createdAt);

@override
String toString() {
  return 'Reserva(id: $id, restauranteId: $restauranteId, restauranteNombre: $restauranteNombre, mesaId: $mesaId, mesaNumero: $mesaNumero, usuarioId: $usuarioId, fecha: $fecha, fechaStr: $fechaStr, hora: $hora, numPersonas: $numPersonas, estado: $estado, createdAt: $createdAt)';
}


}

/// @nodoc
abstract mixin class $ReservaCopyWith<$Res>  {
  factory $ReservaCopyWith(Reserva value, $Res Function(Reserva) _then) = _$ReservaCopyWithImpl;
@useResult
$Res call({
 String id, String restauranteId, String restauranteNombre, String mesaId, int mesaNumero, String usuarioId, DateTime fecha, String fechaStr, int hora, int numPersonas, String estado, DateTime? createdAt
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
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? restauranteId = null,Object? restauranteNombre = null,Object? mesaId = null,Object? mesaNumero = null,Object? usuarioId = null,Object? fecha = null,Object? fechaStr = null,Object? hora = null,Object? numPersonas = null,Object? estado = null,Object? createdAt = freezed,}) {
  return _then(Reserva(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,restauranteId: null == restauranteId ? _self.restauranteId : restauranteId // ignore: cast_nullable_to_non_nullable
as String,restauranteNombre: null == restauranteNombre ? _self.restauranteNombre : restauranteNombre // ignore: cast_nullable_to_non_nullable
as String,mesaId: null == mesaId ? _self.mesaId : mesaId // ignore: cast_nullable_to_non_nullable
as String,mesaNumero: null == mesaNumero ? _self.mesaNumero : mesaNumero // ignore: cast_nullable_to_non_nullable
as int,usuarioId: null == usuarioId ? _self.usuarioId : usuarioId // ignore: cast_nullable_to_non_nullable
as String,fecha: null == fecha ? _self.fecha : fecha // ignore: cast_nullable_to_non_nullable
as DateTime,fechaStr: null == fechaStr ? _self.fechaStr : fechaStr // ignore: cast_nullable_to_non_nullable
as String,hora: null == hora ? _self.hora : hora // ignore: cast_nullable_to_non_nullable
as int,numPersonas: null == numPersonas ? _self.numPersonas : numPersonas // ignore: cast_nullable_to_non_nullable
as int,estado: null == estado ? _self.estado : estado // ignore: cast_nullable_to_non_nullable
as String,createdAt: freezed == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime?,
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String restauranteId,  String restauranteNombre,  String mesaId,  int mesaNumero,  String usuarioId,  DateTime fecha,  String fechaStr,  int hora,  int numPersonas,  String estado,  DateTime? createdAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Reserva() when $default != null:
return $default(_that.id,_that.restauranteId,_that.restauranteNombre,_that.mesaId,_that.mesaNumero,_that.usuarioId,_that.fecha,_that.fechaStr,_that.hora,_that.numPersonas,_that.estado,_that.createdAt);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String restauranteId,  String restauranteNombre,  String mesaId,  int mesaNumero,  String usuarioId,  DateTime fecha,  String fechaStr,  int hora,  int numPersonas,  String estado,  DateTime? createdAt)  $default,) {final _that = this;
switch (_that) {
case _Reserva():
return $default(_that.id,_that.restauranteId,_that.restauranteNombre,_that.mesaId,_that.mesaNumero,_that.usuarioId,_that.fecha,_that.fechaStr,_that.hora,_that.numPersonas,_that.estado,_that.createdAt);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String restauranteId,  String restauranteNombre,  String mesaId,  int mesaNumero,  String usuarioId,  DateTime fecha,  String fechaStr,  int hora,  int numPersonas,  String estado,  DateTime? createdAt)?  $default,) {final _that = this;
switch (_that) {
case _Reserva() when $default != null:
return $default(_that.id,_that.restauranteId,_that.restauranteNombre,_that.mesaId,_that.mesaNumero,_that.usuarioId,_that.fecha,_that.fechaStr,_that.hora,_that.numPersonas,_that.estado,_that.createdAt);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _Reserva extends Reserva {
  const _Reserva({required this.id, required this.restauranteId, this.restauranteNombre = '', required this.mesaId, required this.mesaNumero, required this.usuarioId, required this.fecha, required this.fechaStr, required this.hora, required this.numPersonas, required this.estado, this.createdAt}): super._();
  factory _Reserva.fromJson(Map<String, dynamic> json) => _$ReservaFromJson(json);

@override final  String id;
@override final  String restauranteId;
@override@JsonKey() final  String restauranteNombre;
@override final  String mesaId;
@override final  int mesaNumero;
@override final  String usuarioId;
@override final  DateTime fecha;
@override final  String fechaStr;
@override final  int hora;
@override final  int numPersonas;
@override final  String estado;
@override final  DateTime? createdAt;

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
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _Reserva&&(identical(other.id, id) || other.id == id)&&(identical(other.restauranteId, restauranteId) || other.restauranteId == restauranteId)&&(identical(other.restauranteNombre, restauranteNombre) || other.restauranteNombre == restauranteNombre)&&(identical(other.mesaId, mesaId) || other.mesaId == mesaId)&&(identical(other.mesaNumero, mesaNumero) || other.mesaNumero == mesaNumero)&&(identical(other.usuarioId, usuarioId) || other.usuarioId == usuarioId)&&(identical(other.fecha, fecha) || other.fecha == fecha)&&(identical(other.fechaStr, fechaStr) || other.fechaStr == fechaStr)&&(identical(other.hora, hora) || other.hora == hora)&&(identical(other.numPersonas, numPersonas) || other.numPersonas == numPersonas)&&(identical(other.estado, estado) || other.estado == estado)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,restauranteId,restauranteNombre,mesaId,mesaNumero,usuarioId,fecha,fechaStr,hora,numPersonas,estado,createdAt);

@override
String toString() {
  return 'Reserva(id: $id, restauranteId: $restauranteId, restauranteNombre: $restauranteNombre, mesaId: $mesaId, mesaNumero: $mesaNumero, usuarioId: $usuarioId, fecha: $fecha, fechaStr: $fechaStr, hora: $hora, numPersonas: $numPersonas, estado: $estado, createdAt: $createdAt)';
}


}

/// @nodoc
abstract mixin class _$ReservaCopyWith<$Res> implements $ReservaCopyWith<$Res> {
  factory _$ReservaCopyWith(_Reserva value, $Res Function(_Reserva) _then) = __$ReservaCopyWithImpl;
@override @useResult
$Res call({
 String id, String restauranteId, String restauranteNombre, String mesaId, int mesaNumero, String usuarioId, DateTime fecha, String fechaStr, int hora, int numPersonas, String estado, DateTime? createdAt
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
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? restauranteId = null,Object? restauranteNombre = null,Object? mesaId = null,Object? mesaNumero = null,Object? usuarioId = null,Object? fecha = null,Object? fechaStr = null,Object? hora = null,Object? numPersonas = null,Object? estado = null,Object? createdAt = freezed,}) {
  return _then(_Reserva(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,restauranteId: null == restauranteId ? _self.restauranteId : restauranteId // ignore: cast_nullable_to_non_nullable
as String,restauranteNombre: null == restauranteNombre ? _self.restauranteNombre : restauranteNombre // ignore: cast_nullable_to_non_nullable
as String,mesaId: null == mesaId ? _self.mesaId : mesaId // ignore: cast_nullable_to_non_nullable
as String,mesaNumero: null == mesaNumero ? _self.mesaNumero : mesaNumero // ignore: cast_nullable_to_non_nullable
as int,usuarioId: null == usuarioId ? _self.usuarioId : usuarioId // ignore: cast_nullable_to_non_nullable
as String,fecha: null == fecha ? _self.fecha : fecha // ignore: cast_nullable_to_non_nullable
as DateTime,fechaStr: null == fechaStr ? _self.fechaStr : fechaStr // ignore: cast_nullable_to_non_nullable
as String,hora: null == hora ? _self.hora : hora // ignore: cast_nullable_to_non_nullable
as int,numPersonas: null == numPersonas ? _self.numPersonas : numPersonas // ignore: cast_nullable_to_non_nullable
as int,estado: null == estado ? _self.estado : estado // ignore: cast_nullable_to_non_nullable
as String,createdAt: freezed == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}


}

// dart format on
