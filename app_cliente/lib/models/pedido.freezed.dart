// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'pedido.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$Pedido {

 String get id; String get restauranteId; String get mesaId;/// == [mesaId] (sesión única por mesa, doc ID determinista).
 String get sesionId; String get usuarioId; String get clienteNombre; String get estado; int get total; List<PedidoItem> get items; DateTime? get createdAt; DateTime? get updatedAt;
/// Create a copy of Pedido
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PedidoCopyWith<Pedido> get copyWith => _$PedidoCopyWithImpl<Pedido>(this as Pedido, _$identity);

  /// Serializes this Pedido to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Pedido&&(identical(other.id, id) || other.id == id)&&(identical(other.restauranteId, restauranteId) || other.restauranteId == restauranteId)&&(identical(other.mesaId, mesaId) || other.mesaId == mesaId)&&(identical(other.sesionId, sesionId) || other.sesionId == sesionId)&&(identical(other.usuarioId, usuarioId) || other.usuarioId == usuarioId)&&(identical(other.clienteNombre, clienteNombre) || other.clienteNombre == clienteNombre)&&(identical(other.estado, estado) || other.estado == estado)&&(identical(other.total, total) || other.total == total)&&const DeepCollectionEquality().equals(other.items, items)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,restauranteId,mesaId,sesionId,usuarioId,clienteNombre,estado,total,const DeepCollectionEquality().hash(items),createdAt,updatedAt);

@override
String toString() {
  return 'Pedido(id: $id, restauranteId: $restauranteId, mesaId: $mesaId, sesionId: $sesionId, usuarioId: $usuarioId, clienteNombre: $clienteNombre, estado: $estado, total: $total, items: $items, createdAt: $createdAt, updatedAt: $updatedAt)';
}


}

/// @nodoc
abstract mixin class $PedidoCopyWith<$Res>  {
  factory $PedidoCopyWith(Pedido value, $Res Function(Pedido) _then) = _$PedidoCopyWithImpl;
@useResult
$Res call({
 String id, String restauranteId, String mesaId, String sesionId, String usuarioId, String clienteNombre, String estado, int total, List<PedidoItem> items, DateTime? createdAt, DateTime? updatedAt
});




}
/// @nodoc
class _$PedidoCopyWithImpl<$Res>
    implements $PedidoCopyWith<$Res> {
  _$PedidoCopyWithImpl(this._self, this._then);

  final Pedido _self;
  final $Res Function(Pedido) _then;

/// Create a copy of Pedido
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? restauranteId = null,Object? mesaId = null,Object? sesionId = null,Object? usuarioId = null,Object? clienteNombre = null,Object? estado = null,Object? total = null,Object? items = null,Object? createdAt = freezed,Object? updatedAt = freezed,}) {
  return _then(Pedido(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,restauranteId: null == restauranteId ? _self.restauranteId : restauranteId // ignore: cast_nullable_to_non_nullable
as String,mesaId: null == mesaId ? _self.mesaId : mesaId // ignore: cast_nullable_to_non_nullable
as String,sesionId: null == sesionId ? _self.sesionId : sesionId // ignore: cast_nullable_to_non_nullable
as String,usuarioId: null == usuarioId ? _self.usuarioId : usuarioId // ignore: cast_nullable_to_non_nullable
as String,clienteNombre: null == clienteNombre ? _self.clienteNombre : clienteNombre // ignore: cast_nullable_to_non_nullable
as String,estado: null == estado ? _self.estado : estado // ignore: cast_nullable_to_non_nullable
as String,total: null == total ? _self.total : total // ignore: cast_nullable_to_non_nullable
as int,items: null == items ? _self.items : items // ignore: cast_nullable_to_non_nullable
as List<PedidoItem>,createdAt: freezed == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime?,updatedAt: freezed == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}

}


/// Adds pattern-matching-related methods to [Pedido].
extension PedidoPatterns on Pedido {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _Pedido value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _Pedido() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _Pedido value)  $default,){
final _that = this;
switch (_that) {
case _Pedido():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _Pedido value)?  $default,){
final _that = this;
switch (_that) {
case _Pedido() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String restauranteId,  String mesaId,  String sesionId,  String usuarioId,  String clienteNombre,  String estado,  int total,  List<PedidoItem> items,  DateTime? createdAt,  DateTime? updatedAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Pedido() when $default != null:
return $default(_that.id,_that.restauranteId,_that.mesaId,_that.sesionId,_that.usuarioId,_that.clienteNombre,_that.estado,_that.total,_that.items,_that.createdAt,_that.updatedAt);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String restauranteId,  String mesaId,  String sesionId,  String usuarioId,  String clienteNombre,  String estado,  int total,  List<PedidoItem> items,  DateTime? createdAt,  DateTime? updatedAt)  $default,) {final _that = this;
switch (_that) {
case _Pedido():
return $default(_that.id,_that.restauranteId,_that.mesaId,_that.sesionId,_that.usuarioId,_that.clienteNombre,_that.estado,_that.total,_that.items,_that.createdAt,_that.updatedAt);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String restauranteId,  String mesaId,  String sesionId,  String usuarioId,  String clienteNombre,  String estado,  int total,  List<PedidoItem> items,  DateTime? createdAt,  DateTime? updatedAt)?  $default,) {final _that = this;
switch (_that) {
case _Pedido() when $default != null:
return $default(_that.id,_that.restauranteId,_that.mesaId,_that.sesionId,_that.usuarioId,_that.clienteNombre,_that.estado,_that.total,_that.items,_that.createdAt,_that.updatedAt);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _Pedido extends Pedido {
  const _Pedido({required this.id, required this.restauranteId, required this.mesaId, required this.sesionId, required this.usuarioId, this.clienteNombre = '', required this.estado, required this.total, required  List<PedidoItem> items, this.createdAt, this.updatedAt}): _items = items,super._();
  factory _Pedido.fromJson(Map<String, dynamic> json) => _$PedidoFromJson(json);

@override final  String id;
@override final  String restauranteId;
@override final  String mesaId;
/// == [mesaId] (sesión única por mesa, doc ID determinista).
@override final  String sesionId;
@override final  String usuarioId;
@override@JsonKey() final  String clienteNombre;
@override final  String estado;
@override final  int total;
 final  List<PedidoItem> _items;
@override List<PedidoItem> get items {
  if (_items is EqualUnmodifiableListView) return _items;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_items);
}

@override final  DateTime? createdAt;
@override final  DateTime? updatedAt;

/// Create a copy of Pedido
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$PedidoCopyWith<_Pedido> get copyWith => __$PedidoCopyWithImpl<_Pedido>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$PedidoToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _Pedido&&(identical(other.id, id) || other.id == id)&&(identical(other.restauranteId, restauranteId) || other.restauranteId == restauranteId)&&(identical(other.mesaId, mesaId) || other.mesaId == mesaId)&&(identical(other.sesionId, sesionId) || other.sesionId == sesionId)&&(identical(other.usuarioId, usuarioId) || other.usuarioId == usuarioId)&&(identical(other.clienteNombre, clienteNombre) || other.clienteNombre == clienteNombre)&&(identical(other.estado, estado) || other.estado == estado)&&(identical(other.total, total) || other.total == total)&&const DeepCollectionEquality().equals(other._items, _items)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,restauranteId,mesaId,sesionId,usuarioId,clienteNombre,estado,total,const DeepCollectionEquality().hash(_items),createdAt,updatedAt);

@override
String toString() {
  return 'Pedido(id: $id, restauranteId: $restauranteId, mesaId: $mesaId, sesionId: $sesionId, usuarioId: $usuarioId, clienteNombre: $clienteNombre, estado: $estado, total: $total, items: $items, createdAt: $createdAt, updatedAt: $updatedAt)';
}


}

/// @nodoc
abstract mixin class _$PedidoCopyWith<$Res> implements $PedidoCopyWith<$Res> {
  factory _$PedidoCopyWith(_Pedido value, $Res Function(_Pedido) _then) = __$PedidoCopyWithImpl;
@override @useResult
$Res call({
 String id, String restauranteId, String mesaId, String sesionId, String usuarioId, String clienteNombre, String estado, int total, List<PedidoItem> items, DateTime? createdAt, DateTime? updatedAt
});




}
/// @nodoc
class __$PedidoCopyWithImpl<$Res>
    implements _$PedidoCopyWith<$Res> {
  __$PedidoCopyWithImpl(this._self, this._then);

  final _Pedido _self;
  final $Res Function(_Pedido) _then;

/// Create a copy of Pedido
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? restauranteId = null,Object? mesaId = null,Object? sesionId = null,Object? usuarioId = null,Object? clienteNombre = null,Object? estado = null,Object? total = null,Object? items = null,Object? createdAt = freezed,Object? updatedAt = freezed,}) {
  return _then(_Pedido(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,restauranteId: null == restauranteId ? _self.restauranteId : restauranteId // ignore: cast_nullable_to_non_nullable
as String,mesaId: null == mesaId ? _self.mesaId : mesaId // ignore: cast_nullable_to_non_nullable
as String,sesionId: null == sesionId ? _self.sesionId : sesionId // ignore: cast_nullable_to_non_nullable
as String,usuarioId: null == usuarioId ? _self.usuarioId : usuarioId // ignore: cast_nullable_to_non_nullable
as String,clienteNombre: null == clienteNombre ? _self.clienteNombre : clienteNombre // ignore: cast_nullable_to_non_nullable
as String,estado: null == estado ? _self.estado : estado // ignore: cast_nullable_to_non_nullable
as String,total: null == total ? _self.total : total // ignore: cast_nullable_to_non_nullable
as int,items: null == items ? _self._items : items // ignore: cast_nullable_to_non_nullable
as List<PedidoItem>,createdAt: freezed == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime?,updatedAt: freezed == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}


}

// dart format on
