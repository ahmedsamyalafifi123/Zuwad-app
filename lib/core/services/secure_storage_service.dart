import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Secure storage service for sensitive data like auth tokens.
/// Uses singleton pattern for consistent access across the app.
///
/// Updated for API v2 with refresh token support.
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
    // Use default IOSOptions — no explicit groupId or accessibility override.
    // first_unlock_this_device was causing errSecMissingEntitlement (-34018)
    // on iOS 17+ with certain provisioning profile configurations.
    iOptions: IOSOptions(),
    // Windows and Linux use encrypted file storage internally
    wOptions: WindowsOptions(),
    lOptions: LinuxOptions(),
  );

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
    await _storage.write(key: _tokenKey, value: token);
  }

  /// Get access token
  Future<String?> getToken() async {
    return await _storage.read(key: _tokenKey);
  }

  /// Delete access token
  Future<void> deleteToken() async {
    await _storage.delete(key: _tokenKey);
  }

  // ============================================
  // Refresh Token Methods (New for API v2)
  // ============================================

  /// Save refresh token
  Future<void> saveRefreshToken(String refreshToken) async {
    await _storage.write(key: _refreshTokenKey, value: refreshToken);
  }

  /// Get refresh token
  Future<String?> getRefreshToken() async {
    return await _storage.read(key: _refreshTokenKey);
  }

  /// Delete refresh token
  Future<void> deleteRefreshToken() async {
    await _storage.delete(key: _refreshTokenKey);
  }

  // ============================================
  // Token Expiry Methods (New for API v2)
  // ============================================

  /// Save token expiry timestamp (calculated from expires_in)
  Future<void> saveTokenExpiry(int expiresInSeconds) async {
    final expiryTimestamp = DateTime.now()
        .add(Duration(seconds: expiresInSeconds))
        .millisecondsSinceEpoch;
    await _storage.write(
        key: _tokenExpiryKey, value: expiryTimestamp.toString());
  }

  /// Get token expiry timestamp
  Future<DateTime?> getTokenExpiry() async {
    final expiryStr = await _storage.read(key: _tokenExpiryKey);
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
    await _storage.write(key: _userIdKey, value: userId);
  }

  /// Get user ID
  Future<String?> getUserId() async {
    return await _storage.read(key: _userIdKey);
  }

  /// Get user ID as int (for backward compatibility)
  Future<int?> getUserIdAsInt() async {
    final userId = await getUserId();
    if (userId == null) return null;
    return int.tryParse(userId);
  }

  /// Delete user ID
  Future<void> deleteUserId() async {
    await _storage.delete(key: _userIdKey);
  }

  // ============================================
  // User Role Methods (New for API v2)
  // ============================================

  /// Save user role (student, teacher, supervisor)
  Future<void> saveUserRole(String role) async {
    await _storage.write(key: _userRoleKey, value: role);
  }

  /// Get user role
  Future<String?> getUserRole() async {
    return await _storage.read(key: _userRoleKey);
  }

  // ============================================
  // User Name Methods (New for API v2)
  // ============================================

  /// Save user name
  Future<void> saveUserName(String name) async {
    await _storage.write(key: _userNameKey, value: name);
  }

  /// Get user name
  Future<String?> getUserName() async {
    return await _storage.read(key: _userNameKey);
  }

  // ============================================
  // User M_ID Methods (New for API v2)
  // ============================================

  /// Save user M_ID (membership ID like ST-001-123)
  Future<void> saveUserMId(String mId) async {
    await _storage.write(key: _userMIdKey, value: mId);
  }

  /// Get user M_ID
  Future<String?> getUserMId() async {
    return await _storage.read(key: _userMIdKey);
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
    // Use sequential writes instead of Future.wait to avoid
    // potential file locking issues on Windows
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
    await _storage.deleteAll();
  }

  /// Clear only auth tokens (keep user info)
  Future<void> clearTokens() async {
    await Future.wait([
      deleteToken(),
      deleteRefreshToken(),
      _storage.delete(key: _tokenExpiryKey),
    ]);
  }

  // ============================================
  // Known Supervisors Methods (For Notifications)
  // ============================================

  /// Save list of known supervisor IDs
  Future<void> saveKnownSupervisors(List<String> ids) async {
    // Filter duplicates and empty strings
    final uniqueIds = ids.where((id) => id.isNotEmpty).toSet().toList();
    await _storage.write(
      key: _knownSupervisorsKey,
      value: uniqueIds.join(','),
    );
  }

  /// Get list of known supervisor IDs
  Future<List<String>> getKnownSupervisors() async {
    final value = await _storage.read(key: _knownSupervisorsKey);
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
