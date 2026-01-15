import 'package:flutter/foundation.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../../../../core/services/secure_storage_service.dart';
import '../../../../core/api/wordpress_api.dart';
import '../models/chat_message.dart';
import '../models/contact.dart';
import '../models/conversation.dart';

/// Repository for chat operations using API v2.
///
/// The v2 API uses conversation-based endpoints with proper server-side
/// conversation IDs rather than client-generated ones.
class ChatRepository {
  final WordPressApi _api = WordPressApi();
  final Connectivity _connectivity = Connectivity();
  final SecureStorageService _secureStorage = SecureStorageService();

  /// Create a pending message for optimistic UI updates.
  ChatMessage _createPendingMessage({
    required String senderId,
    required String message,
  }) {
    return ChatMessage(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      content: message,
      senderId: senderId,
      senderName: '',
      timestamp: DateTime.now(),
      isPending: true,
    );
  }

  /// Get available chat contacts for the authenticated user.
  /// Returns list of users the current user can chat with based on their role.
  Future<List<Contact>> getContacts() async {
    try {
      final data = await _api.getChatContacts();

      if (kDebugMode) {
        print('Received ${data.length} contacts from server');
      }

      final contacts = data
          .map((json) => Contact.fromJson(json as Map<String, dynamic>))
          .toList();

      // Cache known supervisors and mini-visors
      final supervisorIds = contacts
          .where((c) =>
              c.role.toLowerCase() == 'supervisor' ||
              c.role.toLowerCase() == 'mini-visor')
          .map((c) => c.id.toString())
          .toList();

      if (supervisorIds.isNotEmpty) {
        if (kDebugMode) {
          print(
              'Caching ${supervisorIds.length} supervisor/mini-visor IDs from contacts');
        }
        // Add individually to merge with existing
        for (final id in supervisorIds) {
          await _secureStorage.addKnownSupervisor(id);
        }
      }

      return contacts;
    } catch (e) {
      if (kDebugMode) {
        print('Error fetching contacts: $e');
      }
      return [];
    }
  }

  /// Get list of conversations with last messages and unread counts.
  Future<List<Conversation>> getConversations({int page = 1}) async {
    try {
      final data = await _api.getConversations(page: page);

      if (kDebugMode) {
        print('Received ${data.length} conversations from server');
      }

      return data
          .map((json) => Conversation.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      if (kDebugMode) {
        print('Error getting conversations: $e');
      }
      return [];
    }
  }

  /// Get messages for a conversation by conversation ID.
  ///
  /// If [afterId] is provided, only messages after that ID are returned
  /// (useful for real-time sync polling).
  Future<List<ChatMessage>> getMessagesByConversationId(
    String conversationId, {
    int page = 1,
    int? afterId,
  }) async {
    try {
      if (kDebugMode) {
        print(
            'Fetching messages for conversation: $conversationId, page: $page, afterId: $afterId');
      }

      final data = await _api.getChatMessages(
        conversationId,
        page: page,
        afterId: afterId,
      );

      // The API returns { conversation_id, other_user, messages: [...] }
      final messagesList = data['messages'] as List<dynamic>? ?? [];

      if (kDebugMode) {
        print('Received ${messagesList.length} messages from server');
      }

      return messagesList
          .map((json) => ChatMessage.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      if (kDebugMode) {
        print('Error fetching messages: $e');
      }
      return [];
    }
  }

  /// Get messages with full metadata (including other_user info)
  Future<Map<String, dynamic>> getMessagesWithMetadata(
    String conversationId, {
    int page = 1,
    int? afterId,
  }) async {
    try {
      if (kDebugMode) {
        print(
            'Fetching messages with metadata for conversation: $conversationId, page: $page, afterId: $afterId');
      }

      final data = await _api.getChatMessages(
        conversationId,
        page: page,
        afterId: afterId,
      );

      return data;
    } catch (e) {
      if (kDebugMode) {
        print('Error fetching messages: $e');
      }
      return {};
    }
  }

  /// Get messages for a conversation between two users.
  ///
  /// This method first creates/gets the conversation, then fetches messages.
  /// For new conversations, this may return an empty list.
  @Deprecated('Use getMessagesByConversationId with a server conversation ID')
  Future<List<ChatMessage>> getMessages({
    required String studentId,
    required String recipientId,
    int page = 1,
  }) async {
    try {
      // First, create or get the conversation to get the server-assigned ID
      final recipientIdInt = int.tryParse(recipientId);
      if (recipientIdInt == null) {
        if (kDebugMode) {
          print('Invalid recipient ID: $recipientId');
        }
        return [];
      }

      final conversationData = await _api.createConversation(recipientIdInt);
      final conversationId = conversationData['id']?.toString();

      if (conversationId == null) {
        if (kDebugMode) {
          print('Could not get conversation ID');
        }
        return [];
      }

      return getMessagesByConversationId(conversationId, page: page);
    } catch (e) {
      if (kDebugMode) {
        print('Error fetching messages: $e');
      }
      return [];
    }
  }

  /// Send a message to a conversation.
  Future<ChatMessage> sendMessageToConversation({
    required String conversationId,
    required String senderId,
    required String message,
  }) async {
    // Check connectivity
    final connectivityResults = await _connectivity.checkConnectivity();
    final bool isOnline =
        !connectivityResults.contains(ConnectivityResult.none);

    // Create a pending message for optimistic UI
    final pendingMessage = _createPendingMessage(
      senderId: senderId,
      message: message,
    );

    // If offline, return pending message
    if (!isOnline) {
      if (kDebugMode) {
        print('Offline - returning pending message');
      }
      return pendingMessage;
    }

    try {
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

  /// Send a direct message to a recipient.
  /// Creates conversation if needed - this is the recommended way to send messages.
  Future<ChatMessage> sendDirectMessage({
    required int recipientId,
    required String senderId,
    required String message,
  }) async {
    // Check connectivity
    final connectivityResults = await _connectivity.checkConnectivity();
    final bool isOnline =
        !connectivityResults.contains(ConnectivityResult.none);

    // Create a pending message for optimistic UI
    final pendingMessage = _createPendingMessage(
      senderId: senderId,
      message: message,
    );

    // If offline, return pending message
    if (!isOnline) {
      if (kDebugMode) {
        print('Offline - returning pending message');
      }
      return pendingMessage;
    }

    try {
      final data = await _api.sendDirectMessage(recipientId, message);

      if (kDebugMode) {
        print('Send direct message response: $data');
      }

      return ChatMessage.fromJson(data);
    } catch (e) {
      if (kDebugMode) {
        print('Error sending direct message: $e');
      }
      // Return pending message on error for retry
      return pendingMessage;
    }
  }

  /// Legacy send message method for backward compatibility.
  @Deprecated('Use sendDirectMessage or sendMessageToConversation instead')
  Future<ChatMessage> sendMessage({
    required String studentId,
    required String recipientId,
    required String message,
  }) async {
    final recipientIdInt = int.tryParse(recipientId);
    if (recipientIdInt == null) {
      return _createPendingMessage(senderId: studentId, message: message);
    }

    return sendDirectMessage(
      recipientId: recipientIdInt,
      senderId: studentId,
      message: message,
    );
  }

  /// Create a new conversation or get existing one.
  /// Returns the conversation data including ID.
  Future<Map<String, dynamic>?> createOrGetConversation({
    required int recipientId,
    String? initialMessage,
  }) async {
    try {
      final data = await _api.createConversation(
        recipientId,
        message: initialMessage,
      );

      if (kDebugMode) {
        print('Create/get conversation response: $data');
      }

      return data;
    } catch (e) {
      if (kDebugMode) {
        print('Error creating conversation: $e');
      }
      return null;
    }
  }

  /// Mark a conversation as read.
  /// Returns the number of messages marked as read.
  Future<int> markAsRead({
    required String conversationId,
  }) async {
    try {
      return await _api.markConversationAsRead(conversationId);
    } catch (e) {
      if (kDebugMode) {
        print('Error marking as read: $e');
      }
      return 0;
    }
  }

  /// Get unread message count.
  Future<int> getUnreadCount() async {
    return await _api.getUnreadCount();
  }
}
