import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Secure storage service for sensitive data like auth tokens.
/// Uses singleton pattern for consistent access across the app.
///
/// On macOS the app sandbox blocks keychain access unless the app has a
/// provisioning profile that grants keychain-access-groups — which is not
/// available in local development builds. SharedPreferences (NSUserDefaults)
/// is used instead on macOS. All other platforms use flutter_secure_storage.
class SecureStorageService {
  // Singleton instance
  static final SecureStorageService _instance =
      SecureStorageService._internal();
  factory SecureStorageService() => _instance;
  SecureStorageService._internal();

  static bool get _isMacOS => !kIsWeb && Platform.isMacOS;

  final FlutterSecureStorage _storage = const FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true,
    ),
    iOptions: IOSOptions(),
    wOptions: WindowsOptions(),
    lOptions: LinuxOptions(),
  );

  // ── Platform-aware primitives ──────────────────────────────────────────────

  Future<void> _write({required String key, required String value}) async {
    if (_isMacOS) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(key, value);
    } else {
      await _storage.write(key: key, value: value);
    }
  }

  Future<String?> _read({required String key}) async {
    if (_isMacOS) {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(key);
    } else {
      return await _storage.read(key: key);
    }
  }

  Future<void> _delete({required String key}) async {
    if (_isMacOS) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(key);
    } else {
      await _storage.delete(key: key);
    }
  }

  Future<void> _deleteAll() async {
    if (_isMacOS) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
    } else {
      await _storage.deleteAll();
    }
  }

  // Keys
  static const String _tokenKey = 'auth_token';
  static const String _refreshTokenKey = 'refresh_token';
  static const String _tokenExpiryKey = 'token_expiry';
  static const String _userIdKey = 'user_id';
  static const String _userRoleKey = 'user_role';
  static const String _userNameKey = 'user_name';
  static const String _userMIdKey = 'user_m_id';
  static const String _knownSupervisorsKey = 'known_supervisors';

  // ============================================
  // Access Token Methods
  // ============================================

  /// Save access token
  Future<void> saveToken(String token) async {
    await _write(key: _tokenKey, value: token);
  }

  /// Get access token
  Future<String?> getToken() async {
    return await _read(key: _tokenKey);
  }

  /// Delete access token
  Future<void> deleteToken() async {
    await _delete(key: _tokenKey);
  }

  // ============================================
  // Refresh Token Methods (New for API v2)
  // ============================================

  /// Save refresh token
  Future<void> saveRefreshToken(String refreshToken) async {
    await _write(key: _refreshTokenKey, value: refreshToken);
  }

  /// Get refresh token
  Future<String?> getRefreshToken() async {
    return await _read(key: _refreshTokenKey);
  }

  /// Delete refresh token
  Future<void> deleteRefreshToken() async {
    await _delete(key: _refreshTokenKey);
  }

  // ============================================
  // Token Expiry Methods (New for API v2)
  // ============================================

  /// Save token expiry timestamp (calculated from expires_in)
  Future<void> saveTokenExpiry(int expiresInSeconds) async {
    final expiryTimestamp = DateTime.now()
        .add(Duration(seconds: expiresInSeconds))
        .millisecondsSinceEpoch;
    await _write(key: _tokenExpiryKey, value: expiryTimestamp.toString());
  }

  /// Get token expiry timestamp
  Future<DateTime?> getTokenExpiry() async {
    final expiryStr = await _read(key: _tokenExpiryKey);
    if (expiryStr == null) return null;
    final timestamp = int.tryParse(expiryStr);
    if (timestamp == null) return null;
    return DateTime.fromMillisecondsSinceEpoch(timestamp);
  }

  /// Check if token is expired or about to expire (within 5 minutes)
  Future<bool> isTokenExpired() async {
    final expiry = await getTokenExpiry();
    if (expiry == null) return true;
    // Consider token expired if it will expire in less than 5 minutes
    return DateTime.now().isAfter(expiry.subtract(const Duration(minutes: 5)));
  }

  /// Check if token is valid (exists and not expired)
  Future<bool> hasValidToken() async {
    final token = await getToken();
    if (token == null || token.isEmpty) return false;
    return !(await isTokenExpired());
  }

  // ============================================
  // User ID Methods
  // ============================================

  /// Save user ID
  Future<void> saveUserId(String userId) async {
    await _write(key: _userIdKey, value: userId);
  }

  /// Get user ID
  Future<String?> getUserId() async {
    return await _read(key: _userIdKey);
  }

  /// Get user ID as int (for backward compatibility)
  Future<int?> getUserIdAsInt() async {
    final userId = await getUserId();
    if (userId == null) return null;
    return int.tryParse(userId);
  }

  /// Delete user ID
  Future<void> deleteUserId() async {
    await _delete(key: _userIdKey);
  }

  // ============================================
  // User Role Methods (New for API v2)
  // ============================================

  /// Save user role (student, teacher, supervisor)
  Future<void> saveUserRole(String role) async {
    await _write(key: _userRoleKey, value: role);
  }

  /// Get user role
  Future<String?> getUserRole() async {
    return await _read(key: _userRoleKey);
  }

  // ============================================
  // User Name Methods (New for API v2)
  // ============================================

  /// Save user name
  Future<void> saveUserName(String name) async {
    await _write(key: _userNameKey, value: name);
  }

  /// Get user name
  Future<String?> getUserName() async {
    return await _read(key: _userNameKey);
  }

  // ============================================
  // User M_ID Methods (New for API v2)
  // ============================================

  /// Save user M_ID (membership ID like ST-001-123)
  Future<void> saveUserMId(String mId) async {
    await _write(key: _userMIdKey, value: mId);
  }

  /// Get user M_ID
  Future<String?> getUserMId() async {
    return await _read(key: _userMIdKey);
  }

  // ============================================
  // Batch Save Methods
  // ============================================

  /// Save all authentication data at once (for login response)
  /// Uses sequential writes to avoid file locking issues on Windows
  Future<void> saveAuthData({
    required String token,
    required String refreshToken,
    required int expiresIn,
    required String userId,
    String? userName,
    String? userRole,
    String? userMId,
  }) async {
    await saveToken(token);
    await saveRefreshToken(refreshToken);
    await saveTokenExpiry(expiresIn);
    await saveUserId(userId);
    if (userName != null) await saveUserName(userName);
    if (userRole != null) await saveUserRole(userRole);
    if (userMId != null) await saveUserMId(userMId);
  }

  // ============================================
  // Clear Methods
  // ============================================

  /// Clear all stored data (for logout)
  Future<void> clearAll() async {
    await _deleteAll();
  }

  /// Clear only auth tokens (keep user info)
  Future<void> clearTokens() async {
    await Future.wait([
      deleteToken(),
      deleteRefreshToken(),
      _delete(key: _tokenExpiryKey),
    ]);
  }

  // ============================================
  // Known Supervisors Methods (For Notifications)
  // ============================================

  /// Save list of known supervisor IDs
  Future<void> saveKnownSupervisors(List<String> ids) async {
    final uniqueIds = ids.where((id) => id.isNotEmpty).toSet().toList();
    await _write(
      key: _knownSupervisorsKey,
      value: uniqueIds.join(','),
    );
  }

  /// Get list of known supervisor IDs
  Future<List<String>> getKnownSupervisors() async {
    final value = await _read(key: _knownSupervisorsKey);
    if (value == null || value.isEmpty) return [];
    return value.split(',');
  }

  /// Add a supervisor ID to the known list
  Future<void> addKnownSupervisor(String id) async {
    if (id.isEmpty) return;

    final currentIds = await getKnownSupervisors();
    if (!currentIds.contains(id)) {
      currentIds.add(id);
      await saveKnownSupervisors(currentIds);
    }
  }
}
