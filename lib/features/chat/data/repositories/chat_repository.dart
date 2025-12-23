import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../../../../core/config/env_config.dart';
import '../../../../core/services/secure_storage_service.dart';
import '../models/chat_message.dart';

class ChatRepository {
  final Dio _dio = Dio();
  final SecureStorageService _secureStorage = SecureStorageService();
  final Connectivity _connectivity = Connectivity();
  final String baseUrl;

  ChatRepository({
    String? baseUrl,
  }) : baseUrl = baseUrl ?? EnvConfig.baseUrl {
    // Configure Dio
    _dio.options.connectTimeout = const Duration(seconds: 10);
    _dio.options.receiveTimeout = const Duration(seconds: 10);
    _dio.options.headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
  }

  ChatMessage _createPendingMessage({
    required String studentId,
    required String recipientId,
    required String message,
  }) {
    return ChatMessage(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      content: message,
      senderId: studentId,
      senderName: '',
      timestamp: DateTime.now(),
      isPending: true,
    );
  }

  Future<String?> _getToken() async {
    return await _secureStorage.getToken();
  }

  Future<List<ChatMessage>> getMessages({
    required String studentId,
    required String recipientId,
    int page = 1,
  }) async {
    try {
      final token = await _getToken();
      if (token == null) throw Exception('Not authenticated');

      final url = '$baseUrl/wp-json/zuwad/v1/chat/messages';
      if (kDebugMode) {
        print(
            'Fetching messages from $url with studentId=$studentId, recipientId=$recipientId, page=$page');
      }

      final response = await _dio.post(
        url,
        options: Options(
          headers: {'Authorization': 'Bearer $token'},
        ),
        data: {
          'student_id': studentId,
          'recipient_id': recipientId,
          'page': page,
        },
      );

      if (kDebugMode) {
        print('API response status: ${response.statusCode}');
        print('API response body: ${response.data}');
      }

      if (response.statusCode == 200) {
        final List<dynamic> data = response.data;
        if (kDebugMode) {
          print('Received ${data.length} messages from server');
          for (var msg in data) {
            print(
                'Message: ${msg['id']} from ${msg['sender_id']} to ${msg['recipient_id']}, content: ${msg['content'] ?? msg['message']}');
          }
        }

        final messages =
            data.map((json) => ChatMessage.fromJson(json)).toList();
        return messages;
      } else {
        if (kDebugMode) {
          print(
              'Failed to load messages: ${response.statusCode} - ${response.data}');
        }
        throw Exception('Failed to load messages: ${response.statusCode}');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error fetching messages: $e');
      }
      return [];
    }
  }

  Future<ChatMessage> sendMessage({
    required String studentId,
    required String recipientId,
    required String message,
  }) async {
    // Check connectivity - handle List<ConnectivityResult> from newer API
    final connectivityResults = await _connectivity.checkConnectivity();
    final bool isOnline =
        !connectivityResults.contains(ConnectivityResult.none);

    // Create a pending message
    final pendingMessage = _createPendingMessage(
      studentId: studentId,
      recipientId: recipientId,
      message: message,
    );

    // If offline, return pending message
    if (!isOnline) {
      return pendingMessage;
    }

    // Try to send immediately if online
    try {
      final token = await _getToken();
      if (token == null) {
        return pendingMessage;
      }

      final url = '$baseUrl/wp-json/zuwad/v1/chat/send';
      final response = await _dio.post(
        url,
        options: Options(
          headers: {'Authorization': 'Bearer $token'},
        ),
        data: {
          'student_id': studentId,
          'recipient_id': recipientId,
          'message': message,
        },
      );

      if (kDebugMode) {
        print(
            'Send message response: ${response.statusCode} - ${response.data}');
      }

      if (response.statusCode == 201 || response.statusCode == 200) {
        final serverMessage = ChatMessage.fromJson(response.data);
        return serverMessage;
      } else {
        throw Exception(
            'Failed to send message. Status: ${response.statusCode}. '
            'Error: ${response.data?['message'] ?? response.data}');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error sending message: $e');
      }
      return pendingMessage;
    }
  }

  Future<void> markAsRead({
    required String messageId,
  }) async {
    final token = await _getToken();
    if (token == null) throw Exception('Not authenticated');

    final url = '$baseUrl/wp-json/zuwad/v1/chat/mark-read';
    final response = await _dio.post(
      url,
      options: Options(
        headers: {'Authorization': 'Bearer $token'},
      ),
      data: {'message_id': messageId},
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to mark message as read');
    }
  }
}
