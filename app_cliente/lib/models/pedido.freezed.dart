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

 int get id;@JsonKey(name: 'sesion_id') int get sesionId;@JsonKey(name: 'mesa_numero') int get mesaNumero; String get estado; double get total; String? get notas;@JsonKey(name: 'created_at') DateTime get createdAt; List<PedidoItem> get items;
/// Create a copy of Pedido
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PedidoCopyWith<Pedido> get copyWith => _$PedidoCopyWithImpl<Pedido>(this as Pedido, _$identity);

  /// Serializes this Pedido to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Pedido&&(identical(other.id, id) || other.id == id)&&(identical(other.sesionId, sesionId) || other.sesionId == sesionId)&&(identical(other.mesaNumero, mesaNumero) || other.mesaNumero == mesaNumero)&&(identical(other.estado, estado) || other.estado == estado)&&(identical(other.total, total) || other.total == total)&&(identical(other.notas, notas) || other.notas == notas)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&const DeepCollectionEquality().equals(other.items, items));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,sesionId,mesaNumero,estado,total,notas,createdAt,const DeepCollectionEquality().hash(items));

@override
String toString() {
  return 'Pedido(id: $id, sesionId: $sesionId, mesaNumero: $mesaNumero, estado: $estado, total: $total, notas: $notas, createdAt: $createdAt, items: $items)';
}


}

/// @nodoc
abstract mixin class $PedidoCopyWith<$Res>  {
  factory $PedidoCopyWith(Pedido value, $Res Function(Pedido) _then) = _$PedidoCopyWithImpl;
@useResult
$Res call({
 int id,@JsonKey(name: 'sesion_id') int sesionId,@JsonKey(name: 'mesa_numero') int mesaNumero, String estado, double total, String? notas,@JsonKey(name: 'created_at') DateTime createdAt, List<PedidoItem> items
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
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? sesionId = null,Object? mesaNumero = null,Object? estado = null,Object? total = null,Object? notas = freezed,Object? createdAt = null,Object? items = null,}) {
  return _then(Pedido(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,sesionId: null == sesionId ? _self.sesionId : sesionId // ignore: cast_nullable_to_non_nullable
as int,mesaNumero: null == mesaNumero ? _self.mesaNumero : mesaNumero // ignore: cast_nullable_to_non_nullable
as int,estado: null == estado ? _self.estado : estado // ignore: cast_nullable_to_non_nullable
as String,total: null == total ? _self.total : total // ignore: cast_nullable_to_non_nullable
as double,notas: freezed == notas ? _self.notas : notas // ignore: cast_nullable_to_non_nullable
as String?,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,items: null == items ? _self.items : items // ignore: cast_nullable_to_non_nullable
as List<PedidoItem>,
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int id, @JsonKey(name: 'sesion_id')  int sesionId, @JsonKey(name: 'mesa_numero')  int mesaNumero,  String estado,  double total,  String? notas, @JsonKey(name: 'created_at')  DateTime createdAt,  List<PedidoItem> items)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Pedido() when $default != null:
return $default(_that.id,_that.sesionId,_that.mesaNumero,_that.estado,_that.total,_that.notas,_that.createdAt,_that.items);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int id, @JsonKey(name: 'sesion_id')  int sesionId, @JsonKey(name: 'mesa_numero')  int mesaNumero,  String estado,  double total,  String? notas, @JsonKey(name: 'created_at')  DateTime createdAt,  List<PedidoItem> items)  $default,) {final _that = this;
switch (_that) {
case _Pedido():
return $default(_that.id,_that.sesionId,_that.mesaNumero,_that.estado,_that.total,_that.notas,_that.createdAt,_that.items);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int id, @JsonKey(name: 'sesion_id')  int sesionId, @JsonKey(name: 'mesa_numero')  int mesaNumero,  String estado,  double total,  String? notas, @JsonKey(name: 'created_at')  DateTime createdAt,  List<PedidoItem> items)?  $default,) {final _that = this;
switch (_that) {
case _Pedido() when $default != null:
return $default(_that.id,_that.sesionId,_that.mesaNumero,_that.estado,_that.total,_that.notas,_that.createdAt,_that.items);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _Pedido implements Pedido {
  const _Pedido({required this.id, @JsonKey(name: 'sesion_id') required this.sesionId, @JsonKey(name: 'mesa_numero') required this.mesaNumero, required this.estado, required this.total, this.notas, @JsonKey(name: 'created_at') required this.createdAt, required  List<PedidoItem> items}): _items = items;
  factory _Pedido.fromJson(Map<String, dynamic> json) => _$PedidoFromJson(json);

@override final  int id;
@override@JsonKey(name: 'sesion_id') final  int sesionId;
@override@JsonKey(name: 'mesa_numero') final  int mesaNumero;
@override final  String estado;
@override final  double total;
@override final  String? notas;
@override@JsonKey(name: 'created_at') final  DateTime createdAt;
 final  List<PedidoItem> _items;
@override List<PedidoItem> get items {
  if (_items is EqualUnmodifiableListView) return _items;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_items);
}


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
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _Pedido&&(identical(other.id, id) || other.id == id)&&(identical(other.sesionId, sesionId) || other.sesionId == sesionId)&&(identical(other.mesaNumero, mesaNumero) || other.mesaNumero == mesaNumero)&&(identical(other.estado, estado) || other.estado == estado)&&(identical(other.total, total) || other.total == total)&&(identical(other.notas, notas) || other.notas == notas)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&const DeepCollectionEquality().equals(other._items, _items));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,sesionId,mesaNumero,estado,total,notas,createdAt,const DeepCollectionEquality().hash(_items));

@override
String toString() {
  return 'Pedido(id: $id, sesionId: $sesionId, mesaNumero: $mesaNumero, estado: $estado, total: $total, notas: $notas, createdAt: $createdAt, items: $items)';
}


}

/// @nodoc
abstract mixin class _$PedidoCopyWith<$Res> implements $PedidoCopyWith<$Res> {
  factory _$PedidoCopyWith(_Pedido value, $Res Function(_Pedido) _then) = __$PedidoCopyWithImpl;
@override @useResult
$Res call({
 int id,@JsonKey(name: 'sesion_id') int sesionId,@JsonKey(name: 'mesa_numero') int mesaNumero, String estado, double total, String? notas,@JsonKey(name: 'created_at') DateTime createdAt, List<PedidoItem> items
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
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? sesionId = null,Object? mesaNumero = null,Object? estado = null,Object? total = null,Object? notas = freezed,Object? createdAt = null,Object? items = null,}) {
  return _then(_Pedido(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,sesionId: null == sesionId ? _self.sesionId : sesionId // ignore: cast_nullable_to_non_nullable
as int,mesaNumero: null == mesaNumero ? _self.mesaNumero : mesaNumero // ignore: cast_nullable_to_non_nullable
as int,estado: null == estado ? _self.estado : estado // ignore: cast_nullable_to_non_nullable
as String,total: null == total ? _self.total : total // ignore: cast_nullable_to_non_nullable
as double,notas: freezed == notas ? _self.notas : notas // ignore: cast_nullable_to_non_nullable
as String?,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,items: null == items ? _self._items : items // ignore: cast_nullable_to_non_nullable
as List<PedidoItem>,
  ));
}


}

// dart format on
