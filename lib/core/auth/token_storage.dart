import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class TokenStorage {
  static const _key = 'pg_connect_access_token';
  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  Future<void> saveAccessToken(String token) => _storage.write(key: _key, value: token);
  Future<String?> readAccessToken() => _storage.read(key: _key);
  Future<void> clear() => _storage.delete(key: _key);
}
