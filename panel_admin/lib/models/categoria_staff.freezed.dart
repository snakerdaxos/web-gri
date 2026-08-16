// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'categoria_staff.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$CategoriaStaff {

/// AutoId de Firestore (el menú no requiere determinismo).
 String get id;/// Tenant de la categoría — TODA query filtra por el rid activo.
 String get restauranteId; String get nombre; int get orden; bool get activo; List<ProductoStaff> get productos;
/// Create a copy of CategoriaStaff
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$CategoriaStaffCopyWith<CategoriaStaff> get copyWith => _$CategoriaStaffCopyWithImpl<CategoriaStaff>(this as CategoriaStaff, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is CategoriaStaff&&(identical(other.id, id) || other.id == id)&&(identical(other.restauranteId, restauranteId) || other.restauranteId == restauranteId)&&(identical(other.nombre, nombre) || other.nombre == nombre)&&(identical(other.orden, orden) || other.orden == orden)&&(identical(other.activo, activo) || other.activo == activo)&&const DeepCollectionEquality().equals(other.productos, productos));
}


@override
int get hashCode => Object.hash(runtimeType,id,restauranteId,nombre,orden,activo,const DeepCollectionEquality().hash(productos));

@override
String toString() {
  return 'CategoriaStaff(id: $id, restauranteId: $restauranteId, nombre: $nombre, orden: $orden, activo: $activo, productos: $productos)';
}


}

/// @nodoc
abstract mixin class $CategoriaStaffCopyWith<$Res>  {
  factory $CategoriaStaffCopyWith(CategoriaStaff value, $Res Function(CategoriaStaff) _then) = _$CategoriaStaffCopyWithImpl;
@useResult
$Res call({
 String id, String restauranteId, String nombre, int orden, bool activo, List<ProductoStaff> productos
});




}
/// @nodoc
class _$CategoriaStaffCopyWithImpl<$Res>
    implements $CategoriaStaffCopyWith<$Res> {
  _$CategoriaStaffCopyWithImpl(this._self, this._then);

  final CategoriaStaff _self;
  final $Res Function(CategoriaStaff) _then;

/// Create a copy of CategoriaStaff
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? restauranteId = null,Object? nombre = null,Object? orden = null,Object? activo = null,Object? productos = null,}) {
  return _then(CategoriaStaff(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,restauranteId: null == restauranteId ? _self.restauranteId : restauranteId // ignore: cast_nullable_to_non_nullable
as String,nombre: null == nombre ? _self.nombre : nombre // ignore: cast_nullable_to_non_nullable
as String,orden: null == orden ? _self.orden : orden // ignore: cast_nullable_to_non_nullable
as int,activo: null == activo ? _self.activo : activo // ignore: cast_nullable_to_non_nullable
as bool,productos: null == productos ? _self.productos : productos // ignore: cast_nullable_to_non_nullable
as List<ProductoStaff>,
  ));
}

}


/// Adds pattern-matching-related methods to [CategoriaStaff].
extension CategoriaStaffPatterns on CategoriaStaff {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _CategoriaStaff value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _CategoriaStaff() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _CategoriaStaff value)  $default,){
final _that = this;
switch (_that) {
case _CategoriaStaff():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _CategoriaStaff value)?  $default,){
final _that = this;
switch (_that) {
case _CategoriaStaff() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String restauranteId,  String nombre,  int orden,  bool activo,  List<ProductoStaff> productos)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _CategoriaStaff() when $default != null:
return $default(_that.id,_that.restauranteId,_that.nombre,_that.orden,_that.activo,_that.productos);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String restauranteId,  String nombre,  int orden,  bool activo,  List<ProductoStaff> productos)  $default,) {final _that = this;
switch (_that) {
case _CategoriaStaff():
return $default(_that.id,_that.restauranteId,_that.nombre,_that.orden,_that.activo,_that.productos);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String restauranteId,  String nombre,  int orden,  bool activo,  List<ProductoStaff> productos)?  $default,) {final _that = this;
switch (_that) {
case _CategoriaStaff() when $default != null:
return $default(_that.id,_that.restauranteId,_that.nombre,_that.orden,_that.activo,_that.productos);case _:
  return null;

}
}

}

/// @nodoc


class _CategoriaStaff implements CategoriaStaff {
  const _CategoriaStaff({required this.id, this.restauranteId = '', required this.nombre, required this.orden, required this.activo,  List<ProductoStaff> productos = const <ProductoStaff>[]}): _productos = productos;
  

/// AutoId de Firestore (el menú no requiere determinismo).
@override final  String id;
/// Tenant de la categoría — TODA query filtra por el rid activo.
@override@JsonKey() final  String restauranteId;
@override final  String nombre;
@override final  int orden;
@override final  bool activo;
 final  List<ProductoStaff> _productos;
@override@JsonKey() List<ProductoStaff> get productos {
  if (_productos is EqualUnmodifiableListView) return _productos;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_productos);
}


/// Create a copy of CategoriaStaff
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$CategoriaStaffCopyWith<_CategoriaStaff> get copyWith => __$CategoriaStaffCopyWithImpl<_CategoriaStaff>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _CategoriaStaff&&(identical(other.id, id) || other.id == id)&&(identical(other.restauranteId, restauranteId) || other.restauranteId == restauranteId)&&(identical(other.nombre, nombre) || other.nombre == nombre)&&(identical(other.orden, orden) || other.orden == orden)&&(identical(other.activo, activo) || other.activo == activo)&&const DeepCollectionEquality().equals(other._productos, _productos));
}


@override
int get hashCode => Object.hash(runtimeType,id,restauranteId,nombre,orden,activo,const DeepCollectionEquality().hash(_productos));

@override
String toString() {
  return 'CategoriaStaff(id: $id, restauranteId: $restauranteId, nombre: $nombre, orden: $orden, activo: $activo, productos: $productos)';
}


}

/// @nodoc
abstract mixin class _$CategoriaStaffCopyWith<$Res> implements $CategoriaStaffCopyWith<$Res> {
  factory _$CategoriaStaffCopyWith(_CategoriaStaff value, $Res Function(_CategoriaStaff) _then) = __$CategoriaStaffCopyWithImpl;
@override @useResult
$Res call({
 String id, String restauranteId, String nombre, int orden, bool activo, List<ProductoStaff> productos
});




}
/// @nodoc
class __$CategoriaStaffCopyWithImpl<$Res>
    implements _$CategoriaStaffCopyWith<$Res> {
  __$CategoriaStaffCopyWithImpl(this._self, this._then);

  final _CategoriaStaff _self;
  final $Res Function(_CategoriaStaff) _then;

/// Create a copy of CategoriaStaff
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? restauranteId = null,Object? nombre = null,Object? orden = null,Object? activo = null,Object? productos = null,}) {
  return _then(_CategoriaStaff(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,restauranteId: null == restauranteId ? _self.restauranteId : restauranteId // ignore: cast_nullable_to_non_nullable
as String,nombre: null == nombre ? _self.nombre : nombre // ignore: cast_nullable_to_non_nullable
as String,orden: null == orden ? _self.orden : orden // ignore: cast_nullable_to_non_nullable
as int,activo: null == activo ? _self.activo : activo // ignore: cast_nullable_to_non_nullable
as bool,productos: null == productos ? _self._productos : productos // ignore: cast_nullable_to_non_nullable
as List<ProductoStaff>,
  ));
}


}

// dart format on
