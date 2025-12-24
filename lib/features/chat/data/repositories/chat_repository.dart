import 'package:flutter/foundation.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../../../../core/api/wordpress_api.dart';
import '../models/chat_message.dart';

/// Repository for chat operations using API v2.
///
/// The v2 API uses conversation-based endpoints rather than direct student/recipient.
class ChatRepository {
  final WordPressApi _api = WordPressApi();
  final Connectivity _connectivity = Connectivity();

  /// Create a pending message for optimistic UI updates.
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

  /// Get messages for a conversation.
  ///
  /// In v2 API, this uses conversation ID instead of student/recipient IDs.
  Future<List<ChatMessage>> getMessages({
    required String studentId,
    required String recipientId,
    int page = 1,
  }) async {
    try {
      // For v2 API, we use conversation ID which could be derived from student/recipient
      // For now, we'll use a simple format: smaller_id-larger_id
      final conversationId = _getConversationId(studentId, recipientId);

      if (kDebugMode) {
        print(
            'Fetching messages for conversation: $conversationId, page: $page');
      }

      final data = await _api.getChatMessages(conversationId, page: page);

      if (kDebugMode) {
        print('Received ${data.length} messages from server');
        for (var msg in data) {
          print(
              'Message: ${msg['id']} from ${msg['sender_id']}, content: ${msg['content'] ?? msg['message']}');
        }
      }

      final messages = data
          .map((json) => ChatMessage.fromJson(json as Map<String, dynamic>))
          .toList();
      return messages;
    } catch (e) {
      if (kDebugMode) {
        print('Error fetching messages: $e');
      }
      return [];
    }
  }

  /// Send a message in a conversation.
  Future<ChatMessage> sendMessage({
    required String studentId,
    required String recipientId,
    required String message,
  }) async {
    // Check connectivity
    final connectivityResults = await _connectivity.checkConnectivity();
    final bool isOnline =
        !connectivityResults.contains(ConnectivityResult.none);

    // Create a pending message for optimistic UI
    final pendingMessage = _createPendingMessage(
      studentId: studentId,
      recipientId: recipientId,
      message: message,
    );

    // If offline, return pending message
    if (!isOnline) {
      if (kDebugMode) {
        print('Offline - returning pending message');
      }
      return pendingMessage;
    }

    // Try to send immediately if online
    try {
      final conversationId = _getConversationId(studentId, recipientId);

      final data = await _api.sendChatMessage(conversationId, message);

      if (kDebugMode) {
        print('Send message response: $data');
      }

      return ChatMessage.fromJson(data);
    } catch (e) {
      if (kDebugMode) {
        print('Error sending message: $e');
      }
      // Return pending message on error for retry
      return pendingMessage;
    }
  }

  /// Create a new conversation.
  Future<String?> createConversation({
    required int recipientId,
    required String message,
  }) async {
    try {
      final data = await _api.createConversation(recipientId, message);

      // Return the conversation ID
      return data['id']?.toString();
    } catch (e) {
      if (kDebugMode) {
        print('Error creating conversation: $e');
      }
      return null;
    }
  }

  /// Mark a conversation as read.
  Future<void> markAsRead({
    required String conversationId,
  }) async {
    try {
      await _api.markConversationAsRead(conversationId);
    } catch (e) {
      if (kDebugMode) {
        print('Error marking as read: $e');
      }
    }
  }

  /// Get unread message count.
  Future<int> getUnreadCount() async {
    return await _api.getUnreadCount();
  }

  /// Get list of conversations.
  Future<List<Map<String, dynamic>>> getConversations({int page = 1}) async {
    try {
      final data = await _api.getConversations(page: page);
      return data.map((item) => item as Map<String, dynamic>).toList();
    } catch (e) {
      if (kDebugMode) {
        print('Error getting conversations: $e');
      }
      return [];
    }
  }

  /// Generate a conversation ID from two user IDs.
  /// Uses smaller ID first for consistency.
  String _getConversationId(String userId1, String userId2) {
    final id1 = int.tryParse(userId1) ?? 0;
    final id2 = int.tryParse(userId2) ?? 0;

    if (id1 < id2) {
      return '$userId1-$userId2';
    } else {
      return '$userId2-$userId1';
    }
  }
}
