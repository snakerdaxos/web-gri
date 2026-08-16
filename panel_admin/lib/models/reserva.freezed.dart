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

 String get id;/// Tenant de la reserva — TODA query filtra por el rid activo.
 String get restauranteId;/// Código QR de la mesa (doc ID determinista).
 String get mesaId;/// Derivado del sufijo numérico del [mesaId].
 int get mesaNumero; DateTime get fecha; int get numPersonas; String get estado;/// UID del cliente (solo identidad — el nombre vive denormalizado en
/// pedidos; las reservas no lo llevan en v1).
 String get usuarioId;
/// Create a copy of Reserva
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ReservaCopyWith<Reserva> get copyWith => _$ReservaCopyWithImpl<Reserva>(this as Reserva, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Reserva&&(identical(other.id, id) || other.id == id)&&(identical(other.restauranteId, restauranteId) || other.restauranteId == restauranteId)&&(identical(other.mesaId, mesaId) || other.mesaId == mesaId)&&(identical(other.mesaNumero, mesaNumero) || other.mesaNumero == mesaNumero)&&(identical(other.fecha, fecha) || other.fecha == fecha)&&(identical(other.numPersonas, numPersonas) || other.numPersonas == numPersonas)&&(identical(other.estado, estado) || other.estado == estado)&&(identical(other.usuarioId, usuarioId) || other.usuarioId == usuarioId));
}


@override
int get hashCode => Object.hash(runtimeType,id,restauranteId,mesaId,mesaNumero,fecha,numPersonas,estado,usuarioId);

@override
String toString() {
  return 'Reserva(id: $id, restauranteId: $restauranteId, mesaId: $mesaId, mesaNumero: $mesaNumero, fecha: $fecha, numPersonas: $numPersonas, estado: $estado, usuarioId: $usuarioId)';
}


}

/// @nodoc
abstract mixin class $ReservaCopyWith<$Res>  {
  factory $ReservaCopyWith(Reserva value, $Res Function(Reserva) _then) = _$ReservaCopyWithImpl;
@useResult
$Res call({
 String id, String restauranteId, String mesaId, int mesaNumero, DateTime fecha, int numPersonas, String estado, String usuarioId
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
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? restauranteId = null,Object? mesaId = null,Object? mesaNumero = null,Object? fecha = null,Object? numPersonas = null,Object? estado = null,Object? usuarioId = null,}) {
  return _then(Reserva(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,restauranteId: null == restauranteId ? _self.restauranteId : restauranteId // ignore: cast_nullable_to_non_nullable
as String,mesaId: null == mesaId ? _self.mesaId : mesaId // ignore: cast_nullable_to_non_nullable
as String,mesaNumero: null == mesaNumero ? _self.mesaNumero : mesaNumero // ignore: cast_nullable_to_non_nullable
as int,fecha: null == fecha ? _self.fecha : fecha // ignore: cast_nullable_to_non_nullable
as DateTime,numPersonas: null == numPersonas ? _self.numPersonas : numPersonas // ignore: cast_nullable_to_non_nullable
as int,estado: null == estado ? _self.estado : estado // ignore: cast_nullable_to_non_nullable
as String,usuarioId: null == usuarioId ? _self.usuarioId : usuarioId // ignore: cast_nullable_to_non_nullable
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String restauranteId,  String mesaId,  int mesaNumero,  DateTime fecha,  int numPersonas,  String estado,  String usuarioId)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Reserva() when $default != null:
return $default(_that.id,_that.restauranteId,_that.mesaId,_that.mesaNumero,_that.fecha,_that.numPersonas,_that.estado,_that.usuarioId);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String restauranteId,  String mesaId,  int mesaNumero,  DateTime fecha,  int numPersonas,  String estado,  String usuarioId)  $default,) {final _that = this;
switch (_that) {
case _Reserva():
return $default(_that.id,_that.restauranteId,_that.mesaId,_that.mesaNumero,_that.fecha,_that.numPersonas,_that.estado,_that.usuarioId);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String restauranteId,  String mesaId,  int mesaNumero,  DateTime fecha,  int numPersonas,  String estado,  String usuarioId)?  $default,) {final _that = this;
switch (_that) {
case _Reserva() when $default != null:
return $default(_that.id,_that.restauranteId,_that.mesaId,_that.mesaNumero,_that.fecha,_that.numPersonas,_that.estado,_that.usuarioId);case _:
  return null;

}
}

}

/// @nodoc


class _Reserva implements Reserva {
  const _Reserva({required this.id, this.restauranteId = '', required this.mesaId, required this.mesaNumero, required this.fecha, required this.numPersonas, required this.estado, this.usuarioId = ''});
  

@override final  String id;
/// Tenant de la reserva — TODA query filtra por el rid activo.
@override@JsonKey() final  String restauranteId;
/// Código QR de la mesa (doc ID determinista).
@override final  String mesaId;
/// Derivado del sufijo numérico del [mesaId].
@override final  int mesaNumero;
@override final  DateTime fecha;
@override final  int numPersonas;
@override final  String estado;
/// UID del cliente (solo identidad — el nombre vive denormalizado en
/// pedidos; las reservas no lo llevan en v1).
@override@JsonKey() final  String usuarioId;

/// Create a copy of Reserva
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ReservaCopyWith<_Reserva> get copyWith => __$ReservaCopyWithImpl<_Reserva>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _Reserva&&(identical(other.id, id) || other.id == id)&&(identical(other.restauranteId, restauranteId) || other.restauranteId == restauranteId)&&(identical(other.mesaId, mesaId) || other.mesaId == mesaId)&&(identical(other.mesaNumero, mesaNumero) || other.mesaNumero == mesaNumero)&&(identical(other.fecha, fecha) || other.fecha == fecha)&&(identical(other.numPersonas, numPersonas) || other.numPersonas == numPersonas)&&(identical(other.estado, estado) || other.estado == estado)&&(identical(other.usuarioId, usuarioId) || other.usuarioId == usuarioId));
}


@override
int get hashCode => Object.hash(runtimeType,id,restauranteId,mesaId,mesaNumero,fecha,numPersonas,estado,usuarioId);

@override
String toString() {
  return 'Reserva(id: $id, restauranteId: $restauranteId, mesaId: $mesaId, mesaNumero: $mesaNumero, fecha: $fecha, numPersonas: $numPersonas, estado: $estado, usuarioId: $usuarioId)';
}


}

/// @nodoc
abstract mixin class _$ReservaCopyWith<$Res> implements $ReservaCopyWith<$Res> {
  factory _$ReservaCopyWith(_Reserva value, $Res Function(_Reserva) _then) = __$ReservaCopyWithImpl;
@override @useResult
$Res call({
 String id, String restauranteId, String mesaId, int mesaNumero, DateTime fecha, int numPersonas, String estado, String usuarioId
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
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? restauranteId = null,Object? mesaId = null,Object? mesaNumero = null,Object? fecha = null,Object? numPersonas = null,Object? estado = null,Object? usuarioId = null,}) {
  return _then(_Reserva(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,restauranteId: null == restauranteId ? _self.restauranteId : restauranteId // ignore: cast_nullable_to_non_nullable
as String,mesaId: null == mesaId ? _self.mesaId : mesaId // ignore: cast_nullable_to_non_nullable
as String,mesaNumero: null == mesaNumero ? _self.mesaNumero : mesaNumero // ignore: cast_nullable_to_non_nullable
as int,fecha: null == fecha ? _self.fecha : fecha // ignore: cast_nullable_to_non_nullable
as DateTime,numPersonas: null == numPersonas ? _self.numPersonas : numPersonas // ignore: cast_nullable_to_non_nullable
as int,estado: null == estado ? _self.estado : estado // ignore: cast_nullable_to_non_nullable
as String,usuarioId: null == usuarioId ? _self.usuarioId : usuarioId // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

// dart format on
