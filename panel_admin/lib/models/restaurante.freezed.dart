// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'restaurante.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$Restaurante {

 int get id; String get nombre; String? get descripcion;@JsonKey(name: 'tipo_cocina') String? get tipoCocina; String? get direccion; bool get activo;@JsonKey(name: 'created_at') DateTime? get createdAt;
/// Create a copy of Restaurante
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$RestauranteCopyWith<Restaurante> get copyWith => _$RestauranteCopyWithImpl<Restaurante>(this as Restaurante, _$identity);

  /// Serializes this Restaurante to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Restaurante&&(identical(other.id, id) || other.id == id)&&(identical(other.nombre, nombre) || other.nombre == nombre)&&(identical(other.descripcion, descripcion) || other.descripcion == descripcion)&&(identical(other.tipoCocina, tipoCocina) || other.tipoCocina == tipoCocina)&&(identical(other.direccion, direccion) || other.direccion == direccion)&&(identical(other.activo, activo) || other.activo == activo)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,nombre,descripcion,tipoCocina,direccion,activo,createdAt);

@override
String toString() {
  return 'Restaurante(id: $id, nombre: $nombre, descripcion: $descripcion, tipoCocina: $tipoCocina, direccion: $direccion, activo: $activo, createdAt: $createdAt)';
}


}

/// @nodoc
abstract mixin class $RestauranteCopyWith<$Res>  {
  factory $RestauranteCopyWith(Restaurante value, $Res Function(Restaurante) _then) = _$RestauranteCopyWithImpl;
@useResult
$Res call({
 int id, String nombre, String? descripcion,@JsonKey(name: 'tipo_cocina') String? tipoCocina, String? direccion, bool activo,@JsonKey(name: 'created_at') DateTime? createdAt
});




}
/// @nodoc
class _$RestauranteCopyWithImpl<$Res>
    implements $RestauranteCopyWith<$Res> {
  _$RestauranteCopyWithImpl(this._self, this._then);

  final Restaurante _self;
  final $Res Function(Restaurante) _then;

/// Create a copy of Restaurante
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? nombre = null,Object? descripcion = freezed,Object? tipoCocina = freezed,Object? direccion = freezed,Object? activo = null,Object? createdAt = freezed,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,nombre: null == nombre ? _self.nombre : nombre // ignore: cast_nullable_to_non_nullable
as String,descripcion: freezed == descripcion ? _self.descripcion : descripcion // ignore: cast_nullable_to_non_nullable
as String?,tipoCocina: freezed == tipoCocina ? _self.tipoCocina : tipoCocina // ignore: cast_nullable_to_non_nullable
as String?,direccion: freezed == direccion ? _self.direccion : direccion // ignore: cast_nullable_to_non_nullable
as String?,activo: null == activo ? _self.activo : activo // ignore: cast_nullable_to_non_nullable
as bool,createdAt: freezed == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}

}


/// Adds pattern-matching-related methods to [Restaurante].
extension RestaurantePatterns on Restaurante {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _Restaurante value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _Restaurante() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _Restaurante value)  $default,){
final _that = this;
switch (_that) {
case _Restaurante():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _Restaurante value)?  $default,){
final _that = this;
switch (_that) {
case _Restaurante() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int id,  String nombre,  String? descripcion, @JsonKey(name: 'tipo_cocina')  String? tipoCocina,  String? direccion,  bool activo, @JsonKey(name: 'created_at')  DateTime? createdAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Restaurante() when $default != null:
return $default(_that.id,_that.nombre,_that.descripcion,_that.tipoCocina,_that.direccion,_that.activo,_that.createdAt);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int id,  String nombre,  String? descripcion, @JsonKey(name: 'tipo_cocina')  String? tipoCocina,  String? direccion,  bool activo, @JsonKey(name: 'created_at')  DateTime? createdAt)  $default,) {final _that = this;
switch (_that) {
case _Restaurante():
return $default(_that.id,_that.nombre,_that.descripcion,_that.tipoCocina,_that.direccion,_that.activo,_that.createdAt);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int id,  String nombre,  String? descripcion, @JsonKey(name: 'tipo_cocina')  String? tipoCocina,  String? direccion,  bool activo, @JsonKey(name: 'created_at')  DateTime? createdAt)?  $default,) {final _that = this;
switch (_that) {
case _Restaurante() when $default != null:
return $default(_that.id,_that.nombre,_that.descripcion,_that.tipoCocina,_that.direccion,_that.activo,_that.createdAt);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _Restaurante implements Restaurante {
  const _Restaurante({required this.id, required this.nombre, this.descripcion, @JsonKey(name: 'tipo_cocina') this.tipoCocina, this.direccion, required this.activo, @JsonKey(name: 'created_at') this.createdAt});
  factory _Restaurante.fromJson(Map<String, dynamic> json) => _$RestauranteFromJson(json);

@override final  int id;
@override final  String nombre;
@override final  String? descripcion;
@override@JsonKey(name: 'tipo_cocina') final  String? tipoCocina;
@override final  String? direccion;
@override final  bool activo;
@override@JsonKey(name: 'created_at') final  DateTime? createdAt;

/// Create a copy of Restaurante
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$RestauranteCopyWith<_Restaurante> get copyWith => __$RestauranteCopyWithImpl<_Restaurante>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$RestauranteToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _Restaurante&&(identical(other.id, id) || other.id == id)&&(identical(other.nombre, nombre) || other.nombre == nombre)&&(identical(other.descripcion, descripcion) || other.descripcion == descripcion)&&(identical(other.tipoCocina, tipoCocina) || other.tipoCocina == tipoCocina)&&(identical(other.direccion, direccion) || other.direccion == direccion)&&(identical(other.activo, activo) || other.activo == activo)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,nombre,descripcion,tipoCocina,direccion,activo,createdAt);

@override
String toString() {
  return 'Restaurante(id: $id, nombre: $nombre, descripcion: $descripcion, tipoCocina: $tipoCocina, direccion: $direccion, activo: $activo, createdAt: $createdAt)';
}


}

/// @nodoc
abstract mixin class _$RestauranteCopyWith<$Res> implements $RestauranteCopyWith<$Res> {
  factory _$RestauranteCopyWith(_Restaurante value, $Res Function(_Restaurante) _then) = __$RestauranteCopyWithImpl;
@override @useResult
$Res call({
 int id, String nombre, String? descripcion,@JsonKey(name: 'tipo_cocina') String? tipoCocina, String? direccion, bool activo,@JsonKey(name: 'created_at') DateTime? createdAt
});




}
/// @nodoc
class __$RestauranteCopyWithImpl<$Res>
    implements _$RestauranteCopyWith<$Res> {
  __$RestauranteCopyWithImpl(this._self, this._then);

  final _Restaurante _self;
  final $Res Function(_Restaurante) _then;

/// Create a copy of Restaurante
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? nombre = null,Object? descripcion = freezed,Object? tipoCocina = freezed,Object? direccion = freezed,Object? activo = null,Object? createdAt = freezed,}) {
  return _then(_Restaurante(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,nombre: null == nombre ? _self.nombre : nombre // ignore: cast_nullable_to_non_nullable
as String,descripcion: freezed == descripcion ? _self.descripcion : descripcion // ignore: cast_nullable_to_non_nullable
as String?,tipoCocina: freezed == tipoCocina ? _self.tipoCocina : tipoCocina // ignore: cast_nullable_to_non_nullable
as String?,direccion: freezed == direccion ? _self.direccion : direccion // ignore: cast_nullable_to_non_nullable
as String?,activo: null == activo ? _self.activo : activo // ignore: cast_nullable_to_non_nullable
as bool,createdAt: freezed == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}


}

// dart format on
