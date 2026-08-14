import 'package:freezed_annotation/freezed_annotation.dart';

part 'user.freezed.dart';
part 'user.g.dart';

/// Usuario autenticado (`GET /auth/me`).
///
/// [role] se mantiene como String a propósito: el enum real
/// (`RolUsuario`) vive en el backend y sus valores (`super_admin`,
/// `admin_restaurante`, `mesero`, `cocina`, `cliente`) se comparan por nombre.
@freezed
abstract class User with _$User {
  const factory User({
    required int id,
    required String nombre,
    required String email,
    required String role,
    @JsonKey(name: 'restaurant_id') int? restaurantId,
  }) = _User;

  factory User.fromJson(Map<String, dynamic> json) => _$UserFromJson(json);

  const User._();

  bool get isSuperAdmin => role == 'super_admin';
}
