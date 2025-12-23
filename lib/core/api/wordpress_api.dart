import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../config/env_config.dart';
import '../services/secure_storage_service.dart';

class WordPressApi {
  final Dio _dio = Dio();
  final SecureStorageService _secureStorage = SecureStorageService();
  late final String _baseUrl;

  // Singleton pattern
  static final WordPressApi _instance = WordPressApi._internal();

  factory WordPressApi() {
    return _instance;
  }

  WordPressApi._internal() {
    // Use centralized environment configuration
    _baseUrl = EnvConfig.apiBaseUrl;

    // Configure Dio
    _dio.options.connectTimeout = const Duration(seconds: 10);
    _dio.options.receiveTimeout = const Duration(seconds: 10);
    _dio.options.headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };

    // Add interceptors for logging only in debug mode
    if (kDebugMode) {
      _dio.interceptors.add(LogInterceptor(
        requestBody: true,
        responseBody: true,
        error: true,
      ));
    }
  }

  // Helper to get token from secure storage
  Future<String?> _getToken() async {
    return await _secureStorage.getToken();
  }

  // Helper to get user ID from secure storage
  Future<int?> _getUserId() async {
    return await _secureStorage.getUserIdAsInt();
  }

  // Student login with phone and password
  Future<Map<String, dynamic>> loginWithPhone(
      String phone, String password) async {
    try {
      // Custom endpoint for phone login
      final response = await _dio.post(
        '$_baseUrl/custom/v1/student-login',
        data: jsonEncode({
          'phone': phone,
          'password': password,
        }),
      );

      if (response.statusCode == 200) {
        // Save token to secure storage
        await _secureStorage.saveToken(response.data['token']);
        await _secureStorage.saveUserId(response.data['user_id'].toString());

        return response.data;
      } else {
        throw Exception('Failed to login');
      }
    } catch (e) {
      throw Exception('Login failed: ${e.toString()}');
    }
  }

  // Get student profile data
  Future<Map<String, dynamic>> getStudentProfile(int? userId) async {
    try {
      final token = await _getToken();

      if (token == null) {
        throw Exception('Not authenticated');
      }

      if (userId == null) {
        userId = await _getUserId();
        if (userId == null) {
          throw Exception('User ID not found');
        }
      }

      _dio.options.headers['Authorization'] = 'Bearer $token';

      final response = await _dio.get('$_baseUrl/custom/v1/user-meta/$userId');

      if (response.statusCode == 200) {
        return response.data;
      } else {
        throw Exception('Failed to get profile');
      }
    } catch (e) {
      throw Exception('Get profile failed: ${e.toString()}');
    }
  }

  // Get user meta data
  Future<Map<String, dynamic>> getUserMeta(int? userId) async {
    try {
      final token = await _getToken();

      if (token == null) {
        throw Exception('Not authenticated');
      }

      if (userId == null) {
        userId = await _getUserId();
        if (userId == null) {
          throw Exception('User ID not found');
        }
      }

      _dio.options.headers['Authorization'] = 'Bearer $token';

      // Custom endpoint to get user meta
      final response = await _dio.get('$_baseUrl/custom/v1/user-meta/$userId');

      if (response.statusCode == 200) {
        return response.data;
      } else {
        throw Exception('Failed to get user meta');
      }
    } catch (e) {
      throw Exception('Get user meta failed: ${e.toString()}');
    }
  }

  // Get teacher data
  Future<Map<String, dynamic>> getTeacherData(int? teacherId) async {
    try {
      final token = await _getToken();

      if (token == null) {
        throw Exception('Not authenticated');
      }

      if (teacherId == null) {
        throw Exception('Teacher ID is null');
      }

      _dio.options.headers['Authorization'] = 'Bearer $token';

      final response =
          await _dio.get('$_baseUrl/custom/v1/user-meta/$teacherId');

      if (response.statusCode == 200) {
        return response.data;
      } else {
        throw Exception('Failed to get teacher data');
      }
    } catch (e) {
      throw Exception('Get teacher data failed: ${e.toString()}');
    }
  }

  // Create postponed event
  Future<Map<String, dynamic>> createPostponedEvent({
    required int studentId,
    required String studentName,
    required int teacherId,
    required String eventDate,
    required String eventTime,
    required String dayOfWeek,
  }) async {
    try {
      final token = await _getToken();

      if (token == null) {
        throw Exception('Not authenticated');
      }

      _dio.options.headers['Authorization'] = 'Bearer $token';

      final response = await _dio.post(
        '$_baseUrl/zuwad/v1/create-postponed-event',
        data: jsonEncode({
          'studentId': studentId,
          'studentName': studentName,
          'teacherId': teacherId,
          'eventDate': eventDate,
          'eventTime': eventTime,
          'dayOfWeek': dayOfWeek,
        }),
      );

      if (response.statusCode == 200) {
        final data = response.data;
        if (data['success'] == true) {
          return data;
        } else {
          throw Exception(
              data['message'] ?? 'Failed to create postponed event');
        }
      } else {
        final errorData = response.data;
        throw Exception(
            errorData['message'] ?? 'Failed to create postponed event');
      }
    } catch (e) {
      throw Exception('Create postponed event failed: ${e.toString()}');
    }
  }

  // Create student report
  Future<Map<String, dynamic>> createStudentReport({
    required int studentId,
    required int teacherId,
    required String attendance,
    String? sessionNumber,
    required String date,
    String? time,
    required int lessonDuration,
    String? evaluation,
    int? grade,
    String? tasmii,
    String? tahfiz,
    String? mourajah,
    String? nextTasmii,
    String? nextMourajah,
    String? notes,
    String? zoomImageUrl,
    int? isPostponed,
  }) async {
    try {
      final token = await _getToken();

      if (token == null) {
        throw Exception('Not authenticated');
      }

      _dio.options.headers['Authorization'] = 'Bearer $token';

      final response = await _dio.post(
        '$_baseUrl/zuwad/v1/create-student-report',
        data: jsonEncode({
          'studentId': studentId,
          'teacherId': teacherId,
          'attendance': attendance,
          'sessionNumber': sessionNumber ?? '',
          'date': date,
          'time': time ?? '',
          'lessonDuration': lessonDuration,
          'evaluation': evaluation ?? '',
          'grade': grade ?? 0,
          'tasmii': tasmii ?? '',
          'tahfiz': tahfiz ?? '',
          'mourajah': mourajah ?? '',
          'nextTasmii': nextTasmii ?? '',
          'nextMourajah': nextMourajah ?? '',
          'notes': notes ?? '',
          'zoomImageUrl': zoomImageUrl ?? '',
          'isPostponed': isPostponed ?? 0,
        }),
      );

      if (kDebugMode) {
        print('Create student report response status: ${response.statusCode}');
        print('Create student report response headers: ${response.headers}');
        print('Create student report response body: ${response.data}');
      }

      if (response.statusCode == 200) {
        final data = response.data;
        if (data['success'] == true) {
          return data;
        } else {
          throw Exception(data['message'] ?? 'Failed to create student report');
        }
      } else {
        final errorData = response.data;
        throw Exception(
            errorData['message'] ?? 'Failed to create student report');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Create student report error: $e');
      }
      throw Exception('Create student report failed: ${e.toString()}');
    }
  }

  // Logout
  Future<void> logout() async {
    await _secureStorage.clearAll();
  }
}
