// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'pedido_item.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$PedidoItem {

 String get productoId; String get nombre; int get precio; int get cantidad;
/// Create a copy of PedidoItem
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PedidoItemCopyWith<PedidoItem> get copyWith => _$PedidoItemCopyWithImpl<PedidoItem>(this as PedidoItem, _$identity);

  /// Serializes this PedidoItem to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PedidoItem&&(identical(other.productoId, productoId) || other.productoId == productoId)&&(identical(other.nombre, nombre) || other.nombre == nombre)&&(identical(other.precio, precio) || other.precio == precio)&&(identical(other.cantidad, cantidad) || other.cantidad == cantidad));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,productoId,nombre,precio,cantidad);

@override
String toString() {
  return 'PedidoItem(productoId: $productoId, nombre: $nombre, precio: $precio, cantidad: $cantidad)';
}


}

/// @nodoc
abstract mixin class $PedidoItemCopyWith<$Res>  {
  factory $PedidoItemCopyWith(PedidoItem value, $Res Function(PedidoItem) _then) = _$PedidoItemCopyWithImpl;
@useResult
$Res call({
 String productoId, String nombre, int precio, int cantidad
});




}
/// @nodoc
class _$PedidoItemCopyWithImpl<$Res>
    implements $PedidoItemCopyWith<$Res> {
  _$PedidoItemCopyWithImpl(this._self, this._then);

  final PedidoItem _self;
  final $Res Function(PedidoItem) _then;

/// Create a copy of PedidoItem
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? productoId = null,Object? nombre = null,Object? precio = null,Object? cantidad = null,}) {
  return _then(PedidoItem(
productoId: null == productoId ? _self.productoId : productoId // ignore: cast_nullable_to_non_nullable
as String,nombre: null == nombre ? _self.nombre : nombre // ignore: cast_nullable_to_non_nullable
as String,precio: null == precio ? _self.precio : precio // ignore: cast_nullable_to_non_nullable
as int,cantidad: null == cantidad ? _self.cantidad : cantidad // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}


/// Adds pattern-matching-related methods to [PedidoItem].
extension PedidoItemPatterns on PedidoItem {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _PedidoItem value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _PedidoItem() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _PedidoItem value)  $default,){
final _that = this;
switch (_that) {
case _PedidoItem():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _PedidoItem value)?  $default,){
final _that = this;
switch (_that) {
case _PedidoItem() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String productoId,  String nombre,  int precio,  int cantidad)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _PedidoItem() when $default != null:
return $default(_that.productoId,_that.nombre,_that.precio,_that.cantidad);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String productoId,  String nombre,  int precio,  int cantidad)  $default,) {final _that = this;
switch (_that) {
case _PedidoItem():
return $default(_that.productoId,_that.nombre,_that.precio,_that.cantidad);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String productoId,  String nombre,  int precio,  int cantidad)?  $default,) {final _that = this;
switch (_that) {
case _PedidoItem() when $default != null:
return $default(_that.productoId,_that.nombre,_that.precio,_that.cantidad);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _PedidoItem implements PedidoItem {
  const _PedidoItem({required this.productoId, required this.nombre, required this.precio, required this.cantidad});
  factory _PedidoItem.fromJson(Map<String, dynamic> json) => _$PedidoItemFromJson(json);

@override final  String productoId;
@override final  String nombre;
@override final  int precio;
@override final  int cantidad;

/// Create a copy of PedidoItem
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$PedidoItemCopyWith<_PedidoItem> get copyWith => __$PedidoItemCopyWithImpl<_PedidoItem>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$PedidoItemToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _PedidoItem&&(identical(other.productoId, productoId) || other.productoId == productoId)&&(identical(other.nombre, nombre) || other.nombre == nombre)&&(identical(other.precio, precio) || other.precio == precio)&&(identical(other.cantidad, cantidad) || other.cantidad == cantidad));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,productoId,nombre,precio,cantidad);

@override
String toString() {
  return 'PedidoItem(productoId: $productoId, nombre: $nombre, precio: $precio, cantidad: $cantidad)';
}


}

/// @nodoc
abstract mixin class _$PedidoItemCopyWith<$Res> implements $PedidoItemCopyWith<$Res> {
  factory _$PedidoItemCopyWith(_PedidoItem value, $Res Function(_PedidoItem) _then) = __$PedidoItemCopyWithImpl;
@override @useResult
$Res call({
 String productoId, String nombre, int precio, int cantidad
});




}
/// @nodoc
class __$PedidoItemCopyWithImpl<$Res>
    implements _$PedidoItemCopyWith<$Res> {
  __$PedidoItemCopyWithImpl(this._self, this._then);

  final _PedidoItem _self;
  final $Res Function(_PedidoItem) _then;

/// Create a copy of PedidoItem
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? productoId = null,Object? nombre = null,Object? precio = null,Object? cantidad = null,}) {
  return _then(_PedidoItem(
productoId: null == productoId ? _self.productoId : productoId // ignore: cast_nullable_to_non_nullable
as String,nombre: null == nombre ? _self.nombre : nombre // ignore: cast_nullable_to_non_nullable
as String,precio: null == precio ? _self.precio : precio // ignore: cast_nullable_to_non_nullable
as int,cantidad: null == cantidad ? _self.cantidad : cantidad // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

// dart format on
