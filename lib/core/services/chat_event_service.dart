import 'dart:async';

/// Service to broadcast chat events across the app.
///
/// This enables components like ChatListPage to react to:
/// - Messages sent from ChatPage
/// - Incoming chat notifications
/// - Read status changes
class ChatEventService {
  // Singleton pattern
  static final ChatEventService _instance = ChatEventService._internal();
  factory ChatEventService() => _instance;
  ChatEventService._internal();

  // Stream controller for chat updates
  final _chatUpdateController = StreamController<ChatEvent>.broadcast();

  /// Stream that components can listen to for chat updates
  Stream<ChatEvent> get onChatUpdate => _chatUpdateController.stream;

  // Track currently active chat conversation
  String? _activeConversationId;
  String? _activeRecipientId;

  /// Set the currently active chat conversation (call when entering ChatPage)
  void setActiveChat({String? conversationId, String? recipientId}) {
    _activeConversationId = conversationId;
    _activeRecipientId = recipientId;
  }

  /// Clear the active chat (call when leaving ChatPage)
  void clearActiveChat() {
    _activeConversationId = null;
    _activeRecipientId = null;
  }

  /// Check if a chat is currently active with specific user/conversation
  bool isChatActive({String? conversationId, String? senderId}) {
    // Check if conversation ID matches
    if (conversationId != null && _activeConversationId != null) {
      return conversationId == _activeConversationId;
    }
    // Check if recipient/sender ID matches
    if (senderId != null && _activeRecipientId != null) {
      return senderId == _activeRecipientId;
    }
    return false;
  }

  /// Get the active conversation ID
  String? get activeConversationId => _activeConversationId;

  /// Get the active recipient ID
  String? get activeRecipientId => _activeRecipientId;

  /// Notify listeners that a message was sent
  void notifyMessageSent({
    required String recipientId,
    required String message,
  }) {
    _chatUpdateController.add(ChatEvent(
      type: ChatEventType.messageSent,
      recipientId: recipientId,
      message: message,
    ));
  }

  /// Notify listeners that a new message was received
  void notifyMessageReceived({
    required String senderId,
    String? message,
  }) {
    _chatUpdateController.add(ChatEvent(
      type: ChatEventType.messageReceived,
      senderId: senderId,
      message: message,
    ));
  }

  /// Notify listeners that messages were read
  void notifyMessagesRead({required String recipientId}) {
    _chatUpdateController.add(ChatEvent(
      type: ChatEventType.messagesRead,
      recipientId: recipientId,
    ));
  }

  /// Notify listeners to refresh all conversations
  void notifyRefresh() {
    _chatUpdateController.add(ChatEvent(type: ChatEventType.refresh));
  }

  /// Dispose resources
  void dispose() {
    _chatUpdateController.close();
  }
}

/// Types of chat events
enum ChatEventType {
  messageSent,
  messageReceived,
  messagesRead,
  refresh,
}

/// Chat event data
class ChatEvent {
  final ChatEventType type;
  final String? recipientId;
  final String? senderId;
  final String? message;

  ChatEvent({
    required this.type,
    this.recipientId,
    this.senderId,
    this.message,
  });
}
