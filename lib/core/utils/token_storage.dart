import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';


/// Handles secure persistence of the JWT token.
///
/// Uses [FlutterSecureStorage] (AES-256 on Android, Keychain on iOS).
/// For anything less sensitive (e.g. user prefs) use shared_preferences instead.
class TokenStorage {
  TokenStorage(this._storage);
  final FlutterSecureStorage _storage;

  static const _tokenKey   = 'auth_token';
  static const _userIdKey  = 'user_id';

  // ── Token ────────────────────────────────────────────────────

  Future<void> saveToken(String token) =>
      _storage.write(key: _tokenKey, value: token);

  Future<String?> readToken() =>
      _storage.read(key: _tokenKey);

  Future<void> deleteToken() =>
      _storage.delete(key: _tokenKey);

  Future<bool> get hasToken async {
    final t = await readToken();
    return t != null && t.isNotEmpty;
  }

  // ── User ID (convenience) ────────────────────────────────────

  Future<void> saveUserId(String id) =>
      _storage.write(key: _userIdKey, value: id);

  Future<String?> readUserId() =>
      _storage.read(key: _userIdKey);

  // ── Clear all (logout) ───────────────────────────────────────

  Future<void> clearAll() => _storage.deleteAll();
}

// ── Provider ──────────────────────────────────────────────────

final tokenStorageProvider = Provider<TokenStorage>((ref) {
  const storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );
  return TokenStorage(storage);
});