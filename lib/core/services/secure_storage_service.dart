import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Secure storage service for sensitive data like auth tokens.
/// Uses singleton pattern for consistent access across the app.
class SecureStorageService {
  // Singleton instance
  static final SecureStorageService _instance =
      SecureStorageService._internal();
  factory SecureStorageService() => _instance;
  SecureStorageService._internal();

  final FlutterSecureStorage _storage = const FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true,
    ),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock_this_device,
    ),
  );

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

  // Get user ID as int (for backward compatibility)
  Future<int?> getUserIdAsInt() async {
    final userId = await getUserId();
    if (userId == null) return null;
    return int.tryParse(userId);
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
