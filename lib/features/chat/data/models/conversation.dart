import 'contact.dart';

/// Model representing a chat conversation from the API.
///
/// Contains information about the other user in the conversation,
/// the last message, and the unread count.
class Conversation {
  final int id;
  final Contact otherUser;
  final String? lastMessage;
  final DateTime? lastMessageAt;
  final int unreadCount;
  final DateTime? updatedAt;

  const Conversation({
    required this.id,
    required this.otherUser,
    this.lastMessage,
    this.lastMessageAt,
    this.unreadCount = 0,
    this.updatedAt,
  });

  factory Conversation.fromJson(Map<String, dynamic> json) {
    // Parse other_user data
    final otherUserData = json['other_user'] as Map<String, dynamic>? ?? {};

    // Parse last_message_at
    DateTime? lastMsgAt;
    if (json['last_message_at'] != null) {
      try {
        lastMsgAt = DateTime.parse(json['last_message_at'].toString());
      } catch (_) {}
    }

    // Parse updated_at
    DateTime? updatedAt;
    if (json['updated_at'] != null) {
      try {
        updatedAt = DateTime.parse(json['updated_at'].toString());
      } catch (_) {}
    }

    return Conversation(
      id: json['id'] is int ? json['id'] : int.parse(json['id'].toString()),
      otherUser: Contact.fromJson(otherUserData),
      lastMessage: json['last_message'],
      lastMessageAt: lastMsgAt,
      unreadCount: json['unread_count'] ?? 0,
      updatedAt: updatedAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'other_user': otherUser.toJson(),
      'last_message': lastMessage,
      'last_message_at': lastMessageAt?.toIso8601String(),
      'unread_count': unreadCount,
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  @override
  String toString() =>
      'Conversation(id: $id, with: ${otherUser.name}, unread: $unreadCount)';
}
