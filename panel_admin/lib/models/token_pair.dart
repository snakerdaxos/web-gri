import 'package:freezed_annotation/freezed_annotation.dart';

part 'token_pair.freezed.dart';
part 'token_pair.g.dart';

/// Par de JWTs del backend (`/auth/login` y `/auth/refresh`).
///
/// El API habla snake_case (`access_token`/`refresh_token`); el modelo los
/// mapea a [access]/[refresh] vía `@JsonKey`.
@freezed
abstract class TokenPair with _$TokenPair {
  const factory TokenPair({
    @JsonKey(name: 'access_token') required String access,
    @JsonKey(name: 'refresh_token') required String refresh,
  }) = _TokenPair;

  factory TokenPair.fromJson(Map<String, dynamic> json) =>
      _$TokenPairFromJson(json);
}
