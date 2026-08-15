// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'pago.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$PagoIntencion {

@JsonKey(name: 'pago_id') int get pagoId; String get referencia; double get monto; String get estado;@JsonKey(name: 'checkout_url') String get checkoutUrl;
/// Create a copy of PagoIntencion
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PagoIntencionCopyWith<PagoIntencion> get copyWith => _$PagoIntencionCopyWithImpl<PagoIntencion>(this as PagoIntencion, _$identity);

  /// Serializes this PagoIntencion to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PagoIntencion&&(identical(other.pagoId, pagoId) || other.pagoId == pagoId)&&(identical(other.referencia, referencia) || other.referencia == referencia)&&(identical(other.monto, monto) || other.monto == monto)&&(identical(other.estado, estado) || other.estado == estado)&&(identical(other.checkoutUrl, checkoutUrl) || other.checkoutUrl == checkoutUrl));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,pagoId,referencia,monto,estado,checkoutUrl);

@override
String toString() {
  return 'PagoIntencion(pagoId: $pagoId, referencia: $referencia, monto: $monto, estado: $estado, checkoutUrl: $checkoutUrl)';
}


}

/// @nodoc
abstract mixin class $PagoIntencionCopyWith<$Res>  {
  factory $PagoIntencionCopyWith(PagoIntencion value, $Res Function(PagoIntencion) _then) = _$PagoIntencionCopyWithImpl;
@useResult
$Res call({
@JsonKey(name: 'pago_id') int pagoId, String referencia, double monto, String estado,@JsonKey(name: 'checkout_url') String checkoutUrl
});




}
/// @nodoc
class _$PagoIntencionCopyWithImpl<$Res>
    implements $PagoIntencionCopyWith<$Res> {
  _$PagoIntencionCopyWithImpl(this._self, this._then);

  final PagoIntencion _self;
  final $Res Function(PagoIntencion) _then;

/// Create a copy of PagoIntencion
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? pagoId = null,Object? referencia = null,Object? monto = null,Object? estado = null,Object? checkoutUrl = null,}) {
  return _then(PagoIntencion(
pagoId: null == pagoId ? _self.pagoId : pagoId // ignore: cast_nullable_to_non_nullable
as int,referencia: null == referencia ? _self.referencia : referencia // ignore: cast_nullable_to_non_nullable
as String,monto: null == monto ? _self.monto : monto // ignore: cast_nullable_to_non_nullable
as double,estado: null == estado ? _self.estado : estado // ignore: cast_nullable_to_non_nullable
as String,checkoutUrl: null == checkoutUrl ? _self.checkoutUrl : checkoutUrl // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [PagoIntencion].
extension PagoIntencionPatterns on PagoIntencion {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _PagoIntencion value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _PagoIntencion() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _PagoIntencion value)  $default,){
final _that = this;
switch (_that) {
case _PagoIntencion():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _PagoIntencion value)?  $default,){
final _that = this;
switch (_that) {
case _PagoIntencion() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function(@JsonKey(name: 'pago_id')  int pagoId,  String referencia,  double monto,  String estado, @JsonKey(name: 'checkout_url')  String checkoutUrl)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _PagoIntencion() when $default != null:
return $default(_that.pagoId,_that.referencia,_that.monto,_that.estado,_that.checkoutUrl);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function(@JsonKey(name: 'pago_id')  int pagoId,  String referencia,  double monto,  String estado, @JsonKey(name: 'checkout_url')  String checkoutUrl)  $default,) {final _that = this;
switch (_that) {
case _PagoIntencion():
return $default(_that.pagoId,_that.referencia,_that.monto,_that.estado,_that.checkoutUrl);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function(@JsonKey(name: 'pago_id')  int pagoId,  String referencia,  double monto,  String estado, @JsonKey(name: 'checkout_url')  String checkoutUrl)?  $default,) {final _that = this;
switch (_that) {
case _PagoIntencion() when $default != null:
return $default(_that.pagoId,_that.referencia,_that.monto,_that.estado,_that.checkoutUrl);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _PagoIntencion implements PagoIntencion {
  const _PagoIntencion({@JsonKey(name: 'pago_id') required this.pagoId, required this.referencia, required this.monto, required this.estado, @JsonKey(name: 'checkout_url') required this.checkoutUrl});
  factory _PagoIntencion.fromJson(Map<String, dynamic> json) => _$PagoIntencionFromJson(json);

@override@JsonKey(name: 'pago_id') final  int pagoId;
@override final  String referencia;
@override final  double monto;
@override final  String estado;
@override@JsonKey(name: 'checkout_url') final  String checkoutUrl;

/// Create a copy of PagoIntencion
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$PagoIntencionCopyWith<_PagoIntencion> get copyWith => __$PagoIntencionCopyWithImpl<_PagoIntencion>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$PagoIntencionToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _PagoIntencion&&(identical(other.pagoId, pagoId) || other.pagoId == pagoId)&&(identical(other.referencia, referencia) || other.referencia == referencia)&&(identical(other.monto, monto) || other.monto == monto)&&(identical(other.estado, estado) || other.estado == estado)&&(identical(other.checkoutUrl, checkoutUrl) || other.checkoutUrl == checkoutUrl));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,pagoId,referencia,monto,estado,checkoutUrl);

@override
String toString() {
  return 'PagoIntencion(pagoId: $pagoId, referencia: $referencia, monto: $monto, estado: $estado, checkoutUrl: $checkoutUrl)';
}


}

/// @nodoc
abstract mixin class _$PagoIntencionCopyWith<$Res> implements $PagoIntencionCopyWith<$Res> {
  factory _$PagoIntencionCopyWith(_PagoIntencion value, $Res Function(_PagoIntencion) _then) = __$PagoIntencionCopyWithImpl;
@override @useResult
$Res call({
@JsonKey(name: 'pago_id') int pagoId, String referencia, double monto, String estado,@JsonKey(name: 'checkout_url') String checkoutUrl
});




}
/// @nodoc
class __$PagoIntencionCopyWithImpl<$Res>
    implements _$PagoIntencionCopyWith<$Res> {
  __$PagoIntencionCopyWithImpl(this._self, this._then);

  final _PagoIntencion _self;
  final $Res Function(_PagoIntencion) _then;

/// Create a copy of PagoIntencion
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? pagoId = null,Object? referencia = null,Object? monto = null,Object? estado = null,Object? checkoutUrl = null,}) {
  return _then(_PagoIntencion(
pagoId: null == pagoId ? _self.pagoId : pagoId // ignore: cast_nullable_to_non_nullable
as int,referencia: null == referencia ? _self.referencia : referencia // ignore: cast_nullable_to_non_nullable
as String,monto: null == monto ? _self.monto : monto // ignore: cast_nullable_to_non_nullable
as double,estado: null == estado ? _self.estado : estado // ignore: cast_nullable_to_non_nullable
as String,checkoutUrl: null == checkoutUrl ? _self.checkoutUrl : checkoutUrl // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}


/// @nodoc
mixin _$PagoEstado {

@JsonKey(name: 'pago_id') int get pagoId; String get estado; String get referencia; double get monto;@JsonKey(name: 'pedido_ids') List<int> get pedidoIds;
/// Create a copy of PagoEstado
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PagoEstadoCopyWith<PagoEstado> get copyWith => _$PagoEstadoCopyWithImpl<PagoEstado>(this as PagoEstado, _$identity);

  /// Serializes this PagoEstado to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PagoEstado&&(identical(other.pagoId, pagoId) || other.pagoId == pagoId)&&(identical(other.estado, estado) || other.estado == estado)&&(identical(other.referencia, referencia) || other.referencia == referencia)&&(identical(other.monto, monto) || other.monto == monto)&&const DeepCollectionEquality().equals(other.pedidoIds, pedidoIds));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,pagoId,estado,referencia,monto,const DeepCollectionEquality().hash(pedidoIds));

@override
String toString() {
  return 'PagoEstado(pagoId: $pagoId, estado: $estado, referencia: $referencia, monto: $monto, pedidoIds: $pedidoIds)';
}


}

/// @nodoc
abstract mixin class $PagoEstadoCopyWith<$Res>  {
  factory $PagoEstadoCopyWith(PagoEstado value, $Res Function(PagoEstado) _then) = _$PagoEstadoCopyWithImpl;
@useResult
$Res call({
@JsonKey(name: 'pago_id') int pagoId, String estado, String referencia, double monto,@JsonKey(name: 'pedido_ids') List<int> pedidoIds
});




}
/// @nodoc
class _$PagoEstadoCopyWithImpl<$Res>
    implements $PagoEstadoCopyWith<$Res> {
  _$PagoEstadoCopyWithImpl(this._self, this._then);

  final PagoEstado _self;
  final $Res Function(PagoEstado) _then;

/// Create a copy of PagoEstado
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? pagoId = null,Object? estado = null,Object? referencia = null,Object? monto = null,Object? pedidoIds = null,}) {
  return _then(PagoEstado(
pagoId: null == pagoId ? _self.pagoId : pagoId // ignore: cast_nullable_to_non_nullable
as int,estado: null == estado ? _self.estado : estado // ignore: cast_nullable_to_non_nullable
as String,referencia: null == referencia ? _self.referencia : referencia // ignore: cast_nullable_to_non_nullable
as String,monto: null == monto ? _self.monto : monto // ignore: cast_nullable_to_non_nullable
as double,pedidoIds: null == pedidoIds ? _self.pedidoIds : pedidoIds // ignore: cast_nullable_to_non_nullable
as List<int>,
  ));
}

}


/// Adds pattern-matching-related methods to [PagoEstado].
extension PagoEstadoPatterns on PagoEstado {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _PagoEstado value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _PagoEstado() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _PagoEstado value)  $default,){
final _that = this;
switch (_that) {
case _PagoEstado():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _PagoEstado value)?  $default,){
final _that = this;
switch (_that) {
case _PagoEstado() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function(@JsonKey(name: 'pago_id')  int pagoId,  String estado,  String referencia,  double monto, @JsonKey(name: 'pedido_ids')  List<int> pedidoIds)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _PagoEstado() when $default != null:
return $default(_that.pagoId,_that.estado,_that.referencia,_that.monto,_that.pedidoIds);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function(@JsonKey(name: 'pago_id')  int pagoId,  String estado,  String referencia,  double monto, @JsonKey(name: 'pedido_ids')  List<int> pedidoIds)  $default,) {final _that = this;
switch (_that) {
case _PagoEstado():
return $default(_that.pagoId,_that.estado,_that.referencia,_that.monto,_that.pedidoIds);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function(@JsonKey(name: 'pago_id')  int pagoId,  String estado,  String referencia,  double monto, @JsonKey(name: 'pedido_ids')  List<int> pedidoIds)?  $default,) {final _that = this;
switch (_that) {
case _PagoEstado() when $default != null:
return $default(_that.pagoId,_that.estado,_that.referencia,_that.monto,_that.pedidoIds);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _PagoEstado implements PagoEstado {
  const _PagoEstado({@JsonKey(name: 'pago_id') required this.pagoId, required this.estado, required this.referencia, required this.monto, @JsonKey(name: 'pedido_ids') required  List<int> pedidoIds}): _pedidoIds = pedidoIds;
  factory _PagoEstado.fromJson(Map<String, dynamic> json) => _$PagoEstadoFromJson(json);

@override@JsonKey(name: 'pago_id') final  int pagoId;
@override final  String estado;
@override final  String referencia;
@override final  double monto;
 final  List<int> _pedidoIds;
@override@JsonKey(name: 'pedido_ids') List<int> get pedidoIds {
  if (_pedidoIds is EqualUnmodifiableListView) return _pedidoIds;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_pedidoIds);
}


/// Create a copy of PagoEstado
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$PagoEstadoCopyWith<_PagoEstado> get copyWith => __$PagoEstadoCopyWithImpl<_PagoEstado>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$PagoEstadoToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _PagoEstado&&(identical(other.pagoId, pagoId) || other.pagoId == pagoId)&&(identical(other.estado, estado) || other.estado == estado)&&(identical(other.referencia, referencia) || other.referencia == referencia)&&(identical(other.monto, monto) || other.monto == monto)&&const DeepCollectionEquality().equals(other._pedidoIds, _pedidoIds));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,pagoId,estado,referencia,monto,const DeepCollectionEquality().hash(_pedidoIds));

@override
String toString() {
  return 'PagoEstado(pagoId: $pagoId, estado: $estado, referencia: $referencia, monto: $monto, pedidoIds: $pedidoIds)';
}


}

/// @nodoc
abstract mixin class _$PagoEstadoCopyWith<$Res> implements $PagoEstadoCopyWith<$Res> {
  factory _$PagoEstadoCopyWith(_PagoEstado value, $Res Function(_PagoEstado) _then) = __$PagoEstadoCopyWithImpl;
@override @useResult
$Res call({
@JsonKey(name: 'pago_id') int pagoId, String estado, String referencia, double monto,@JsonKey(name: 'pedido_ids') List<int> pedidoIds
});




}
/// @nodoc
class __$PagoEstadoCopyWithImpl<$Res>
    implements _$PagoEstadoCopyWith<$Res> {
  __$PagoEstadoCopyWithImpl(this._self, this._then);

  final _PagoEstado _self;
  final $Res Function(_PagoEstado) _then;

/// Create a copy of PagoEstado
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? pagoId = null,Object? estado = null,Object? referencia = null,Object? monto = null,Object? pedidoIds = null,}) {
  return _then(_PagoEstado(
pagoId: null == pagoId ? _self.pagoId : pagoId // ignore: cast_nullable_to_non_nullable
as int,estado: null == estado ? _self.estado : estado // ignore: cast_nullable_to_non_nullable
as String,referencia: null == referencia ? _self.referencia : referencia // ignore: cast_nullable_to_non_nullable
as String,monto: null == monto ? _self.monto : monto // ignore: cast_nullable_to_non_nullable
as double,pedidoIds: null == pedidoIds ? _self._pedidoIds : pedidoIds // ignore: cast_nullable_to_non_nullable
as List<int>,
  ));
}


}

// dart format on
