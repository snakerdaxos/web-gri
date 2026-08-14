// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'dashboard_stats.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$DashboardStats {

@JsonKey(name: 'mesas_disponibles') int get mesasDisponibles;@JsonKey(name: 'mesas_ocupadas') int get mesasOcupadas;@JsonKey(name: 'mesas_reservadas') int get mesasReservadas;@JsonKey(name: 'mesas_limpieza') int get mesasLimpieza;@JsonKey(name: 'total_mesas') int get totalMesas;@JsonKey(name: 'reservas_hoy') int get reservasHoy;@JsonKey(name: 'pedidos_activos') int get pedidosActivos;
/// Create a copy of DashboardStats
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$DashboardStatsCopyWith<DashboardStats> get copyWith => _$DashboardStatsCopyWithImpl<DashboardStats>(this as DashboardStats, _$identity);

  /// Serializes this DashboardStats to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is DashboardStats&&(identical(other.mesasDisponibles, mesasDisponibles) || other.mesasDisponibles == mesasDisponibles)&&(identical(other.mesasOcupadas, mesasOcupadas) || other.mesasOcupadas == mesasOcupadas)&&(identical(other.mesasReservadas, mesasReservadas) || other.mesasReservadas == mesasReservadas)&&(identical(other.mesasLimpieza, mesasLimpieza) || other.mesasLimpieza == mesasLimpieza)&&(identical(other.totalMesas, totalMesas) || other.totalMesas == totalMesas)&&(identical(other.reservasHoy, reservasHoy) || other.reservasHoy == reservasHoy)&&(identical(other.pedidosActivos, pedidosActivos) || other.pedidosActivos == pedidosActivos));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,mesasDisponibles,mesasOcupadas,mesasReservadas,mesasLimpieza,totalMesas,reservasHoy,pedidosActivos);

@override
String toString() {
  return 'DashboardStats(mesasDisponibles: $mesasDisponibles, mesasOcupadas: $mesasOcupadas, mesasReservadas: $mesasReservadas, mesasLimpieza: $mesasLimpieza, totalMesas: $totalMesas, reservasHoy: $reservasHoy, pedidosActivos: $pedidosActivos)';
}


}

/// @nodoc
abstract mixin class $DashboardStatsCopyWith<$Res>  {
  factory $DashboardStatsCopyWith(DashboardStats value, $Res Function(DashboardStats) _then) = _$DashboardStatsCopyWithImpl;
@useResult
$Res call({
@JsonKey(name: 'mesas_disponibles') int mesasDisponibles,@JsonKey(name: 'mesas_ocupadas') int mesasOcupadas,@JsonKey(name: 'mesas_reservadas') int mesasReservadas,@JsonKey(name: 'mesas_limpieza') int mesasLimpieza,@JsonKey(name: 'total_mesas') int totalMesas,@JsonKey(name: 'reservas_hoy') int reservasHoy,@JsonKey(name: 'pedidos_activos') int pedidosActivos
});




}
/// @nodoc
class _$DashboardStatsCopyWithImpl<$Res>
    implements $DashboardStatsCopyWith<$Res> {
  _$DashboardStatsCopyWithImpl(this._self, this._then);

  final DashboardStats _self;
  final $Res Function(DashboardStats) _then;

/// Create a copy of DashboardStats
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? mesasDisponibles = null,Object? mesasOcupadas = null,Object? mesasReservadas = null,Object? mesasLimpieza = null,Object? totalMesas = null,Object? reservasHoy = null,Object? pedidosActivos = null,}) {
  return _then(DashboardStats(
mesasDisponibles: null == mesasDisponibles ? _self.mesasDisponibles : mesasDisponibles // ignore: cast_nullable_to_non_nullable
as int,mesasOcupadas: null == mesasOcupadas ? _self.mesasOcupadas : mesasOcupadas // ignore: cast_nullable_to_non_nullable
as int,mesasReservadas: null == mesasReservadas ? _self.mesasReservadas : mesasReservadas // ignore: cast_nullable_to_non_nullable
as int,mesasLimpieza: null == mesasLimpieza ? _self.mesasLimpieza : mesasLimpieza // ignore: cast_nullable_to_non_nullable
as int,totalMesas: null == totalMesas ? _self.totalMesas : totalMesas // ignore: cast_nullable_to_non_nullable
as int,reservasHoy: null == reservasHoy ? _self.reservasHoy : reservasHoy // ignore: cast_nullable_to_non_nullable
as int,pedidosActivos: null == pedidosActivos ? _self.pedidosActivos : pedidosActivos // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}


/// Adds pattern-matching-related methods to [DashboardStats].
extension DashboardStatsPatterns on DashboardStats {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _DashboardStats value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _DashboardStats() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _DashboardStats value)  $default,){
final _that = this;
switch (_that) {
case _DashboardStats():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _DashboardStats value)?  $default,){
final _that = this;
switch (_that) {
case _DashboardStats() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function(@JsonKey(name: 'mesas_disponibles')  int mesasDisponibles, @JsonKey(name: 'mesas_ocupadas')  int mesasOcupadas, @JsonKey(name: 'mesas_reservadas')  int mesasReservadas, @JsonKey(name: 'mesas_limpieza')  int mesasLimpieza, @JsonKey(name: 'total_mesas')  int totalMesas, @JsonKey(name: 'reservas_hoy')  int reservasHoy, @JsonKey(name: 'pedidos_activos')  int pedidosActivos)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _DashboardStats() when $default != null:
return $default(_that.mesasDisponibles,_that.mesasOcupadas,_that.mesasReservadas,_that.mesasLimpieza,_that.totalMesas,_that.reservasHoy,_that.pedidosActivos);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function(@JsonKey(name: 'mesas_disponibles')  int mesasDisponibles, @JsonKey(name: 'mesas_ocupadas')  int mesasOcupadas, @JsonKey(name: 'mesas_reservadas')  int mesasReservadas, @JsonKey(name: 'mesas_limpieza')  int mesasLimpieza, @JsonKey(name: 'total_mesas')  int totalMesas, @JsonKey(name: 'reservas_hoy')  int reservasHoy, @JsonKey(name: 'pedidos_activos')  int pedidosActivos)  $default,) {final _that = this;
switch (_that) {
case _DashboardStats():
return $default(_that.mesasDisponibles,_that.mesasOcupadas,_that.mesasReservadas,_that.mesasLimpieza,_that.totalMesas,_that.reservasHoy,_that.pedidosActivos);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function(@JsonKey(name: 'mesas_disponibles')  int mesasDisponibles, @JsonKey(name: 'mesas_ocupadas')  int mesasOcupadas, @JsonKey(name: 'mesas_reservadas')  int mesasReservadas, @JsonKey(name: 'mesas_limpieza')  int mesasLimpieza, @JsonKey(name: 'total_mesas')  int totalMesas, @JsonKey(name: 'reservas_hoy')  int reservasHoy, @JsonKey(name: 'pedidos_activos')  int pedidosActivos)?  $default,) {final _that = this;
switch (_that) {
case _DashboardStats() when $default != null:
return $default(_that.mesasDisponibles,_that.mesasOcupadas,_that.mesasReservadas,_that.mesasLimpieza,_that.totalMesas,_that.reservasHoy,_that.pedidosActivos);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _DashboardStats implements DashboardStats {
  const _DashboardStats({@JsonKey(name: 'mesas_disponibles') required this.mesasDisponibles, @JsonKey(name: 'mesas_ocupadas') required this.mesasOcupadas, @JsonKey(name: 'mesas_reservadas') required this.mesasReservadas, @JsonKey(name: 'mesas_limpieza') required this.mesasLimpieza, @JsonKey(name: 'total_mesas') required this.totalMesas, @JsonKey(name: 'reservas_hoy') required this.reservasHoy, @JsonKey(name: 'pedidos_activos') required this.pedidosActivos});
  factory _DashboardStats.fromJson(Map<String, dynamic> json) => _$DashboardStatsFromJson(json);

@override@JsonKey(name: 'mesas_disponibles') final  int mesasDisponibles;
@override@JsonKey(name: 'mesas_ocupadas') final  int mesasOcupadas;
@override@JsonKey(name: 'mesas_reservadas') final  int mesasReservadas;
@override@JsonKey(name: 'mesas_limpieza') final  int mesasLimpieza;
@override@JsonKey(name: 'total_mesas') final  int totalMesas;
@override@JsonKey(name: 'reservas_hoy') final  int reservasHoy;
@override@JsonKey(name: 'pedidos_activos') final  int pedidosActivos;

/// Create a copy of DashboardStats
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$DashboardStatsCopyWith<_DashboardStats> get copyWith => __$DashboardStatsCopyWithImpl<_DashboardStats>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$DashboardStatsToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _DashboardStats&&(identical(other.mesasDisponibles, mesasDisponibles) || other.mesasDisponibles == mesasDisponibles)&&(identical(other.mesasOcupadas, mesasOcupadas) || other.mesasOcupadas == mesasOcupadas)&&(identical(other.mesasReservadas, mesasReservadas) || other.mesasReservadas == mesasReservadas)&&(identical(other.mesasLimpieza, mesasLimpieza) || other.mesasLimpieza == mesasLimpieza)&&(identical(other.totalMesas, totalMesas) || other.totalMesas == totalMesas)&&(identical(other.reservasHoy, reservasHoy) || other.reservasHoy == reservasHoy)&&(identical(other.pedidosActivos, pedidosActivos) || other.pedidosActivos == pedidosActivos));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,mesasDisponibles,mesasOcupadas,mesasReservadas,mesasLimpieza,totalMesas,reservasHoy,pedidosActivos);

@override
String toString() {
  return 'DashboardStats(mesasDisponibles: $mesasDisponibles, mesasOcupadas: $mesasOcupadas, mesasReservadas: $mesasReservadas, mesasLimpieza: $mesasLimpieza, totalMesas: $totalMesas, reservasHoy: $reservasHoy, pedidosActivos: $pedidosActivos)';
}


}

/// @nodoc
abstract mixin class _$DashboardStatsCopyWith<$Res> implements $DashboardStatsCopyWith<$Res> {
  factory _$DashboardStatsCopyWith(_DashboardStats value, $Res Function(_DashboardStats) _then) = __$DashboardStatsCopyWithImpl;
@override @useResult
$Res call({
@JsonKey(name: 'mesas_disponibles') int mesasDisponibles,@JsonKey(name: 'mesas_ocupadas') int mesasOcupadas,@JsonKey(name: 'mesas_reservadas') int mesasReservadas,@JsonKey(name: 'mesas_limpieza') int mesasLimpieza,@JsonKey(name: 'total_mesas') int totalMesas,@JsonKey(name: 'reservas_hoy') int reservasHoy,@JsonKey(name: 'pedidos_activos') int pedidosActivos
});




}
/// @nodoc
class __$DashboardStatsCopyWithImpl<$Res>
    implements _$DashboardStatsCopyWith<$Res> {
  __$DashboardStatsCopyWithImpl(this._self, this._then);

  final _DashboardStats _self;
  final $Res Function(_DashboardStats) _then;

/// Create a copy of DashboardStats
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? mesasDisponibles = null,Object? mesasOcupadas = null,Object? mesasReservadas = null,Object? mesasLimpieza = null,Object? totalMesas = null,Object? reservasHoy = null,Object? pedidosActivos = null,}) {
  return _then(_DashboardStats(
mesasDisponibles: null == mesasDisponibles ? _self.mesasDisponibles : mesasDisponibles // ignore: cast_nullable_to_non_nullable
as int,mesasOcupadas: null == mesasOcupadas ? _self.mesasOcupadas : mesasOcupadas // ignore: cast_nullable_to_non_nullable
as int,mesasReservadas: null == mesasReservadas ? _self.mesasReservadas : mesasReservadas // ignore: cast_nullable_to_non_nullable
as int,mesasLimpieza: null == mesasLimpieza ? _self.mesasLimpieza : mesasLimpieza // ignore: cast_nullable_to_non_nullable
as int,totalMesas: null == totalMesas ? _self.totalMesas : totalMesas // ignore: cast_nullable_to_non_nullable
as int,reservasHoy: null == reservasHoy ? _self.reservasHoy : reservasHoy // ignore: cast_nullable_to_non_nullable
as int,pedidosActivos: null == pedidosActivos ? _self.pedidosActivos : pedidosActivos // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

// dart format on
