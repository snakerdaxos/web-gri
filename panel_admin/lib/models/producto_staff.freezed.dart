// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'producto_staff.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$ProductoStaff {

 int get id;@JsonKey(name: 'categoria_id') int get categoriaId; String get nombre; String? get descripcion; double get precio;@JsonKey(name: 'imagen_url') String? get imagenUrl; bool get disponible; bool get activo;
/// Create a copy of ProductoStaff
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ProductoStaffCopyWith<ProductoStaff> get copyWith => _$ProductoStaffCopyWithImpl<ProductoStaff>(this as ProductoStaff, _$identity);

  /// Serializes this ProductoStaff to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ProductoStaff&&(identical(other.id, id) || other.id == id)&&(identical(other.categoriaId, categoriaId) || other.categoriaId == categoriaId)&&(identical(other.nombre, nombre) || other.nombre == nombre)&&(identical(other.descripcion, descripcion) || other.descripcion == descripcion)&&(identical(other.precio, precio) || other.precio == precio)&&(identical(other.imagenUrl, imagenUrl) || other.imagenUrl == imagenUrl)&&(identical(other.disponible, disponible) || other.disponible == disponible)&&(identical(other.activo, activo) || other.activo == activo));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,categoriaId,nombre,descripcion,precio,imagenUrl,disponible,activo);

@override
String toString() {
  return 'ProductoStaff(id: $id, categoriaId: $categoriaId, nombre: $nombre, descripcion: $descripcion, precio: $precio, imagenUrl: $imagenUrl, disponible: $disponible, activo: $activo)';
}


}

/// @nodoc
abstract mixin class $ProductoStaffCopyWith<$Res>  {
  factory $ProductoStaffCopyWith(ProductoStaff value, $Res Function(ProductoStaff) _then) = _$ProductoStaffCopyWithImpl;
@useResult
$Res call({
 int id,@JsonKey(name: 'categoria_id') int categoriaId, String nombre, String? descripcion, double precio,@JsonKey(name: 'imagen_url') String? imagenUrl, bool disponible, bool activo
});




}
/// @nodoc
class _$ProductoStaffCopyWithImpl<$Res>
    implements $ProductoStaffCopyWith<$Res> {
  _$ProductoStaffCopyWithImpl(this._self, this._then);

  final ProductoStaff _self;
  final $Res Function(ProductoStaff) _then;

/// Create a copy of ProductoStaff
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? categoriaId = null,Object? nombre = null,Object? descripcion = freezed,Object? precio = null,Object? imagenUrl = freezed,Object? disponible = null,Object? activo = null,}) {
  return _then(ProductoStaff(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,categoriaId: null == categoriaId ? _self.categoriaId : categoriaId // ignore: cast_nullable_to_non_nullable
as int,nombre: null == nombre ? _self.nombre : nombre // ignore: cast_nullable_to_non_nullable
as String,descripcion: freezed == descripcion ? _self.descripcion : descripcion // ignore: cast_nullable_to_non_nullable
as String?,precio: null == precio ? _self.precio : precio // ignore: cast_nullable_to_non_nullable
as double,imagenUrl: freezed == imagenUrl ? _self.imagenUrl : imagenUrl // ignore: cast_nullable_to_non_nullable
as String?,disponible: null == disponible ? _self.disponible : disponible // ignore: cast_nullable_to_non_nullable
as bool,activo: null == activo ? _self.activo : activo // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}


/// Adds pattern-matching-related methods to [ProductoStaff].
extension ProductoStaffPatterns on ProductoStaff {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ProductoStaff value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ProductoStaff() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ProductoStaff value)  $default,){
final _that = this;
switch (_that) {
case _ProductoStaff():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ProductoStaff value)?  $default,){
final _that = this;
switch (_that) {
case _ProductoStaff() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int id, @JsonKey(name: 'categoria_id')  int categoriaId,  String nombre,  String? descripcion,  double precio, @JsonKey(name: 'imagen_url')  String? imagenUrl,  bool disponible,  bool activo)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ProductoStaff() when $default != null:
return $default(_that.id,_that.categoriaId,_that.nombre,_that.descripcion,_that.precio,_that.imagenUrl,_that.disponible,_that.activo);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int id, @JsonKey(name: 'categoria_id')  int categoriaId,  String nombre,  String? descripcion,  double precio, @JsonKey(name: 'imagen_url')  String? imagenUrl,  bool disponible,  bool activo)  $default,) {final _that = this;
switch (_that) {
case _ProductoStaff():
return $default(_that.id,_that.categoriaId,_that.nombre,_that.descripcion,_that.precio,_that.imagenUrl,_that.disponible,_that.activo);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int id, @JsonKey(name: 'categoria_id')  int categoriaId,  String nombre,  String? descripcion,  double precio, @JsonKey(name: 'imagen_url')  String? imagenUrl,  bool disponible,  bool activo)?  $default,) {final _that = this;
switch (_that) {
case _ProductoStaff() when $default != null:
return $default(_that.id,_that.categoriaId,_that.nombre,_that.descripcion,_that.precio,_that.imagenUrl,_that.disponible,_that.activo);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _ProductoStaff implements ProductoStaff {
  const _ProductoStaff({required this.id, @JsonKey(name: 'categoria_id') required this.categoriaId, required this.nombre, required this.descripcion, required this.precio, @JsonKey(name: 'imagen_url') required this.imagenUrl, required this.disponible, required this.activo});
  factory _ProductoStaff.fromJson(Map<String, dynamic> json) => _$ProductoStaffFromJson(json);

@override final  int id;
@override@JsonKey(name: 'categoria_id') final  int categoriaId;
@override final  String nombre;
@override final  String? descripcion;
@override final  double precio;
@override@JsonKey(name: 'imagen_url') final  String? imagenUrl;
@override final  bool disponible;
@override final  bool activo;

/// Create a copy of ProductoStaff
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ProductoStaffCopyWith<_ProductoStaff> get copyWith => __$ProductoStaffCopyWithImpl<_ProductoStaff>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ProductoStaffToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ProductoStaff&&(identical(other.id, id) || other.id == id)&&(identical(other.categoriaId, categoriaId) || other.categoriaId == categoriaId)&&(identical(other.nombre, nombre) || other.nombre == nombre)&&(identical(other.descripcion, descripcion) || other.descripcion == descripcion)&&(identical(other.precio, precio) || other.precio == precio)&&(identical(other.imagenUrl, imagenUrl) || other.imagenUrl == imagenUrl)&&(identical(other.disponible, disponible) || other.disponible == disponible)&&(identical(other.activo, activo) || other.activo == activo));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,categoriaId,nombre,descripcion,precio,imagenUrl,disponible,activo);

@override
String toString() {
  return 'ProductoStaff(id: $id, categoriaId: $categoriaId, nombre: $nombre, descripcion: $descripcion, precio: $precio, imagenUrl: $imagenUrl, disponible: $disponible, activo: $activo)';
}


}

/// @nodoc
abstract mixin class _$ProductoStaffCopyWith<$Res> implements $ProductoStaffCopyWith<$Res> {
  factory _$ProductoStaffCopyWith(_ProductoStaff value, $Res Function(_ProductoStaff) _then) = __$ProductoStaffCopyWithImpl;
@override @useResult
$Res call({
 int id,@JsonKey(name: 'categoria_id') int categoriaId, String nombre, String? descripcion, double precio,@JsonKey(name: 'imagen_url') String? imagenUrl, bool disponible, bool activo
});




}
/// @nodoc
class __$ProductoStaffCopyWithImpl<$Res>
    implements _$ProductoStaffCopyWith<$Res> {
  __$ProductoStaffCopyWithImpl(this._self, this._then);

  final _ProductoStaff _self;
  final $Res Function(_ProductoStaff) _then;

/// Create a copy of ProductoStaff
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? categoriaId = null,Object? nombre = null,Object? descripcion = freezed,Object? precio = null,Object? imagenUrl = freezed,Object? disponible = null,Object? activo = null,}) {
  return _then(_ProductoStaff(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,categoriaId: null == categoriaId ? _self.categoriaId : categoriaId // ignore: cast_nullable_to_non_nullable
as int,nombre: null == nombre ? _self.nombre : nombre // ignore: cast_nullable_to_non_nullable
as String,descripcion: freezed == descripcion ? _self.descripcion : descripcion // ignore: cast_nullable_to_non_nullable
as String?,precio: null == precio ? _self.precio : precio // ignore: cast_nullable_to_non_nullable
as double,imagenUrl: freezed == imagenUrl ? _self.imagenUrl : imagenUrl // ignore: cast_nullable_to_non_nullable
as String?,disponible: null == disponible ? _self.disponible : disponible // ignore: cast_nullable_to_non_nullable
as bool,activo: null == activo ? _self.activo : activo // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}

// dart format on
