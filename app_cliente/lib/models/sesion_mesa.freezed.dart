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

 int get id;@JsonKey(name: 'restaurante_id') int get restauranteId;@JsonKey(name: 'restaurante_nombre') String get restauranteNombre;@JsonKey(name: 'mesa_id') int get mesaId;@JsonKey(name: 'mesa_numero') int get mesaNumero;@JsonKey(name: 'abierta_en') DateTime get abiertaEn;@JsonKey(name: 'solicita_cuenta') bool get solicitaCuenta;@JsonKey(name: 'solicitada_en') DateTime? get solicitadaEn;
/// Create a copy of SesionMesa
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SesionMesaCopyWith<SesionMesa> get copyWith => _$SesionMesaCopyWithImpl<SesionMesa>(this as SesionMesa, _$identity);

  /// Serializes this SesionMesa to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SesionMesa&&(identical(other.id, id) || other.id == id)&&(identical(other.restauranteId, restauranteId) || other.restauranteId == restauranteId)&&(identical(other.restauranteNombre, restauranteNombre) || other.restauranteNombre == restauranteNombre)&&(identical(other.mesaId, mesaId) || other.mesaId == mesaId)&&(identical(other.mesaNumero, mesaNumero) || other.mesaNumero == mesaNumero)&&(identical(other.abiertaEn, abiertaEn) || other.abiertaEn == abiertaEn)&&(identical(other.solicitaCuenta, solicitaCuenta) || other.solicitaCuenta == solicitaCuenta)&&(identical(other.solicitadaEn, solicitadaEn) || other.solicitadaEn == solicitadaEn));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,restauranteId,restauranteNombre,mesaId,mesaNumero,abiertaEn,solicitaCuenta,solicitadaEn);

@override
String toString() {
  return 'SesionMesa(id: $id, restauranteId: $restauranteId, restauranteNombre: $restauranteNombre, mesaId: $mesaId, mesaNumero: $mesaNumero, abiertaEn: $abiertaEn, solicitaCuenta: $solicitaCuenta, solicitadaEn: $solicitadaEn)';
}


}

/// @nodoc
abstract mixin class $SesionMesaCopyWith<$Res>  {
  factory $SesionMesaCopyWith(SesionMesa value, $Res Function(SesionMesa) _then) = _$SesionMesaCopyWithImpl;
@useResult
$Res call({
 int id,@JsonKey(name: 'restaurante_id') int restauranteId,@JsonKey(name: 'restaurante_nombre') String restauranteNombre,@JsonKey(name: 'mesa_id') int mesaId,@JsonKey(name: 'mesa_numero') int mesaNumero,@JsonKey(name: 'abierta_en') DateTime abiertaEn,@JsonKey(name: 'solicita_cuenta') bool solicitaCuenta,@JsonKey(name: 'solicitada_en') DateTime? solicitadaEn
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
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? restauranteId = null,Object? restauranteNombre = null,Object? mesaId = null,Object? mesaNumero = null,Object? abiertaEn = null,Object? solicitaCuenta = null,Object? solicitadaEn = freezed,}) {
  return _then(SesionMesa(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,restauranteId: null == restauranteId ? _self.restauranteId : restauranteId // ignore: cast_nullable_to_non_nullable
as int,restauranteNombre: null == restauranteNombre ? _self.restauranteNombre : restauranteNombre // ignore: cast_nullable_to_non_nullable
as String,mesaId: null == mesaId ? _self.mesaId : mesaId // ignore: cast_nullable_to_non_nullable
as int,mesaNumero: null == mesaNumero ? _self.mesaNumero : mesaNumero // ignore: cast_nullable_to_non_nullable
as int,abiertaEn: null == abiertaEn ? _self.abiertaEn : abiertaEn // ignore: cast_nullable_to_non_nullable
as DateTime,solicitaCuenta: null == solicitaCuenta ? _self.solicitaCuenta : solicitaCuenta // ignore: cast_nullable_to_non_nullable
as bool,solicitadaEn: freezed == solicitadaEn ? _self.solicitadaEn : solicitadaEn // ignore: cast_nullable_to_non_nullable
as DateTime?,
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int id, @JsonKey(name: 'restaurante_id')  int restauranteId, @JsonKey(name: 'restaurante_nombre')  String restauranteNombre, @JsonKey(name: 'mesa_id')  int mesaId, @JsonKey(name: 'mesa_numero')  int mesaNumero, @JsonKey(name: 'abierta_en')  DateTime abiertaEn, @JsonKey(name: 'solicita_cuenta')  bool solicitaCuenta, @JsonKey(name: 'solicitada_en')  DateTime? solicitadaEn)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _SesionMesa() when $default != null:
return $default(_that.id,_that.restauranteId,_that.restauranteNombre,_that.mesaId,_that.mesaNumero,_that.abiertaEn,_that.solicitaCuenta,_that.solicitadaEn);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int id, @JsonKey(name: 'restaurante_id')  int restauranteId, @JsonKey(name: 'restaurante_nombre')  String restauranteNombre, @JsonKey(name: 'mesa_id')  int mesaId, @JsonKey(name: 'mesa_numero')  int mesaNumero, @JsonKey(name: 'abierta_en')  DateTime abiertaEn, @JsonKey(name: 'solicita_cuenta')  bool solicitaCuenta, @JsonKey(name: 'solicitada_en')  DateTime? solicitadaEn)  $default,) {final _that = this;
switch (_that) {
case _SesionMesa():
return $default(_that.id,_that.restauranteId,_that.restauranteNombre,_that.mesaId,_that.mesaNumero,_that.abiertaEn,_that.solicitaCuenta,_that.solicitadaEn);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int id, @JsonKey(name: 'restaurante_id')  int restauranteId, @JsonKey(name: 'restaurante_nombre')  String restauranteNombre, @JsonKey(name: 'mesa_id')  int mesaId, @JsonKey(name: 'mesa_numero')  int mesaNumero, @JsonKey(name: 'abierta_en')  DateTime abiertaEn, @JsonKey(name: 'solicita_cuenta')  bool solicitaCuenta, @JsonKey(name: 'solicitada_en')  DateTime? solicitadaEn)?  $default,) {final _that = this;
switch (_that) {
case _SesionMesa() when $default != null:
return $default(_that.id,_that.restauranteId,_that.restauranteNombre,_that.mesaId,_that.mesaNumero,_that.abiertaEn,_that.solicitaCuenta,_that.solicitadaEn);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _SesionMesa implements SesionMesa {
  const _SesionMesa({required this.id, @JsonKey(name: 'restaurante_id') required this.restauranteId, @JsonKey(name: 'restaurante_nombre') required this.restauranteNombre, @JsonKey(name: 'mesa_id') required this.mesaId, @JsonKey(name: 'mesa_numero') required this.mesaNumero, @JsonKey(name: 'abierta_en') required this.abiertaEn, @JsonKey(name: 'solicita_cuenta') required this.solicitaCuenta, @JsonKey(name: 'solicitada_en') this.solicitadaEn});
  factory _SesionMesa.fromJson(Map<String, dynamic> json) => _$SesionMesaFromJson(json);

@override final  int id;
@override@JsonKey(name: 'restaurante_id') final  int restauranteId;
@override@JsonKey(name: 'restaurante_nombre') final  String restauranteNombre;
@override@JsonKey(name: 'mesa_id') final  int mesaId;
@override@JsonKey(name: 'mesa_numero') final  int mesaNumero;
@override@JsonKey(name: 'abierta_en') final  DateTime abiertaEn;
@override@JsonKey(name: 'solicita_cuenta') final  bool solicitaCuenta;
@override@JsonKey(name: 'solicitada_en') final  DateTime? solicitadaEn;

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
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _SesionMesa&&(identical(other.id, id) || other.id == id)&&(identical(other.restauranteId, restauranteId) || other.restauranteId == restauranteId)&&(identical(other.restauranteNombre, restauranteNombre) || other.restauranteNombre == restauranteNombre)&&(identical(other.mesaId, mesaId) || other.mesaId == mesaId)&&(identical(other.mesaNumero, mesaNumero) || other.mesaNumero == mesaNumero)&&(identical(other.abiertaEn, abiertaEn) || other.abiertaEn == abiertaEn)&&(identical(other.solicitaCuenta, solicitaCuenta) || other.solicitaCuenta == solicitaCuenta)&&(identical(other.solicitadaEn, solicitadaEn) || other.solicitadaEn == solicitadaEn));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,restauranteId,restauranteNombre,mesaId,mesaNumero,abiertaEn,solicitaCuenta,solicitadaEn);

@override
String toString() {
  return 'SesionMesa(id: $id, restauranteId: $restauranteId, restauranteNombre: $restauranteNombre, mesaId: $mesaId, mesaNumero: $mesaNumero, abiertaEn: $abiertaEn, solicitaCuenta: $solicitaCuenta, solicitadaEn: $solicitadaEn)';
}


}

/// @nodoc
abstract mixin class _$SesionMesaCopyWith<$Res> implements $SesionMesaCopyWith<$Res> {
  factory _$SesionMesaCopyWith(_SesionMesa value, $Res Function(_SesionMesa) _then) = __$SesionMesaCopyWithImpl;
@override @useResult
$Res call({
 int id,@JsonKey(name: 'restaurante_id') int restauranteId,@JsonKey(name: 'restaurante_nombre') String restauranteNombre,@JsonKey(name: 'mesa_id') int mesaId,@JsonKey(name: 'mesa_numero') int mesaNumero,@JsonKey(name: 'abierta_en') DateTime abiertaEn,@JsonKey(name: 'solicita_cuenta') bool solicitaCuenta,@JsonKey(name: 'solicitada_en') DateTime? solicitadaEn
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
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? restauranteId = null,Object? restauranteNombre = null,Object? mesaId = null,Object? mesaNumero = null,Object? abiertaEn = null,Object? solicitaCuenta = null,Object? solicitadaEn = freezed,}) {
  return _then(_SesionMesa(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,restauranteId: null == restauranteId ? _self.restauranteId : restauranteId // ignore: cast_nullable_to_non_nullable
as int,restauranteNombre: null == restauranteNombre ? _self.restauranteNombre : restauranteNombre // ignore: cast_nullable_to_non_nullable
as String,mesaId: null == mesaId ? _self.mesaId : mesaId // ignore: cast_nullable_to_non_nullable
as int,mesaNumero: null == mesaNumero ? _self.mesaNumero : mesaNumero // ignore: cast_nullable_to_non_nullable
as int,abiertaEn: null == abiertaEn ? _self.abiertaEn : abiertaEn // ignore: cast_nullable_to_non_nullable
as DateTime,solicitaCuenta: null == solicitaCuenta ? _self.solicitaCuenta : solicitaCuenta // ignore: cast_nullable_to_non_nullable
as bool,solicitadaEn: freezed == solicitadaEn ? _self.solicitadaEn : solicitadaEn // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}


}

// dart format on
