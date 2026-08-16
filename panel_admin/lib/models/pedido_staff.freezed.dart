// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'pedido_staff.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$PedidoStaffItem {

 String get productoId; String get nombre; int get cantidad; int get precio; int get subtotal;
/// Create a copy of PedidoStaffItem
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PedidoStaffItemCopyWith<PedidoStaffItem> get copyWith => _$PedidoStaffItemCopyWithImpl<PedidoStaffItem>(this as PedidoStaffItem, _$identity);

  /// Serializes this PedidoStaffItem to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PedidoStaffItem&&(identical(other.productoId, productoId) || other.productoId == productoId)&&(identical(other.nombre, nombre) || other.nombre == nombre)&&(identical(other.cantidad, cantidad) || other.cantidad == cantidad)&&(identical(other.precio, precio) || other.precio == precio)&&(identical(other.subtotal, subtotal) || other.subtotal == subtotal));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,productoId,nombre,cantidad,precio,subtotal);

@override
String toString() {
  return 'PedidoStaffItem(productoId: $productoId, nombre: $nombre, cantidad: $cantidad, precio: $precio, subtotal: $subtotal)';
}


}

/// @nodoc
abstract mixin class $PedidoStaffItemCopyWith<$Res>  {
  factory $PedidoStaffItemCopyWith(PedidoStaffItem value, $Res Function(PedidoStaffItem) _then) = _$PedidoStaffItemCopyWithImpl;
@useResult
$Res call({
 String productoId, String nombre, int cantidad, int precio, int subtotal
});




}
/// @nodoc
class _$PedidoStaffItemCopyWithImpl<$Res>
    implements $PedidoStaffItemCopyWith<$Res> {
  _$PedidoStaffItemCopyWithImpl(this._self, this._then);

  final PedidoStaffItem _self;
  final $Res Function(PedidoStaffItem) _then;

/// Create a copy of PedidoStaffItem
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? productoId = null,Object? nombre = null,Object? cantidad = null,Object? precio = null,Object? subtotal = null,}) {
  return _then(PedidoStaffItem(
productoId: null == productoId ? _self.productoId : productoId // ignore: cast_nullable_to_non_nullable
as String,nombre: null == nombre ? _self.nombre : nombre // ignore: cast_nullable_to_non_nullable
as String,cantidad: null == cantidad ? _self.cantidad : cantidad // ignore: cast_nullable_to_non_nullable
as int,precio: null == precio ? _self.precio : precio // ignore: cast_nullable_to_non_nullable
as int,subtotal: null == subtotal ? _self.subtotal : subtotal // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}


/// Adds pattern-matching-related methods to [PedidoStaffItem].
extension PedidoStaffItemPatterns on PedidoStaffItem {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _PedidoStaffItem value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _PedidoStaffItem() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _PedidoStaffItem value)  $default,){
final _that = this;
switch (_that) {
case _PedidoStaffItem():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _PedidoStaffItem value)?  $default,){
final _that = this;
switch (_that) {
case _PedidoStaffItem() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String productoId,  String nombre,  int cantidad,  int precio,  int subtotal)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _PedidoStaffItem() when $default != null:
return $default(_that.productoId,_that.nombre,_that.cantidad,_that.precio,_that.subtotal);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String productoId,  String nombre,  int cantidad,  int precio,  int subtotal)  $default,) {final _that = this;
switch (_that) {
case _PedidoStaffItem():
return $default(_that.productoId,_that.nombre,_that.cantidad,_that.precio,_that.subtotal);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String productoId,  String nombre,  int cantidad,  int precio,  int subtotal)?  $default,) {final _that = this;
switch (_that) {
case _PedidoStaffItem() when $default != null:
return $default(_that.productoId,_that.nombre,_that.cantidad,_that.precio,_that.subtotal);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _PedidoStaffItem implements PedidoStaffItem {
  const _PedidoStaffItem({required this.productoId, required this.nombre, required this.cantidad, required this.precio, required this.subtotal});
  factory _PedidoStaffItem.fromJson(Map<String, dynamic> json) => _$PedidoStaffItemFromJson(json);

@override final  String productoId;
@override final  String nombre;
@override final  int cantidad;
@override final  int precio;
@override final  int subtotal;

/// Create a copy of PedidoStaffItem
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$PedidoStaffItemCopyWith<_PedidoStaffItem> get copyWith => __$PedidoStaffItemCopyWithImpl<_PedidoStaffItem>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$PedidoStaffItemToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _PedidoStaffItem&&(identical(other.productoId, productoId) || other.productoId == productoId)&&(identical(other.nombre, nombre) || other.nombre == nombre)&&(identical(other.cantidad, cantidad) || other.cantidad == cantidad)&&(identical(other.precio, precio) || other.precio == precio)&&(identical(other.subtotal, subtotal) || other.subtotal == subtotal));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,productoId,nombre,cantidad,precio,subtotal);

@override
String toString() {
  return 'PedidoStaffItem(productoId: $productoId, nombre: $nombre, cantidad: $cantidad, precio: $precio, subtotal: $subtotal)';
}


}

/// @nodoc
abstract mixin class _$PedidoStaffItemCopyWith<$Res> implements $PedidoStaffItemCopyWith<$Res> {
  factory _$PedidoStaffItemCopyWith(_PedidoStaffItem value, $Res Function(_PedidoStaffItem) _then) = __$PedidoStaffItemCopyWithImpl;
@override @useResult
$Res call({
 String productoId, String nombre, int cantidad, int precio, int subtotal
});




}
/// @nodoc
class __$PedidoStaffItemCopyWithImpl<$Res>
    implements _$PedidoStaffItemCopyWith<$Res> {
  __$PedidoStaffItemCopyWithImpl(this._self, this._then);

  final _PedidoStaffItem _self;
  final $Res Function(_PedidoStaffItem) _then;

/// Create a copy of PedidoStaffItem
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? productoId = null,Object? nombre = null,Object? cantidad = null,Object? precio = null,Object? subtotal = null,}) {
  return _then(_PedidoStaffItem(
productoId: null == productoId ? _self.productoId : productoId // ignore: cast_nullable_to_non_nullable
as String,nombre: null == nombre ? _self.nombre : nombre // ignore: cast_nullable_to_non_nullable
as String,cantidad: null == cantidad ? _self.cantidad : cantidad // ignore: cast_nullable_to_non_nullable
as int,precio: null == precio ? _self.precio : precio // ignore: cast_nullable_to_non_nullable
as int,subtotal: null == subtotal ? _self.subtotal : subtotal // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}


/// @nodoc
mixin _$PedidoStaff {

/// AutoId de Firestore.
 String get id; String get restauranteId;/// Código QR de la mesa (doc ID determinista).
 String get mesaId; String? get sesionId;/// Derivado de [mesaId] (sufijo numérico del QR).
 int get mesaNumero;@JsonKey(fromJson: estadoPedidoFromJson, toJson: estadoPedidoToJson) EstadoPedido get estado; int get total; String? get notas; DateTime get createdAt; List<PedidoStaffItem> get items; String get usuarioNombre; bool get solicitaCuenta; DateTime? get solicitadaEn;
/// Create a copy of PedidoStaff
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PedidoStaffCopyWith<PedidoStaff> get copyWith => _$PedidoStaffCopyWithImpl<PedidoStaff>(this as PedidoStaff, _$identity);

  /// Serializes this PedidoStaff to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PedidoStaff&&(identical(other.id, id) || other.id == id)&&(identical(other.restauranteId, restauranteId) || other.restauranteId == restauranteId)&&(identical(other.mesaId, mesaId) || other.mesaId == mesaId)&&(identical(other.sesionId, sesionId) || other.sesionId == sesionId)&&(identical(other.mesaNumero, mesaNumero) || other.mesaNumero == mesaNumero)&&(identical(other.estado, estado) || other.estado == estado)&&(identical(other.total, total) || other.total == total)&&(identical(other.notas, notas) || other.notas == notas)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&const DeepCollectionEquality().equals(other.items, items)&&(identical(other.usuarioNombre, usuarioNombre) || other.usuarioNombre == usuarioNombre)&&(identical(other.solicitaCuenta, solicitaCuenta) || other.solicitaCuenta == solicitaCuenta)&&(identical(other.solicitadaEn, solicitadaEn) || other.solicitadaEn == solicitadaEn));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,restauranteId,mesaId,sesionId,mesaNumero,estado,total,notas,createdAt,const DeepCollectionEquality().hash(items),usuarioNombre,solicitaCuenta,solicitadaEn);

@override
String toString() {
  return 'PedidoStaff(id: $id, restauranteId: $restauranteId, mesaId: $mesaId, sesionId: $sesionId, mesaNumero: $mesaNumero, estado: $estado, total: $total, notas: $notas, createdAt: $createdAt, items: $items, usuarioNombre: $usuarioNombre, solicitaCuenta: $solicitaCuenta, solicitadaEn: $solicitadaEn)';
}


}

/// @nodoc
abstract mixin class $PedidoStaffCopyWith<$Res>  {
  factory $PedidoStaffCopyWith(PedidoStaff value, $Res Function(PedidoStaff) _then) = _$PedidoStaffCopyWithImpl;
@useResult
$Res call({
 String id, String restauranteId, String mesaId, String? sesionId, int mesaNumero,@JsonKey(fromJson: estadoPedidoFromJson, toJson: estadoPedidoToJson) EstadoPedido estado, int total, String? notas, DateTime createdAt, List<PedidoStaffItem> items, String usuarioNombre, bool solicitaCuenta, DateTime? solicitadaEn
});




}
/// @nodoc
class _$PedidoStaffCopyWithImpl<$Res>
    implements $PedidoStaffCopyWith<$Res> {
  _$PedidoStaffCopyWithImpl(this._self, this._then);

  final PedidoStaff _self;
  final $Res Function(PedidoStaff) _then;

/// Create a copy of PedidoStaff
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? restauranteId = null,Object? mesaId = null,Object? sesionId = freezed,Object? mesaNumero = null,Object? estado = null,Object? total = null,Object? notas = freezed,Object? createdAt = null,Object? items = null,Object? usuarioNombre = null,Object? solicitaCuenta = null,Object? solicitadaEn = freezed,}) {
  return _then(PedidoStaff(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,restauranteId: null == restauranteId ? _self.restauranteId : restauranteId // ignore: cast_nullable_to_non_nullable
as String,mesaId: null == mesaId ? _self.mesaId : mesaId // ignore: cast_nullable_to_non_nullable
as String,sesionId: freezed == sesionId ? _self.sesionId : sesionId // ignore: cast_nullable_to_non_nullable
as String?,mesaNumero: null == mesaNumero ? _self.mesaNumero : mesaNumero // ignore: cast_nullable_to_non_nullable
as int,estado: null == estado ? _self.estado : estado // ignore: cast_nullable_to_non_nullable
as EstadoPedido,total: null == total ? _self.total : total // ignore: cast_nullable_to_non_nullable
as int,notas: freezed == notas ? _self.notas : notas // ignore: cast_nullable_to_non_nullable
as String?,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,items: null == items ? _self.items : items // ignore: cast_nullable_to_non_nullable
as List<PedidoStaffItem>,usuarioNombre: null == usuarioNombre ? _self.usuarioNombre : usuarioNombre // ignore: cast_nullable_to_non_nullable
as String,solicitaCuenta: null == solicitaCuenta ? _self.solicitaCuenta : solicitaCuenta // ignore: cast_nullable_to_non_nullable
as bool,solicitadaEn: freezed == solicitadaEn ? _self.solicitadaEn : solicitadaEn // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}

}


/// Adds pattern-matching-related methods to [PedidoStaff].
extension PedidoStaffPatterns on PedidoStaff {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _PedidoStaff value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _PedidoStaff() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _PedidoStaff value)  $default,){
final _that = this;
switch (_that) {
case _PedidoStaff():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _PedidoStaff value)?  $default,){
final _that = this;
switch (_that) {
case _PedidoStaff() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String restauranteId,  String mesaId,  String? sesionId,  int mesaNumero, @JsonKey(fromJson: estadoPedidoFromJson, toJson: estadoPedidoToJson)  EstadoPedido estado,  int total,  String? notas,  DateTime createdAt,  List<PedidoStaffItem> items,  String usuarioNombre,  bool solicitaCuenta,  DateTime? solicitadaEn)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _PedidoStaff() when $default != null:
return $default(_that.id,_that.restauranteId,_that.mesaId,_that.sesionId,_that.mesaNumero,_that.estado,_that.total,_that.notas,_that.createdAt,_that.items,_that.usuarioNombre,_that.solicitaCuenta,_that.solicitadaEn);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String restauranteId,  String mesaId,  String? sesionId,  int mesaNumero, @JsonKey(fromJson: estadoPedidoFromJson, toJson: estadoPedidoToJson)  EstadoPedido estado,  int total,  String? notas,  DateTime createdAt,  List<PedidoStaffItem> items,  String usuarioNombre,  bool solicitaCuenta,  DateTime? solicitadaEn)  $default,) {final _that = this;
switch (_that) {
case _PedidoStaff():
return $default(_that.id,_that.restauranteId,_that.mesaId,_that.sesionId,_that.mesaNumero,_that.estado,_that.total,_that.notas,_that.createdAt,_that.items,_that.usuarioNombre,_that.solicitaCuenta,_that.solicitadaEn);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String restauranteId,  String mesaId,  String? sesionId,  int mesaNumero, @JsonKey(fromJson: estadoPedidoFromJson, toJson: estadoPedidoToJson)  EstadoPedido estado,  int total,  String? notas,  DateTime createdAt,  List<PedidoStaffItem> items,  String usuarioNombre,  bool solicitaCuenta,  DateTime? solicitadaEn)?  $default,) {final _that = this;
switch (_that) {
case _PedidoStaff() when $default != null:
return $default(_that.id,_that.restauranteId,_that.mesaId,_that.sesionId,_that.mesaNumero,_that.estado,_that.total,_that.notas,_that.createdAt,_that.items,_that.usuarioNombre,_that.solicitaCuenta,_that.solicitadaEn);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _PedidoStaff implements PedidoStaff {
  const _PedidoStaff({required this.id, this.restauranteId = '', this.mesaId = '', required this.sesionId, required this.mesaNumero, @JsonKey(fromJson: estadoPedidoFromJson, toJson: estadoPedidoToJson) required this.estado, required this.total, required this.notas, required this.createdAt, required  List<PedidoStaffItem> items, required this.usuarioNombre, this.solicitaCuenta = false, this.solicitadaEn}): _items = items;
  factory _PedidoStaff.fromJson(Map<String, dynamic> json) => _$PedidoStaffFromJson(json);

/// AutoId de Firestore.
@override final  String id;
@override@JsonKey() final  String restauranteId;
/// Código QR de la mesa (doc ID determinista).
@override@JsonKey() final  String mesaId;
@override final  String? sesionId;
/// Derivado de [mesaId] (sufijo numérico del QR).
@override final  int mesaNumero;
@override@JsonKey(fromJson: estadoPedidoFromJson, toJson: estadoPedidoToJson) final  EstadoPedido estado;
@override final  int total;
@override final  String? notas;
@override final  DateTime createdAt;
 final  List<PedidoStaffItem> _items;
@override List<PedidoStaffItem> get items {
  if (_items is EqualUnmodifiableListView) return _items;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_items);
}

@override final  String usuarioNombre;
@override@JsonKey() final  bool solicitaCuenta;
@override final  DateTime? solicitadaEn;

/// Create a copy of PedidoStaff
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$PedidoStaffCopyWith<_PedidoStaff> get copyWith => __$PedidoStaffCopyWithImpl<_PedidoStaff>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$PedidoStaffToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _PedidoStaff&&(identical(other.id, id) || other.id == id)&&(identical(other.restauranteId, restauranteId) || other.restauranteId == restauranteId)&&(identical(other.mesaId, mesaId) || other.mesaId == mesaId)&&(identical(other.sesionId, sesionId) || other.sesionId == sesionId)&&(identical(other.mesaNumero, mesaNumero) || other.mesaNumero == mesaNumero)&&(identical(other.estado, estado) || other.estado == estado)&&(identical(other.total, total) || other.total == total)&&(identical(other.notas, notas) || other.notas == notas)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&const DeepCollectionEquality().equals(other._items, _items)&&(identical(other.usuarioNombre, usuarioNombre) || other.usuarioNombre == usuarioNombre)&&(identical(other.solicitaCuenta, solicitaCuenta) || other.solicitaCuenta == solicitaCuenta)&&(identical(other.solicitadaEn, solicitadaEn) || other.solicitadaEn == solicitadaEn));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,restauranteId,mesaId,sesionId,mesaNumero,estado,total,notas,createdAt,const DeepCollectionEquality().hash(_items),usuarioNombre,solicitaCuenta,solicitadaEn);

@override
String toString() {
  return 'PedidoStaff(id: $id, restauranteId: $restauranteId, mesaId: $mesaId, sesionId: $sesionId, mesaNumero: $mesaNumero, estado: $estado, total: $total, notas: $notas, createdAt: $createdAt, items: $items, usuarioNombre: $usuarioNombre, solicitaCuenta: $solicitaCuenta, solicitadaEn: $solicitadaEn)';
}


}

/// @nodoc
abstract mixin class _$PedidoStaffCopyWith<$Res> implements $PedidoStaffCopyWith<$Res> {
  factory _$PedidoStaffCopyWith(_PedidoStaff value, $Res Function(_PedidoStaff) _then) = __$PedidoStaffCopyWithImpl;
@override @useResult
$Res call({
 String id, String restauranteId, String mesaId, String? sesionId, int mesaNumero,@JsonKey(fromJson: estadoPedidoFromJson, toJson: estadoPedidoToJson) EstadoPedido estado, int total, String? notas, DateTime createdAt, List<PedidoStaffItem> items, String usuarioNombre, bool solicitaCuenta, DateTime? solicitadaEn
});




}
/// @nodoc
class __$PedidoStaffCopyWithImpl<$Res>
    implements _$PedidoStaffCopyWith<$Res> {
  __$PedidoStaffCopyWithImpl(this._self, this._then);

  final _PedidoStaff _self;
  final $Res Function(_PedidoStaff) _then;

/// Create a copy of PedidoStaff
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? restauranteId = null,Object? mesaId = null,Object? sesionId = freezed,Object? mesaNumero = null,Object? estado = null,Object? total = null,Object? notas = freezed,Object? createdAt = null,Object? items = null,Object? usuarioNombre = null,Object? solicitaCuenta = null,Object? solicitadaEn = freezed,}) {
  return _then(_PedidoStaff(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,restauranteId: null == restauranteId ? _self.restauranteId : restauranteId // ignore: cast_nullable_to_non_nullable
as String,mesaId: null == mesaId ? _self.mesaId : mesaId // ignore: cast_nullable_to_non_nullable
as String,sesionId: freezed == sesionId ? _self.sesionId : sesionId // ignore: cast_nullable_to_non_nullable
as String?,mesaNumero: null == mesaNumero ? _self.mesaNumero : mesaNumero // ignore: cast_nullable_to_non_nullable
as int,estado: null == estado ? _self.estado : estado // ignore: cast_nullable_to_non_nullable
as EstadoPedido,total: null == total ? _self.total : total // ignore: cast_nullable_to_non_nullable
as int,notas: freezed == notas ? _self.notas : notas // ignore: cast_nullable_to_non_nullable
as String?,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,items: null == items ? _self._items : items // ignore: cast_nullable_to_non_nullable
as List<PedidoStaffItem>,usuarioNombre: null == usuarioNombre ? _self.usuarioNombre : usuarioNombre // ignore: cast_nullable_to_non_nullable
as String,solicitaCuenta: null == solicitaCuenta ? _self.solicitaCuenta : solicitaCuenta // ignore: cast_nullable_to_non_nullable
as bool,solicitadaEn: freezed == solicitadaEn ? _self.solicitadaEn : solicitadaEn // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}


}

// dart format on
