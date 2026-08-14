import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

final authStorageProvider = Provider<AuthStorage>((ref) => AuthStorage());

/// Wrapper sobre flutter_secure_storage para el par de JWTs.
///
/// T-04-05 — en Web (este panel) flutter_secure_storage 11 usa WebCrypto +
/// LocalStorage: la clave la genera el browser y queda atada al dominio. Es
/// "obfuscado, no cifrado" — aceptable para un panel staff-only en localhost
/// (dev) y sobre HTTPS (Phase 9: nginx + TLS). INACEPTABLE para un kiosk
/// público. En móvil (futura app cliente) mapea a Android Keystore / iOS
/// Keychain con la misma API.
///
/// Esta clase es la ÚNICA puerta de escritura/lectura de tokens (T-04-07):
/// los widgets jamás la tocan — van por [AuthState] / login_controller.
class AuthStorage {
  AuthStorage({FlutterSecureStorage? storage})
      : _s = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _s;

  static const _kAccess = 'gri_access';
  static const _kRefresh = 'gri_refresh';

  Future<String?> readAccess() => _s.read(key: _kAccess);
  Future<String?> readRefresh() => _s.read(key: _kRefresh);

  Future<void> write(String access, String refresh) async {
    await _s.write(key: _kAccess, value: access);
    await _s.write(key: _kRefresh, value: refresh);
  }

  Future<void> clear() async {
    await _s.delete(key: _kAccess);
    await _s.delete(key: _kRefresh);
  }
}
