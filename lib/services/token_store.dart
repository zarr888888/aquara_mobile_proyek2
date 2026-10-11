import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Injectable boundary; production must never fall back to plaintext storage.
abstract interface class TokenStore {
  Future<String?> read();
  Future<void> write(String token);
  Future<void> delete();
}

class SecureTokenStore implements TokenStore {
  SecureTokenStore({FlutterSecureStorage? storage})
    : _storage =
          storage ??
          const FlutterSecureStorage(
            iOptions: IOSOptions(
              accessibility: KeychainAccessibility.unlocked_this_device,
              synchronizable: false,
            ),
          );

  static const key = 'samudera.sanctum_token.v1';
  final FlutterSecureStorage _storage;

  @override
  Future<String?> read() => _storage.read(key: key);
  @override
  Future<void> write(String token) => _storage.write(key: key, value: token);
  @override
  Future<void> delete() => _storage.delete(key: key);
}
