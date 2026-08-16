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
mixin _$Reporte {

 int get totalVentas; int get numeroPedidos; List<TopPlato> get topPlatos;
/// Create a copy of Reporte
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ReporteCopyWith<Reporte> get copyWith => _$ReporteCopyWithImpl<Reporte>(this as Reporte, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Reporte&&(identical(other.totalVentas, totalVentas) || other.totalVentas == totalVentas)&&(identical(other.numeroPedidos, numeroPedidos) || other.numeroPedidos == numeroPedidos)&&const DeepCollectionEquality().equals(other.topPlatos, topPlatos));
}


@override
int get hashCode => Object.hash(runtimeType,totalVentas,numeroPedidos,const DeepCollectionEquality().hash(topPlatos));

@override
String toString() {
  return 'Reporte(totalVentas: $totalVentas, numeroPedidos: $numeroPedidos, topPlatos: $topPlatos)';
}


}

/// @nodoc
abstract mixin class $ReporteCopyWith<$Res>  {
  factory $ReporteCopyWith(Reporte value, $Res Function(Reporte) _then) = _$ReporteCopyWithImpl;
@useResult
$Res call({
 int totalVentas, int numeroPedidos, List<TopPlato> topPlatos
});




}
/// @nodoc
class _$ReporteCopyWithImpl<$Res>
    implements $ReporteCopyWith<$Res> {
  _$ReporteCopyWithImpl(this._self, this._then);

  final Reporte _self;
  final $Res Function(Reporte) _then;

/// Create a copy of Reporte
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? totalVentas = null,Object? numeroPedidos = null,Object? topPlatos = null,}) {
  return _then(Reporte(
totalVentas: null == totalVentas ? _self.totalVentas : totalVentas // ignore: cast_nullable_to_non_nullable
as int,numeroPedidos: null == numeroPedidos ? _self.numeroPedidos : numeroPedidos // ignore: cast_nullable_to_non_nullable
as int,topPlatos: null == topPlatos ? _self.topPlatos : topPlatos // ignore: cast_nullable_to_non_nullable
as List<TopPlato>,
  ));
}

}


/// Adds pattern-matching-related methods to [Reporte].
extension ReportePatterns on Reporte {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _Reporte value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _Reporte() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _Reporte value)  $default,){
final _that = this;
switch (_that) {
case _Reporte():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _Reporte value)?  $default,){
final _that = this;
switch (_that) {
case _Reporte() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int totalVentas,  int numeroPedidos,  List<TopPlato> topPlatos)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Reporte() when $default != null:
return $default(_that.totalVentas,_that.numeroPedidos,_that.topPlatos);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int totalVentas,  int numeroPedidos,  List<TopPlato> topPlatos)  $default,) {final _that = this;
switch (_that) {
case _Reporte():
return $default(_that.totalVentas,_that.numeroPedidos,_that.topPlatos);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int totalVentas,  int numeroPedidos,  List<TopPlato> topPlatos)?  $default,) {final _that = this;
switch (_that) {
case _Reporte() when $default != null:
return $default(_that.totalVentas,_that.numeroPedidos,_that.topPlatos);case _:
  return null;

}
}

}

/// @nodoc


class _Reporte implements Reporte {
  const _Reporte({required this.totalVentas, required this.numeroPedidos,  List<TopPlato> topPlatos = const <TopPlato>[]}): _topPlatos = topPlatos;
  

@override final  int totalVentas;
@override final  int numeroPedidos;
 final  List<TopPlato> _topPlatos;
@override@JsonKey() List<TopPlato> get topPlatos {
  if (_topPlatos is EqualUnmodifiableListView) return _topPlatos;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_topPlatos);
}


/// Create a copy of Reporte
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ReporteCopyWith<_Reporte> get copyWith => __$ReporteCopyWithImpl<_Reporte>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _Reporte&&(identical(other.totalVentas, totalVentas) || other.totalVentas == totalVentas)&&(identical(other.numeroPedidos, numeroPedidos) || other.numeroPedidos == numeroPedidos)&&const DeepCollectionEquality().equals(other._topPlatos, _topPlatos));
}


@override
int get hashCode => Object.hash(runtimeType,totalVentas,numeroPedidos,const DeepCollectionEquality().hash(_topPlatos));

@override
String toString() {
  return 'Reporte(totalVentas: $totalVentas, numeroPedidos: $numeroPedidos, topPlatos: $topPlatos)';
}


}

/// @nodoc
abstract mixin class _$ReporteCopyWith<$Res> implements $ReporteCopyWith<$Res> {
  factory _$ReporteCopyWith(_Reporte value, $Res Function(_Reporte) _then) = __$ReporteCopyWithImpl;
@override @useResult
$Res call({
 int totalVentas, int numeroPedidos, List<TopPlato> topPlatos
});




}
/// @nodoc
class __$ReporteCopyWithImpl<$Res>
    implements _$ReporteCopyWith<$Res> {
  __$ReporteCopyWithImpl(this._self, this._then);

  final _Reporte _self;
  final $Res Function(_Reporte) _then;

/// Create a copy of Reporte
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? totalVentas = null,Object? numeroPedidos = null,Object? topPlatos = null,}) {
  return _then(_Reporte(
totalVentas: null == totalVentas ? _self.totalVentas : totalVentas // ignore: cast_nullable_to_non_nullable
as int,numeroPedidos: null == numeroPedidos ? _self.numeroPedidos : numeroPedidos // ignore: cast_nullable_to_non_nullable
as int,topPlatos: null == topPlatos ? _self._topPlatos : topPlatos // ignore: cast_nullable_to_non_nullable
as List<TopPlato>,
  ));
}


}

/// @nodoc
mixin _$TopPlato {

 String get nombre; int get cantidad;/// Σ precio×cantidad del snapshot (int COP).
 int get venta;
/// Create a copy of TopPlato
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$TopPlatoCopyWith<TopPlato> get copyWith => _$TopPlatoCopyWithImpl<TopPlato>(this as TopPlato, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is TopPlato&&(identical(other.nombre, nombre) || other.nombre == nombre)&&(identical(other.cantidad, cantidad) || other.cantidad == cantidad)&&(identical(other.venta, venta) || other.venta == venta));
}


@override
int get hashCode => Object.hash(runtimeType,nombre,cantidad,venta);

@override
String toString() {
  return 'TopPlato(nombre: $nombre, cantidad: $cantidad, venta: $venta)';
}


}

/// @nodoc
abstract mixin class $TopPlatoCopyWith<$Res>  {
  factory $TopPlatoCopyWith(TopPlato value, $Res Function(TopPlato) _then) = _$TopPlatoCopyWithImpl;
@useResult
$Res call({
 String nombre, int cantidad, int venta
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
@pragma('vm:prefer-inline') @override $Res call({Object? nombre = null,Object? cantidad = null,Object? venta = null,}) {
  return _then(TopPlato(
nombre: null == nombre ? _self.nombre : nombre // ignore: cast_nullable_to_non_nullable
as String,cantidad: null == cantidad ? _self.cantidad : cantidad // ignore: cast_nullable_to_non_nullable
as int,venta: null == venta ? _self.venta : venta // ignore: cast_nullable_to_non_nullable
as int,
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String nombre,  int cantidad,  int venta)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _TopPlato() when $default != null:
return $default(_that.nombre,_that.cantidad,_that.venta);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String nombre,  int cantidad,  int venta)  $default,) {final _that = this;
switch (_that) {
case _TopPlato():
return $default(_that.nombre,_that.cantidad,_that.venta);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String nombre,  int cantidad,  int venta)?  $default,) {final _that = this;
switch (_that) {
case _TopPlato() when $default != null:
return $default(_that.nombre,_that.cantidad,_that.venta);case _:
  return null;

}
}

}

/// @nodoc


class _TopPlato implements TopPlato {
  const _TopPlato({required this.nombre, required this.cantidad, required this.venta});
  

@override final  String nombre;
@override final  int cantidad;
/// Σ precio×cantidad del snapshot (int COP).
@override final  int venta;

/// Create a copy of TopPlato
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$TopPlatoCopyWith<_TopPlato> get copyWith => __$TopPlatoCopyWithImpl<_TopPlato>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _TopPlato&&(identical(other.nombre, nombre) || other.nombre == nombre)&&(identical(other.cantidad, cantidad) || other.cantidad == cantidad)&&(identical(other.venta, venta) || other.venta == venta));
}


@override
int get hashCode => Object.hash(runtimeType,nombre,cantidad,venta);

@override
String toString() {
  return 'TopPlato(nombre: $nombre, cantidad: $cantidad, venta: $venta)';
}


}

/// @nodoc
abstract mixin class _$TopPlatoCopyWith<$Res> implements $TopPlatoCopyWith<$Res> {
  factory _$TopPlatoCopyWith(_TopPlato value, $Res Function(_TopPlato) _then) = __$TopPlatoCopyWithImpl;
@override @useResult
$Res call({
 String nombre, int cantidad, int venta
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
@override @pragma('vm:prefer-inline') $Res call({Object? nombre = null,Object? cantidad = null,Object? venta = null,}) {
  return _then(_TopPlato(
nombre: null == nombre ? _self.nombre : nombre // ignore: cast_nullable_to_non_nullable
as String,cantidad: null == cantidad ? _self.cantidad : cantidad // ignore: cast_nullable_to_non_nullable
as int,venta: null == venta ? _self.venta : venta // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

// dart format on
