// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'reporte.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$VentaDia {

 String get fecha; double get total;@JsonKey(name: 'num_pedidos') int get numPedidos;
/// Create a copy of VentaDia
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$VentaDiaCopyWith<VentaDia> get copyWith => _$VentaDiaCopyWithImpl<VentaDia>(this as VentaDia, _$identity);

  /// Serializes this VentaDia to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is VentaDia&&(identical(other.fecha, fecha) || other.fecha == fecha)&&(identical(other.total, total) || other.total == total)&&(identical(other.numPedidos, numPedidos) || other.numPedidos == numPedidos));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,fecha,total,numPedidos);

@override
String toString() {
  return 'VentaDia(fecha: $fecha, total: $total, numPedidos: $numPedidos)';
}


}

/// @nodoc
abstract mixin class $VentaDiaCopyWith<$Res>  {
  factory $VentaDiaCopyWith(VentaDia value, $Res Function(VentaDia) _then) = _$VentaDiaCopyWithImpl;
@useResult
$Res call({
 String fecha, double total,@JsonKey(name: 'num_pedidos') int numPedidos
});




}
/// @nodoc
class _$VentaDiaCopyWithImpl<$Res>
    implements $VentaDiaCopyWith<$Res> {
  _$VentaDiaCopyWithImpl(this._self, this._then);

  final VentaDia _self;
  final $Res Function(VentaDia) _then;

/// Create a copy of VentaDia
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? fecha = null,Object? total = null,Object? numPedidos = null,}) {
  return _then(VentaDia(
fecha: null == fecha ? _self.fecha : fecha // ignore: cast_nullable_to_non_nullable
as String,total: null == total ? _self.total : total // ignore: cast_nullable_to_non_nullable
as double,numPedidos: null == numPedidos ? _self.numPedidos : numPedidos // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}


/// Adds pattern-matching-related methods to [VentaDia].
extension VentaDiaPatterns on VentaDia {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _VentaDia value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _VentaDia() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _VentaDia value)  $default,){
final _that = this;
switch (_that) {
case _VentaDia():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _VentaDia value)?  $default,){
final _that = this;
switch (_that) {
case _VentaDia() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String fecha,  double total, @JsonKey(name: 'num_pedidos')  int numPedidos)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _VentaDia() when $default != null:
return $default(_that.fecha,_that.total,_that.numPedidos);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String fecha,  double total, @JsonKey(name: 'num_pedidos')  int numPedidos)  $default,) {final _that = this;
switch (_that) {
case _VentaDia():
return $default(_that.fecha,_that.total,_that.numPedidos);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String fecha,  double total, @JsonKey(name: 'num_pedidos')  int numPedidos)?  $default,) {final _that = this;
switch (_that) {
case _VentaDia() when $default != null:
return $default(_that.fecha,_that.total,_that.numPedidos);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _VentaDia implements VentaDia {
  const _VentaDia({required this.fecha, required this.total, @JsonKey(name: 'num_pedidos') required this.numPedidos});
  factory _VentaDia.fromJson(Map<String, dynamic> json) => _$VentaDiaFromJson(json);

@override final  String fecha;
@override final  double total;
@override@JsonKey(name: 'num_pedidos') final  int numPedidos;

/// Create a copy of VentaDia
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$VentaDiaCopyWith<_VentaDia> get copyWith => __$VentaDiaCopyWithImpl<_VentaDia>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$VentaDiaToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _VentaDia&&(identical(other.fecha, fecha) || other.fecha == fecha)&&(identical(other.total, total) || other.total == total)&&(identical(other.numPedidos, numPedidos) || other.numPedidos == numPedidos));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,fecha,total,numPedidos);

@override
String toString() {
  return 'VentaDia(fecha: $fecha, total: $total, numPedidos: $numPedidos)';
}


}

/// @nodoc
abstract mixin class _$VentaDiaCopyWith<$Res> implements $VentaDiaCopyWith<$Res> {
  factory _$VentaDiaCopyWith(_VentaDia value, $Res Function(_VentaDia) _then) = __$VentaDiaCopyWithImpl;
@override @useResult
$Res call({
 String fecha, double total,@JsonKey(name: 'num_pedidos') int numPedidos
});




}
/// @nodoc
class __$VentaDiaCopyWithImpl<$Res>
    implements _$VentaDiaCopyWith<$Res> {
  __$VentaDiaCopyWithImpl(this._self, this._then);

  final _VentaDia _self;
  final $Res Function(_VentaDia) _then;

/// Create a copy of VentaDia
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? fecha = null,Object? total = null,Object? numPedidos = null,}) {
  return _then(_VentaDia(
fecha: null == fecha ? _self.fecha : fecha // ignore: cast_nullable_to_non_nullable
as String,total: null == total ? _self.total : total // ignore: cast_nullable_to_non_nullable
as double,numPedidos: null == numPedidos ? _self.numPedidos : numPedidos // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}


/// @nodoc
mixin _$VentasReporte {

 String get desde; String get hasta; double get total;@JsonKey(name: 'num_pedidos') int get numPedidos;@JsonKey(name: 'por_dia') List<VentaDia> get porDia;
/// Create a copy of VentasReporte
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$VentasReporteCopyWith<VentasReporte> get copyWith => _$VentasReporteCopyWithImpl<VentasReporte>(this as VentasReporte, _$identity);

  /// Serializes this VentasReporte to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is VentasReporte&&(identical(other.desde, desde) || other.desde == desde)&&(identical(other.hasta, hasta) || other.hasta == hasta)&&(identical(other.total, total) || other.total == total)&&(identical(other.numPedidos, numPedidos) || other.numPedidos == numPedidos)&&const DeepCollectionEquality().equals(other.porDia, porDia));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,desde,hasta,total,numPedidos,const DeepCollectionEquality().hash(porDia));

@override
String toString() {
  return 'VentasReporte(desde: $desde, hasta: $hasta, total: $total, numPedidos: $numPedidos, porDia: $porDia)';
}


}

/// @nodoc
abstract mixin class $VentasReporteCopyWith<$Res>  {
  factory $VentasReporteCopyWith(VentasReporte value, $Res Function(VentasReporte) _then) = _$VentasReporteCopyWithImpl;
@useResult
$Res call({
 String desde, String hasta, double total,@JsonKey(name: 'num_pedidos') int numPedidos,@JsonKey(name: 'por_dia') List<VentaDia> porDia
});




}
/// @nodoc
class _$VentasReporteCopyWithImpl<$Res>
    implements $VentasReporteCopyWith<$Res> {
  _$VentasReporteCopyWithImpl(this._self, this._then);

  final VentasReporte _self;
  final $Res Function(VentasReporte) _then;

/// Create a copy of VentasReporte
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? desde = null,Object? hasta = null,Object? total = null,Object? numPedidos = null,Object? porDia = null,}) {
  return _then(VentasReporte(
desde: null == desde ? _self.desde : desde // ignore: cast_nullable_to_non_nullable
as String,hasta: null == hasta ? _self.hasta : hasta // ignore: cast_nullable_to_non_nullable
as String,total: null == total ? _self.total : total // ignore: cast_nullable_to_non_nullable
as double,numPedidos: null == numPedidos ? _self.numPedidos : numPedidos // ignore: cast_nullable_to_non_nullable
as int,porDia: null == porDia ? _self.porDia : porDia // ignore: cast_nullable_to_non_nullable
as List<VentaDia>,
  ));
}

}


/// Adds pattern-matching-related methods to [VentasReporte].
extension VentasReportePatterns on VentasReporte {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _VentasReporte value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _VentasReporte() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _VentasReporte value)  $default,){
final _that = this;
switch (_that) {
case _VentasReporte():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _VentasReporte value)?  $default,){
final _that = this;
switch (_that) {
case _VentasReporte() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String desde,  String hasta,  double total, @JsonKey(name: 'num_pedidos')  int numPedidos, @JsonKey(name: 'por_dia')  List<VentaDia> porDia)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _VentasReporte() when $default != null:
return $default(_that.desde,_that.hasta,_that.total,_that.numPedidos,_that.porDia);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String desde,  String hasta,  double total, @JsonKey(name: 'num_pedidos')  int numPedidos, @JsonKey(name: 'por_dia')  List<VentaDia> porDia)  $default,) {final _that = this;
switch (_that) {
case _VentasReporte():
return $default(_that.desde,_that.hasta,_that.total,_that.numPedidos,_that.porDia);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String desde,  String hasta,  double total, @JsonKey(name: 'num_pedidos')  int numPedidos, @JsonKey(name: 'por_dia')  List<VentaDia> porDia)?  $default,) {final _that = this;
switch (_that) {
case _VentasReporte() when $default != null:
return $default(_that.desde,_that.hasta,_that.total,_that.numPedidos,_that.porDia);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _VentasReporte implements VentasReporte {
  const _VentasReporte({required this.desde, required this.hasta, required this.total, @JsonKey(name: 'num_pedidos') required this.numPedidos, @JsonKey(name: 'por_dia') required  List<VentaDia> porDia}): _porDia = porDia;
  factory _VentasReporte.fromJson(Map<String, dynamic> json) => _$VentasReporteFromJson(json);

@override final  String desde;
@override final  String hasta;
@override final  double total;
@override@JsonKey(name: 'num_pedidos') final  int numPedidos;
 final  List<VentaDia> _porDia;
@override@JsonKey(name: 'por_dia') List<VentaDia> get porDia {
  if (_porDia is EqualUnmodifiableListView) return _porDia;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_porDia);
}


/// Create a copy of VentasReporte
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$VentasReporteCopyWith<_VentasReporte> get copyWith => __$VentasReporteCopyWithImpl<_VentasReporte>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$VentasReporteToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _VentasReporte&&(identical(other.desde, desde) || other.desde == desde)&&(identical(other.hasta, hasta) || other.hasta == hasta)&&(identical(other.total, total) || other.total == total)&&(identical(other.numPedidos, numPedidos) || other.numPedidos == numPedidos)&&const DeepCollectionEquality().equals(other._porDia, _porDia));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,desde,hasta,total,numPedidos,const DeepCollectionEquality().hash(_porDia));

@override
String toString() {
  return 'VentasReporte(desde: $desde, hasta: $hasta, total: $total, numPedidos: $numPedidos, porDia: $porDia)';
}


}

/// @nodoc
abstract mixin class _$VentasReporteCopyWith<$Res> implements $VentasReporteCopyWith<$Res> {
  factory _$VentasReporteCopyWith(_VentasReporte value, $Res Function(_VentasReporte) _then) = __$VentasReporteCopyWithImpl;
@override @useResult
$Res call({
 String desde, String hasta, double total,@JsonKey(name: 'num_pedidos') int numPedidos,@JsonKey(name: 'por_dia') List<VentaDia> porDia
});




}
/// @nodoc
class __$VentasReporteCopyWithImpl<$Res>
    implements _$VentasReporteCopyWith<$Res> {
  __$VentasReporteCopyWithImpl(this._self, this._then);

  final _VentasReporte _self;
  final $Res Function(_VentasReporte) _then;

/// Create a copy of VentasReporte
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? desde = null,Object? hasta = null,Object? total = null,Object? numPedidos = null,Object? porDia = null,}) {
  return _then(_VentasReporte(
desde: null == desde ? _self.desde : desde // ignore: cast_nullable_to_non_nullable
as String,hasta: null == hasta ? _self.hasta : hasta // ignore: cast_nullable_to_non_nullable
as String,total: null == total ? _self.total : total // ignore: cast_nullable_to_non_nullable
as double,numPedidos: null == numPedidos ? _self.numPedidos : numPedidos // ignore: cast_nullable_to_non_nullable
as int,porDia: null == porDia ? _self._porDia : porDia // ignore: cast_nullable_to_non_nullable
as List<VentaDia>,
  ));
}


}


/// @nodoc
mixin _$TopPlato {

@JsonKey(name: 'producto_id') int get productoId; String get nombre; int get cantidad; double get total;
/// Create a copy of TopPlato
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$TopPlatoCopyWith<TopPlato> get copyWith => _$TopPlatoCopyWithImpl<TopPlato>(this as TopPlato, _$identity);

  /// Serializes this TopPlato to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is TopPlato&&(identical(other.productoId, productoId) || other.productoId == productoId)&&(identical(other.nombre, nombre) || other.nombre == nombre)&&(identical(other.cantidad, cantidad) || other.cantidad == cantidad)&&(identical(other.total, total) || other.total == total));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,productoId,nombre,cantidad,total);

@override
String toString() {
  return 'TopPlato(productoId: $productoId, nombre: $nombre, cantidad: $cantidad, total: $total)';
}


}

/// @nodoc
abstract mixin class $TopPlatoCopyWith<$Res>  {
  factory $TopPlatoCopyWith(TopPlato value, $Res Function(TopPlato) _then) = _$TopPlatoCopyWithImpl;
@useResult
$Res call({
@JsonKey(name: 'producto_id') int productoId, String nombre, int cantidad, double total
});




}
/// @nodoc
class _$TopPlatoCopyWithImpl<$Res>
    implements $TopPlatoCopyWith<$Res> {
  _$TopPlatoCopyWithImpl(this._self, this._then);

  final TopPlato _self;
  final $Res Function(TopPlato) _then;

/// Create a copy of TopPlato
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? productoId = null,Object? nombre = null,Object? cantidad = null,Object? total = null,}) {
  return _then(TopPlato(
productoId: null == productoId ? _self.productoId : productoId // ignore: cast_nullable_to_non_nullable
as int,nombre: null == nombre ? _self.nombre : nombre // ignore: cast_nullable_to_non_nullable
as String,cantidad: null == cantidad ? _self.cantidad : cantidad // ignore: cast_nullable_to_non_nullable
as int,total: null == total ? _self.total : total // ignore: cast_nullable_to_non_nullable
as double,
  ));
}

}


/// Adds pattern-matching-related methods to [TopPlato].
extension TopPlatoPatterns on TopPlato {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _TopPlato value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _TopPlato() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _TopPlato value)  $default,){
final _that = this;
switch (_that) {
case _TopPlato():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _TopPlato value)?  $default,){
final _that = this;
switch (_that) {
case _TopPlato() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function(@JsonKey(name: 'producto_id')  int productoId,  String nombre,  int cantidad,  double total)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _TopPlato() when $default != null:
return $default(_that.productoId,_that.nombre,_that.cantidad,_that.total);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function(@JsonKey(name: 'producto_id')  int productoId,  String nombre,  int cantidad,  double total)  $default,) {final _that = this;
switch (_that) {
case _TopPlato():
return $default(_that.productoId,_that.nombre,_that.cantidad,_that.total);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function(@JsonKey(name: 'producto_id')  int productoId,  String nombre,  int cantidad,  double total)?  $default,) {final _that = this;
switch (_that) {
case _TopPlato() when $default != null:
return $default(_that.productoId,_that.nombre,_that.cantidad,_that.total);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _TopPlato implements TopPlato {
  const _TopPlato({@JsonKey(name: 'producto_id') required this.productoId, required this.nombre, required this.cantidad, required this.total});
  factory _TopPlato.fromJson(Map<String, dynamic> json) => _$TopPlatoFromJson(json);

@override@JsonKey(name: 'producto_id') final  int productoId;
@override final  String nombre;
@override final  int cantidad;
@override final  double total;

/// Create a copy of TopPlato
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$TopPlatoCopyWith<_TopPlato> get copyWith => __$TopPlatoCopyWithImpl<_TopPlato>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$TopPlatoToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _TopPlato&&(identical(other.productoId, productoId) || other.productoId == productoId)&&(identical(other.nombre, nombre) || other.nombre == nombre)&&(identical(other.cantidad, cantidad) || other.cantidad == cantidad)&&(identical(other.total, total) || other.total == total));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,productoId,nombre,cantidad,total);

@override
String toString() {
  return 'TopPlato(productoId: $productoId, nombre: $nombre, cantidad: $cantidad, total: $total)';
}


}

/// @nodoc
abstract mixin class _$TopPlatoCopyWith<$Res> implements $TopPlatoCopyWith<$Res> {
  factory _$TopPlatoCopyWith(_TopPlato value, $Res Function(_TopPlato) _then) = __$TopPlatoCopyWithImpl;
@override @useResult
$Res call({
@JsonKey(name: 'producto_id') int productoId, String nombre, int cantidad, double total
});




}
/// @nodoc
class __$TopPlatoCopyWithImpl<$Res>
    implements _$TopPlatoCopyWith<$Res> {
  __$TopPlatoCopyWithImpl(this._self, this._then);

  final _TopPlato _self;
  final $Res Function(_TopPlato) _then;

/// Create a copy of TopPlato
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? productoId = null,Object? nombre = null,Object? cantidad = null,Object? total = null,}) {
  return _then(_TopPlato(
productoId: null == productoId ? _self.productoId : productoId // ignore: cast_nullable_to_non_nullable
as int,nombre: null == nombre ? _self.nombre : nombre // ignore: cast_nullable_to_non_nullable
as String,cantidad: null == cantidad ? _self.cantidad : cantidad // ignore: cast_nullable_to_non_nullable
as int,total: null == total ? _self.total : total // ignore: cast_nullable_to_non_nullable
as double,
  ));
}


}

// dart format on
