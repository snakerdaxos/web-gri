// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'sesion_mesa.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$SesionMesa {

/// Doc ID (= mesaId = código QR de la mesa).
 String get id; String get restauranteId; String get mesaId; String get usuarioId;/// `activa | cerrada | expirada` (sesionTransitions de state_machines).
 String get estado;/// Flag "pedir la cuenta" — visible para el staff en vivo.
 bool get cuentaSolicitada; DateTime? get cuentaPedidaAt; DateTime? get inicioAt; DateTime? get cerradaAt; String get restauranteNombre; int get mesaNumero;
/// Create a copy of SesionMesa
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SesionMesaCopyWith<SesionMesa> get copyWith => _$SesionMesaCopyWithImpl<SesionMesa>(this as SesionMesa, _$identity);

  /// Serializes this SesionMesa to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SesionMesa&&(identical(other.id, id) || other.id == id)&&(identical(other.restauranteId, restauranteId) || other.restauranteId == restauranteId)&&(identical(other.mesaId, mesaId) || other.mesaId == mesaId)&&(identical(other.usuarioId, usuarioId) || other.usuarioId == usuarioId)&&(identical(other.estado, estado) || other.estado == estado)&&(identical(other.cuentaSolicitada, cuentaSolicitada) || other.cuentaSolicitada == cuentaSolicitada)&&(identical(other.cuentaPedidaAt, cuentaPedidaAt) || other.cuentaPedidaAt == cuentaPedidaAt)&&(identical(other.inicioAt, inicioAt) || other.inicioAt == inicioAt)&&(identical(other.cerradaAt, cerradaAt) || other.cerradaAt == cerradaAt)&&(identical(other.restauranteNombre, restauranteNombre) || other.restauranteNombre == restauranteNombre)&&(identical(other.mesaNumero, mesaNumero) || other.mesaNumero == mesaNumero));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,restauranteId,mesaId,usuarioId,estado,cuentaSolicitada,cuentaPedidaAt,inicioAt,cerradaAt,restauranteNombre,mesaNumero);

@override
String toString() {
  return 'SesionMesa(id: $id, restauranteId: $restauranteId, mesaId: $mesaId, usuarioId: $usuarioId, estado: $estado, cuentaSolicitada: $cuentaSolicitada, cuentaPedidaAt: $cuentaPedidaAt, inicioAt: $inicioAt, cerradaAt: $cerradaAt, restauranteNombre: $restauranteNombre, mesaNumero: $mesaNumero)';
}


}

/// @nodoc
abstract mixin class $SesionMesaCopyWith<$Res>  {
  factory $SesionMesaCopyWith(SesionMesa value, $Res Function(SesionMesa) _then) = _$SesionMesaCopyWithImpl;
@useResult
$Res call({
 String id, String restauranteId, String mesaId, String usuarioId, String estado, bool cuentaSolicitada, DateTime? cuentaPedidaAt, DateTime? inicioAt, DateTime? cerradaAt, String restauranteNombre, int mesaNumero
});




}
/// @nodoc
class _$SesionMesaCopyWithImpl<$Res>
    implements $SesionMesaCopyWith<$Res> {
  _$SesionMesaCopyWithImpl(this._self, this._then);

  final SesionMesa _self;
  final $Res Function(SesionMesa) _then;

/// Create a copy of SesionMesa
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? restauranteId = null,Object? mesaId = null,Object? usuarioId = null,Object? estado = null,Object? cuentaSolicitada = null,Object? cuentaPedidaAt = freezed,Object? inicioAt = freezed,Object? cerradaAt = freezed,Object? restauranteNombre = null,Object? mesaNumero = null,}) {
  return _then(SesionMesa(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,restauranteId: null == restauranteId ? _self.restauranteId : restauranteId // ignore: cast_nullable_to_non_nullable
as String,mesaId: null == mesaId ? _self.mesaId : mesaId // ignore: cast_nullable_to_non_nullable
as String,usuarioId: null == usuarioId ? _self.usuarioId : usuarioId // ignore: cast_nullable_to_non_nullable
as String,estado: null == estado ? _self.estado : estado // ignore: cast_nullable_to_non_nullable
as String,cuentaSolicitada: null == cuentaSolicitada ? _self.cuentaSolicitada : cuentaSolicitada // ignore: cast_nullable_to_non_nullable
as bool,cuentaPedidaAt: freezed == cuentaPedidaAt ? _self.cuentaPedidaAt : cuentaPedidaAt // ignore: cast_nullable_to_non_nullable
as DateTime?,inicioAt: freezed == inicioAt ? _self.inicioAt : inicioAt // ignore: cast_nullable_to_non_nullable
as DateTime?,cerradaAt: freezed == cerradaAt ? _self.cerradaAt : cerradaAt // ignore: cast_nullable_to_non_nullable
as DateTime?,restauranteNombre: null == restauranteNombre ? _self.restauranteNombre : restauranteNombre // ignore: cast_nullable_to_non_nullable
as String,mesaNumero: null == mesaNumero ? _self.mesaNumero : mesaNumero // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}


/// Adds pattern-matching-related methods to [SesionMesa].
extension SesionMesaPatterns on SesionMesa {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _SesionMesa value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _SesionMesa() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _SesionMesa value)  $default,){
final _that = this;
switch (_that) {
case _SesionMesa():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _SesionMesa value)?  $default,){
final _that = this;
switch (_that) {
case _SesionMesa() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String restauranteId,  String mesaId,  String usuarioId,  String estado,  bool cuentaSolicitada,  DateTime? cuentaPedidaAt,  DateTime? inicioAt,  DateTime? cerradaAt,  String restauranteNombre,  int mesaNumero)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _SesionMesa() when $default != null:
return $default(_that.id,_that.restauranteId,_that.mesaId,_that.usuarioId,_that.estado,_that.cuentaSolicitada,_that.cuentaPedidaAt,_that.inicioAt,_that.cerradaAt,_that.restauranteNombre,_that.mesaNumero);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String restauranteId,  String mesaId,  String usuarioId,  String estado,  bool cuentaSolicitada,  DateTime? cuentaPedidaAt,  DateTime? inicioAt,  DateTime? cerradaAt,  String restauranteNombre,  int mesaNumero)  $default,) {final _that = this;
switch (_that) {
case _SesionMesa():
return $default(_that.id,_that.restauranteId,_that.mesaId,_that.usuarioId,_that.estado,_that.cuentaSolicitada,_that.cuentaPedidaAt,_that.inicioAt,_that.cerradaAt,_that.restauranteNombre,_that.mesaNumero);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String restauranteId,  String mesaId,  String usuarioId,  String estado,  bool cuentaSolicitada,  DateTime? cuentaPedidaAt,  DateTime? inicioAt,  DateTime? cerradaAt,  String restauranteNombre,  int mesaNumero)?  $default,) {final _that = this;
switch (_that) {
case _SesionMesa() when $default != null:
return $default(_that.id,_that.restauranteId,_that.mesaId,_that.usuarioId,_that.estado,_that.cuentaSolicitada,_that.cuentaPedidaAt,_that.inicioAt,_that.cerradaAt,_that.restauranteNombre,_that.mesaNumero);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _SesionMesa implements SesionMesa {
  const _SesionMesa({required this.id, required this.restauranteId, required this.mesaId, required this.usuarioId, this.estado = 'activa', this.cuentaSolicitada = false, this.cuentaPedidaAt, this.inicioAt, this.cerradaAt, this.restauranteNombre = '', this.mesaNumero = 0});
  factory _SesionMesa.fromJson(Map<String, dynamic> json) => _$SesionMesaFromJson(json);

/// Doc ID (= mesaId = código QR de la mesa).
@override final  String id;
@override final  String restauranteId;
@override final  String mesaId;
@override final  String usuarioId;
/// `activa | cerrada | expirada` (sesionTransitions de state_machines).
@override@JsonKey() final  String estado;
/// Flag "pedir la cuenta" — visible para el staff en vivo.
@override@JsonKey() final  bool cuentaSolicitada;
@override final  DateTime? cuentaPedidaAt;
@override final  DateTime? inicioAt;
@override final  DateTime? cerradaAt;
@override@JsonKey() final  String restauranteNombre;
@override@JsonKey() final  int mesaNumero;

/// Create a copy of SesionMesa
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$SesionMesaCopyWith<_SesionMesa> get copyWith => __$SesionMesaCopyWithImpl<_SesionMesa>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$SesionMesaToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _SesionMesa&&(identical(other.id, id) || other.id == id)&&(identical(other.restauranteId, restauranteId) || other.restauranteId == restauranteId)&&(identical(other.mesaId, mesaId) || other.mesaId == mesaId)&&(identical(other.usuarioId, usuarioId) || other.usuarioId == usuarioId)&&(identical(other.estado, estado) || other.estado == estado)&&(identical(other.cuentaSolicitada, cuentaSolicitada) || other.cuentaSolicitada == cuentaSolicitada)&&(identical(other.cuentaPedidaAt, cuentaPedidaAt) || other.cuentaPedidaAt == cuentaPedidaAt)&&(identical(other.inicioAt, inicioAt) || other.inicioAt == inicioAt)&&(identical(other.cerradaAt, cerradaAt) || other.cerradaAt == cerradaAt)&&(identical(other.restauranteNombre, restauranteNombre) || other.restauranteNombre == restauranteNombre)&&(identical(other.mesaNumero, mesaNumero) || other.mesaNumero == mesaNumero));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,restauranteId,mesaId,usuarioId,estado,cuentaSolicitada,cuentaPedidaAt,inicioAt,cerradaAt,restauranteNombre,mesaNumero);

@override
String toString() {
  return 'SesionMesa(id: $id, restauranteId: $restauranteId, mesaId: $mesaId, usuarioId: $usuarioId, estado: $estado, cuentaSolicitada: $cuentaSolicitada, cuentaPedidaAt: $cuentaPedidaAt, inicioAt: $inicioAt, cerradaAt: $cerradaAt, restauranteNombre: $restauranteNombre, mesaNumero: $mesaNumero)';
}


}

/// @nodoc
abstract mixin class _$SesionMesaCopyWith<$Res> implements $SesionMesaCopyWith<$Res> {
  factory _$SesionMesaCopyWith(_SesionMesa value, $Res Function(_SesionMesa) _then) = __$SesionMesaCopyWithImpl;
@override @useResult
$Res call({
 String id, String restauranteId, String mesaId, String usuarioId, String estado, bool cuentaSolicitada, DateTime? cuentaPedidaAt, DateTime? inicioAt, DateTime? cerradaAt, String restauranteNombre, int mesaNumero
});




}
/// @nodoc
class __$SesionMesaCopyWithImpl<$Res>
    implements _$SesionMesaCopyWith<$Res> {
  __$SesionMesaCopyWithImpl(this._self, this._then);

  final _SesionMesa _self;
  final $Res Function(_SesionMesa) _then;

/// Create a copy of SesionMesa
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? restauranteId = null,Object? mesaId = null,Object? usuarioId = null,Object? estado = null,Object? cuentaSolicitada = null,Object? cuentaPedidaAt = freezed,Object? inicioAt = freezed,Object? cerradaAt = freezed,Object? restauranteNombre = null,Object? mesaNumero = null,}) {
  return _then(_SesionMesa(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,restauranteId: null == restauranteId ? _self.restauranteId : restauranteId // ignore: cast_nullable_to_non_nullable
as String,mesaId: null == mesaId ? _self.mesaId : mesaId // ignore: cast_nullable_to_non_nullable
as String,usuarioId: null == usuarioId ? _self.usuarioId : usuarioId // ignore: cast_nullable_to_non_nullable
as String,estado: null == estado ? _self.estado : estado // ignore: cast_nullable_to_non_nullable
as String,cuentaSolicitada: null == cuentaSolicitada ? _self.cuentaSolicitada : cuentaSolicitada // ignore: cast_nullable_to_non_nullable
as bool,cuentaPedidaAt: freezed == cuentaPedidaAt ? _self.cuentaPedidaAt : cuentaPedidaAt // ignore: cast_nullable_to_non_nullable
as DateTime?,inicioAt: freezed == inicioAt ? _self.inicioAt : inicioAt // ignore: cast_nullable_to_non_nullable
as DateTime?,cerradaAt: freezed == cerradaAt ? _self.cerradaAt : cerradaAt // ignore: cast_nullable_to_non_nullable
as DateTime?,restauranteNombre: null == restauranteNombre ? _self.restauranteNombre : restauranteNombre // ignore: cast_nullable_to_non_nullable
as String,mesaNumero: null == mesaNumero ? _self.mesaNumero : mesaNumero // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

// dart format on
