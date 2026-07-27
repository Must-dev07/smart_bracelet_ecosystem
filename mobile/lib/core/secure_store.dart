/// Thin wrapper over flutter_secure_storage for JWT + user payload.
/// Logout clears everything here plus BLE bond state (see AuthRepository).
import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureStore {
  static const _kAccess = 'jwt_access';
  static const _kRefresh = 'jwt_refresh';
  static const _kUser = 'user_json';

  final FlutterSecureStorage _storage;
  SecureStore([FlutterSecureStorage? storage])
      : _storage = storage ?? const FlutterSecureStorage();

  Future<void> saveTokens({required String access, required String refresh}) async {
    await _storage.write(key: _kAccess, value: access);
    await _storage.write(key: _kRefresh, value: refresh);
  }

  Future<void> saveUser(Map<String, dynamic> user) =>
      _storage.write(key: _kUser, value: jsonEncode(user));

  Future<String?> readAccessToken() => _storage.read(key: _kAccess);
  Future<String?> readRefreshToken() => _storage.read(key: _kRefresh);

  Future<Map<String, dynamic>?> readUser() async {
    final raw = await _storage.read(key: _kUser);
    return raw == null ? null : jsonDecode(raw) as Map<String, dynamic>;
  }

  Future<void> clear() => _storage.deleteAll();
}
