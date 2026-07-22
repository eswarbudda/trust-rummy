import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Persists auth credentials in platform secure storage (Keychain / Keystore).
///
/// Access + refresh tokens and username only — no other PII.
class AuthSessionStore {
  AuthSessionStore({FlutterSecureStorage? storage})
      : _storage = storage ??
            const FlutterSecureStorage(
              aOptions: AndroidOptions(encryptedSharedPreferences: true),
            );

  static const _kAccess = 'tr_access_token';
  static const _kRefresh = 'tr_refresh_token';
  static const _kUsername = 'tr_username';
  static const _kExpiresAtMs = 'tr_access_expires_at_ms';

  final FlutterSecureStorage _storage;

  Future<void> save({
    required String accessToken,
    required String username,
    String? refreshToken,
    int? expiresInMs,
  }) async {
    await _storage.write(key: _kAccess, value: accessToken);
    await _storage.write(key: _kUsername, value: username);
    if (refreshToken != null && refreshToken.isNotEmpty) {
      await _storage.write(key: _kRefresh, value: refreshToken);
    }
    if (expiresInMs != null && expiresInMs > 0) {
      final expiresAt = DateTime.now().millisecondsSinceEpoch + expiresInMs;
      await _storage.write(key: _kExpiresAtMs, value: expiresAt.toString());
    }
  }

  Future<void> clear() async {
    await Future.wait([
      _storage.delete(key: _kAccess),
      _storage.delete(key: _kRefresh),
      _storage.delete(key: _kUsername),
      _storage.delete(key: _kExpiresAtMs),
    ]);
  }

  Future<String?> readAccessToken() => _storage.read(key: _kAccess);

  Future<String?> readRefreshToken() => _storage.read(key: _kRefresh);

  Future<String?> readUsername() => _storage.read(key: _kUsername);

  Future<int?> readAccessExpiresAtMs() async {
    final raw = await _storage.read(key: _kExpiresAtMs);
    if (raw == null || raw.isEmpty) return null;
    return int.tryParse(raw);
  }
}
