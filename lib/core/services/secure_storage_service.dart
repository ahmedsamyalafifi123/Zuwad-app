import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureStorageService {
  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  
  // Keys
  static const String _tokenKey = 'auth_token';
  static const String _userIdKey = 'user_id';
  
  // Save token
  Future<void> saveToken(String token) async {
    await _storage.write(key: _tokenKey, value: token);
  }
  
  // Get token
  Future<String?> getToken() async {
    return await _storage.read(key: _tokenKey);
  }
  
  // Delete token
  Future<void> deleteToken() async {
    await _storage.delete(key: _tokenKey);
  }
  
  // Save user ID
  Future<void> saveUserId(String userId) async {
    await _storage.write(key: _userIdKey, value: userId);
  }
  
  // Get user ID
  Future<String?> getUserId() async {
    return await _storage.read(key: _userIdKey);
  }
  
  // Delete user ID
  Future<void> deleteUserId() async {
    await _storage.delete(key: _userIdKey);
  }
  
  // Clear all data
  Future<void> clearAll() async {
    await _storage.deleteAll();
  }
}
