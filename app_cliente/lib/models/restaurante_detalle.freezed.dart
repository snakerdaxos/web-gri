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

 int get id; String get nombre;@JsonKey(name: 'tipo_cocina') String? get tipoCocina; String? get descripcion; String? get direccion; double? get calificacion;@JsonKey(name: 'total_calificaciones') int get totalCalificaciones; List<Categoria> get categorias;
/// Create a copy of RestauranteDetalle
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$RestauranteDetalleCopyWith<RestauranteDetalle> get copyWith => _$RestauranteDetalleCopyWithImpl<RestauranteDetalle>(this as RestauranteDetalle, _$identity);

  /// Serializes this RestauranteDetalle to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is RestauranteDetalle&&(identical(other.id, id) || other.id == id)&&(identical(other.nombre, nombre) || other.nombre == nombre)&&(identical(other.tipoCocina, tipoCocina) || other.tipoCocina == tipoCocina)&&(identical(other.descripcion, descripcion) || other.descripcion == descripcion)&&(identical(other.direccion, direccion) || other.direccion == direccion)&&(identical(other.calificacion, calificacion) || other.calificacion == calificacion)&&(identical(other.totalCalificaciones, totalCalificaciones) || other.totalCalificaciones == totalCalificaciones)&&const DeepCollectionEquality().equals(other.categorias, categorias));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,nombre,tipoCocina,descripcion,direccion,calificacion,totalCalificaciones,const DeepCollectionEquality().hash(categorias));

@override
String toString() {
  return 'RestauranteDetalle(id: $id, nombre: $nombre, tipoCocina: $tipoCocina, descripcion: $descripcion, direccion: $direccion, calificacion: $calificacion, totalCalificaciones: $totalCalificaciones, categorias: $categorias)';
}


}

/// @nodoc
abstract mixin class $RestauranteDetalleCopyWith<$Res>  {
  factory $RestauranteDetalleCopyWith(RestauranteDetalle value, $Res Function(RestauranteDetalle) _then) = _$RestauranteDetalleCopyWithImpl;
@useResult
$Res call({
 int id, String nombre,@JsonKey(name: 'tipo_cocina') String? tipoCocina, String? descripcion, String? direccion, double? calificacion,@JsonKey(name: 'total_calificaciones') int totalCalificaciones, List<Categoria> categorias
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
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? nombre = null,Object? tipoCocina = freezed,Object? descripcion = freezed,Object? direccion = freezed,Object? calificacion = freezed,Object? totalCalificaciones = null,Object? categorias = null,}) {
  return _then(RestauranteDetalle(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,nombre: null == nombre ? _self.nombre : nombre // ignore: cast_nullable_to_non_nullable
as String,tipoCocina: freezed == tipoCocina ? _self.tipoCocina : tipoCocina // ignore: cast_nullable_to_non_nullable
as String?,descripcion: freezed == descripcion ? _self.descripcion : descripcion // ignore: cast_nullable_to_non_nullable
as String?,direccion: freezed == direccion ? _self.direccion : direccion // ignore: cast_nullable_to_non_nullable
as String?,calificacion: freezed == calificacion ? _self.calificacion : calificacion // ignore: cast_nullable_to_non_nullable
as double?,totalCalificaciones: null == totalCalificaciones ? _self.totalCalificaciones : totalCalificaciones // ignore: cast_nullable_to_non_nullable
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int id,  String nombre, @JsonKey(name: 'tipo_cocina')  String? tipoCocina,  String? descripcion,  String? direccion,  double? calificacion, @JsonKey(name: 'total_calificaciones')  int totalCalificaciones,  List<Categoria> categorias)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _RestauranteDetalle() when $default != null:
return $default(_that.id,_that.nombre,_that.tipoCocina,_that.descripcion,_that.direccion,_that.calificacion,_that.totalCalificaciones,_that.categorias);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int id,  String nombre, @JsonKey(name: 'tipo_cocina')  String? tipoCocina,  String? descripcion,  String? direccion,  double? calificacion, @JsonKey(name: 'total_calificaciones')  int totalCalificaciones,  List<Categoria> categorias)  $default,) {final _that = this;
switch (_that) {
case _RestauranteDetalle():
return $default(_that.id,_that.nombre,_that.tipoCocina,_that.descripcion,_that.direccion,_that.calificacion,_that.totalCalificaciones,_that.categorias);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int id,  String nombre, @JsonKey(name: 'tipo_cocina')  String? tipoCocina,  String? descripcion,  String? direccion,  double? calificacion, @JsonKey(name: 'total_calificaciones')  int totalCalificaciones,  List<Categoria> categorias)?  $default,) {final _that = this;
switch (_that) {
case _RestauranteDetalle() when $default != null:
return $default(_that.id,_that.nombre,_that.tipoCocina,_that.descripcion,_that.direccion,_that.calificacion,_that.totalCalificaciones,_that.categorias);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _RestauranteDetalle extends RestauranteDetalle {
  const _RestauranteDetalle({required this.id, required this.nombre, @JsonKey(name: 'tipo_cocina') this.tipoCocina, this.descripcion, this.direccion, this.calificacion, @JsonKey(name: 'total_calificaciones') this.totalCalificaciones = 0, required  List<Categoria> categorias}): _categorias = categorias,super._();
  factory _RestauranteDetalle.fromJson(Map<String, dynamic> json) => _$RestauranteDetalleFromJson(json);

@override final  int id;
@override final  String nombre;
@override@JsonKey(name: 'tipo_cocina') final  String? tipoCocina;
@override final  String? descripcion;
@override final  String? direccion;
@override final  double? calificacion;
@override@JsonKey(name: 'total_calificaciones') final  int totalCalificaciones;
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
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _RestauranteDetalle&&(identical(other.id, id) || other.id == id)&&(identical(other.nombre, nombre) || other.nombre == nombre)&&(identical(other.tipoCocina, tipoCocina) || other.tipoCocina == tipoCocina)&&(identical(other.descripcion, descripcion) || other.descripcion == descripcion)&&(identical(other.direccion, direccion) || other.direccion == direccion)&&(identical(other.calificacion, calificacion) || other.calificacion == calificacion)&&(identical(other.totalCalificaciones, totalCalificaciones) || other.totalCalificaciones == totalCalificaciones)&&const DeepCollectionEquality().equals(other._categorias, _categorias));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,nombre,tipoCocina,descripcion,direccion,calificacion,totalCalificaciones,const DeepCollectionEquality().hash(_categorias));

@override
String toString() {
  return 'RestauranteDetalle(id: $id, nombre: $nombre, tipoCocina: $tipoCocina, descripcion: $descripcion, direccion: $direccion, calificacion: $calificacion, totalCalificaciones: $totalCalificaciones, categorias: $categorias)';
}


}

/// @nodoc
abstract mixin class _$RestauranteDetalleCopyWith<$Res> implements $RestauranteDetalleCopyWith<$Res> {
  factory _$RestauranteDetalleCopyWith(_RestauranteDetalle value, $Res Function(_RestauranteDetalle) _then) = __$RestauranteDetalleCopyWithImpl;
@override @useResult
$Res call({
 int id, String nombre,@JsonKey(name: 'tipo_cocina') String? tipoCocina, String? descripcion, String? direccion, double? calificacion,@JsonKey(name: 'total_calificaciones') int totalCalificaciones, List<Categoria> categorias
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
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? nombre = null,Object? tipoCocina = freezed,Object? descripcion = freezed,Object? direccion = freezed,Object? calificacion = freezed,Object? totalCalificaciones = null,Object? categorias = null,}) {
  return _then(_RestauranteDetalle(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,nombre: null == nombre ? _self.nombre : nombre // ignore: cast_nullable_to_non_nullable
as String,tipoCocina: freezed == tipoCocina ? _self.tipoCocina : tipoCocina // ignore: cast_nullable_to_non_nullable
as String?,descripcion: freezed == descripcion ? _self.descripcion : descripcion // ignore: cast_nullable_to_non_nullable
as String?,direccion: freezed == direccion ? _self.direccion : direccion // ignore: cast_nullable_to_non_nullable
as String?,calificacion: freezed == calificacion ? _self.calificacion : calificacion // ignore: cast_nullable_to_non_nullable
as double?,totalCalificaciones: null == totalCalificaciones ? _self.totalCalificaciones : totalCalificaciones // ignore: cast_nullable_to_non_nullable
as int,categorias: null == categorias ? _self._categorias : categorias // ignore: cast_nullable_to_non_nullable
as List<Categoria>,
  ));
}


}

// dart format on
