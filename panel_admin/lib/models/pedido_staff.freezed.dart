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

@JsonKey(name: 'producto_id') int get productoId; String get nombre; int get cantidad;@JsonKey(name: 'precio_unitario') double get precioUnitario; double get subtotal;
/// Create a copy of PedidoStaffItem
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PedidoStaffItemCopyWith<PedidoStaffItem> get copyWith => _$PedidoStaffItemCopyWithImpl<PedidoStaffItem>(this as PedidoStaffItem, _$identity);

  /// Serializes this PedidoStaffItem to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PedidoStaffItem&&(identical(other.productoId, productoId) || other.productoId == productoId)&&(identical(other.nombre, nombre) || other.nombre == nombre)&&(identical(other.cantidad, cantidad) || other.cantidad == cantidad)&&(identical(other.precioUnitario, precioUnitario) || other.precioUnitario == precioUnitario)&&(identical(other.subtotal, subtotal) || other.subtotal == subtotal));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,productoId,nombre,cantidad,precioUnitario,subtotal);

@override
String toString() {
  return 'PedidoStaffItem(productoId: $productoId, nombre: $nombre, cantidad: $cantidad, precioUnitario: $precioUnitario, subtotal: $subtotal)';
}


}

/// @nodoc
abstract mixin class $PedidoStaffItemCopyWith<$Res>  {
  factory $PedidoStaffItemCopyWith(PedidoStaffItem value, $Res Function(PedidoStaffItem) _then) = _$PedidoStaffItemCopyWithImpl;
@useResult
$Res call({
@JsonKey(name: 'producto_id') int productoId, String nombre, int cantidad,@JsonKey(name: 'precio_unitario') double precioUnitario, double subtotal
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
@pragma('vm:prefer-inline') @override $Res call({Object? productoId = null,Object? nombre = null,Object? cantidad = null,Object? precioUnitario = null,Object? subtotal = null,}) {
  return _then(PedidoStaffItem(
productoId: null == productoId ? _self.productoId : productoId // ignore: cast_nullable_to_non_nullable
as int,nombre: null == nombre ? _self.nombre : nombre // ignore: cast_nullable_to_non_nullable
as String,cantidad: null == cantidad ? _self.cantidad : cantidad // ignore: cast_nullable_to_non_nullable
as int,precioUnitario: null == precioUnitario ? _self.precioUnitario : precioUnitario // ignore: cast_nullable_to_non_nullable
as double,subtotal: null == subtotal ? _self.subtotal : subtotal // ignore: cast_nullable_to_non_nullable
as double,
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function(@JsonKey(name: 'producto_id')  int productoId,  String nombre,  int cantidad, @JsonKey(name: 'precio_unitario')  double precioUnitario,  double subtotal)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _PedidoStaffItem() when $default != null:
return $default(_that.productoId,_that.nombre,_that.cantidad,_that.precioUnitario,_that.subtotal);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function(@JsonKey(name: 'producto_id')  int productoId,  String nombre,  int cantidad, @JsonKey(name: 'precio_unitario')  double precioUnitario,  double subtotal)  $default,) {final _that = this;
switch (_that) {
case _PedidoStaffItem():
return $default(_that.productoId,_that.nombre,_that.cantidad,_that.precioUnitario,_that.subtotal);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function(@JsonKey(name: 'producto_id')  int productoId,  String nombre,  int cantidad, @JsonKey(name: 'precio_unitario')  double precioUnitario,  double subtotal)?  $default,) {final _that = this;
switch (_that) {
case _PedidoStaffItem() when $default != null:
return $default(_that.productoId,_that.nombre,_that.cantidad,_that.precioUnitario,_that.subtotal);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _PedidoStaffItem implements PedidoStaffItem {
  const _PedidoStaffItem({@JsonKey(name: 'producto_id') required this.productoId, required this.nombre, required this.cantidad, @JsonKey(name: 'precio_unitario') required this.precioUnitario, required this.subtotal});
  factory _PedidoStaffItem.fromJson(Map<String, dynamic> json) => _$PedidoStaffItemFromJson(json);

@override@JsonKey(name: 'producto_id') final  int productoId;
@override final  String nombre;
@override final  int cantidad;
@override@JsonKey(name: 'precio_unitario') final  double precioUnitario;
@override final  double subtotal;

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
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _PedidoStaffItem&&(identical(other.productoId, productoId) || other.productoId == productoId)&&(identical(other.nombre, nombre) || other.nombre == nombre)&&(identical(other.cantidad, cantidad) || other.cantidad == cantidad)&&(identical(other.precioUnitario, precioUnitario) || other.precioUnitario == precioUnitario)&&(identical(other.subtotal, subtotal) || other.subtotal == subtotal));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,productoId,nombre,cantidad,precioUnitario,subtotal);

@override
String toString() {
  return 'PedidoStaffItem(productoId: $productoId, nombre: $nombre, cantidad: $cantidad, precioUnitario: $precioUnitario, subtotal: $subtotal)';
}


}

/// @nodoc
abstract mixin class _$PedidoStaffItemCopyWith<$Res> implements $PedidoStaffItemCopyWith<$Res> {
  factory _$PedidoStaffItemCopyWith(_PedidoStaffItem value, $Res Function(_PedidoStaffItem) _then) = __$PedidoStaffItemCopyWithImpl;
@override @useResult
$Res call({
@JsonKey(name: 'producto_id') int productoId, String nombre, int cantidad,@JsonKey(name: 'precio_unitario') double precioUnitario, double subtotal
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
@override @pragma('vm:prefer-inline') $Res call({Object? productoId = null,Object? nombre = null,Object? cantidad = null,Object? precioUnitario = null,Object? subtotal = null,}) {
  return _then(_PedidoStaffItem(
productoId: null == productoId ? _self.productoId : productoId // ignore: cast_nullable_to_non_nullable
as int,nombre: null == nombre ? _self.nombre : nombre // ignore: cast_nullable_to_non_nullable
as String,cantidad: null == cantidad ? _self.cantidad : cantidad // ignore: cast_nullable_to_non_nullable
as int,precioUnitario: null == precioUnitario ? _self.precioUnitario : precioUnitario // ignore: cast_nullable_to_non_nullable
as double,subtotal: null == subtotal ? _self.subtotal : subtotal // ignore: cast_nullable_to_non_nullable
as double,
  ));
}


}


/// @nodoc
mixin _$PedidoStaff {

 int get id;@JsonKey(name: 'sesion_id') int? get sesionId;@JsonKey(name: 'mesa_numero') int get mesaNumero;@JsonKey(fromJson: estadoPedidoFromJson, toJson: estadoPedidoToJson) EstadoPedido get estado; double get total; String? get notas;@JsonKey(name: 'created_at') DateTime get createdAt; List<PedidoStaffItem> get items;@JsonKey(name: 'usuario_nombre') String get usuarioNombre;@JsonKey(name: 'solicita_cuenta', defaultValue: false) bool get solicitaCuenta;@JsonKey(name: 'solicitada_en') DateTime? get solicitadaEn;
/// Create a copy of PedidoStaff
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PedidoStaffCopyWith<PedidoStaff> get copyWith => _$PedidoStaffCopyWithImpl<PedidoStaff>(this as PedidoStaff, _$identity);

  /// Serializes this PedidoStaff to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PedidoStaff&&(identical(other.id, id) || other.id == id)&&(identical(other.sesionId, sesionId) || other.sesionId == sesionId)&&(identical(other.mesaNumero, mesaNumero) || other.mesaNumero == mesaNumero)&&(identical(other.estado, estado) || other.estado == estado)&&(identical(other.total, total) || other.total == total)&&(identical(other.notas, notas) || other.notas == notas)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&const DeepCollectionEquality().equals(other.items, items)&&(identical(other.usuarioNombre, usuarioNombre) || other.usuarioNombre == usuarioNombre)&&(identical(other.solicitaCuenta, solicitaCuenta) || other.solicitaCuenta == solicitaCuenta)&&(identical(other.solicitadaEn, solicitadaEn) || other.solicitadaEn == solicitadaEn));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,sesionId,mesaNumero,estado,total,notas,createdAt,const DeepCollectionEquality().hash(items),usuarioNombre,solicitaCuenta,solicitadaEn);

@override
String toString() {
  return 'PedidoStaff(id: $id, sesionId: $sesionId, mesaNumero: $mesaNumero, estado: $estado, total: $total, notas: $notas, createdAt: $createdAt, items: $items, usuarioNombre: $usuarioNombre, solicitaCuenta: $solicitaCuenta, solicitadaEn: $solicitadaEn)';
}


}

/// @nodoc
abstract mixin class $PedidoStaffCopyWith<$Res>  {
  factory $PedidoStaffCopyWith(PedidoStaff value, $Res Function(PedidoStaff) _then) = _$PedidoStaffCopyWithImpl;
@useResult
$Res call({
 int id,@JsonKey(name: 'sesion_id') int? sesionId,@JsonKey(name: 'mesa_numero') int mesaNumero,@JsonKey(fromJson: estadoPedidoFromJson, toJson: estadoPedidoToJson) EstadoPedido estado, double total, String? notas,@JsonKey(name: 'created_at') DateTime createdAt, List<PedidoStaffItem> items,@JsonKey(name: 'usuario_nombre') String usuarioNombre,@JsonKey(name: 'solicita_cuenta', defaultValue: false) bool solicitaCuenta,@JsonKey(name: 'solicitada_en') DateTime? solicitadaEn
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
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? sesionId = freezed,Object? mesaNumero = null,Object? estado = null,Object? total = null,Object? notas = freezed,Object? createdAt = null,Object? items = null,Object? usuarioNombre = null,Object? solicitaCuenta = null,Object? solicitadaEn = freezed,}) {
  return _then(PedidoStaff(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,sesionId: freezed == sesionId ? _self.sesionId : sesionId // ignore: cast_nullable_to_non_nullable
as int?,mesaNumero: null == mesaNumero ? _self.mesaNumero : mesaNumero // ignore: cast_nullable_to_non_nullable
as int,estado: null == estado ? _self.estado : estado // ignore: cast_nullable_to_non_nullable
as EstadoPedido,total: null == total ? _self.total : total // ignore: cast_nullable_to_non_nullable
as double,notas: freezed == notas ? _self.notas : notas // ignore: cast_nullable_to_non_nullable
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int id, @JsonKey(name: 'sesion_id')  int? sesionId, @JsonKey(name: 'mesa_numero')  int mesaNumero, @JsonKey(fromJson: estadoPedidoFromJson, toJson: estadoPedidoToJson)  EstadoPedido estado,  double total,  String? notas, @JsonKey(name: 'created_at')  DateTime createdAt,  List<PedidoStaffItem> items, @JsonKey(name: 'usuario_nombre')  String usuarioNombre, @JsonKey(name: 'solicita_cuenta', defaultValue: false)  bool solicitaCuenta, @JsonKey(name: 'solicitada_en')  DateTime? solicitadaEn)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _PedidoStaff() when $default != null:
return $default(_that.id,_that.sesionId,_that.mesaNumero,_that.estado,_that.total,_that.notas,_that.createdAt,_that.items,_that.usuarioNombre,_that.solicitaCuenta,_that.solicitadaEn);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int id, @JsonKey(name: 'sesion_id')  int? sesionId, @JsonKey(name: 'mesa_numero')  int mesaNumero, @JsonKey(fromJson: estadoPedidoFromJson, toJson: estadoPedidoToJson)  EstadoPedido estado,  double total,  String? notas, @JsonKey(name: 'created_at')  DateTime createdAt,  List<PedidoStaffItem> items, @JsonKey(name: 'usuario_nombre')  String usuarioNombre, @JsonKey(name: 'solicita_cuenta', defaultValue: false)  bool solicitaCuenta, @JsonKey(name: 'solicitada_en')  DateTime? solicitadaEn)  $default,) {final _that = this;
switch (_that) {
case _PedidoStaff():
return $default(_that.id,_that.sesionId,_that.mesaNumero,_that.estado,_that.total,_that.notas,_that.createdAt,_that.items,_that.usuarioNombre,_that.solicitaCuenta,_that.solicitadaEn);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int id, @JsonKey(name: 'sesion_id')  int? sesionId, @JsonKey(name: 'mesa_numero')  int mesaNumero, @JsonKey(fromJson: estadoPedidoFromJson, toJson: estadoPedidoToJson)  EstadoPedido estado,  double total,  String? notas, @JsonKey(name: 'created_at')  DateTime createdAt,  List<PedidoStaffItem> items, @JsonKey(name: 'usuario_nombre')  String usuarioNombre, @JsonKey(name: 'solicita_cuenta', defaultValue: false)  bool solicitaCuenta, @JsonKey(name: 'solicitada_en')  DateTime? solicitadaEn)?  $default,) {final _that = this;
switch (_that) {
case _PedidoStaff() when $default != null:
return $default(_that.id,_that.sesionId,_that.mesaNumero,_that.estado,_that.total,_that.notas,_that.createdAt,_that.items,_that.usuarioNombre,_that.solicitaCuenta,_that.solicitadaEn);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _PedidoStaff implements PedidoStaff {
  const _PedidoStaff({required this.id, @JsonKey(name: 'sesion_id') required this.sesionId, @JsonKey(name: 'mesa_numero') required this.mesaNumero, @JsonKey(fromJson: estadoPedidoFromJson, toJson: estadoPedidoToJson) required this.estado, required this.total, required this.notas, @JsonKey(name: 'created_at') required this.createdAt, required  List<PedidoStaffItem> items, @JsonKey(name: 'usuario_nombre') required this.usuarioNombre, @JsonKey(name: 'solicita_cuenta', defaultValue: false) required this.solicitaCuenta, @JsonKey(name: 'solicitada_en') required this.solicitadaEn}): _items = items;
  factory _PedidoStaff.fromJson(Map<String, dynamic> json) => _$PedidoStaffFromJson(json);

@override final  int id;
@override@JsonKey(name: 'sesion_id') final  int? sesionId;
@override@JsonKey(name: 'mesa_numero') final  int mesaNumero;
@override@JsonKey(fromJson: estadoPedidoFromJson, toJson: estadoPedidoToJson) final  EstadoPedido estado;
@override final  double total;
@override final  String? notas;
@override@JsonKey(name: 'created_at') final  DateTime createdAt;
 final  List<PedidoStaffItem> _items;
@override List<PedidoStaffItem> get items {
  if (_items is EqualUnmodifiableListView) return _items;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_items);
}

@override@JsonKey(name: 'usuario_nombre') final  String usuarioNombre;
@override@JsonKey(name: 'solicita_cuenta', defaultValue: false) final  bool solicitaCuenta;
@override@JsonKey(name: 'solicitada_en') final  DateTime? solicitadaEn;

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
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _PedidoStaff&&(identical(other.id, id) || other.id == id)&&(identical(other.sesionId, sesionId) || other.sesionId == sesionId)&&(identical(other.mesaNumero, mesaNumero) || other.mesaNumero == mesaNumero)&&(identical(other.estado, estado) || other.estado == estado)&&(identical(other.total, total) || other.total == total)&&(identical(other.notas, notas) || other.notas == notas)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&const DeepCollectionEquality().equals(other._items, _items)&&(identical(other.usuarioNombre, usuarioNombre) || other.usuarioNombre == usuarioNombre)&&(identical(other.solicitaCuenta, solicitaCuenta) || other.solicitaCuenta == solicitaCuenta)&&(identical(other.solicitadaEn, solicitadaEn) || other.solicitadaEn == solicitadaEn));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,sesionId,mesaNumero,estado,total,notas,createdAt,const DeepCollectionEquality().hash(_items),usuarioNombre,solicitaCuenta,solicitadaEn);

@override
String toString() {
  return 'PedidoStaff(id: $id, sesionId: $sesionId, mesaNumero: $mesaNumero, estado: $estado, total: $total, notas: $notas, createdAt: $createdAt, items: $items, usuarioNombre: $usuarioNombre, solicitaCuenta: $solicitaCuenta, solicitadaEn: $solicitadaEn)';
}


}

/// @nodoc
abstract mixin class _$PedidoStaffCopyWith<$Res> implements $PedidoStaffCopyWith<$Res> {
  factory _$PedidoStaffCopyWith(_PedidoStaff value, $Res Function(_PedidoStaff) _then) = __$PedidoStaffCopyWithImpl;
@override @useResult
$Res call({
 int id,@JsonKey(name: 'sesion_id') int? sesionId,@JsonKey(name: 'mesa_numero') int mesaNumero,@JsonKey(fromJson: estadoPedidoFromJson, toJson: estadoPedidoToJson) EstadoPedido estado, double total, String? notas,@JsonKey(name: 'created_at') DateTime createdAt, List<PedidoStaffItem> items,@JsonKey(name: 'usuario_nombre') String usuarioNombre,@JsonKey(name: 'solicita_cuenta', defaultValue: false) bool solicitaCuenta,@JsonKey(name: 'solicitada_en') DateTime? solicitadaEn
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
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? sesionId = freezed,Object? mesaNumero = null,Object? estado = null,Object? total = null,Object? notas = freezed,Object? createdAt = null,Object? items = null,Object? usuarioNombre = null,Object? solicitaCuenta = null,Object? solicitadaEn = freezed,}) {
  return _then(_PedidoStaff(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,sesionId: freezed == sesionId ? _self.sesionId : sesionId // ignore: cast_nullable_to_non_nullable
as int?,mesaNumero: null == mesaNumero ? _self.mesaNumero : mesaNumero // ignore: cast_nullable_to_non_nullable
as int,estado: null == estado ? _self.estado : estado // ignore: cast_nullable_to_non_nullable
as EstadoPedido,total: null == total ? _self.total : total // ignore: cast_nullable_to_non_nullable
as double,notas: freezed == notas ? _self.notas : notas // ignore: cast_nullable_to_non_nullable
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
