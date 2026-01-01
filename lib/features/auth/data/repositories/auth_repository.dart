import 'package:flutter/foundation.dart';
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
      if (kDebugMode) {
        print('AuthRepository.getStudentProfile: userId = $userId');
      }

      if (userId == null) {
        throw Exception('User not logged in');
      }

      // Get student profile from v2 API
      if (kDebugMode) {
        print(
            'AuthRepository.getStudentProfile: Fetching profile for userId $userId');
      }
      final profileData = await _api.getStudentProfile(userId);
      if (kDebugMode) {
        print(
            'AuthRepository.getStudentProfile: Received profileData: $profileData');
      }

      // Create student object from the response
      // v2 API returns student data directly, no need for separate meta call
      final student = Student.fromApiV2(profileData);
      if (kDebugMode) {
        print(
            'AuthRepository.getStudentProfile: Created student: ${student.name}');
      }

      return student;
    } catch (e) {
      if (kDebugMode) {
        print('AuthRepository.getStudentProfile: Error - $e');
      }
      throw Exception('Failed to get student profile: ${e.toString()}');
    }
  }

  /// Change the user's password.
  Future<bool> changePassword(
      String currentPassword, String newPassword) async {
    return await _api.changePassword(currentPassword, newPassword);
  }

  /// Get family members (siblings).
  Future<List<Student>> getFamilyMembers() async {
    try {
      final userId = await getCurrentUserId();
      if (kDebugMode) {
        print('AuthRepository.getFamilyMembers: userId = $userId');
      }
      if (userId == null) {
        if (kDebugMode) {
          print(
              'AuthRepository.getFamilyMembers: userId is null, returning empty list');
        }
        return [];
      }

      final data = await _api.getStudentFamily(userId);
      if (kDebugMode) {
        print(
            'AuthRepository.getFamilyMembers: Received ${data.length} items from API');
      }
      final students = data.map((json) => Student.fromApiV2(json)).toList();
      if (kDebugMode) {
        print(
            'AuthRepository.getFamilyMembers: Parsed ${students.length} students');
      }
      return students;
    } catch (e) {
      if (kDebugMode) {
        print('AuthRepository.getFamilyMembers: Error - $e');
      }
      // Return empty list on failure rather than blocking UI
      return [];
    }
  }

  /// Switch current user to another family member.
  /// This updates the stored user ID but keeps the same auth token.
  Future<void> switchUser(Student newStudent) async {
    if (kDebugMode) {
      print(
          'AuthRepository.switchUser: Switching to student id=${newStudent.id}, name=${newStudent.name}');
    }
    // We update the stored user ID and Name.
    // The Token remains the same, assuming it's valid for the whole family.
    await _secureStorage.saveUserId(newStudent.id.toString());
    await _secureStorage.saveUserName(newStudent.name);
    if (kDebugMode) {
      print('AuthRepository.switchUser: Done saving user ID and name');
    }
    // Role is likely same (student)
  }

  /// Logout and clear all stored data.
  Future<void> logout() async {
    await _api.logout();
  }
}
