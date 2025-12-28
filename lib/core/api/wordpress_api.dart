import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../constants/api_constants.dart';
import '../services/secure_storage_service.dart';
import 'api_response.dart';

/// WordPress API client for Zuwad REST API v2.
///
/// Features:
/// - JWT authentication with refresh token support
/// - Automatic token refresh on expiry
/// - Standardized error handling
/// - Request/response logging in debug mode
class WordPressApi {
  final Dio _dio = Dio();
  final SecureStorageService _secureStorage = SecureStorageService();

  // Singleton pattern
  static final WordPressApi _instance = WordPressApi._internal();

  factory WordPressApi() {
    return _instance;
  }

  WordPressApi._internal() {
    // Configure Dio
    _dio.options.connectTimeout = const Duration(seconds: 15);
    _dio.options.receiveTimeout = const Duration(seconds: 15);
    _dio.options.headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };

    // Add interceptors
    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        // Auto-attach token if available
        final token = await _secureStorage.getToken();
        if (token != null && token.isNotEmpty) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        return handler.next(options);
      },
      onError: (error, handler) async {
        // Auto-refresh token on 401 errors
        if (error.response?.statusCode == 401) {
          // Skip if this is already a refresh request (prevent loop)
          if (error.requestOptions.path.contains('/auth/refresh')) {
            return handler.next(error);
          }

          try {
            final refreshed = await refreshToken();
            if (refreshed) {
              // Retry the original request with new token
              final newToken = await _secureStorage.getToken();
              error.requestOptions.headers['Authorization'] =
                  'Bearer $newToken';
              final response = await _dio.fetch(error.requestOptions);
              return handler.resolve(response);
            }
          } catch (e) {
            if (kDebugMode) {
              print('Token refresh failed: $e');
            }
          }
        }
        return handler.next(error);
      },
    ));

    // Add logging interceptor only in debug mode
    if (kDebugMode) {
      _dio.interceptors.add(LogInterceptor(
        requestBody: true,
        responseBody: true,
        error: true,
      ));
    }
  }

  // ============================================
  // Authentication Methods
  // ============================================

  /// Login with phone number and password.
  /// Returns the full user data on success.
  ///
  /// Note: For this system, users login with their phone number as the password.
  Future<Map<String, dynamic>> loginWithPhone(
    String phone,
    String password, {
    String? role,
  }) async {
    try {
      final response = await _dio.post(
        ApiConstants.loginEndpoint,
        data: jsonEncode({
          'phone': phone,
          'password': password,
          if (role != null) 'role': role,
        }),
      );

      if (response.statusCode == 200) {
        final jsonData = response.data;

        if (jsonData['success'] == true) {
          final data = jsonData['data'];

          // Save all auth data
          await _secureStorage.saveAuthData(
            token: data['token'],
            refreshToken: data['refresh_token'],
            expiresIn: data['expires_in'] ?? 604800,
            userId: data['user']['id'].toString(),
            userName: data['user']['name'],
            userRole: data['user']['role'],
            userMId: data['user']['m_id'],
          );

          return data;
        } else {
          throw Exception(jsonData['error']?['message'] ?? 'Login failed');
        }
      } else {
        throw Exception('Failed to login: ${response.statusCode}');
      }
    } on DioException catch (e) {
      final errorMessage =
          e.response?.data?['error']?['message'] ?? e.message ?? 'Login failed';
      throw Exception(errorMessage);
    } catch (e) {
      throw Exception('Login failed: ${e.toString()}');
    }
  }

  /// Refresh the access token using the refresh token.
  /// Returns true if refresh was successful.
  Future<bool> refreshToken() async {
    try {
      final refreshToken = await _secureStorage.getRefreshToken();
      if (refreshToken == null) {
        return false;
      }

      final response = await _dio.post(
        ApiConstants.refreshTokenEndpoint,
        data: jsonEncode({
          'refresh_token': refreshToken,
        }),
        options: Options(
          headers: {'Authorization': null}, // Don't use old token
        ),
      );

      if (response.statusCode == 200) {
        final jsonData = response.data;

        if (jsonData['success'] == true) {
          final data = jsonData['data'];
          await _secureStorage.saveToken(data['token']);
          await _secureStorage.saveRefreshToken(data['refresh_token']);
          await _secureStorage.saveTokenExpiry(data['expires_in'] ?? 604800);
          return true;
        }
      }
      return false;
    } catch (e) {
      if (kDebugMode) {
        print('Refresh token error: $e');
      }
      return false;
    }
  }

  /// Verify if the current token is valid.
  Future<bool> verifyToken() async {
    try {
      final response = await _dio.get(ApiConstants.verifyTokenEndpoint);
      return response.statusCode == 200 && response.data?['success'] == true;
    } catch (e) {
      return false;
    }
  }

  /// Logout the current user.
  Future<void> logout() async {
    try {
      // Call logout endpoint to invalidate token on server
      await _dio.post(ApiConstants.logoutEndpoint);
    } catch (e) {
      if (kDebugMode) {
        print('Logout API call failed: $e');
      }
    } finally {
      // Always clear local storage
      await _secureStorage.clearAll();
    }
  }

  /// Change the user's password.
  Future<bool> changePassword(
      String currentPassword, String newPassword) async {
    try {
      final response = await _dio.post(
        ApiConstants.changePasswordEndpoint,
        data: jsonEncode({
          'current_password': currentPassword,
          'new_password': newPassword,
        }),
      );

      return response.statusCode == 200 && response.data?['success'] == true;
    } catch (e) {
      throw Exception('Failed to change password: ${e.toString()}');
    }
  }

  // ============================================
  // Student Methods
  // ============================================

  /// Get student profile data.
  Future<Map<String, dynamic>> getStudentProfile(int? userId) async {
    try {
      userId ??= await _secureStorage.getUserIdAsInt();
      if (userId == null) {
        throw Exception('User ID not found');
      }

      final response = await _dio.get(
        ApiConstants.studentByIdEndpoint(userId),
      );

      if (response.statusCode == 200) {
        final jsonData = response.data;
        if (jsonData['success'] == true) {
          return jsonData['data'];
        }
        throw Exception(
            jsonData['error']?['message'] ?? 'Failed to get profile');
      }
      throw Exception('Failed to get profile: ${response.statusCode}');
    } catch (e) {
      throw Exception('Get profile failed: ${e.toString()}');
    }
  }

  /// Get student reports.
  Future<List<dynamic>> getStudentReports(int studentId,
      {int page = 1, int perPage = 50}) async {
    try {
      final response = await _dio.get(
        ApiConstants.studentReportsEndpoint(studentId),
        queryParameters: {
          'page': page,
          'per_page': perPage,
        },
      );

      if (response.statusCode == 200) {
        final jsonData = response.data;
        if (jsonData['success'] == true) {
          return jsonData['data'] as List<dynamic>;
        }
        throw Exception(
            jsonData['error']?['message'] ?? 'Failed to get reports');
      }
      throw Exception('Failed to get reports: ${response.statusCode}');
    } catch (e) {
      throw Exception('Get reports failed: ${e.toString()}');
    }
  }

  /// Get student schedules.
  Future<List<dynamic>> getStudentSchedules(int studentId) async {
    try {
      final response = await _dio.get(
        ApiConstants.studentSchedulesEndpoint(studentId),
      );

      if (response.statusCode == 200) {
        final jsonData = response.data;
        if (jsonData['success'] == true) {
          return jsonData['data'] as List<dynamic>;
        }
        throw Exception(
            jsonData['error']?['message'] ?? 'Failed to get schedules');
      }
      throw Exception('Failed to get schedules: ${response.statusCode}');
    } catch (e) {
      throw Exception('Get schedules failed: ${e.toString()}');
    }
  }

  // ============================================
  // Teacher Methods
  // ============================================

  /// Get teacher data.
  Future<Map<String, dynamic>> getTeacherData(int teacherId) async {
    try {
      final response = await _dio.get(
        ApiConstants.teacherByIdEndpoint(teacherId),
      );

      if (response.statusCode == 200) {
        final jsonData = response.data;
        if (jsonData['success'] == true) {
          return jsonData['data'];
        }
        throw Exception(
            jsonData['error']?['message'] ?? 'Failed to get teacher data');
      }
      throw Exception('Failed to get teacher data: ${response.statusCode}');
    } catch (e) {
      throw Exception('Get teacher data failed: ${e.toString()}');
    }
  }

  /// Get teacher free slots.
  Future<List<dynamic>> getTeacherFreeSlots(int teacherId) async {
    try {
      final response = await _dio.get(
        ApiConstants.teacherFreeSlotsEndpoint(teacherId),
      );

      if (response.statusCode == 200) {
        // Check if response.data is already a Map (parsed JSON)
        final jsonData = response.data;
        if (jsonData is Map<String, dynamic>) {
          if (jsonData['success'] == true) {
            final data = jsonData['data'];
            if (data is List) {
              return data;
            }
            return [];
          }
          throw Exception(
              jsonData['error']?['message'] ?? 'Failed to get free slots');
        } else {
          // Response is not valid JSON
          if (kDebugMode) {
            print(
                'Free slots API returned non-JSON response: ${response.data}');
          }
          return []; // Return empty list instead of crashing
        }
      }
      throw Exception('Failed to get free slots: ${response.statusCode}');
    } on DioException catch (e) {
      if (kDebugMode) {
        print('DioException getting free slots: ${e.message}');
        print('Response data: ${e.response?.data}');
      }
      return []; // Return empty list on network errors
    } catch (e) {
      if (kDebugMode) {
        print('Error getting free slots: $e');
      }
      return []; // Return empty list instead of throwing
    }
  }

  // ============================================
  // Schedule Methods
  // ============================================

  /// Create a postponed event.
  Future<Map<String, dynamic>> createPostponedEvent({
    required int studentId,
    required int teacherId,
    required String originalDate,
    required String originalTime,
    required String newDate,
    required String newTime,
  }) async {
    try {
      final response = await _dio.post(
        ApiConstants.schedulePostponeEndpoint,
        data: jsonEncode({
          'student_id': studentId,
          'teacher_id': teacherId,
          'original_date': originalDate,
          'original_time': originalTime,
          'new_date': newDate,
          'new_time': newTime,
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final jsonData = response.data;
        if (jsonData['success'] == true) {
          return jsonData['data'];
        }
        throw Exception(jsonData['error']?['message'] ??
            'Failed to create postponed event');
      }
      throw Exception(
          'Failed to create postponed event: ${response.statusCode}');
    } catch (e) {
      throw Exception('Create postponed event failed: ${e.toString()}');
    }
  }

  // ============================================
  // Report Methods
  // ============================================

  /// Create a student report.
  Future<Map<String, dynamic>> createStudentReport({
    required int studentId,
    required int teacherId,
    required String attendance,
    required String date,
    required int lessonDuration,
    String? sessionNumber,
    String? time,
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
      final response = await _dio.post(
        ApiConstants.reportsEndpoint,
        data: jsonEncode({
          'student_id': studentId,
          'teacher_id': teacherId,
          'attendance': attendance,
          'date': date,
          'lesson_duration': lessonDuration,
          if (sessionNumber != null) 'session_number': sessionNumber,
          if (time != null) 'time': time,
          if (evaluation != null) 'evaluation': evaluation,
          if (grade != null) 'grade': grade,
          if (tasmii != null) 'tasmii': tasmii,
          if (tahfiz != null) 'tahfiz': tahfiz,
          if (mourajah != null) 'mourajah': mourajah,
          if (nextTasmii != null) 'next_tasmii': nextTasmii,
          if (nextMourajah != null) 'next_mourajah': nextMourajah,
          if (notes != null) 'notes': notes,
          if (zoomImageUrl != null) 'zoom_image_url': zoomImageUrl,
          if (isPostponed != null) 'is_postponed': isPostponed,
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final jsonData = response.data;
        if (jsonData['success'] == true) {
          return jsonData['data'];
        }
        throw Exception(
            jsonData['error']?['message'] ?? 'Failed to create report');
      }
      throw Exception('Failed to create report: ${response.statusCode}');
    } catch (e) {
      throw Exception('Create report failed: ${e.toString()}');
    }
  }

  /// Calculate session number based on attendance.
  Future<Map<String, dynamic>> calculateSessionNumber({
    required int studentId,
    required String attendance,
  }) async {
    try {
      final response = await _dio.get(
        ApiConstants.sessionNumberEndpoint,
        queryParameters: {
          'student_id': studentId,
          'attendance': attendance,
        },
      );

      if (response.statusCode == 200) {
        final jsonData = response.data;
        if (jsonData['success'] == true) {
          return jsonData['data'];
        }
        throw Exception(jsonData['error']?['message'] ??
            'Failed to calculate session number');
      }
      throw Exception(
          'Failed to calculate session number: ${response.statusCode}');
    } catch (e) {
      throw Exception('Calculate session number failed: ${e.toString()}');
    }
  }

  // ============================================
  // Chat Methods
  // ============================================

  /// Get available chat contacts for the authenticated user.
  /// Returns list of users the current user can chat with.
  Future<List<dynamic>> getChatContacts() async {
    try {
      final response = await _dio.get(ApiConstants.chatContactsEndpoint);

      if (response.statusCode == 200) {
        final jsonData = response.data;
        if (jsonData['success'] == true) {
          return jsonData['data'] as List<dynamic>;
        }
      }
      return [];
    } catch (e) {
      if (kDebugMode) {
        print('Get chat contacts failed: $e');
      }
      return [];
    }
  }

  /// Get chat conversations.
  Future<List<dynamic>> getConversations(
      {int page = 1, int perPage = 50}) async {
    try {
      final response = await _dio.get(
        ApiConstants.chatConversationsEndpoint,
        queryParameters: {
          'page': page,
          'per_page': perPage,
        },
      );

      if (response.statusCode == 200) {
        final jsonData = response.data;
        if (jsonData['success'] == true) {
          return jsonData['data'] as List<dynamic>;
        }
      }
      return [];
    } catch (e) {
      if (kDebugMode) {
        print('Get conversations failed: $e');
      }
      return [];
    }
  }

  /// Get messages for a conversation.
  ///
  /// Supports pagination with [page] parameter and real-time sync
  /// with [afterId] parameter to get only new messages.
  Future<Map<String, dynamic>> getChatMessages(
    String conversationId, {
    int page = 1,
    int? afterId,
  }) async {
    try {
      final queryParams = <String, dynamic>{'page': page};
      if (afterId != null) {
        queryParams['after_id'] = afterId;
      }

      final response = await _dio.get(
        ApiConstants.chatMessagesEndpoint(conversationId),
        queryParameters: queryParams,
      );

      if (response.statusCode == 200) {
        final jsonData = response.data;
        if (jsonData['success'] == true) {
          // Response includes conversation_id, other_user, and messages
          return jsonData['data'] as Map<String, dynamic>;
        }
      }
      return {'messages': []};
    } catch (e) {
      if (kDebugMode) {
        print('Get messages failed: $e');
      }
      return {'messages': []};
    }
  }

  /// Send a chat message to a conversation.
  Future<Map<String, dynamic>> sendChatMessage(
    String conversationId,
    String message,
  ) async {
    try {
      final response = await _dio.post(
        ApiConstants.chatMessagesEndpoint(conversationId),
        data: jsonEncode({'message': message}),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final jsonData = response.data;
        if (jsonData['success'] == true) {
          return jsonData['data'];
        }
        throw Exception(
            jsonData['error']?['message'] ?? 'Failed to send message');
      }
      throw Exception('Failed to send message: ${response.statusCode}');
    } catch (e) {
      throw Exception('Send message failed: ${e.toString()}');
    }
  }

  /// Send a direct message to a recipient.
  /// Creates conversation if needed.
  Future<Map<String, dynamic>> sendDirectMessage(
    int recipientId,
    String message,
  ) async {
    try {
      final response = await _dio.post(
        ApiConstants.chatSendDirectEndpoint,
        data: jsonEncode({
          'recipient_id': recipientId,
          'message': message,
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final jsonData = response.data;
        if (jsonData['success'] == true) {
          return jsonData['data'];
        }
        throw Exception(
            jsonData['error']?['message'] ?? 'Failed to send direct message');
      }
      throw Exception('Failed to send direct message: ${response.statusCode}');
    } catch (e) {
      throw Exception('Send direct message failed: ${e.toString()}');
    }
  }

  /// Create a new conversation or get existing one.
  Future<Map<String, dynamic>> createConversation(
    int recipientId, {
    String? message,
  }) async {
    try {
      final data = <String, dynamic>{'recipient_id': recipientId};
      if (message != null && message.isNotEmpty) {
        data['message'] = message;
      }

      final response = await _dio.post(
        ApiConstants.chatConversationsEndpoint,
        data: jsonEncode(data),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final jsonData = response.data;
        if (jsonData['success'] == true) {
          return jsonData['data'];
        }
        throw Exception(
            jsonData['error']?['message'] ?? 'Failed to create conversation');
      }
      throw Exception('Failed to create conversation: ${response.statusCode}');
    } catch (e) {
      throw Exception('Create conversation failed: ${e.toString()}');
    }
  }

  /// Mark conversation as read.
  Future<int> markConversationAsRead(String conversationId) async {
    try {
      final response =
          await _dio.post(ApiConstants.chatReadEndpoint(conversationId));
      if (response.statusCode == 200) {
        final jsonData = response.data;
        if (jsonData['success'] == true) {
          return jsonData['data']?['marked_read'] ?? 0;
        }
      }
      return 0;
    } catch (e) {
      if (kDebugMode) {
        print('Mark as read failed: $e');
      }
      return 0;
    }
  }

  /// Get unread message count.
  Future<int> getUnreadCount() async {
    try {
      final response = await _dio.get(ApiConstants.chatUnreadCountEndpoint);
      if (response.statusCode == 200) {
        final jsonData = response.data;
        if (jsonData['success'] == true) {
          return jsonData['data']['unread_count'] ?? 0;
        }
      }
      return 0;
    } catch (e) {
      return 0;
    }
  }

  // ============================================
  // Settings/Profile Methods
  // ============================================

  /// Upload student profile image.
  Future<String> uploadStudentProfileImage(
      int studentId, String imagePath) async {
    try {
      String fileName = imagePath.split('/').last;
      FormData formData = FormData.fromMap({
        'image': await MultipartFile.fromFile(imagePath, filename: fileName),
      });

      final response = await _dio.post(
        ApiConstants.studentUploadImageEndpoint(studentId),
        data: formData,
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final jsonData = response.data;
        if (jsonData['success'] == true) {
          return jsonData['data']['profile_image_url'];
        }
        throw Exception(
            jsonData['error']?['message'] ?? 'Failed to upload image');
      }
      throw Exception('Failed to upload image: ${response.statusCode}');
    } catch (e) {
      throw Exception('Upload image failed: ${e.toString()}');
    }
  }

  /// Update student profile data.
  Future<Map<String, dynamic>> updateStudentProfile(
    int studentId,
    Map<String, dynamic> data,
  ) async {
    try {
      if (kDebugMode) {
        print('WordPressApi.updateStudentProfile - studentId: $studentId');
        print(
            'WordPressApi.updateStudentProfile - endpoint: ${ApiConstants.studentByIdEndpoint(studentId)}');
        print('WordPressApi.updateStudentProfile - data: $data');
      }

      final response = await _dio.put(
        ApiConstants.studentByIdEndpoint(studentId),
        data: jsonEncode(data),
      );

      if (kDebugMode) {
        print(
            'WordPressApi.updateStudentProfile - statusCode: ${response.statusCode}');
        print('WordPressApi.updateStudentProfile - response: ${response.data}');
      }

      if (response.statusCode == 200) {
        final jsonData = response.data;
        if (jsonData['success'] == true) {
          return jsonData['data'];
        }
        throw Exception(
            jsonData['error']?['message'] ?? 'Failed to update profile');
      }
      throw Exception('Failed to update profile: ${response.statusCode}');
    } on DioException catch (e) {
      if (kDebugMode) {
        print('WordPressApi.updateStudentProfile - DioException: ${e.message}');
        print(
            'WordPressApi.updateStudentProfile - Response data: ${e.response?.data}');
      }
      final errorMessage = e.response?.data?['error']?['message'] ??
          e.response?.data?['message'] ??
          e.message ??
          'Update failed';
      throw Exception('Update profile failed: $errorMessage');
    } catch (e) {
      if (kDebugMode) {
        print('WordPressApi.updateStudentProfile - Error: $e');
      }
      throw Exception('Update profile failed: ${e.toString()}');
    }
  }

  /// Get student's wallet information.
  Future<Map<String, dynamic>> getStudentWallet(int studentId) async {
    try {
      if (kDebugMode) {
        print('WordPressApi.getStudentWallet - studentId: $studentId');
        print(
            'WordPressApi.getStudentWallet - endpoint: ${ApiConstants.studentWalletEndpoint(studentId)}');
      }

      final response = await _dio.get(
        ApiConstants.studentWalletEndpoint(studentId),
      );

      if (kDebugMode) {
        print(
            'WordPressApi.getStudentWallet - statusCode: ${response.statusCode}');
        print('WordPressApi.getStudentWallet - response: ${response.data}');
      }

      if (response.statusCode == 200) {
        final jsonData = response.data;
        if (jsonData['success'] == true) {
          return jsonData['data'];
        }
        throw Exception(
            jsonData['error']?['message'] ?? 'Failed to get wallet');
      }
      throw Exception('Failed to get wallet: ${response.statusCode}');
    } catch (e) {
      if (kDebugMode) {
        print('WordPressApi.getStudentWallet - Error: $e');
      }
      throw Exception('Get wallet failed: ${e.toString()}');
    }
  }

  /// Get wallet transactions for a family.
  Future<List<dynamic>> getWalletTransactions(int familyId) async {
    try {
      if (kDebugMode) {
        print('WordPressApi.getWalletTransactions - familyId: $familyId');
        print(
            'WordPressApi.getWalletTransactions - endpoint: ${ApiConstants.walletTransactionsEndpoint(familyId)}');
      }

      final response = await _dio.get(
        ApiConstants.walletTransactionsEndpoint(familyId),
      );

      if (kDebugMode) {
        print(
            'WordPressApi.getWalletTransactions - statusCode: ${response.statusCode}');
        print(
            'WordPressApi.getWalletTransactions - response: ${response.data}');
      }

      if (response.statusCode == 200) {
        final jsonData = response.data;
        if (jsonData['success'] == true) {
          return jsonData['data'] as List<dynamic>? ?? [];
        }
        return [];
      }
      return [];
    } catch (e) {
      if (kDebugMode) {
        print('WordPressApi.getWalletTransactions - Error: $e');
      }
      return [];
    }
  }

  // ============================================
  // Utility Methods
  // ============================================

  /// Check API status.
  Future<bool> checkApiStatus() async {
    try {
      final response = await _dio.get(ApiConstants.statusEndpoint);
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  /// Generic GET request helper.
  Future<ApiResponse<T>> get<T>(
    String endpoint,
    T Function(dynamic json) fromJsonT, {
    Map<String, dynamic>? queryParameters,
  }) async {
    try {
      final response = await _dio.get(
        endpoint,
        queryParameters: queryParameters,
      );
      return ApiResponse.fromJson(response.data, fromJsonT);
    } on DioException catch (e) {
      return ApiResponse(
        success: false,
        error: ApiError(
          code: 'request_failed',
          message: e.message ?? 'Request failed',
          status: e.response?.statusCode ?? 500,
        ),
      );
    }
  }

  /// Generic POST request helper.
  Future<ApiResponse<T>> post<T>(
    String endpoint,
    T Function(dynamic json) fromJsonT, {
    Map<String, dynamic>? data,
  }) async {
    try {
      final response = await _dio.post(
        endpoint,
        data: data != null ? jsonEncode(data) : null,
      );
      return ApiResponse.fromJson(response.data, fromJsonT);
    } on DioException catch (e) {
      return ApiResponse(
        success: false,
        error: ApiError(
          code: 'request_failed',
          message: e.message ?? 'Request failed',
          status: e.response?.statusCode ?? 500,
        ),
      );
    }
  }
}
