// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'restaurante_detalle.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$RestauranteDetalle {

 String get id; String get nombre; String? get tipoCocina; String? get descripcion; String? get direccion; double get califProm; int get califCount; List<Categoria> get categorias;
/// Create a copy of RestauranteDetalle
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$RestauranteDetalleCopyWith<RestauranteDetalle> get copyWith => _$RestauranteDetalleCopyWithImpl<RestauranteDetalle>(this as RestauranteDetalle, _$identity);

  /// Serializes this RestauranteDetalle to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is RestauranteDetalle&&(identical(other.id, id) || other.id == id)&&(identical(other.nombre, nombre) || other.nombre == nombre)&&(identical(other.tipoCocina, tipoCocina) || other.tipoCocina == tipoCocina)&&(identical(other.descripcion, descripcion) || other.descripcion == descripcion)&&(identical(other.direccion, direccion) || other.direccion == direccion)&&(identical(other.califProm, califProm) || other.califProm == califProm)&&(identical(other.califCount, califCount) || other.califCount == califCount)&&const DeepCollectionEquality().equals(other.categorias, categorias));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,nombre,tipoCocina,descripcion,direccion,califProm,califCount,const DeepCollectionEquality().hash(categorias));

@override
String toString() {
  return 'RestauranteDetalle(id: $id, nombre: $nombre, tipoCocina: $tipoCocina, descripcion: $descripcion, direccion: $direccion, califProm: $califProm, califCount: $califCount, categorias: $categorias)';
}


}

/// @nodoc
abstract mixin class $RestauranteDetalleCopyWith<$Res>  {
  factory $RestauranteDetalleCopyWith(RestauranteDetalle value, $Res Function(RestauranteDetalle) _then) = _$RestauranteDetalleCopyWithImpl;
@useResult
$Res call({
 String id, String nombre, String? tipoCocina, String? descripcion, String? direccion, double califProm, int califCount, List<Categoria> categorias
});




}
/// @nodoc
class _$RestauranteDetalleCopyWithImpl<$Res>
    implements $RestauranteDetalleCopyWith<$Res> {
  _$RestauranteDetalleCopyWithImpl(this._self, this._then);

  final RestauranteDetalle _self;
  final $Res Function(RestauranteDetalle) _then;

/// Create a copy of RestauranteDetalle
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? nombre = null,Object? tipoCocina = freezed,Object? descripcion = freezed,Object? direccion = freezed,Object? califProm = null,Object? califCount = null,Object? categorias = null,}) {
  return _then(RestauranteDetalle(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,nombre: null == nombre ? _self.nombre : nombre // ignore: cast_nullable_to_non_nullable
as String,tipoCocina: freezed == tipoCocina ? _self.tipoCocina : tipoCocina // ignore: cast_nullable_to_non_nullable
as String?,descripcion: freezed == descripcion ? _self.descripcion : descripcion // ignore: cast_nullable_to_non_nullable
as String?,direccion: freezed == direccion ? _self.direccion : direccion // ignore: cast_nullable_to_non_nullable
as String?,califProm: null == califProm ? _self.califProm : califProm // ignore: cast_nullable_to_non_nullable
as double,califCount: null == califCount ? _self.califCount : califCount // ignore: cast_nullable_to_non_nullable
as int,categorias: null == categorias ? _self.categorias : categorias // ignore: cast_nullable_to_non_nullable
as List<Categoria>,
  ));
}

}


/// Adds pattern-matching-related methods to [RestauranteDetalle].
extension RestauranteDetallePatterns on RestauranteDetalle {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _RestauranteDetalle value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _RestauranteDetalle() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _RestauranteDetalle value)  $default,){
final _that = this;
switch (_that) {
case _RestauranteDetalle():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _RestauranteDetalle value)?  $default,){
final _that = this;
switch (_that) {
case _RestauranteDetalle() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String nombre,  String? tipoCocina,  String? descripcion,  String? direccion,  double califProm,  int califCount,  List<Categoria> categorias)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _RestauranteDetalle() when $default != null:
return $default(_that.id,_that.nombre,_that.tipoCocina,_that.descripcion,_that.direccion,_that.califProm,_that.califCount,_that.categorias);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String nombre,  String? tipoCocina,  String? descripcion,  String? direccion,  double califProm,  int califCount,  List<Categoria> categorias)  $default,) {final _that = this;
switch (_that) {
case _RestauranteDetalle():
return $default(_that.id,_that.nombre,_that.tipoCocina,_that.descripcion,_that.direccion,_that.califProm,_that.califCount,_that.categorias);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String nombre,  String? tipoCocina,  String? descripcion,  String? direccion,  double califProm,  int califCount,  List<Categoria> categorias)?  $default,) {final _that = this;
switch (_that) {
case _RestauranteDetalle() when $default != null:
return $default(_that.id,_that.nombre,_that.tipoCocina,_that.descripcion,_that.direccion,_that.califProm,_that.califCount,_that.categorias);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _RestauranteDetalle extends RestauranteDetalle {
  const _RestauranteDetalle({required this.id, required this.nombre, this.tipoCocina, this.descripcion, this.direccion, this.califProm = 0.0, this.califCount = 0, required  List<Categoria> categorias}): _categorias = categorias,super._();
  factory _RestauranteDetalle.fromJson(Map<String, dynamic> json) => _$RestauranteDetalleFromJson(json);

@override final  String id;
@override final  String nombre;
@override final  String? tipoCocina;
@override final  String? descripcion;
@override final  String? direccion;
@override@JsonKey() final  double califProm;
@override@JsonKey() final  int califCount;
 final  List<Categoria> _categorias;
@override List<Categoria> get categorias {
  if (_categorias is EqualUnmodifiableListView) return _categorias;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_categorias);
}


/// Create a copy of RestauranteDetalle
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$RestauranteDetalleCopyWith<_RestauranteDetalle> get copyWith => __$RestauranteDetalleCopyWithImpl<_RestauranteDetalle>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$RestauranteDetalleToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _RestauranteDetalle&&(identical(other.id, id) || other.id == id)&&(identical(other.nombre, nombre) || other.nombre == nombre)&&(identical(other.tipoCocina, tipoCocina) || other.tipoCocina == tipoCocina)&&(identical(other.descripcion, descripcion) || other.descripcion == descripcion)&&(identical(other.direccion, direccion) || other.direccion == direccion)&&(identical(other.califProm, califProm) || other.califProm == califProm)&&(identical(other.califCount, califCount) || other.califCount == califCount)&&const DeepCollectionEquality().equals(other._categorias, _categorias));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,nombre,tipoCocina,descripcion,direccion,califProm,califCount,const DeepCollectionEquality().hash(_categorias));

@override
String toString() {
  return 'RestauranteDetalle(id: $id, nombre: $nombre, tipoCocina: $tipoCocina, descripcion: $descripcion, direccion: $direccion, califProm: $califProm, califCount: $califCount, categorias: $categorias)';
}


}

/// @nodoc
abstract mixin class _$RestauranteDetalleCopyWith<$Res> implements $RestauranteDetalleCopyWith<$Res> {
  factory _$RestauranteDetalleCopyWith(_RestauranteDetalle value, $Res Function(_RestauranteDetalle) _then) = __$RestauranteDetalleCopyWithImpl;
@override @useResult
$Res call({
 String id, String nombre, String? tipoCocina, String? descripcion, String? direccion, double califProm, int califCount, List<Categoria> categorias
});




}
/// @nodoc
class __$RestauranteDetalleCopyWithImpl<$Res>
    implements _$RestauranteDetalleCopyWith<$Res> {
  __$RestauranteDetalleCopyWithImpl(this._self, this._then);

  final _RestauranteDetalle _self;
  final $Res Function(_RestauranteDetalle) _then;

/// Create a copy of RestauranteDetalle
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? nombre = null,Object? tipoCocina = freezed,Object? descripcion = freezed,Object? direccion = freezed,Object? califProm = null,Object? califCount = null,Object? categorias = null,}) {
  return _then(_RestauranteDetalle(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,nombre: null == nombre ? _self.nombre : nombre // ignore: cast_nullable_to_non_nullable
as String,tipoCocina: freezed == tipoCocina ? _self.tipoCocina : tipoCocina // ignore: cast_nullable_to_non_nullable
as String?,descripcion: freezed == descripcion ? _self.descripcion : descripcion // ignore: cast_nullable_to_non_nullable
as String?,direccion: freezed == direccion ? _self.direccion : direccion // ignore: cast_nullable_to_non_nullable
as String?,califProm: null == califProm ? _self.califProm : califProm // ignore: cast_nullable_to_non_nullable
as double,califCount: null == califCount ? _self.califCount : califCount // ignore: cast_nullable_to_non_nullable
as int,categorias: null == categorias ? _self._categorias : categorias // ignore: cast_nullable_to_non_nullable
as List<Categoria>,
  ));
}


}

// dart format on
