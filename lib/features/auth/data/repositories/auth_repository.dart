import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/api/wordpress_api.dart';
import '../../domain/models/student.dart';

class AuthRepository {
  final WordPressApi _api = WordPressApi();

  // Login with phone and password
  Future<bool> login(String phone, String password) async {
    try {
      final response = await _api.loginWithPhone(phone, password);
      return response.containsKey('token');
    } catch (e) {
      return false;
    }
  }

  // Check if user is logged in
  Future<bool> isLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.containsKey('auth_token');
  }

  // Get current user ID
  Future<int?> getCurrentUserId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt('user_id');
  }

  // Get student profile with all required data
  Future<Student> getStudentProfile() async {
    try {
      final userId = await getCurrentUserId();

      if (userId == null) {
        throw Exception('User not logged in');
      }

      // Get user meta data which contains all the student information
      final userMeta = await _api.getUserMeta(userId);

      // The API now returns all student data in one call
      // Create student object with a placeholder ID and the user meta data
      final student = Student.fromJson({'id': userId}, userMeta);

      return student;
    } catch (e) {
      throw Exception('Failed to get student profile: ${e.toString()}');
    }
  }

  // Logout
  Future<void> logout() async {
    await _api.logout();
  }
}
