import 'package:flutter/foundation.dart';
import 'package:flutter_chat_types/flutter_chat_types.dart' as types;

class ChatMessage {
  final String id;
  final String content;
  final String senderId;
  final String senderName;
  final DateTime timestamp;
  final bool isRead;
  final bool isPending;
  final bool isMine; // Whether the current user sent this message

  ChatMessage({
    required this.id,
    required this.content,
    required this.senderId,
    required this.senderName,
    required this.timestamp,
    this.isRead = false,
    this.isPending = false,
    this.isMine = false,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    if (kDebugMode) {
      print('Parsing message JSON: $json');
    }

    // Handle different field names and formats from WordPress API
    final String messageId = json['id'].toString();

    // Content can be in 'content' or 'message' field
    final String messageContent = json['content'] ?? json['message'] ?? '';

    // Sender ID can be in 'sender_id' field
    final String messageSenderId = json['sender_id'].toString();

    // Sender name can be in 'sender_name' field
    final String messageSenderName = json['sender_name'] ?? '';

    // Timestamp can be in 'timestamp' or 'created_at' field
    String timestampStr = json['timestamp'] ??
        json['created_at'] ??
        DateTime.now().toIso8601String();
    // Handle timestamp parsing - try without Z suffix first
    DateTime messageTimestamp;
    try {
      if (timestampStr.endsWith('Z')) {
        messageTimestamp = DateTime.parse(timestampStr).toLocal();
      } else {
        messageTimestamp = DateTime.parse('${timestampStr}Z').toLocal();
      }
    } catch (e) {
      messageTimestamp = DateTime.now();
    }

    // isRead can be boolean or integer (0/1)
    bool messageIsRead = false;
    if (json['is_read'] != null) {
      messageIsRead = json['is_read'] == 1 || json['is_read'] == true;
    }

    // isPending can be boolean or integer (0/1)
    bool messageIsPending = false;
    if (json['is_pending'] != null) {
      messageIsPending = json['is_pending'] == 1 || json['is_pending'] == true;
    }

    // isMine - the API provides this field to indicate if current user sent the message
    bool messageIsMine = false;
    if (json['is_mine'] != null) {
      messageIsMine = json['is_mine'] == 1 || json['is_mine'] == true;
    }

    return ChatMessage(
      id: messageId,
      content: messageContent,
      senderId: messageSenderId,
      senderName: messageSenderName,
      timestamp: messageTimestamp,
      isRead: messageIsRead,
      isPending: messageIsPending,
      isMine: messageIsMine,
    );
  }

  // Convert to flutter_chat_types Message. Provide the currentUserId so
  // the returned message.author.id will exactly match the Chat widget's
  // `user.id` when this message was sent by the current user. This
  // ensures the chat UI properly aligns/sizes/colors sent vs received bubbles.
  types.Message toUIMessage({required String currentUserId}) {
    // Use isMine from API if available, otherwise compare senderId
    final isMyMessage = isMine || (senderId == currentUserId);
    final authorId = isMyMessage ? currentUserId : senderId;

    // Determine status:
    // - pending: sending indicator
    // - For MY messages: isRead=true means seen (✓✓), isRead=false means sent (✓)
    // - For THEIR messages: always show as sent (no status icon needed)
    types.Status status;
    if (isPending) {
      status = types.Status.sending;
    } else if (isMyMessage) {
      status = isRead ? types.Status.seen : types.Status.sent;
    } else {
      status = types.Status.delivered; // No visible status for incoming
    }

    return types.TextMessage(
      author: types.User(
        id: authorId,
        firstName: senderName,
      ),
      id: id,
      text: content,
      createdAt: timestamp.millisecondsSinceEpoch,
      status: status,
    );
  }
}
