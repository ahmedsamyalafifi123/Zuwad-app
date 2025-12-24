import '../../../../core/services/secure_storage_service.dart';
import '../../../../core/api/wordpress_api.dart';
import '../../domain/models/student.dart';

/// Repository for authentication operations using API v2.
class AuthRepository {
  final WordPressApi _api = WordPressApi();
  final SecureStorageService _secureStorage = SecureStorageService();

  /// Login with phone and password.
  /// Returns true on success, throws exception on failure.
  Future<bool> login(String phone, String password, {String? role}) async {
    try {
      final response = await _api.loginWithPhone(phone, password, role: role);
      // Response is already handled by WordPressApi, just check if we got user data
      return response.containsKey('user');
    } catch (e) {
      rethrow; // Let the caller handle the exception with proper message
    }
  }

  /// Check if user is logged in with a valid token.
  Future<bool> isLoggedIn() async {
    return await _secureStorage.hasValidToken();
  }

  /// Check if token needs refresh and refresh if needed.
  Future<bool> ensureValidToken() async {
    // Check if token is expired or about to expire
    if (await _secureStorage.isTokenExpired()) {
      // Try to refresh
      return await _api.refreshToken();
    }
    return true;
  }

  /// Verify token with the server.
  Future<bool> verifyToken() async {
    return await _api.verifyToken();
  }

  /// Get current user ID.
  Future<int?> getCurrentUserId() async {
    return await _secureStorage.getUserIdAsInt();
  }

  /// Get current user role.
  Future<String?> getCurrentUserRole() async {
    return await _secureStorage.getUserRole();
  }

  /// Get current user name.
  Future<String?> getCurrentUserName() async {
    return await _secureStorage.getUserName();
  }

  /// Get student profile with all required data.
  Future<Student> getStudentProfile() async {
    try {
      final userId = await getCurrentUserId();

      if (userId == null) {
        throw Exception('User not logged in');
      }

      // Get student profile from v2 API
      final profileData = await _api.getStudentProfile(userId);

      // Create student object from the response
      // v2 API returns student data directly, no need for separate meta call
      final student = Student.fromApiV2(profileData);

      return student;
    } catch (e) {
      throw Exception('Failed to get student profile: ${e.toString()}');
    }
  }

  /// Change the user's password.
  Future<bool> changePassword(
      String currentPassword, String newPassword) async {
    return await _api.changePassword(currentPassword, newPassword);
  }

  /// Logout and clear all stored data.
  Future<void> logout() async {
    await _api.logout();
  }
}
