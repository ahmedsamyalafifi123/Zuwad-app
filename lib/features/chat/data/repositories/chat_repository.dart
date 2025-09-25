import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
// Removed chat database import as we're not using local database anymore
import '../models/chat_message.dart';

import 'package:connectivity_plus/connectivity_plus.dart';

class ChatRepository {
  final String baseUrl;
  // Removed database instance as we're not using local database anymore
  final Connectivity _connectivity = Connectivity();

  ChatRepository({
    required this.baseUrl,
  }) {
    // Listen for connectivity changes
    _connectivity.onConnectivityChanged.listen((result) async {
      if (result != ConnectivityResult.none) {
        // When connection is restored, retry sending pending messages
        await retrySendingPendingMessages();
      }
    });
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
      senderName: '', // We'll need to get this from somewhere
      timestamp: DateTime.now(),
      isPending: true,
    );
  }

  Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('auth_token');
  }

  // This method is no longer needed as we're not using local database for messages
  Future<List<ChatMessage>> loadLocalMessages(String userId1, String userId2) async {
    // Return empty list as we're not using local database anymore
    return [];
  }

  Future<List<ChatMessage>> getMessages({
    required String studentId,
    required String recipientId,
    int page = 1,
  }) async {
    try {
      final token = await _getToken();
      if (token == null) throw Exception('Not authenticated');

      final url = Uri.parse('$baseUrl/wp-json/zuwad/v1/chat/messages');
      print('Fetching messages from $url with studentId=$studentId, recipientId=$recipientId, page=$page');
      
      final response = await http.post(
        url,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'student_id': studentId,
          'recipient_id': recipientId,
          'page': page,
        }),
      );

      print('API response status: ${response.statusCode}');
      print('API response body: ${response.body}');

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        print('Received ${data.length} messages from server');
        for (var msg in data) {
          print('Message: ${msg['id']} from ${msg['sender_id']} to ${msg['recipient_id']}, content: ${msg['content'] ?? msg['message']}');
        }
        
        final messages = data.map((json) => ChatMessage.fromJson(json)).toList();
        
        // Return the server messages directly
        return messages;
      } else {
        print('Failed to load messages: ${response.statusCode} - ${response.body}');
        throw Exception('Failed to load messages: ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching messages: $e');
      // Return empty list
      return [];
    }
  }

  Future<ChatMessage> sendMessage({
    required String studentId,
    required String recipientId,
    required String message,
  }) async {
    // Check connectivity first
    final connectivityResult = await _connectivity.checkConnectivity();
    final bool isOnline = connectivityResult != ConnectivityResult.none;
    
    // Create a pending message
    final pendingMessage = _createPendingMessage(
      studentId: studentId,
      recipientId: recipientId,
      message: message,
    );

    // If offline, return pending message but don't store locally
    if (!isOnline) {
      return pendingMessage;
    }

    // Try to send immediately if online
    try {
      final token = await _getToken();
      if (token == null) {
        return pendingMessage;
      }

      final url = Uri.parse('$baseUrl/wp-json/zuwad/v1/chat/send');
      final response = await http.post(
        url,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'student_id': studentId,
          'recipient_id': recipientId,
          'message': message,
        }),
      );

      print('Send message response: ${response.statusCode} - ${response.body}');

      if (response.statusCode == 201 || response.statusCode == 200) {
        final json = jsonDecode(response.body);
        final serverMessage = ChatMessage.fromJson(json);
        return serverMessage;
      } else {
        Map<String, dynamic>? errorJson;
        try {
          errorJson = jsonDecode(response.body);
        } catch (_) {}
        
        throw Exception(
          'Failed to send message. Status: ${response.statusCode}. '
          'Error: ${errorJson?['message'] ?? response.body}'
        );
      }
    } catch (e) {
      print('Error sending message: $e');
      return pendingMessage;
    }
  }

  // This method is no longer needed as we're not storing messages locally
  Future<void> retrySendingPendingMessages() async {
    // No-op as we're not using local database for messages anymore
    return;
  }

  Future<void> markAsRead({
    required String messageId,
  }) async {
    final token = await _getToken();
    if (token == null) throw Exception('Not authenticated');

    final url = Uri.parse('$baseUrl/wp-json/zuwad/v1/chat/mark-read');
    final response = await http.post(
      url,
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'message_id': messageId,
      }),
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to mark message as read');
    }
    
    // No need to update local database as we're not using it anymore
  }
}
